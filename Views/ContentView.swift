//
//  ContentView.swift
//  faff
//
//  Created by kyle reddy  on 6/26/24.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Root tab container

struct MainTabView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        TabView {
            Tab("Lists", systemImage: "books.vertical.fill") {
                ContentView()
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .tint(themeManager.theme.primary)
    }
}

// MARK: - Lists

struct ContentView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    /// Explicitly ordered. Without a sort descriptor SwiftData returns rows in
    /// whatever order the store yields, which is not stable across launches.
    @Query(sort: \MediaItem.sortIndex) private var mediaItems: [MediaItem]
    @State private var path = NavigationPath()
    @State private var selectedMediaType: MediaType? = nil
    @State private var isShowingAddMedia = false

    private var theme: AppTheme { themeManager.theme }

    private var filteredItems: [MediaItem] {
        if let selectedType = selectedMediaType {
            return mediaItems.filter { $0.mediaType == selectedType }
        }
        return mediaItems
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                theme.background
                    .ignoresSafeArea()

                if filteredItems.isEmpty {
                    emptyState
                } else {
                    libraryList
                }
            }
            .navigationDestination(for: MediaItem.self) { item in
                MediaItemView(mediaItem: item)
            }
            // Replaces the old global UINavigationBar.appearance() override,
            // which forced a transparent background app-wide and defeated the
            // navigation bar's adaptive scroll-edge behavior.
            // No header for the unfiltered library: the tab already says
            // "Lists". A filter still names itself so its state is visible.
            .themedNavigationTitle(selectedMediaType?.pluralTitle, theme: theme)
            .toolbar {
                // Adding a list is the primary action, so it is the last thing
                // that should ever be pushed into the overflow menu.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddMedia = true
                    } label: {
                        Label("Add List", systemImage: "plus")
                    }
                }
                .visibilityPriority(.high)

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Filter", selection: $selectedMediaType) {
                            Text("All").tag(MediaType?.none)
                            ForEach(MediaType.allCases, id: \.self) { type in
                                Label(type.rawValue.capitalized,
                                      systemImage: mediaSymbol(type))
                                    .tag(MediaType?.some(type))
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease")
                    }
                }
                .visibilityPriority(.low)
            }
            .sheet(isPresented: $isShowingAddMedia) {
                AddMediaView()
            }
        }
    }

    private var libraryList: some View {
        ScrollView {
            GlassGroup {
                LazyVStack(spacing: 14) {
                    ForEach(filteredItems) { item in
                        NavigationLink(value: item) {
                            MediaRow(item: item, theme: theme)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                deleteItem(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteItem(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .reorderable()
                }
                .reorderContainer(for: MediaItem.self) { difference in
                    reorderLists(difference)
                }
            }
            .padding()
        }
        .swipeActionsContainer()
        .toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical")
                .font(.system(size: 52))
                .foregroundStyle(theme.primary.opacity(0.5))
            Text("No lists yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
            Text("Tap + to track words from a book, movie, or podcast.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 40)
        }
    }

    /// Persist a drag by rewriting `sortIndex` across the whole library.
    private func reorderLists(_ difference: ReorderDifference<MediaItem.ID, ReorderableSingleCollectionIdentifier>) {
        var ordered = mediaItems
        difference.apply(to: &ordered)
        for (offset, item) in ordered.enumerated() {
            item.sortIndex = offset
        }
        try? modelContext.save()
    }

    private func deleteItem(_ item: MediaItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
}

// MARK: - List row

private struct MediaRow: View {
    let item: MediaItem
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: mediaSymbol(item.mediaType))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.media(item.mediaType))
                .frame(width: 44, height: 44)
                .background(theme.media(item.mediaType).opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text("\(item.learnedWords.count) words • \(item.creator)")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.textSecondary.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 18, tint: theme.surface)
    }
}

// MARK: - Add media

struct AddMediaView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MediaItem.sortIndex) private var mediaItems: [MediaItem]

    @State private var title = ""
    @State private var creator = ""
    @State private var selectedType: MediaType = .book

    // Wiki detection state.
    @State private var detection: WikiDetectionState = .idle
    @State private var isEditingWikiManually = false
    @State private var manualWiki = ""

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                GlassGroup(spacing: 18) {
                    VStack(spacing: 18) {
                        TextField("Title", text: $title)
                            .padding()
                            .glassCard(cornerRadius: 14, tint: theme.surface)
                            .tint(theme.primary)

                        TextField("Creator", text: $creator)
                            .padding()
                            .glassCard(cornerRadius: 14, tint: theme.surface)
                            .tint(theme.primary)

                        Picker("Media Type", selection: $selectedType) {
                            ForEach(MediaType.allCases, id: \.self) { type in
                                Label(type.rawValue.capitalized,
                                      systemImage: mediaSymbol(type))
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        wikiSection

                        Spacer()
                    }
                }
                .padding()
            }
            .navigationTitle("Add Media")
            .navigationBarTitleDisplayMode(.inline)
            // Detection is keyed off the title and debounced inside the task,
            // which SwiftUI cancels and restarts on each keystroke.
            .task(id: title) { await detectWiki() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addMedia()
                        dismiss()
                    }
                    .disabled(title.isEmpty || creator.isEmpty)
                }
            }
        }
        .tint(theme.primary)
    }

    /// Wiki row: shows what detection found, and only offers a text field when
    /// the user wants to override it.
    @ViewBuilder
    private var wikiSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditingWikiManually {
                TextField("Wiki subdomain, e.g. dune", text: $manualWiki)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .glassCard(cornerRadius: 14, tint: theme.surface)
                    .tint(theme.primary)

                HStack {
                    Text("Used for invented words, e.g. \u{201C}dune\u{201D} for dune.fandom.com.")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Button("Use automatic") {
                        manualWiki = ""
                        isEditingWikiManually = false
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 4)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: detection.symbol)
                        .foregroundStyle(detection.isFound ? theme.primary : theme.textSecondary)
                        .accessibilityHidden(true)
                    Text(detection.message)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                    Spacer()
                    Button(detection.isFound ? "Change" : "Set manually") {
                        isEditingWikiManually = true
                    }
                    .font(.caption.weight(.semibold))
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEditingWikiManually)
    }

    /// Debounced wiki lookup for the current title.
    private func detectWiki() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            detection = .idle
            return
        }

        // Wait out further typing. `.task(id:)` cancels this on the next
        // keystroke, so only a settled title reaches the network.
        do {
            try await Task.sleep(for: .milliseconds(500))
        } catch {
            return
        }

        detection = .searching
        let found = await FandomDirectory.detect(title: trimmed)
        guard !Task.isCancelled else { return }
        detection = found.map { .found($0) } ?? .notFound
    }

    private func addMedia() {
        let manual = manualWiki.trimmingCharacters(in: .whitespacesAndNewlines)
        let useManual = isEditingWikiManually && !manual.isEmpty

        let newItem = MediaItem(
            title: title,
            creator: creator,
            mediaType: selectedType,
            fandomWiki: useManual ? manual : detection.wiki?.slug,
            fandomWikiName: useManual ? nil : detection.wiki?.name,
            fandomWikiIsManual: useManual,
            // Only claim detection ran if it actually finished, so an item added
            // before the probe settled still gets one later.
            fandomWikiDetectionAttempted: useManual || detection.hasSettled,
            // New lists land at the bottom of the user's ordering.
            sortIndex: (mediaItems.map(\.sortIndex).max() ?? -1) + 1
        )
        modelContext.insert(newItem)
        try? modelContext.save()
    }
}

