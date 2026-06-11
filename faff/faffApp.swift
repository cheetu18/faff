//
//  faffApp.swift
//  faff
//
//  Created by kyle reddy  on 6/20/24.
//

import SwiftUI
import SwiftData

@main
struct faffApp: App {
        let container: ModelContainer
        @StateObject private var themeManager = ThemeManager.shared

        init() {
            do {
                container = try ModelContainer(
                    for: MediaItem.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: false)
                )

                // Seed sample data only on a fresh (empty) store so that the
                // user's real data — including imports and cached definitions —
                // persists across launches. Release builds start empty and are
                // populated by the user (manually or via import).
                #if DEBUG
                let context = container.mainContext
                let existing = (try? context.fetchCount(FetchDescriptor<MediaItem>())) ?? 0
                if existing == 0 {
                    SampleData.generateSampleData(modelContext: context)
                }
                #endif
            } catch {
                fatalError("Failed to create container: \(error.localizedDescription)")
            }
        }
        
        var body: some Scene {
            WindowGroup {
                MainTabView()
                    .environmentObject(themeManager)
                    .preferredColorScheme(themeManager.theme.isDark ? .dark : .light)
            }
            .modelContainer(container)
        }
    }
