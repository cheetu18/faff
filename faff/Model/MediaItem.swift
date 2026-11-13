import SwiftUI
import SwiftData

@Model
class MediaItem {
    var title: String
    var creator: String
    var mediaType: MediaType
    var progressStatus: ProgressStatus
    /// Fandom wiki subdomain (e.g. "dune") used to resolve invented or
    /// franchise-specific words that aren't in a standard dictionary. Normally
    /// detected from the title; the user only sets it when detection misses.
    var fandomWiki: String?
    /// Display name of the wiki, e.g. "The One Wiki to Rule Them All". Set when
    /// the wiki was detected, so the UI can name what it found.
    var fandomWikiName: String?
    /// True when the user typed the wiki themselves. Detection never overwrites
    /// a manual choice.
    var fandomWikiIsManual: Bool = false
    /// Whether detection has already run for this item, so a title with no
    /// wiki isn't re-probed on every appearance.
    var fandomWikiDetectionAttempted: Bool = false
    /// User-controlled position in the library, driven by drag-to-reorder.
    /// Defaulted so the schema change is a lightweight migration.
    var sortIndex: Int = 0
    @Relationship(deleteRule: .cascade)
    var learnedWords: [VocabWord]


    init(title: String, creator: String, mediaType: MediaType, progressStatus: ProgressStatus = .inProgress, fandomWiki: String? = nil, fandomWikiName: String? = nil, fandomWikiIsManual: Bool = false, fandomWikiDetectionAttempted: Bool = false, sortIndex: Int = 0, learnedWords: [VocabWord] = []) {
        self.title = title
        self.creator = creator
        self.mediaType = mediaType
        self.progressStatus = progressStatus
        self.fandomWiki = fandomWiki
        self.fandomWikiName = fandomWikiName
        self.fandomWikiIsManual = fandomWikiIsManual
        self.fandomWikiDetectionAttempted = fandomWikiDetectionAttempted
        self.sortIndex = sortIndex
        self.learnedWords = learnedWords
        // Stamp incoming words so they have a deterministic order from the start.
        for (offset, word) in learnedWords.enumerated() where word.sortIndex == 0 {
            word.sortIndex = offset
        }
    }

    /// Wiki label for the UI: the detected name when known, else the raw slug.
    var fandomWikiDisplayName: String? {
        if let name = fandomWikiName, !name.isEmpty { return name }
        return fandomWiki
    }

    /// Detect and store the wiki for this title, unless the user already chose
    /// one or detection has already been tried. Safe to call on every appear.
    @MainActor
    func detectFandomWikiIfNeeded() async {
        guard !fandomWikiIsManual, !fandomWikiDetectionAttempted else { return }

        let detected = await FandomDirectory.detect(title: title)

        // Re-check: the user may have set one manually while the probe ran.
        guard !fandomWikiIsManual else { return }
        fandomWikiDetectionAttempted = true
        if let detected {
            fandomWiki = detected.slug
            fandomWikiName = detected.name
        }
        try? modelContext?.save()
    }

