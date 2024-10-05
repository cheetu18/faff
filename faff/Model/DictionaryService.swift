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

class DictionaryService {
    static func fetchDefinition(for word: String) async throws -> DictionaryEntry {
        let urlString = "https://api.dictionaryapi.dev/api/v2/entries/en/\(word)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let entries = try JSONDecoder().decode([DictionaryEntry].self, from: data)
        
        guard let entry = entries.first else {
            throw NSError(domain: "DictionaryService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No definition found"])
        }
        
        return entry
    }
}
