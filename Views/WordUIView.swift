//
//  WordUIView.swift
//  faff
//
//  Created by kyle reddy  on 8/30/24.
//

import SwiftUI
import SwiftData


struct WordUIView: View {
    @Bindable  var vocabWord : VocabWord
    
    var body: some View {
        NavigationView {
            VStack {
                HStack{
                    Text(vocabWord.word)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    
                    Button(action: { vocabWord.toggle() })
                    {
                        Image(systemName: vocabWord.tracked ? "star.fill" : "star")
                            .foregroundColor(vocabWord.tracked ? .yellow : .gray)
                    }
                    
                }
                
                
            }
        }
    }
}

#Preview {
    //let config = ModelConfiguration(isStoredInMemoryOnly: true)
   // let container = try ModelContainer(for: MediaItem.self, configurations: config)
    
var sampleWord =  VocabWord(word: "confidant", definition: "friend, someone who has your back", context: "he was a true confidant blah blah page 32", tracked: true)
    
    WordUIView(vocabWord: sampleWord)
}
