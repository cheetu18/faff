//
//  DictionaryService.swift
//  faff
//
//  Created by kyle reddy  on 9/11/24.
//
//  Tiered word lookup. Real words resolve via the Free Dictionary, Wiktionary,
//  and Datamuse APIs; invented or franchise-specific terms (e.g. "Lisan
//  al-Gaib") fall back to the list's Fandom wiki, then Wikipedia.
//
//  Every source is either lexicographic or an encyclopedia with active
//  moderation. Unmoderated user-generated dictionaries are deliberately not
//  consulted, so the app cannot surface objectionable third-party content.
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

    /// Resolve a term, preferring dictionary definitions over encyclopedia lore.
    /// `fandomWiki` is an optional wiki subdomain (e.g. "dune") tied to the list.
    ///
    /// Sources within a phase are fetched **concurrently** but awaited in
    /// priority order, so the result is still the best available source rather
    /// than whichever server happened to answer first. Latency is therefore the
    /// slowest source consulted, not the sum of all of them — the previous
    /// serial chain could stack five timeouts back to back.
    static func lookup(term: String, fandomWiki: String? = nil) async throws -> WordLookup {
        let query = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw DictionaryError.notFound(term) }

        // Phase 1: real-word dictionaries.
        async let free = try? freeDictionary(query)
        async let wikt = try? wiktionary(query)
        async let datam = try? datamuse(query)

        if let result = await free { return result }
        if let result = await wikt { return result }
        if let result = await datam { return result }

        // Phase 2: lore sources, only once no dictionary recognized the term.
        let wiki = fandomWiki?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        async let fan = wiki.isEmpty ? nil : (try? fandom(query, wiki: wiki))
        async let wikip = try? wikipedia(query)

        if let result = await fan { return result }
        if let result = await wikip { return result }

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

        let (data, response) = try await get(url, timeout: preferredSourceTimeout)
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

    /// Look a term up on a Fandom wiki.
    ///
    /// This deliberately does *not* use `prop=extracts`. That is the TextExtracts
    /// extension, which Fandom does not install — wikis reject it with
    /// "Unrecognized value for parameter prop", so the old implementation could
    /// never find an extract and always returned nil.
    ///
    /// Nor does it lead with `list=search`: a wiki's own search frequently fails
    /// to rank the exact page first (searching dune.fandom.com for "Kwisatz
    /// Haderach" returns "Paul Atreides/Featured"). Fetching the title directly
    /// is both more accurate and one request shorter, with search kept only as
    /// a fallback.
    private static func fandom(_ term: String, wiki: String) async throws -> WordLookup? {
        let host = wiki.contains(".") ? wiki : "\(wiki).fandom.com"

        // `action=parse` needs a near-exact title and only auto-capitalizes the
        // first letter, so "kwisatz haderach" 404s where "Kwisatz Haderach"
        // resolves. Words arrive from the scanner and keyboard in any case.
        for title in titleCandidates(term) {
            if let lookup = try? await fandomPage(title: title, host: host, term: term) {
                return lookup
            }
        }

        // Fallback: let the wiki's search suggest a title, then parse that.
        if let title = try? await fandomSearchTitle(term, host: host),
           let lookup = try? await fandomPage(title: title, host: host, term: term) {
            return lookup
        }
        return nil
    }

    /// Casing variants to try for a wiki page title, most likely first.
    private static func titleCandidates(_ term: String) -> [String] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var candidates = [trimmed]

        // "kwisatz haderach" -> "Kwisatz Haderach"
        let titleCased = trimmed
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
        if !candidates.contains(titleCased) { candidates.append(titleCased) }

        // "gom jabbar" -> "Gom jabbar" (wikis vary on sentence vs title case)
        let sentenceCased = trimmed.prefix(1).uppercased() + trimmed.dropFirst()
        if !candidates.contains(sentenceCased) { candidates.append(sentenceCased) }

        return candidates
    }

    /// Fetch and parse the lead section of a specific wiki page.
    private static func fandomPage(title: String, host: String, term: String) async throws -> WordLookup? {
        var components = URLComponents(string: "https://\(host)/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "parse"),
            URLQueryItem(name: "page", value: title),
            URLQueryItem(name: "section", value: "0"),   // lead section only
            URLQueryItem(name: "prop", value: "text"),
            URLQueryItem(name: "redirects", value: "1"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components?.url else { return nil }

        let (data, response) = try await get(url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return nil
        }

        struct ParseResponse: Decodable {
            struct Parse: Decodable {
                struct Text: Decodable {
                    let value: String
                    enum CodingKeys: String, CodingKey { case value = "*" }
                }
                let title: String
                let text: Text
            }
            // Absent when the page does not exist (`error.code == "missingtitle"`).
            let parse: Parse?
        }

        guard
            let decoded = try? JSONDecoder().decode(ParseResponse.self, from: data),
            let parse = decoded.parse,
            let prose = leadProse(fromHTML: parse.text.value)
        else { return nil }

        return WordLookup(term: term,
                          sourceLabel: wikiLabel(for: host),
                          isLore: true,
                          content: .prose(concise(prose)),
                          phonetic: nil,
                          phoneticAudioURL: nil)
    }

    /// Ask the wiki's search for a plausible title, rejecting unrelated hits.
    private static func fandomSearchTitle(_ term: String, host: String) async throws -> String? {
        var components = URLComponents(string: "https://\(host)/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "list", value: "search"),
            URLQueryItem(name: "srsearch", value: term),
            URLQueryItem(name: "srlimit", value: "5"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components?.url else { return nil }

        let (data, response) = try await get(url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return nil
        }

        struct SearchResponse: Decodable {
            struct Query: Decodable {
                struct Hit: Decodable { let title: String }
                let search: [Hit]
            }
            let query: Query?
        }

        guard let decoded = try? JSONDecoder().decode(SearchResponse.self, from: data) else {
            return nil
        }
        // Search ranks poorly, so only accept a hit whose title actually
        // corresponds to the queried term.
        return decoded.query?.search
            .first { titlesMatch(query: term, resultTitle: $0.title) }?
            .title
    }

    /// "dune.fandom.com" → "Dune Wiki".
    private static func wikiLabel(for host: String) -> String {
        let name = host
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: ".fandom.com", with: "")
            .capitalized
        return name.hasSuffix("Wiki") ? name : "\(name) Wiki"
    }

    /// Pull the first real prose paragraph out of a parsed lead section.
    ///
    /// The lead section is not just prose: it opens with infoboxes, canon
    /// banners, and image captions. Non-prose containers are removed first,
    /// then hatnotes are filtered by phrasing — an image caption can otherwise
    /// look like a definition because it mentions the subject by name.
    private static func leadProse(fromHTML html: String) -> String? {
        var stripped = html
        for tag in ["table", "figure", "aside", "style", "sup", "ol", "ul"] {
            stripped = stripped.replacingOccurrences(
                of: "<\(tag)\\b[\\s\\S]*?</\(tag)>",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
        }

        let hatnotePattern = "(this article|refers to elements|pages for this subject|for other uses|may refer to|disambiguat|see also|^redirects here)"

        for paragraph in matches(of: "<p\\b[^>]*>([\\s\\S]*?)</p>", in: stripped) {
            var text = stripHTML(paragraph)
            // Drop citation markers such as "[1]".
            text = text.replacingOccurrences(of: "\\[\\d+\\]", with: "", options: .regularExpression)
            text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard text.count >= 50 else { continue }
            let opening = String(text.prefix(120))
            if opening.range(of: hatnotePattern, options: [.regularExpression, .caseInsensitive]) != nil {
                continue
            }
            return text
        }
        return nil
    }

    /// First capture group of every match, in order.
    private static func matches(of pattern: String, in string: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }
        let range = NSRange(string.startIndex..., in: string)
        return regex.matches(in: string, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let captured = Range(match.range(at: 1), in: string) else { return nil }
            return String(string[captured])
        }
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

    /// WordNet-backed lookup via Datamuse. This replaces the former Urban
    /// Dictionary tier: Datamuse serves curated lexicographic data rather than
    /// unmoderated user submissions, so it carries no objectionable-content
    /// risk, and its spelled-like query resolves inflected forms that the
    /// exact-match dictionaries above miss.
    private static func datamuse(_ term: String) async throws -> WordLookup? {
        var components = URLComponents(string: "https://api.datamuse.com/words")
        components?.queryItems = [
            URLQueryItem(name: "sp", value: term),   // spelled like
            URLQueryItem(name: "md", value: "dp"),   // definitions + parts of speech
            URLQueryItem(name: "max", value: "1")
        ]
        guard let url = components?.url else { return nil }

        let (data, response) = try await get(url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return nil
        }

        struct DatamuseWord: Codable {
            let word: String
            let defs: [String]?
        }

        // Require an exact spelling match, not the loose containment check the
        // wiki sources use. Datamuse falls back to fuzzy matches when the
        // spelled-like query misses — "sietch" comes back as "sketch" — and a
        // substring test would happily accept a longer word that contains the
        // query ("ice" matching "voice"), attaching a confidently wrong
        // definition to the user's word.
        guard
            let results = try? JSONDecoder().decode([DatamuseWord].self, from: data),
            let match = results.first,
            let defs = match.defs, !defs.isEmpty,
            normalizeTitle(match.word) == normalizeTitle(term)
        else { return nil }

        // Each entry is "<pos>\t<definition>", e.g. "adj\tpresent everywhere".
        var byPartOfSpeech: [String: [Definition]] = [:]
        var order: [String] = []
        for entry in defs {
            let parts = entry.components(separatedBy: "\t")
            let pos = parts.count > 1 ? expandPartOfSpeech(parts[0]) : ""
            let text = (parts.count > 1 ? parts.dropFirst().joined(separator: " ") : entry)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if byPartOfSpeech[pos] == nil { order.append(pos) }
            byPartOfSpeech[pos, default: []].append(Definition(definition: text, example: nil))
        }

        let meanings = order.compactMap { pos -> Meaning? in
            guard let defs = byPartOfSpeech[pos] else { return nil }
            return Meaning(partOfSpeech: pos, definitions: defs)
        }
        guard !meanings.isEmpty else { return nil }

        return WordLookup(term: term, sourceLabel: "Dictionary", isLore: false,
                          content: .definitions(meanings),
                          phonetic: nil, phoneticAudioURL: nil)
    }

    /// Datamuse abbreviates parts of speech; spell them out for display.
    private static func expandPartOfSpeech(_ abbreviation: String) -> String {
        switch abbreviation {
        case "n":   return "noun"
        case "v":   return "verb"
        case "adj": return "adjective"
        case "adv": return "adverb"
        default:    return ""
        }
    }

    // MARK: Networking helper

    /// Wikimedia and Fandom REST endpoints ask for a descriptive User-Agent.
    static let userAgent = "faff-vocab-app/1.0 (https://faffapp.com)"

    /// Default ceiling for a source that we are willing to wait on.
    private static let standardTimeout: TimeInterval = 6

    /// Tighter ceiling for `api.dictionaryapi.dev`. It is an unaffiliated
    /// hobby API with no SLA, and it is the highest-priority source only
    /// because it is the one that supplies phonetics and pronunciation audio.
    /// When it is healthy it answers in a few hundred milliseconds; when it is
    /// down it black-holes the request entirely. Keeping its budget small means
    /// a healthy day still gets the richer entry, while an outage costs a short
    /// pause instead of holding the whole lookup hostage.
    private static let preferredSourceTimeout: TimeInterval = 2.5

    private static func get(_ url: URL,
                            timeout: TimeInterval = standardTimeout) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout
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
