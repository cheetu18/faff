//
//  Item.swift
//  faff
//
//  Created by kyle reddy  on 6/20/24.
//

import Foundation
import SwiftData

final class Item {
 //   @Attribute(.unique) let title: String
     let title: String
     let type: mediaType
    //private let type: mediaType
    //private let createDate: Date
     let createDate: Date
     var wordList: [String]
   //default selection of a
    init(title: String, type: mediaType,  createDate: Date, wordList: [String]) {
        self.title = title
        self.type = type
        self.createDate = createDate
        self.wordList = wordList
        
    }
  
}

   

func mediaSymbol(_ type: mediaType) -> String {
    switch type {
    case .Book:
        return "book.fill"
    case .Podcast:
        return "mic.fill"
    case .Movie:
        return "film.fill"
    case .Other:
        return "newspaper.fill"
    }
}
    
   
    

