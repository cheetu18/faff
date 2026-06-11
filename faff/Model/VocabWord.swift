//
//  VocabWord.swift
//  faff
//
//  Created by kyle reddy  on 6/26/24.
//

import Foundation
import SwiftData

@Model
class VocabWord : Identifiable {
    var word: String
    var definition: String?
    var context: String?
    var phonetic: String?
    var phoneticUrl: String?
    var tracked: Bool
    /// Cached lookup result (encoded WordLookup JSON) so definitions load
    /// instantly and offline after the first fetch. Stored as a plain String
    /// to keep the SwiftData schema simple (lightweight migration only).
    var cachedLookupJSON: String?
    var cachedAt: Date?

    init(word: String,
         definition: String? = nil,
         context: String? = nil,
         tracked: Bool = false,
         phonetic: String? = nil,
         phoneticUrl: String? = nil,
         cachedLookupJSON: String? = nil,
         cachedAt: Date? = nil) {
        self.word = word
        self.definition = definition
        self.context = context
        self.tracked = tracked
        self.phonetic = phonetic
        self.phoneticUrl = phoneticUrl
        self.cachedLookupJSON = cachedLookupJSON
        self.cachedAt = cachedAt
    }

    func toggle(){
        self.tracked = !self.tracked
    }
}

extension VocabWord {
    /// Decode the cached lookup, if present.
    func cachedLookup() -> WordLookup? {
        guard
            let json = cachedLookupJSON,
            let data = json.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(WordLookup.self, from: data)
    }

    /// Encode and store a lookup result for instant reuse.
    func storeLookup(_ lookup: WordLookup) {
        guard
            let data = try? JSONEncoder().encode(lookup),
            let json = String(data: data, encoding: .utf8)
        else { return }
        cachedLookupJSON = json
        cachedAt = Date()
    }
}
