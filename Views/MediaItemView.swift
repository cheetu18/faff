import SwiftUI
import SwiftData

struct MediaItemView: View {
    @Bindable var mediaItem: MediaItem
    @State private var showingAddWordOptions = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 20) {
                        HeaderBlock(title: mediaItem.title, creator: mediaItem.creator, mediaType: mediaItem.mediaType)
                        
                        WordCountBlock(count: mediaItem.learnedWords.count)
                        
                        
                        LearnedWordsBlock(words: mediaItem.learnedWords)
                            .frame(maxHeight: .infinity)
                    }
                    .padding()
                    
                    ProgressStatusIndicator(status: $mediaItem.progressStatus)
                        .padding(.top, 50)
                        .padding(.trailing, 20)
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            AddWordButton(showingAddWordOptions: $showingAddWordOptions)
                        }
                    }
                    .padding(.bottom, 20)
                    .padding(.trailing, 20)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            //cream color background
            //Color(red: 0.98, green: 0.96, blue: 0.94)
            //.background(Color(UIColor.systemBackground))
            .background(Color(red: 0.98, green: 0.96, blue: 0.94))
            .edgesIgnoringSafeArea(.bottom)
        }
        .sheet(isPresented: $showingAddWordOptions) {
            AddWordOptionsView(mediaItem: mediaItem)
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
        
        return MediaItemView(mediaItem: exampleItem)
            .modelContainer(container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
