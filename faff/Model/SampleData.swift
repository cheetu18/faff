//
//  SampleData.swift
//  faff
//
//  Created by kyle reddy  on 6/26/24.
//

import Foundation
import SwiftData

struct SampleData {
    static func generateSampleData(modelContext: ModelContext) {
        let books = [
            MediaItem(title: "Dune", creator: "Frank Herbert", mediaType: .book),
            MediaItem(title: "1984", creator: "George Orwell", mediaType: .book),
            MediaItem(title: "The Hobbit", creator: "J.R.R. Tolkien", mediaType: .book)
        ]
        
        let movies = [
            MediaItem(title: "Inception", creator: "Christopher Nolan", mediaType: .movie),
            MediaItem(title: "The Matrix", creator: "Wachowski Sisters", mediaType: .movie),
            MediaItem(title: "Pulp Fiction", creator: "Quentin Tarantino", mediaType: .movie)
        ]
        
        let podcasts = [
            MediaItem(title: "Serial", creator: "Sarah Koenig", mediaType: .podcast),
            MediaItem(title: "Radiolab", creator: "WNYC Studios", mediaType: .podcast),
            MediaItem(title: "This American Life", creator: "Ira Glass", mediaType: .podcast)
        ]
        
        for media in books + movies + podcasts {
            modelContext.insert(media)
        }
        
        do {
            try modelContext.save()
            print("Sample data saved successfully")
        } catch {
            print("Failed to save sample data: \(error)")
        }
    }
}
