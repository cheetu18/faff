import SwiftUI
import SwiftData

struct MediaItemView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Bindable var mediaItem: MediaItem
    @State private var showingAddWordOptions = false

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

                LearnedWordsBlock(words: mediaItem.learnedWords, theme: theme)
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
    }

    private func dismissAddWord() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            showingAddWordOptions = false
        }
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