    /// Record a wiki the user typed, or clear it back to automatic.
    @MainActor
    func setManualFandomWiki(_ slug: String?) {
        let trimmed = slug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            // Clearing hands control back to detection on next appearance.
            fandomWiki = nil
            fandomWikiName = nil
            fandomWikiIsManual = false
            fandomWikiDetectionAttempted = false
        } else {
            fandomWiki = trimmed
            fandomWikiName = nil
            fandomWikiIsManual = true
            fandomWikiDetectionAttempted = true
        }
        try? modelContext?.save()
    }

    /// Words in user-defined order. Always read through this rather than
    /// `learnedWords` directly, which SwiftData returns in arbitrary order.
    var orderedWords: [VocabWord] {
        learnedWords.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// New words go to the top, without renumbering everything else.
    func addWord(_ word: VocabWord) {
        word.sortIndex = (learnedWords.map(\.sortIndex).min() ?? 0) - 1
        learnedWords.append(word)
    }

    /// Rewrite `sortIndex` to match the given order (used after a reorder).
    func applyWordOrder(_ words: [VocabWord]) {
        for (offset, word) in words.enumerated() {
            word.sortIndex = offset
        }
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

// MARK: - Export / Import

/// Flat, codable snapshots used for JSON/CSV transfer (independent of SwiftData).
struct WordExport: Codable {
    var word: String
    var definition: String?
    var context: String?
    var phonetic: String?
    var phoneticUrl: String?
    var tracked: Bool
}

struct MediaExport: Codable {
    var title: String
    var creator: String
    var mediaType: String
    var progressStatus: String
    var fandomWiki: String?
    var words: [WordExport]
}

enum WordDataFormat {
    case json
    case csv
}

enum WordDataTransfer {

    enum TransferError: LocalizedError {
        case unreadable
        var errorDescription: String? { "The file could not be read." }
    }

    // MARK: Snapshot

    static func snapshot(_ items: [MediaItem]) -> [MediaExport] {
        items.map { item in
            MediaExport(
                title: item.title,
                creator: item.creator,
                mediaType: item.mediaType.rawValue,
                progressStatus: item.progressStatus.rawValue,
                fandomWiki: item.fandomWiki,
                words: item.orderedWords.map { word in
                    WordExport(
                        word: word.word,
                        definition: plainDefinition(word),
                        context: word.context,
                        phonetic: word.phonetic,
                        phoneticUrl: word.phoneticUrl,
                        tracked: word.tracked
                    )
                }
            )
        }
    }

    /// Best available readable definition: explicit value, else cached lookup.
    private static func plainDefinition(_ word: VocabWord) -> String? {
        if let d = word.definition, !d.isEmpty { return d }
        guard let lookup = word.cachedLookup() else { return nil }
        switch lookup.content {
        case .definitions(let meanings):
            return meanings.first?.definitions.first?.definition
        case .prose(let text):
            return text
        }
    }

    // MARK: Export

    static func exportJSON(_ items: [MediaItem]) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(snapshot(items))) ?? Data()
    }

    static func exportCSV(_ items: [MediaItem]) -> Data {
        var rows: [[String]] = [[
            "List", "Creator", "Type", "Status", "Wiki",
            "Word", "Definition", "Context", "Phonetic", "Tracked"
        ]]
        for media in snapshot(items) {
            if media.words.isEmpty {
                rows.append([media.title, media.creator, media.mediaType,
                             media.progressStatus, media.fandomWiki ?? "",
                             "", "", "", "", ""])
            } else {
                for word in media.words {
                    rows.append([
                        media.title, media.creator, media.mediaType,
                        media.progressStatus, media.fandomWiki ?? "",
                        word.word, word.definition ?? "", word.context ?? "",
                        word.phonetic ?? "", word.tracked ? "true" : "false"
                    ])
                }
            }
        }
        let csv = rows
            .map { $0.map(escapeCSV).joined(separator: ",") }
            .joined(separator: "\r\n")
        return Data(csv.utf8)
    }

    private static func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    // MARK: Parse

    static func parse(_ data: Data, format: WordDataFormat) throws -> [MediaExport] {
        switch format {
        case .json:
            return try JSONDecoder().decode([MediaExport].self, from: data)
        case .csv:
            guard let text = String(data: data, encoding: .utf8) else { throw TransferError.unreadable }
            return parseCSV(text)
        }
    }

    private static func parseCSV(_ text: String) -> [MediaExport] {
        let table = csvRows(text)
        guard table.count > 1 else { return [] }

        let header = table[0].map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        func index(_ name: String) -> Int? { header.firstIndex(of: name) }

        let iList = index("list") ?? 0
        let iCreator = index("creator") ?? 1
        let iType = index("type") ?? 2
        let iStatus = index("status") ?? 3
        let iWiki = index("wiki")
        let iWord = index("word")
        let iDef = index("definition")
        let iContext = index("context")
        let iPhon = index("phonetic")
        let iTracked = index("tracked")

        var order: [String] = []
        var map: [String: MediaExport] = [:]

        for row in table.dropFirst() {
            func col(_ i: Int?) -> String {
                guard let i, i < row.count else { return "" }
                return row[i]
            }
            let title = col(iList)
            guard !title.isEmpty else { continue }
            let creator = col(iCreator)
            let key = "\(title)|\(creator)|\(col(iType))"

            if map[key] == nil {
                let wiki = col(iWiki)
                map[key] = MediaExport(
                    title: title,
                    creator: creator,
                    mediaType: col(iType).isEmpty ? "book" : col(iType),
                    progressStatus: col(iStatus).isEmpty ? "In Progress" : col(iStatus),
                    fandomWiki: wiki.isEmpty ? nil : wiki,
                    words: []
                )
                order.append(key)
            }

            let word = col(iWord)
            if !word.isEmpty {
                map[key]?.words.append(WordExport(
                    word: word,
                    definition: nilIfEmpty(col(iDef)),
                    context: nilIfEmpty(col(iContext)),
                    phonetic: nilIfEmpty(col(iPhon)),
                    phoneticUrl: nil,
                    tracked: col(iTracked).lowercased() == "true"
                ))
            }
        }
        return order.compactMap { map[$0] }
    }

    private static func nilIfEmpty(_ s: String) -> String? { s.isEmpty ? nil : s }

    /// Quote-aware CSV tokenizer (handles commas, quotes, and CRLF/LF inside fields).
    private static func csvRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var record: [String] = []
        var inQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"":
                    inQuotes = true
                case ",":
                    record.append(field); field = ""
                case "\n":
                    record.append(field); field = ""
                    rows.append(record); record = []
                case "\r":
                    break
                default:
                    field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !record.isEmpty {
            record.append(field)
            rows.append(record)
        }
        return rows.filter { !($0.count == 1 && $0[0].isEmpty) }
    }

    // MARK: Import

    /// Insert parsed items, skipping any list that already exists
    /// (matched by title + creator + type). Returns counts added.
    @MainActor
    @discardableResult
    static func importItems(_ exports: [MediaExport],
                            into context: ModelContext,
                            existing: [MediaItem]) -> (lists: Int, words: Int) {
        var keys = Set(existing.map { "\($0.title)|\($0.creator)|\($0.mediaType.rawValue)" })
        var lists = 0
        var words = 0
        // Imported lists append below whatever is already in the library.
        var nextSortIndex = (existing.map(\.sortIndex).max() ?? -1) + 1

        for export in exports {
            let key = "\(export.title)|\(export.creator)|\(export.mediaType)"
            if keys.contains(key) { continue }
            keys.insert(key)

            let vocab = export.words.enumerated().map { offset, w in
                VocabWord(word: w.word,
                          definition: w.definition,
                          context: w.context,
                          tracked: w.tracked,
                          phonetic: w.phonetic,
                          phoneticUrl: w.phoneticUrl,
                          sortIndex: offset)
            }
            let item = MediaItem(
                title: export.title,
                creator: export.creator,
                mediaType: MediaType(rawValue: export.mediaType) ?? .other,
                progressStatus: ProgressStatus(rawValue: export.progressStatus) ?? .inProgress,
                fandomWiki: export.fandomWiki,
                // An imported wiki is an explicit choice, so keep it; imported
                // items without one fall through to detection.
                fandomWikiIsManual: export.fandomWiki != nil,
                sortIndex: nextSortIndex,
                learnedWords: vocab
            )
            nextSortIndex += 1
            context.insert(item)
            lists += 1
            words += vocab.count
        }

        try? context.save()
        return (lists, words)
    }
}
    
   
