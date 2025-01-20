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
    
    init(word: String, definition: String? = nil, context: String? = nil, tracked: Bool = false , phonetic:String?  = nil, phoneticUrl :String? = nil) {
        self.word = word
        self.definition = definition
        self.context = context
        self.tracked = tracked
        self.phonetic = phonetic
        self.phoneticUrl = phoneticUrl
    }
   
    func toggle(){
        self.tracked = !self.tracked
    }
}
