//
//  ContentView.swift
//  faff
//
//  Created by kyle reddy  on 6/26/24.
//

import SwiftUI
import SwiftData

// MARK: - Root tab container

struct MainTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Lists", systemImage: "books.vertical.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(themeManager.theme.primary)
    }
}

// MARK: - Lists

struct ContentView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Query private var mediaItems: [MediaItem]
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
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(filteredItems) { item in
                                NavigationLink(value: item) {
                                    MediaRow(item: item, theme: theme)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteItem(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationDestination(for: MediaItem.self) { item in
                MediaItemView(mediaItem: item)
            }
            .navigationTitle("My Lists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            isShowingAddMedia = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(theme.primary)
                        }

                        Menu {
                            Button("All") { selectedMediaType = nil }
                            ForEach(MediaType.allCases, id: \.self) { type in
                                Button {
                                    selectedMediaType = type
                                } label: {
                                    Label(type.rawValue.capitalized,
                                          systemImage: mediaSymbol(type))
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(theme.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingAddMedia) {
                AddMediaView()
                    .environmentObject(themeManager)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical")
                .font(.system(size: 52))
                .foregroundColor(theme.primary.opacity(0.5))
            Text("No lists yet")
                .font(.title3.weight(.semibold))
                .foregroundColor(theme.textPrimary)
            Text("Tap + to track words from a book, movie, or podcast.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(theme.textSecondary)
                .padding(.horizontal, 40)
        }
    }

    private func deleteItem(_ item: MediaItem) {
        guard let modelContext = item.modelContext else { return }
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
                .foregroundColor(theme.media(item.mediaType))
                .frame(width: 44, height: 44)
                .background(theme.media(item.mediaType).opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                    .foregroundColor(theme.textPrimary)
                Text("\(item.learnedWords.count) words • \(item.creator)")
                    .font(.caption)
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundColor(theme.textSecondary.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 18, tint: theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.surfaceStroke, lineWidth: 1)
        )
    }
}

// MARK: - Add media

struct AddMediaView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var creator = ""
    @State private var selectedType: MediaType = .book

    private var theme: AppTheme { themeManager.theme }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background.ignoresSafeArea()

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

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Add Media")
            .navigationBarTitleDisplayMode(.inline)
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

    private func addMedia() {
        let newItem = MediaItem(title: title, creator: creator, mediaType: selectedType)
        modelContext.insert(newItem)
        try? modelContext.save()
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager

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
                                .foregroundColor(theme.textSecondary)
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
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var livePreview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: theme.symbol)
                    .font(.title2)
                    .foregroundColor(theme.onPrimary)
                    .frame(width: 46, height: 46)
                    .background(theme.primary)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(.headline)
                        .foregroundColor(theme.textPrimary)
                    Text("Active color pack")
                        .font(.caption)
                        .foregroundColor(theme.textSecondary)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(["Melange", "Fremen", "Spice"], id: \.self) { chip in
                    Text(chip)
                        .font(.caption.weight(.medium))
                        .foregroundColor(theme.textPrimary)
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
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.surfaceStroke, lineWidth: 1)
        )
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
                        .foregroundColor(t.primary)
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? t.primary : t.textSecondary.opacity(0.4))
                }

                Text(t.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(t.textPrimary)

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

// MARK: - Previews

#Preview("App") {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: MediaItem.self, configurations: config)
        SampleData.generateSampleData(modelContext: container.mainContext)

        return MainTabView()
            .modelContainer(container)
            .environmentObject(ThemeManager.shared)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}

#Preview("Settings") {
    SettingsView()
        .environmentObject(ThemeManager.shared)
}
