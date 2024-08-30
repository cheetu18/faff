//
//  AddWordOptionView.swift
//  faff
//
//  Created by kyle reddy  on 6/26/24.
//

import Foundation
import SwiftUI

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
            }
            
            Button("Scan Word") {
                // Action to scan word (to be implemented)
            }
        }
        .padding()
    }
}
