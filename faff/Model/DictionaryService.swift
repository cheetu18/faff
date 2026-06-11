//
//  DictionaryService.swift
//  faff
//
//  Created by kyle reddy  on 9/11/24.
//
//  Tiered word lookup. Real words resolve via the Free Dictionary / Wiktionary
//  APIs; invented or franchise-specific terms (e.g. "Lisan al-Gaib") fall back
//  to the list's Fandom wiki, then Wikipedia, then Urban Dictionary.
//

import Foundation

// MARK: - Structured dictionary models (Free Dictionary API shape)

struct DictionaryEntry: Codable {
    let word: String
    let phonetic: String?
    let phonetics: [Phonetic]
    let meanings: [Meaning]
}

struct Phonetic: Codable {
    let text: String?
    let audio: String?
}

struct Meaning: Codable {
    let partOfSpeech: String
    let definitions: [Definition]
}

struct Definition: Codable {
    let definition: String
    let example: String?
}

// MARK: - Unified lookup result

/// A normalized result that can carry either structured definitions or a block
/// of encyclopedia/lore prose, plus the human-readable source it came from.
struct WordLookup: Codable {
    enum Content: Codable {
        case definitions([Meaning])
        case prose(String)
    }

    let term: String
    let sourceLabel: String      // e.g. "Dictionary", "Dune Wiki", "Wikipedia"
    let isLore: Bool             // true for wiki/encyclopedia sources
    let content: Content
    let phonetic: String?
    let phoneticAudioURL: String?
}

enum DictionaryError: LocalizedError {
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let word):
            return "No definition or entry found for \u{201C}\(word)\u{201D}."
        }
    }
}

// MARK: - Service

class DictionaryService {

    /// Try each source in order and return the first usable result.
    /// `fandomWiki` is an optional wiki subdomain (e.g. "dune") tied to the list.
    static func lookup(term: String, fandomWiki: String? = nil) async throws -> WordLookup {
        let query = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw DictionaryError.notFound(term) }

        if let result = try? await freeDictionary(query) { return result }
        if let result = try? await wiktionary(query) { return result }

        if let wiki = fandomWiki?.trimmingCharacters(in: .whitespacesAndNewlines),
           !wiki.isEmpty,
           let result = try? await fandom(query, wiki: wiki) {
            return result
        }

        if let result = try? await wikipedia(query) { return result }
        if let result = try? await urbanDictionary(query) { return result }

