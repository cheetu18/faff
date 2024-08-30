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
    
    init(word: String, definition: String? = nil, context: String? = nil) {
        self.word = word
        self.definition = definition
        self.context = context
    }
    
}
