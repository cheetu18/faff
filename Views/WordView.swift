//
//  WordView.swift
//  faff
//
//  Created by kyle reddy  on 6/26/24.
//

import SwiftUI

struct DuneVocabView: View {
    @State private var learnedWords: [String] = ["Kwisatz Haderach", "Fremen", "Melange", "Shai-Hulud", "Bene Gesserit", "Gom Jabbar", "Arrakis", "Sietch", "Crysknife", "Ornithopter"]
    @State private var readingStatus: ReadingStatus = .inProgress
    @State private var showingAddWordOptions = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 20) {
                    HeaderBlock()
                    
                    WordCountBlock(count: learnedWords.count)
                    
                    LearnedWordsBlock(words: learnedWords)
                        .frame(maxHeight: .infinity)
                }
                .padding()
                
                ReadingStatusIndicator(status: $readingStatus)
                    .padding(.top, 50)
                    .padding(.trailing, 20)
                
                AddWordButton(showingAddWordOptions: $showingAddWordOptions)
                    .padding(.bottom, 20)
                    .padding(.trailing, 20)
            }
            .background(Color(UIColor.systemBackground))
            .edgesIgnoringSafeArea(.bottom)
        }
        .sheet(isPresented: $showingAddWordOptions) {
            AddWordOptionsView()
        }
    }
}

struct HeaderBlock: View {
    var body: some View {
        VStack {
            Text("Dune")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("by Frank Herbert")
                .font(.subheadline)
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
    let words: [String]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Learned Words")
                .font(.headline)
                .padding(.bottom, 5)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(words, id: \.self) { word in
                        NavigationLink(destination: Text("Details for \(word)")) {
                            Text(word)
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

enum ReadingStatus: CaseIterable {
    case inProgress, completed, reread
    
    var color: Color {
        switch self {
        case .inProgress: return .blue
        case .completed: return .green
        case .reread: return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .inProgress: return "book"
        case .completed: return "checkmark.circle.fill"
        case .reread: return "arrow.clockwise.circle.fill"
        }
    }
}

struct ReadingStatusIndicator: View {
    @Binding var status: ReadingStatus
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
            ActionSheet(title: Text("Reading Status"), buttons:
                ReadingStatus.allCases.map { status in
                    .default(Text(String(describing: status).capitalized)) {
                        self.status = status
                    }
                } + [.cancel()]
            )
        }
    }
}

struct AddWordButton: View {
    @Binding var showingAddWordOptions: Bool
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: { showingAddWordOptions = true }) {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
        }
    }
}

struct AddWordOptionsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Word")
                .font(.headline)
            
            Button("Type Word") {
                // Action to type word (to be implemented)
            }
            
            Button("Scan Word") {
                // Action to scan word (to be implemented)
            }
        }
        .padding()
    }
}

#Preview {
    DuneVocabView()
}
