import SwiftUI
import SwiftData

@Model
class MediaItem {
    var title: String
    var creator: String
    
    //enums in enums class
    var mediaType: MediaType
    var progressStatus: ProgressStatus
    
    //cascade rule... if Media Item is deleted so are all the following words
    @Relationship(deleteRule: .cascade) var learnedWords: [VocabWord]
    
     
    init(title: String, creator: String, mediaType: MediaType, progressStatus: ProgressStatus = .inProgress, learnedWords: [VocabWord] = []) {
        self.title = title
        self.creator = creator
        self.mediaType = mediaType
        self.progressStatus = progressStatus
        self.learnedWords = learnedWords
    }
    
    func addWord(_ word: VocabWord) {
        learnedWords.insert(word, at: 0)
    }
}
// Extensions to add media-specific functionality
//extension MediaItem: BookSpecific where MediaType == .book {}
//extension MediaItem: AudioVisualSpecific where MediaType == .movie || MediaType == .podcast {}

func mediaSymbol(_ type: MediaType) -> String {
    switch type {
    case .book:
        return "book.fill"
    case .podcast:
        return "mic.fill"
    case .movie:
        return "film.fill"
    case .other:
        return "newspaper.fill"
    }
}
    
   