// MARK: - Wiki detection state

/// Outcome of looking for a Fandom wiki for a title.
enum WikiDetectionState: Equatable {
    case idle
    case searching
    case found(DetectedWiki)
    case notFound

    var wiki: DetectedWiki? {
        if case .found(let wiki) = self { return wiki }
        return nil
    }

    var isFound: Bool { wiki != nil }

    /// Whether the probe reached a conclusion (as opposed to never running).
    var hasSettled: Bool {
        switch self {
        case .found, .notFound: return true
        case .idle, .searching: return false
        }
    }

    var symbol: String {
        switch self {
        case .idle:      return "sparkle.magnifyingglass"
        case .searching: return "sparkle.magnifyingglass"
        case .found:     return "checkmark.circle.fill"
        case .notFound:  return "questionmark.circle"
        }
    }

    var message: String {
        switch self {
        case .idle:
            return "Enter a title to find its wiki automatically."
        case .searching:
            return "Looking for a wiki\u{2026}"
        case .found(let wiki):
            return "Using \(wiki.name)"
        case .notFound:
            return "No wiki found. Invented words may not resolve."
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MediaItem.sortIndex) private var mediaItems: [MediaItem]

    @State private var exportDocument: TransferDocument?
    @State private var exportContentType: UTType = .json
    @State private var exportFilename = "faff-words"
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var resultMessage: String?
    @State private var showingResult = false

    private var theme: AppTheme { themeManager.theme }
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        livePreview

                        VStack(alignment: .leading, spacing: 12) {
                            Text("COLOR PACK")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.textSecondary)
                                .padding(.leading, 4)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(ColorPack.allCases) { pack in
                                    ColorPackCard(
                                        pack: pack,
                                        isSelected: pack == themeManager.pack
                                    ) {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            themeManager.pack = pack
                                        }
                                    }
                                }
                            }
                        }

                        dataSection
                    }
                    .padding()
                }
            }
            .themedNavigationTitle(nil, theme: theme)
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: exportContentType,
                defaultFilename: exportFilename
            ) { _ in }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json, .commaSeparatedText, .plainText, .text]
            ) { result in
                handleImport(result)
            }
            .alert("Import", isPresented: $showingResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(resultMessage ?? "")
            }
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR DATA")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.textSecondary)
                .padding(.leading, 4)

            LazyVGrid(columns: columns, spacing: 16) {
                dataButton(title: "Export JSON", systemImage: "arrow.up.doc.fill") {
                    exportContentType = .json
                    exportFilename = "faff-words"
                    exportDocument = TransferDocument(data: WordDataTransfer.exportJSON(mediaItems),
                                                      contentType: .json)
                    showingExporter = true
                }
                dataButton(title: "Export CSV", systemImage: "tablecells.fill") {
                    exportContentType = .commaSeparatedText
                    exportFilename = "faff-words"
                    exportDocument = TransferDocument(data: WordDataTransfer.exportCSV(mediaItems),
                                                      contentType: .commaSeparatedText)
                    showingExporter = true
                }
                dataButton(title: "Import File", systemImage: "arrow.down.doc.fill") {
                    showingImporter = true
                }
            }

            Text("\(mediaItems.count) lists • \(mediaItems.reduce(0) { $0 + $1.learnedWords.count }) words. Export to back up or analyze elsewhere; import adds lists that aren\u{2019}t already here.")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, 4)
        }
    }

    private func dataButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(theme.primary)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.surfaceStroke, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let format: WordDataFormat = url.pathExtension.lowercased() == "json" ? .json : .csv
                let exports = try WordDataTransfer.parse(data, format: format)
                let added = WordDataTransfer.importItems(exports, into: modelContext, existing: mediaItems)
                resultMessage = added.lists == 0
                    ? "Nothing new to import — those lists are already here."
                    : "Imported \(added.lists) lists and \(added.words) words."
            } catch {
                resultMessage = "Import failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            resultMessage = "Import failed: \(error.localizedDescription)"
        }
        showingResult = true
    }

    private var livePreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: theme.symbol)
                    .font(.title2)
                    .foregroundStyle(theme.onPrimary)
                    .frame(width: 46, height: 46)
                    .background(theme.primary)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    Text("Active color pack")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(["Melange", "Fremen", "Spice"], id: \.self) { chip in
                    Text(chip)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.accent.opacity(0.30))
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 22, tint: theme.surface)
    }
}

