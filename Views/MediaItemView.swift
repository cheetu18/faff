import SwiftUI
import SwiftData

struct MediaItemView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Bindable var mediaItem: MediaItem
    @State private var showingAddWordOptions = false
    @State private var showingSourceEditor = false

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            theme.background.ignoresSafeArea()

            // Main content
            GlassGroup(spacing: 20) {
                VStack(spacing: 20) {
                    HeaderBlock(title: mediaItem.title,
                                creator: mediaItem.creator,
                                mediaType: mediaItem.mediaType,
                                theme: theme)

                    WordCountBlock(count: mediaItem.learnedWords.count, theme: theme)

                    LearnedWordsBlock(mediaItem: mediaItem, theme: theme)
                        .frame(maxHeight: .infinity)
                }
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
            // Pinned so the word-source editor stays reachable even when the
            // bar is constrained and other content collapses into overflow.
            ToolbarItem(placement: .topBarPinnedTrailing) {
                Button {
                    showingSourceEditor = true
                } label: {
                    Label("Word Source", systemImage: "book.closed")
                }
            }
        }
        .tint(theme.primary)
        // Covers items created before detection existed, imported items, and
        // anything added before its probe settled. No-ops once attempted.
        .task { await mediaItem.detectFandomWikiIfNeeded() }
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
    @State private var isRedetecting = false

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Words that aren\u{2019}t in a standard dictionary (invented or franchise-specific terms) are looked up in this Fandom wiki. faff finds it from the title \u{2014} you only need to set it if that misses.")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)

                    currentSource

                    TextField("Wiki subdomain, e.g. dune", text: $wiki)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding()
                        .glassCard(cornerRadius: 14, tint: theme.surface)
                        .tint(theme.primary)

                    if !hostPreview.isEmpty {
                        Text("Resolves to \(hostPreview).fandom.com")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }

                    Button {
                        Task { await redetect() }
                    } label: {
                        HStack(spacing: 6) {
                            if isRedetecting {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "sparkle.magnifyingglass")
                            }
                            Text(isRedetecting ? "Searching\u{2026}" : "Detect from title again")
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    .disabled(isRedetecting)

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
                        mediaItem.setManualFandomWiki(wiki)
                        dismiss()
                    }
                }
            }
        }
        .tint(theme.primary)
        .onAppear { wiki = mediaItem.fandomWiki ?? "" }
    }

    @ViewBuilder
    private var currentSource: some View {
        if let name = mediaItem.fandomWikiDisplayName {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.primary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                    Text(mediaItem.fandomWikiIsManual ? "Set by you" : "Detected from the title")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 14, tint: theme.surface)
        }
    }

    /// Clear the manual override and probe the title again.
    private func redetect() async {
        isRedetecting = true
        mediaItem.setManualFandomWiki(nil)
        await mediaItem.detectFandomWikiIfNeeded()
        wiki = mediaItem.fandomWiki ?? ""
        isRedetecting = false
    }

    private var hostPreview: String {
        wiki.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ".fandom.com", with: "")
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
        .environment(ThemeManager.shared)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
