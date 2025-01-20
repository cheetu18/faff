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
        
        init() {
            do {
                // Delete existing store in debug
                #if DEBUG
                try? FileManager.default.removeItem(
                    at: URL.applicationSupportDirectory.appendingPathComponent("default.store")
                )
                #endif
                
                container = try ModelContainer(
                    for: MediaItem.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: false)
                )
                
                #if DEBUG
                SampleData.generateSampleData(modelContext: container.mainContext)
                #endif
                
            } catch {
                fatalError("Failed to create container: \(error.localizedDescription)")
            }
        }
        
        var body: some Scene {
            WindowGroup {
                ContentView()
            }
            .modelContainer(container)
        }
    }
