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
        .background(Color.mallardGreen.opacity(0.1))
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
                                .background(Color.duckGold.opacity(0.3))
                                //.background(Color.yellow.opacity(0.3))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        //old yellow color
        //.background(Color.yellow.opacity(0.1))
        .background(Color.duckGold.opacity(0.1))
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
                .background(Color.duckSlate)
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
    
    private let creamColor = Color(red: 0.98, green: 0.96, blue: 0.94)
    
    var body: some View {
        ZStack {
            // Full-screen background
            creamColor
                .edgesIgnoringSafeArea(.all)  // This ensures it goes edge to edge
            
            // Content container
            VStack {
                Spacer()  // This pushes content down from top
                
                VStack(spacing: 24) {
                    Text("Add New Word")
                        .font(.headline)
                        .foregroundColor(.duckSlate)
                    
                    TextField("Enter word", text: $newWord)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .tint(.duckSlate)
                    
                    HStack(spacing: 20) {
                        // Write/Add Word Button
                        Button(action: {
                            if !newWord.isEmpty {
                                mediaItem.addWord(VocabWord(word: newWord))
                                newWord = ""
                                dismiss()
                            }
                        }) {
                            VStack {
                                Rectangle()
                                    .fill(Color.duckSlate.opacity(0.1))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "pencil")
                                            .foregroundColor(.duckSlate)
                                            .font(.system(size: 24))
                                    )
                                
                                Text("Add Word")
                                    .foregroundColor(.duckSlate)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Scan Button
                        Button(action: {
                            // Scan action
                        }) {
                            VStack {
                                Rectangle()
                                    .fill(Color.duckSlate.opacity(0.1))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "camera")
                                            .foregroundColor(.duckSlate)
                                            .font(.system(size: 24))
                                    )
                                
                                Text("Scan Word")
                                    .foregroundColor(.duckSlate)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 30)
                
                Spacer()  // This pushes content up from bottom
                Spacer()  // Adding an extra spacer to move content up more
            }
            .padding(.horizontal)
        }
        .background(creamColor)  // This ensures any gaps are filled with cream color
    }
}
