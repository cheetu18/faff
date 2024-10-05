//
//  VocabWordDetailedView.swift
//  faff
//
//  Created by kyle reddy  on 9/8/24.
//

import SwiftUI
import SwiftData
import AVFoundation

struct VocabWordDetailView: View {
    @Bindable var vocabWord: VocabWord
    @State private var dictionaryEntry: DictionaryEntry?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var audioPlayer: AVPlayer?
    @State private var isShowingAddContextSheet = false
    
    let backgroundColor = Color(red: 0.98, green: 0.96, blue: 0.94) // Cream color
    let accentColor = Color.blue
    let gradientColors = [Color.blue, Color.purple]
    
    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    wordHeader
                    phoneticSection
                    contentSection
                    contextSection
                    Spacer()
                    learnButton
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchDefinition()
        }
        .sheet(isPresented: $isShowingAddContextSheet) {
            AddContextView(vocabWord: vocabWord)
        }
    }
    
    private var wordHeader: some View {
        HStack {
            Text(vocabWord.word)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(accentColor)
            
            Spacer()
            
            Button(action: {
                vocabWord.tracked.toggle()
            }) {
                Image(systemName: vocabWord.tracked ? "star.fill" : "star")
                    .foregroundColor(vocabWord.tracked ? .yellow : .gray)
                    .font(.title)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.gray.opacity(0.2), radius: 5, x: 0, y: 2)
    }
    
    private var phoneticSection: some View {
        Group {
            if let phonetic = vocabWord.phonetic {
                HStack {
                    Text(phonetic)
                        .font(.title3)
                        .foregroundColor(.black)
                    
                    if let phoneticUrl = vocabWord.phoneticUrl {
                        Button(action: {
                            playAudio(url: phoneticUrl)
                        }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.white)
                                .padding(10)
                                .background(accentColor)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.gray.opacity(0.2), radius: 5, x: 0, y: 2)
            }
        }
    }
    
    private var contentSection: some View {
        Group {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .foregroundColor(accentColor)
            } else if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(color: Color.gray.opacity(0.2), radius: 5, x: 0, y: 2)
            } else if let entry = dictionaryEntry {
                dictionaryContent(entry)
            }
        }
    }
    
    private func dictionaryContent(_ entry: DictionaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            ForEach(entry.meanings, id: \.partOfSpeech) { meaning in
                meaningSection(meaning)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.gray.opacity(0.2), radius: 5, x: 0, y: 2)
    }
    
    private func meaningSection(_ meaning: Meaning) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(meaning.partOfSpeech)
                .font(.headline)
                .foregroundColor(accentColor)
            
            ForEach(meaning.definitions.indices, id: \.self) { index in
                definitionSection(meaning.definitions[index], index: index)
            }
        }
    }
    
    private func definitionSection(_ definition: Definition, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(index + 1). \(definition.definition)")
                .font(.body)
            
            if let example = definition.example {
                Text("Example: \(example)")
                    .italic()
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
    
    private var contextSection: some View {
          Group {
              if let context = vocabWord.context {
                  VStack(alignment: .leading) {
                      Text("Context")
                          .font(.headline)
                          .foregroundColor(accentColor)
                      Text(context)
                          .foregroundColor(.black)
                  }
                  .padding()
                  .background(Color.white)
                  .cornerRadius(10)
                  .shadow(color: Color.gray.opacity(0.2), radius: 5, x: 0, y: 2)
              } else {
                  Button(action: {
                      isShowingAddContextSheet = true
                  }) {
                      Text("Add Context")
                          .font(.headline)
                          .foregroundColor(.white)
                          .padding()
                          .frame(maxWidth: .infinity)
                          .background(
                              RoundedRectangle(cornerRadius: 10)
                                  .fill(accentColor)
                          )
                  }
                  .shadow(color: Color.gray.opacity(0.3), radius: 5, x: 0, y: 2)
              }
          }
      }
      
    
    private var learnButton: some View {
        Button(action: {
            // Action for learn button
            print("Learn button tapped")
        }) {
            Text("Learn")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(LinearGradient(gradient: Gradient(colors: gradientColors), startPoint: .leading, endPoint: .trailing))
                )
        }
        .padding(.horizontal)
        .shadow(color: Color.gray.opacity(0.3), radius: 5, x: 0, y: 2)
    }
    

    private func fetchDefinition() async {
        isLoading = true
        errorMessage = nil
        do {
            let entry = try await DictionaryService.fetchDefinition(for: vocabWord.word)
            dictionaryEntry = entry
            
            // Update VocabWord with phonetic information
            if vocabWord.phonetic == nil {
                vocabWord.phonetic = entry.phonetic ?? entry.phonetics.first?.text
            }
            if vocabWord.phoneticUrl == nil {
                vocabWord.phoneticUrl = entry.phonetics.first?.audio
            }
            
        } catch {
            errorMessage = "Failed to fetch definition: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func playAudio(url: String) {
        guard let audioUrl = URL(string: url) else { return }
        let playerItem = AVPlayerItem(url: audioUrl)
        audioPlayer = AVPlayer(playerItem: playerItem)
        audioPlayer?.play()
    }
}
struct AddContextView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var vocabWord: VocabWord
    @State private var newContext = ""
    @State private var isShowingScanner = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Add Context")) {
                    TextEditor(text: $newContext)
                        .frame(height: 150)
                    
                    Button("Scan Context") {
                        isShowingScanner = true
                    }
                }
                
                Section {
                    Button("Save") {
                        vocabWord.context = newContext
                        dismiss()
                    }
                    .disabled(newContext.isEmpty)
                }
            }
            .navigationTitle("Add Context")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
            .sheet(isPresented: $isShowingScanner) {
                ScannerView(scannedText: $newContext)
            }
        }
    }
}

struct ScannerView: View {
    @Binding var scannedText: String
    
    var body: some View {
        Text("Scanner Placeholder")
            // Implement actual scanning functionality here
    }
}
#Preview {
    //let config = ModelConfiguration(isStoredInMemoryOnly: true)
   // let container = try ModelContainer(for: MediaItem.self, configurations: config)
    
    var sampleWord = VocabWord(word: "ubiquitous", tracked: true)
    //var sampleWord =  VocabWord(word: "confidant", definition: "friend, someone who has your back", context: "he was a true confidant blah blah page 32", tracked: true)

    VocabWordDetailView(vocabWord: sampleWord)
}
