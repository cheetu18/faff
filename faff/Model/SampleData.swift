//
//  SampleData.swift
//  faff
//
//  Created by kyle reddy  on 6/26/24.
//

import Foundation
import SwiftData

import Foundation
import SwiftData

struct SampleData {
    static func generateSampleData(modelContext: ModelContext) {
        // Book vocab words
        let duneWords = [
            VocabWord(word: "melange"),
            VocabWord(word: "sietch"),
            VocabWord(word: "kwisatz haderach"),
            VocabWord(word: "gom jabbar"),
            VocabWord(word: "crysknife"),
            VocabWord(word: "ornithopter")
        ]
        
        let orwellWords = [
            VocabWord(word: "doublethink"),
            VocabWord(word: "thoughtcrime"),
            VocabWord(word: "newspeak"),
            VocabWord(word: "telescreen"),
            VocabWord(word: "Ministry of Truth"),
            VocabWord(word: "unperson")
        ]
        
        let hobbitWords = [
            VocabWord(word: "elevenses"),
            VocabWord(word: "mathom"),
            VocabWord(word: "smial"),
            VocabWord(word: "hobbitry"),
            VocabWord(word: "mathom-house"),
            VocabWord(word: "tookish")
        ]
        
        let prideWords = [
            VocabWord(word: "entailment"),
            VocabWord(word: "connexion"),
            VocabWord(word: "solicitude"),
            VocabWord(word: "perturbation"),
            VocabWord(word: "countenance")
        ]
        
        let neuromancerWords = [
            VocabWord(word: "cyberspace"),
            VocabWord(word: "matrix"),
            VocabWord(word: "construct"),
            VocabWord(word: "ice"),
            VocabWord(word: "flatline")
        ]
        
        // Add context to some words
        duneWords[0].context = "The spice melange is essential for space navigation"
        duneWords[4].context = "A sacred knife made from a sandworm's tooth"
        orwellWords[0].context = "The power of holding two contradictory beliefs simultaneously"
        orwellWords[5].context = "Someone who has been erased from existence and memory"
        hobbitWords[0].context = "A hobbit's second breakfast, served at 11:00"
        hobbitWords[5].context = "Having adventurous qualities like a Took"
        prideWords[0].context = "A legal term regarding inheritance of property"
        neuromancerWords[3].context = "Intrusion Countermeasures Electronics - security software"

        let books = [
            MediaItem(title: "Dune", creator: "Frank Herbert", mediaType: .book, learnedWords: duneWords),
            MediaItem(title: "1984", creator: "George Orwell", mediaType: .book, learnedWords: orwellWords),
            MediaItem(title: "The Hobbit", creator: "J.R.R. Tolkien", mediaType: .book, learnedWords: hobbitWords),
            MediaItem(title: "Pride and Prejudice", creator: "Jane Austen", mediaType: .book, learnedWords: prideWords),
            MediaItem(title: "Neuromancer", creator: "William Gibson", mediaType: .book, learnedWords: neuromancerWords),
            MediaItem(title: "The Great Gatsby", creator: "F. Scott Fitzgerald", mediaType: .book)
        ]
        
        // Movie vocab words
        let inceptionWords = [
            VocabWord(word: "limbo"),
            VocabWord(word: "totem"),
            VocabWord(word: "architect"),
            VocabWord(word: "kick"),
            VocabWord(word: "projection"),
            VocabWord(word: "subconscious security")
        ]
        
        let matrixWords = [
            VocabWord(word: "neural interface"),
            VocabWord(word: "sentient program"),
            VocabWord(word: "redpill"),
            VocabWord(word: "blueprint"),
            VocabWord(word: "residual self-image"),
            VocabWord(word: "zion")
        ]
        
        let alienWords = [
            VocabWord(word: "xenomorph"),
            VocabWord(word: "hypersleep"),
            VocabWord(word: "terraforming"),
            VocabWord(word: "atmospheric processor")
        ]
        
        inceptionWords[0].context = "The deepest level of the dream state"
        inceptionWords[3].context = "The sensation used to wake up from a dream"
        matrixWords[2].context = "Someone who has chosen to leave the Matrix and see reality"
        matrixWords[4].context = "Mental projection of your digital self"
        alienWords[0].context = "Scientific name for the alien species"
        
        let movies = [
            MediaItem(title: "Inception", creator: "Christopher Nolan", mediaType: .movie, learnedWords: inceptionWords),
            MediaItem(title: "The Matrix", creator: "Wachowski Sisters", mediaType: .movie, learnedWords: matrixWords),
            MediaItem(title: "Aliens", creator: "James Cameron", mediaType: .movie, learnedWords: alienWords),
            MediaItem(title: "Pulp Fiction", creator: "Quentin Tarantino", mediaType: .movie),
            MediaItem(title: "Blade Runner", creator: "Ridley Scott", mediaType: .movie)
        ]
        
        // Podcast vocab words
        let serialWords = [
            VocabWord(word: "alibi"),
            VocabWord(word: "corroborate"),
            VocabWord(word: "testimony"),
            VocabWord(word: "deposition"),
            VocabWord(word: "circumstantial")
        ]
        
        let radiolabWords = [
            VocabWord(word: "radioactive decay"),
            VocabWord(word: "neurotransmitter"),
            VocabWord(word: "symbiosis"),
            VocabWord(word: "bioluminescence"),
            VocabWord(word: "quantum entanglement")
        ]
        
        let hardcoreWords = [
            VocabWord(word: "hegemony"),
            VocabWord(word: "reformation"),
            VocabWord(word: "oligarchy"),
            VocabWord(word: "plutocracy")
        ]
        
        serialWords[0].context = "A claim or piece of evidence that someone was elsewhere when a crime occurred"
        serialWords[4].context = "Evidence that relies on inference to connect it to a conclusion"
        radiolabWords[2].context = "A mutually beneficial relationship between different organisms"
        radiolabWords[3].context = "The production and emission of light by living organisms"
        hardcoreWords[0].context = "Leadership or dominance, especially by one state or social group over others"
        
        let podcasts = [
            MediaItem(title: "Serial", creator: "Sarah Koenig", mediaType: .podcast, learnedWords: serialWords),
            MediaItem(title: "Radiolab", creator: "WNYC Studios", mediaType: .podcast, learnedWords: radiolabWords),
            MediaItem(title: "Hardcore History", creator: "Dan Carlin", mediaType: .podcast, learnedWords: hardcoreWords),
            MediaItem(title: "This American Life", creator: "Ira Glass", mediaType: .podcast),
            MediaItem(title: "99% Invisible", creator: "Roman Mars", mediaType: .podcast)
        ]
        
        // Set various progress statuses
        books[0].progressStatus = .completed
        books[2].progressStatus = .repeated
        books[3].progressStatus = .completed
        movies[0].progressStatus = .completed
        movies[1].progressStatus = .repeated
        podcasts[0].progressStatus = .repeated
        podcasts[1].progressStatus = .completed
        
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
