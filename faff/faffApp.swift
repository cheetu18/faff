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
    /*
     var sharedModelContainer: ModelContainer = {
     let schema = Schema([
     Item.self,
     ])
     let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
     
     do {
     return try ModelContainer(for: schema, configurations: [modelConfiguration])
     } catch {
     fatalError("Could not create ModelContainer: \(error)")
     }
     }
     ()
     */
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: MediaItem.self)
        /*        .modelContainer(for: MediaItem.self) { result in
         switch result {
         case .success(let container):
         let fetchDescriptor = FetchDescriptor<MediaItem>(predicate: nil)
         let count = try? container.mainContext.fetchCount(fetchDescriptor)
         print("Initial item count: \(count ?? 0)")
         if count == 0 {
         SampleData.generateSampleData(modelContext: container.mainContext)
         let newCount = try? container.mainContext.fetchCount(fetchDescriptor)
         print("After adding sample data, count: \(newCount ?? 0)")
         }
         case .failure(let error):
         fatalError("Failed to create ModelContainer: \(error.localizedDescription)")
         }
         }
         }
         */
    }
    
}