private struct ColorPackCard: View {
    let pack: ColorPack
    let isSelected: Bool
    let action: () -> Void

    private var t: AppTheme { pack.theme }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: t.symbol)
                        .foregroundStyle(t.primary)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? t.primary : t.textSecondary.opacity(0.4))
                }

                Text(t.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(t.textPrimary)

                HStack(spacing: 6) {
                    swatch(t.primary)
                    swatch(t.secondary)
                    swatch(t.accent)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t.background)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? t.primary : t.surfaceStroke,
                            lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: .black.opacity(isSelected ? 0.12 : 0.04),
                    radius: isSelected ? 8 : 3, y: 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }

    private func swatch(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1))
    }
}

// MARK: - Transfer document

/// Lightweight FileDocument used by the export sheet to write JSON or CSV.
struct TransferDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.json, .commaSeparatedText, .plainText, .text]
    }

    var data: Data
    var contentType: UTType

    init(data: Data, contentType: UTType) {
        self.data = data
        self.contentType = contentType
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
        contentType = .json
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Previews

#Preview("App") {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MediaItem.self, configurations: config)
        SampleData.generateSampleData(modelContext: container.mainContext)

        return MainTabView()
            .modelContainer(container)
            .environment(ThemeManager.shared)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}

#Preview("Settings") {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MediaItem.self, configurations: config)
        SampleData.generateSampleData(modelContext: container.mainContext)

        return SettingsView()
            .modelContainer(container)
            .environment(ThemeManager.shared)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
