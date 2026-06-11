import SwiftUI
import SwiftData

struct MediaItemView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Bindable var mediaItem: MediaItem
    @State private var showingAddWordOptions = false
    @State private var showingSourceEditor = false

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.background.ignoresSafeArea()

            // Main content
            VStack(spacing: 20) {
                HeaderBlock(title: mediaItem.title,
                            creator: mediaItem.creator,
                            mediaType: mediaItem.mediaType,
                            theme: theme)

                WordCountBlock(count: mediaItem.learnedWords.count, theme: theme)

                LearnedWordsBlock(words: mediaItem.learnedWords,
                                  fandomWiki: mediaItem.fandomWiki,
                                  theme: theme)
                    .frame(maxHeight: .infinity)
            }
            .padding()

            // Progress status (top-right)
            ProgressStatusIndicator(status: $mediaItem.progressStatus)
                .padding(.top, 8)
                .padding(.trailing, 8)

            // Floating add button (bottom-right)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    AddWordButton(showingAddWordOptions: $showingAddWordOptions, theme: theme)
                }
            }
            .padding(20)

            // Animated add-word overlay
            if showingAddWordOptions {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { dismissAddWord() }

                VStack {
                    Spacer()
                    AddWordOptionsView(mediaItem: mediaItem,
                                       isPresented: $showingAddWordOptions,
                                       theme: theme)
                    Spacer()
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: showingAddWordOptions)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSourceEditor = true
                } label: {
                    Image(systemName: "book.closed")
                        .foregroundColor(theme.primary)
                }
            }
        }
        .sheet(isPresented: $showingSourceEditor) {
            SourceWikiEditor(mediaItem: mediaItem, theme: theme)
        }
    }

    private func dismissAddWord() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            showingAddWordOptions = false
        }
    }
}

// MARK: - Source wiki editor

struct SourceWikiEditor: View {
    @Bindable var mediaItem: MediaItem
    var theme: AppTheme

    @Environment(\.dismiss) private var dismiss
    @State private var wiki = ""

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Words that aren\u{2019}t in a standard dictionary (invented or franchise-specific terms) are looked up in this Fandom wiki.")
                        .font(.subheadline)
                        .foregroundColor(theme.textSecondary)

                    TextField("Fandom wiki subdomain, e.g. dune", text: $wiki)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .glassCard(cornerRadius: 14, tint: theme.surface)
                        .tint(theme.primary)

                    if !wiki.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("Resolves to \(hostPreview).fandom.com")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Word Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = wiki.trimmingCharacters(in: .whitespacesAndNewlines)
                        mediaItem.fandomWiki = trimmed.isEmpty ? nil : trimmed
                        dismiss()
                    }
                }
            }
        }
        .tint(theme.primary)
        .onAppear { wiki = mediaItem.fandomWiki ?? "" }
    }

    private var hostPreview: String {
        let trimmed = wiki.trimmingCharacters(in: .whitespaces)
        return trimmed.replacingOccurrences(of: ".fandom.com", with: "")
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MediaItem.self, configurations: config)

        let exampleItem = MediaItem(title: "Dune", creator: "Frank Herbert", mediaType: .book)
        exampleItem.learnedWords = [
            VocabWord(word: "Kwisatz Haderach"),
            VocabWord(word: "Fremen"),
            VocabWord(word: "Melange"),
            VocabWord(word: "Shai-Hulud")
        ]

        return NavigationStack {
            MediaItemView(mediaItem: exampleItem)
        }
        .modelContainer(container)
        .environmentObject(ThemeManager.shared)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
