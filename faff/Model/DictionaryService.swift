//
//  DictionaryService.swift
//  faff
//
//  Created by kyle reddy  on 9/11/24.
//

import Foundation

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

enum DictionaryError: LocalizedError {
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let word):
            return "No dictionary definition found for \u{201C}\(word)\u{201D}."
        }
    }
}

class DictionaryService {
    static func fetchDefinition(for word: String) async throws -> DictionaryEntry {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)

        // Percent-encode so multi-word / accented entries produce a valid URL.
        guard
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)")
        else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        // On a miss the API returns 404 with a JSON *object* (not an array),
        // which is why decoding [DictionaryEntry] used to fail. Treat any
        // non-success status as "not found".
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw DictionaryError.notFound(trimmed)
        }

        do {
            let entries = try JSONDecoder().decode([DictionaryEntry].self, from: data)
            guard let entry = entries.first else {
                throw DictionaryError.notFound(trimmed)
            }
            return entry
        } catch is DecodingError {
            // Body wasn't the expected array (e.g. the error object slipped
            // through with a 200). Surface a clean message instead of a
            // confusing decoding error.
            throw DictionaryError.notFound(trimmed)
        }
    }
}
