//
//  HeaderBlock.swift
//  faff
//
//  Created by kyle reddy  on 6/26/24.
//

import Foundation
import SwiftUI

struct HeaderBlock: View {
    let title: String
    let creator: String
    let mediaType: MediaType
    
    var body: some View {
        VStack {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("\(mediaTypeString) by \(creator)")
                .font(.subheadline)
        }
    }
    
    private var mediaTypeString: String {
        switch mediaType {
        case .book: return "Book"
        case .movie: return "Movie"
        case .podcast: return "Podcast"
        case .other: return "Other"
        }
    }
    
}
struct WordCountBlock: View {
    let count: Int
    
    var body: some View {
        VStack {
            Text("\(count)")
                .font(.system(size: 60, weight: .bold))
            Text("Words Learned")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
}

struct LearnedWordsBlock: View {
    let words: [VocabWord]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Learned Words")
                .font(.headline)
                .padding(.bottom, 5)
            
            /**
                            Need to update the destination for learned words block.
                
             */
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(words) { word in
                        //NavigationLink(destination: WordUIView(vocabWord: word)){
                        NavigationLink(destination: VocabWordDetailView(vocabWord: word)){
                       // NavigationLink(destination: Text("Test")){
                            Text(word.word)
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.yellow.opacity(0.3))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(10)
    }
}

struct AddWordButton: View {
    @Binding var showingAddWordOptions: Bool
    
    var body: some View {
        Button(action: { showingAddWordOptions = true }) {
            Image(systemName: "plus")
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.blue)
                .clipShape(Circle())
        }
    }
}
struct ProgressStatusIndicator: View {
    @Binding var status: ProgressStatus
    @State private var showingPicker = false
    
    var body: some View {
        Button(action: { showingPicker = true }) {
            Image(systemName: status.icon)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(status.color)
                .clipShape(Circle())
        }
        .actionSheet(isPresented: $showingPicker) {
            ActionSheet(title: Text("Progress Status"), buttons:
                ProgressStatus.allCases.map { status in
                    .default(Text(status.rawValue)) {
                        self.status = status
                    }
                } + [.cancel()]
            )
        }
    }
}
struct AddWordOptionsView: View {
    @Bindable var mediaItem: MediaItem
    @State private var newWord = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Word")
                .font(.headline)
            
            TextField("Enter word", text: $newWord)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button("Add Word") {
                if !newWord.isEmpty {
                    mediaItem.addWord(VocabWord(word: newWord))
                    newWord = ""
                    dismiss()
                }
                else {
                    
                }
            }
            
            Button("Scan Word") {
                // Action to scan word (to be implemented)
            }
        }
        .padding()
    }
}

