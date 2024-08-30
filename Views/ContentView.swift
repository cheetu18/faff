//
//  ContentView.swift
//  faff
//
//  Created by kyle reddy  on 6/26/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var mediaItems: [MediaItem]
    @State private var path = NavigationPath()

    var body: some View {

    NavigationStack(path: $path) {
            List(mediaItems) { item in
                NavigationLink(item.title, value: item)
            }
            
            .navigationDestination(for: MediaItem.self) { item in
                MediaItemView(mediaItem: item)
            }
        }
    }
}


#Preview {
    do {
         let config = ModelConfiguration(isStoredInMemoryOnly: true)
         let container = try ModelContainer(for: MediaItem.self, configurations: config)
         
         // Generate sample data
         SampleData.generateSampleData(modelContext: container.mainContext)
         
         return ContentView()
             .modelContainer(container)
     } catch {
         return Text("Failed to create preview: \(error.localizedDescription)")
     }
}
