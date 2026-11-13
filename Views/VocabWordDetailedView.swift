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
    @Environment(ThemeManager.self) private var themeManager
    @Bindable var vocabWord: VocabWord
    var fandomWiki: String? = nil
    @State private var lookup: WordLookup?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pronunciation = PronunciationPlayer()
    @State private var isShowingAddContextSheet = false

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            ScrollView {
                // One container so the sibling glass surfaces blend and morph
                // together instead of compositing independently.
                GlassGroup(spacing: 20) {
                    VStack(spacing: 20) {
                        wordHeader
                        phoneticSection
                        contentSection
                        contextSection
                        Spacer()
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await fetchDefinition()
        }
        .id(vocabWord.word)
        .tint(theme.primary)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await fetchDefinition(forceRefresh: true) }
                } label: {
                    Label("Refresh Definition", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .sheet(isPresented: $isShowingAddContextSheet) {
            AddContextView(vocabWord: vocabWord, theme: theme)
        }
    }

    private var wordHeader: some View {
        HStack {
            Text(vocabWord.word)
                // Scales with Dynamic Type rather than being pinned at 40pt.
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Button {
                vocabWord.tracked.toggle()
            } label: {
                Image(systemName: vocabWord.tracked ? "star.fill" : "star")
                    .foregroundStyle(vocabWord.tracked ? theme.primary : theme.textSecondary)
                    .font(.title)
            }
            .accessibilityLabel(vocabWord.tracked ? "Untrack word" : "Track word")
        }
        .padding()
        .glassCard(cornerRadius: 18, tint: theme.surface)
    }

    private var phoneticSection: some View {
        Group {
            if let phonetic = vocabWord.phonetic {
                HStack {
                    Text(phonetic)
                        .font(.title3)
                        .foregroundStyle(theme.textPrimary)

                    // Always offered: plays the recording when one is available
                    // and falls back to on-device speech otherwise.
                    Button {
                        pronunciation.play(word: vocabWord.word, audioURL: vocabWord.phoneticUrl)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(theme.onPrimary)
                            .padding(10)
                            .background(theme.primary)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Play pronunciation")
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 14, tint: theme.secondary.opacity(0.25))
            }
        }
    }

    private var contentSection: some View {
        Group {
            if isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(theme.primary)
                    .padding(.vertical, 24)
            } else if let lookup {
                VStack(alignment: .leading, spacing: 12) {
                    sourceBadge(lookup)
                    switch lookup.content {
                    case .definitions(let meanings):
                        dictionaryContent(meanings)
                    case .prose(let text):
                        proseContent(text)
                    }
                }
            } else if let error = errorMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Text(error)
                        .foregroundStyle(theme.textPrimary)
                    Text("You can still add your own context below.")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .glassCard(cornerRadius: 14, tint: theme.surface)
            }
        }
    }

    private func sourceBadge(_ lookup: WordLookup) -> some View {
        HStack(spacing: 6) {
            Image(systemName: lookup.isLore ? "sparkles" : "character.book.closed")
                .font(.caption)
            Text(lookup.isLore ? "Lore from \(lookup.sourceLabel)" : "from \(lookup.sourceLabel)")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassCard(cornerRadius: 12, tint: theme.accent.opacity(0.20))
    }

    private func dictionaryContent(_ meanings: [Meaning]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            ForEach(Array(meanings.enumerated()), id: \.offset) { _, meaning in
                meaningSection(meaning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glassCard(cornerRadius: 18, tint: theme.surface)
    }

    private func proseContent(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .glassCard(cornerRadius: 18, tint: theme.surface)
    }

    private func meaningSection(_ meaning: Meaning) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(meaning.partOfSpeech)
                .font(.headline)
                .foregroundStyle(theme.primary)

            ForEach(meaning.definitions.indices, id: \.self) { index in
                definitionSection(meaning.definitions[index], index: index)
            }
        }
    }

    private func definitionSection(_ definition: Definition, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(index + 1). \(definition.definition)")
                .font(.body)
                .foregroundStyle(theme.textPrimary)

            if let example = definition.example {
                Text("Example: \(example)")
                    .italic()
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.vertical, 5)
    }

    private var contextSection: some View {
        Button {
            isShowingAddContextSheet = true
        } label: {
            if let context = vocabWord.context, !context.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Context")
                        .font(.headline)
                        .foregroundStyle(theme.primary)
                    Text(context)
                        .foregroundStyle(theme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .glassCard(cornerRadius: 14, tint: theme.surface)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(theme.primary)
                        .symbolEffect(.wiggle)
                    Text("Add Context")
                        .font(.title3)
                        .foregroundStyle(theme.textPrimary)
                    Spacer()
                }
                .padding()
                .glassCard(cornerRadius: 14, tint: theme.surface)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(vocabWord.context?.isEmpty == false ? "Edit context" : "Add context")
    }

    private func fetchDefinition(forceRefresh: Bool = false) async {
        // Instant path: use the cached lookup unless a refresh was requested.
        if !forceRefresh, let cached = vocabWord.cachedLookup() {
            lookup = cached
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let result = try await DictionaryService.lookup(term: vocabWord.word, fandomWiki: fandomWiki)
            lookup = result
            vocabWord.storeLookup(result)

            // Cache phonetic info. A manual refresh replaces the saved audio
            // link outright so a stale or broken one can't stick around.
            if forceRefresh {
                vocabWord.phonetic = result.phonetic ?? vocabWord.phonetic
                vocabWord.phoneticUrl = result.phoneticAudioURL
            } else {
                if vocabWord.phonetic == nil {
                    vocabWord.phonetic = result.phonetic
                }
                if vocabWord.phoneticUrl == nil {
                    vocabWord.phoneticUrl = result.phoneticAudioURL
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Add context

struct AddContextView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var vocabWord: VocabWord
    var theme: AppTheme = ColorPack.rubberDucky.theme

    @State private var newContext = ""
    @State private var isShowingScanner = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                GlassGroup(spacing: 16) {
                    VStack(spacing: 20) {
                        TextEditor(text: $newContext)
                            .scrollContentBackground(.hidden)
                            .frame(height: 150)
                            .padding(8)
                            .glassCard(cornerRadius: 14, tint: theme.surface)
                            .tint(theme.primary)
                            .foregroundStyle(theme.textPrimary)

                        Button {
                            isShowingScanner = true
                        } label: {
                            HStack {
                                Image(systemName: "camera")
                                Text("Scan Context")
                            }
                            .foregroundStyle(theme.primary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .glassCard(cornerRadius: 14, tint: theme.accent.opacity(0.18))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }
                .padding()
            }
            .navigationTitle("Add Context")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        vocabWord.context = newContext
                        dismiss()
                    }
                    .disabled(newContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(theme.primary)
        // Pre-fill so editing existing context doesn't silently wipe it.
        .onAppear { newContext = vocabWord.context ?? "" }
        .fullScreenCover(isPresented: $isShowingScanner) {
            WordScannerView(theme: theme, mode: .phrase) { scanned in
                newContext = newContext.isEmpty ? scanned
                                                : newContext + " " + scanned
            }
        }
    }
}

#Preview {
    let sampleWord = VocabWord(word: "ubiquitous", tracked: true)

    NavigationStack {
        VocabWordDetailView(vocabWord: sampleWord)
    }
    .environment(ThemeManager.shared)
}
