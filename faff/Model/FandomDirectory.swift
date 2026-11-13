//
//  FandomDirectory.swift
//  faff
//
//  Resolves a media title to a Fandom wiki so the user does not have to know
//  or type a subdomain.
//
//  Fandom has no public cross-wiki discovery endpoint (the old
//  `Search/CrossWiki` route returns 403, and MediaWiki's `list=wikidiscover`
//  is not installed), so detection works the other way around: derive
//  candidate subdomains from the title and ask each one whether it exists.
//  In practice this resolves most titles on the first candidate, because
//  Fandom subdomains are overwhelmingly the title with the spaces removed.
//

import Foundation

/// A Fandom wiki that was confirmed to exist.
struct DetectedWiki: Equatable, Sendable {
    /// Canonical subdomain, e.g. "lotr".
    let slug: String
    /// Human-readable name, e.g. "The One Wiki to Rule Them All".
    let name: String
}

enum FandomDirectory {

    /// Probes are best-effort background work, so they get a tight budget.
    private static let probeTimeout: TimeInterval = 4

    /// Find the wiki for a title, or `nil` if no candidate subdomain exists.
    static func detect(title: String) async -> DetectedWiki? {
        for slug in candidateSlugs(from: title) {
            if Task.isCancelled { return nil }
            if let wiki = await validate(slug: slug) { return wiki }
        }
        return nil
    }

    // MARK: Candidate generation

    /// Subdomain guesses for a title, most likely first.
    ///
    /// "Dune" -> ["dune"], "The Hobbit" -> ["thehobbit", "hobbit"],
    /// "Star Wars: A New Hope" -> ["starwars", "starwarsanewhope"].
    static func candidateSlugs(from title: String) -> [String] {
        var candidates: [String] = []

        func add(_ slug: String) {
            // Single characters are never real wikis and cost a request.
            guard slug.count >= 2, !candidates.contains(slug) else { return }
            candidates.append(slug)
        }

        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // A franchise wiki is usually named for the series, not the instalment,
        // so try the part before any subtitle first.
        let subtitleSeparators = CharacterSet(charactersIn: ":(-\u{2013}\u{2014}")
        let mainTitle = trimmed.components(separatedBy: subtitleSeparators).first ?? trimmed

        for variant in [mainTitle, trimmed] {
            let words = slugWords(variant)
            guard !words.isEmpty else { continue }
            add(words.joined())
            // Wikis commonly drop a leading article: "thehobbit" vs "hobbit".
            if words.count > 1, ["the", "a", "an"].contains(words[0]) {
                add(words.dropFirst().joined())
            }
        }

        // Cap the fan-out; beyond a few guesses the hit rate is not worth the
        // requests.
        return Array(candidates.prefix(4))
    }

    private static func slugWords(_ string: String) -> [String] {
        string
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    // MARK: Validation

    private struct SiteInfoResponse: Decodable {
        struct Query: Decodable {
            struct General: Decodable {
                let sitename: String?
                let server: String?
            }
            let general: General
        }
        let query: Query
    }

    /// Ask a candidate subdomain to identify itself. Returns `nil` when no wiki
    /// lives there.
    static func validate(slug: String) async -> DetectedWiki? {
        var components = URLComponents(string: "https://\(slug).fandom.com/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "meta", value: "siteinfo"),
            URLQueryItem(name: "siprop", value: "general"),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue(DictionaryService.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = probeTimeout

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            let http = response as? HTTPURLResponse,
            (200...299).contains(http.statusCode),
            let decoded = try? JSONDecoder().decode(SiteInfoResponse.self, from: data),
            let name = decoded.query.general.sitename, !name.isEmpty
        else { return nil }

        // Aliases 301 to their canonical host (thehobbit -> lotr). URLSession
        // follows that, and `server` reports where we actually landed, so the
        // slug we persist is the real one.
        let canonical = decoded.query.general.server.flatMap(canonicalSlug) ?? slug
        return DetectedWiki(slug: canonical, name: name)
    }

    /// "https://lotr.fandom.com" -> "lotr".
    private static func canonicalSlug(_ server: String) -> String? {
        guard let host = URLComponents(string: server)?.host
                ?? URLComponents(string: "https://\(server)")?.host else {
            return nil
        }
        guard host.hasSuffix(".fandom.com") else { return host }
        let slug = host.replacingOccurrences(of: ".fandom.com", with: "")
        return slug.isEmpty ? nil : slug
    }
}
