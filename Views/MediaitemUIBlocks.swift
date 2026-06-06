//
//  MediaitemUIBlocks.swift
//  faff
//
//  Created by kyle reddy  on 6/26/24.
//

import Foundation
import SwiftUI

// MARK: - Header

struct HeaderBlock: View {
    let title: String
    let creator: String
    let mediaType: MediaType
    var theme: AppTheme = ColorPack.rubberDucky.theme

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: mediaSymbol(mediaType))
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(theme.onPrimary)
                .frame(width: 52, height: 52)
                .background(theme.media(mediaType))
                .clipShape(Circle())

            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundColor(theme.textPrimary)
                .multilineTextAlignment(.center)

            Text("\(mediaTypeString) by \(creator)")
                .font(.subheadline)
                .foregroundColor(theme.textSecondary)
        }
    }

    private var mediaTypeString: String {
        switch mediaType {
        case .book:    return "Book"
        case .movie:   return "Movie"
        case .podcast: return "Podcast"
        case .other:   return "Other"
        }
    }
}

// MARK: - Word count

struct WordCountBlock: View {
    let count: Int
    var theme: AppTheme = ColorPack.rubberDucky.theme

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.system(size: 60, weight: .bold, design: .rounded))
                .foregroundColor(theme.primary)
                .contentTransition(.numericText())
            Text("Words Learned")
                .font(.headline)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassCard(cornerRadius: 20, tint: theme.secondary.opacity(0.25))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.surfaceStroke, lineWidth: 1)
        )
    }
}

// MARK: - Learned words

struct LearnedWordsBlock: View {
    let words: [VocabWord]
    var theme: AppTheme = ColorPack.rubberDucky.theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Learned Words")
                .font(.headline)
                .foregroundColor(theme.textPrimary)

            if words.isEmpty {
                Text("No words yet — tap + to add your first one.")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(words) { word in
                            NavigationLink(destination: VocabWordDetailView(vocabWord: word)) {
                                HStack {
                                    Text(word.word)
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    if word.tracked {
                                        Image(systemName: "star.fill")
                                            .font(.caption)
                                            .foregroundColor(theme.accent)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(theme.accent.opacity(0.22))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCard(cornerRadius: 20, tint: theme.accent.opacity(0.18))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.surfaceStroke, lineWidth: 1)
        )
    }
}

// MARK: - Add word button (floating)

struct AddWordButton: View {
    @Binding var showingAddWordOptions: Bool
    var theme: AppTheme = ColorPack.rubberDucky.theme

    var body: some View {
        Button {
            showingAddWordOptions = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(theme.onPrimary)
                .frame(width: 56, height: 56)
                .background(theme.primary)
                .clipShape(Circle())
                .shadow(color: theme.primary.opacity(0.4), radius: 10, y: 4)
        }
    }
}

// MARK: - Progress status

struct ProgressStatusIndicator: View {
    @Binding var status: ProgressStatus
    @State private var showingPicker = false

    var body: some View {
        Button {
            showingPicker = true
        } label: {
            Image(systemName: status.icon)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(status.color)
                .clipShape(Circle())
                .shadow(color: status.color.opacity(0.35), radius: 6, y: 2)
        }
        .confirmationDialog("Progress Status", isPresented: $showingPicker, titleVisibility: .visible) {
            ForEach(ProgressStatus.allCases, id: \.self) { option in
                Button(option.rawValue) { status = option }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Add word card (presented as an animated overlay, not a sheet)

struct AddWordOptionsView: View {
    @Bindable var mediaItem: MediaItem
    @Binding var isPresented: Bool
    var theme: AppTheme = ColorPack.rubberDucky.theme

    @State private var newWord = ""
    @State private var showingScanner = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 22) {
            Capsule()
                .fill(theme.textSecondary.opacity(0.4))
                .frame(width: 40, height: 5)

            Text("Add New Word")
                .font(.title3.weight(.bold))
                .foregroundColor(theme.textPrimary)

            TextField("Enter word", text: $newWord)
                .focused($fieldFocused)
                .submitLabel(.done)
                .onSubmit(addWord)
                .padding()
                .background(theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.surfaceStroke, lineWidth: 1)
                )
                .tint(theme.primary)
                .foregroundColor(theme.textPrimary)

            HStack(spacing: 16) {
                optionButton(title: "Add Word", systemImage: "pencil", action: addWord)
                optionButton(title: "Scan Word", systemImage: "camera") {
                    fieldFocused = false
                    showingScanner = true
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 28, tint: theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(theme.surfaceStroke, lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .onAppear { fieldFocused = true }
        .fullScreenCover(isPresented: $showingScanner) {
            WordScannerView(theme: theme) { scanned in
                newWord = scanned
            }
        }
    }

    private func optionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 22))
                    .foregroundColor(theme.primary)
                    .frame(width: 64, height: 64)
                    .background(theme.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(theme.textPrimary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mediaItem.addWord(VocabWord(word: trimmed))
        newWord = ""
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            isPresented = false
        }
    }
}