        throw DictionaryError.notFound(query)
    }

    /// Backwards-compatible structured lookup (kept for any older callers).
    static func fetchDefinition(for word: String) async throws -> DictionaryEntry {
        guard let entry = try await freeDictionaryEntry(word) else {
            throw DictionaryError.notFound(word)
        }
        return entry
    }

    // MARK: Providers

    private static func freeDictionary(_ term: String) async throws -> WordLookup? {
        guard let entry = try await freeDictionaryEntry(term), !entry.meanings.isEmpty else {
            return nil
        }
        let audio = entry.phonetics.first(where: { !($0.audio?.isEmpty ?? true) })?.audio
        return WordLookup(
            term: term,
            sourceLabel: "Dictionary",
            isLore: false,
            content: .definitions(entry.meanings),
            phonetic: entry.phonetic ?? entry.phonetics.first?.text,
            phoneticAudioURL: audio
        )
    }

    private static func freeDictionaryEntry(_ term: String) async throws -> DictionaryEntry? {
        guard
            let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)")
        else { return nil }

        let (data, response) = try await get(url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return nil
        }
        guard
            let entries = try? JSONDecoder().decode([DictionaryEntry].self, from: data),
            let entry = entries.first
        else { return nil }
        return entry
    }

    private static func wiktionary(_ term: String) async throws -> WordLookup? {
        guard
            let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "https://en.wiktionary.org/api/rest_v1/page/definition/\(encoded)")
        else { return nil }

        let (data, response) = try await get(url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return nil
        }

        struct Sense: Codable {
            let partOfSpeech: String?
            let definitions: [Def]
        }
        struct Def: Codable {
            let definition: String
            let examples: [String]?
        }

        guard
            let map = try? JSONDecoder().decode([String: [Sense]].self, from: data),
            let english = map["en"], !english.isEmpty
        else { return nil }

        let meanings: [Meaning] = english.compactMap { sense in
            let defs: [Definition] = sense.definitions.compactMap { d in
                let text = stripHTML(d.definition)
                guard !text.isEmpty else { return nil }
                return Definition(definition: text, example: d.examples?.first.map(stripHTML))
            }
            guard !defs.isEmpty else { return nil }
            return Meaning(partOfSpeech: sense.partOfSpeech ?? "", definitions: defs)
        }

        guard !meanings.isEmpty else { return nil }
        return WordLookup(term: term, sourceLabel: "Wiktionary", isLore: false,
                          content: .definitions(meanings),
                          phonetic: nil, phoneticAudioURL: nil)
    }

    private static func fandom(_ term: String, wiki: String) async throws -> WordLookup? {
        let host = wiki.contains(".") ? wiki : "\(wiki).fandom.com"
        var components = URLComponents(string: "https://\(host)/api.php")
        // Use the search generator so casing/near-matches resolve to the right
        // page (e.g. "kwisatz haderach" -> "Kwisatz Haderach").
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: term),
            URLQueryItem(name: "gsrlimit", value: "1"),
            URLQueryItem(name: "prop", value: "extracts"),
            URLQueryItem(name: "exintro", value: "1"),
            URLQueryItem(name: "explaintext", value: "1"),
            URLQueryItem(name: "redirects", value: "1"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components?.url else { return nil }

        let (data, response) = try await get(url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return nil
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let query = json["query"] as? [String: Any],
            let pages = query["pages"] as? [String: Any]
        else { return nil }

        for (_, value) in pages {
            guard
                let page = value as? [String: Any],
                let title = page["title"] as? String,
                let extract = (page["extract"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                !extract.isEmpty,
                titlesMatch(query: term, resultTitle: title)
            else { continue }

            let name = host
                .replacingOccurrences(of: ".fandom.com", with: "")
                .replacingOccurrences(of: "https://", with: "")
                .capitalized
            return WordLookup(term: term, sourceLabel: "\(name) Wiki", isLore: true,
                              content: .prose(concise(extract)),
                              phonetic: nil, phoneticAudioURL: nil)
        }
        return nil
    }

    private static func wikipedia(_ term: String) async throws -> WordLookup? {
        guard
            let encoded = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)?redirect=true")
        else { return nil }

        let (data, response) = try await get(url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return nil
        }

        struct Summary: Codable {
            let title: String?
            let extract: String?
            let type: String?
        }
        guard
            let summary = try? JSONDecoder().decode(Summary.self, from: data),
            summary.type != "disambiguation",
            let extract = summary.extract?.trimmingCharacters(in: .whitespacesAndNewlines),
            !extract.isEmpty
        else { return nil }

        // Wikipedia frequently redirects a niche term to a broad article
        // (e.g. "Kwisatz Haderach" -> "Bene Gesserit"). Reject the result when
        // the resolved title isn't actually about the word we asked for.
        if let title = summary.title, !titlesMatch(query: term, resultTitle: title) {
            return nil
        }

        return WordLookup(term: term, sourceLabel: "Wikipedia", isLore: true,
                          content: .prose(concise(extract)),
                          phonetic: nil, phoneticAudioURL: nil)
    }

    private static func urbanDictionary(_ term: String) async throws -> WordLookup? {
        var components = URLComponents(string: "https://api.urbandictionary.com/v0/define")
        components?.queryItems = [URLQueryItem(name: "term", value: term)]
        guard let url = components?.url else { return nil }

        let (data, response) = try await get(url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return nil
        }

        struct UDResponse: Codable { let list: [UDItem] }
        struct UDItem: Codable {
            let definition: String
            let example: String?
            let thumbs_up: Int?
        }

        guard
            let resp = try? JSONDecoder().decode(UDResponse.self, from: data),
            let top = resp.list.max(by: { ($0.thumbs_up ?? 0) < ($1.thumbs_up ?? 0) })
        else { return nil }

        let definition = stripBrackets(top.definition)
        guard !definition.isEmpty else { return nil }
        let example = top.example
            .map(stripBrackets)
            .flatMap { $0.isEmpty ? nil : $0 }

        let meaning = Meaning(
            partOfSpeech: "slang",
            definitions: [Definition(definition: definition, example: example)]
        )
        return WordLookup(term: term, sourceLabel: "Urban Dictionary", isLore: true,
                          content: .definitions([meaning]),
                          phonetic: nil, phoneticAudioURL: nil)
    }

    // MARK: Networking helper

    private static func get(_ url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        // Wikimedia REST endpoints ask for a descriptive User-Agent.
        request.setValue("faff-vocab-app/1.0 (https://faff.world)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12
        return try await URLSession.shared.data(for: request)
    }

    // MARK: Text cleanup

    private static func stripHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Urban Dictionary wraps cross-referenced terms in [square brackets].
    private static func stripBrackets(_ string: String) -> String {
        string
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Shorten lore prose to the first couple of sentences (with a hard cap)
    /// so entries stay readable instead of dumping a whole article.
    private static func concise(_ text: String, maxSentences: Int = 2, maxChars: Int = 300) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return cleaned }

        var result = ""
        var sentences = 0
        for ch in cleaned {
            result.append(ch)
            if ch == "." || ch == "!" || ch == "?" {
                sentences += 1
                if sentences >= maxSentences { break }
            }
        }

        var trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > maxChars {
            let end = trimmed.index(trimmed.startIndex, offsetBy: maxChars)
            trimmed = String(trimmed[..<end])
            if let lastSpace = trimmed.lastIndex(of: " ") {
                trimmed = String(trimmed[..<lastSpace])
            }
            trimmed += "\u{2026}"
        }
        return trimmed
    }

    /// Normalize a title/term to letters+digits only for loose comparison.
    private static func normalizeTitle(_ s: String) -> String {
        s.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    /// Whether a resolved page title is plausibly about the queried word, used
    /// to reject redirects that land on an unrelated, broader article.
    private static func titlesMatch(query: String, resultTitle: String) -> Bool {
        let q = normalizeTitle(query)
        let t = normalizeTitle(resultTitle)
        guard !q.isEmpty, !t.isEmpty else { return false }
        return t == q || t.contains(q) || q.contains(t)
    }
}
