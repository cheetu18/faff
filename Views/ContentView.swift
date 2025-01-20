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
    @State private var selectedMediaType: MediaType? = nil
    @State private var isShowingAddMedia = false  // New state for showing add sheet
    
    private var filteredItems: [MediaItem] {
        if let selectedType = selectedMediaType {
            return mediaItems.filter { $0.mediaType == selectedType }
        }
        return mediaItems
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.duckCream
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(filteredItems) { item in
                            NavigationLink(value: item) {
                                HStack {
                                    Image(systemName: mediaSymbol(item.mediaType))
                                        .foregroundColor(mediaColor(item.mediaType))
                                        .font(.system(size: 20))
                                        .frame(width: 30)
                                    
                                    Text(item.title)
                                        .foregroundColor(.duckSlate)
                                        .padding(.vertical, 12)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(mediaColor(item.mediaType).opacity(0.6))
                                }
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(mediaColor(item.mediaType).opacity(0.2), lineWidth: 1)
                                )
                                .shadow(
                                    color: mediaColor(item.mediaType).opacity(0.1),
                                    radius: 4,
                                    x: 0,
                                    y: 2
                                )
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    // Delete media item
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
            .navigationDestination(for: MediaItem.self) { item in
                MediaItemView(mediaItem: item)
            }
            .navigationTitle("My Lists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            isShowingAddMedia = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.duckSlate)
                        }
                        
                        Menu {
                            Button("All", action: { selectedMediaType = nil })
                            ForEach(MediaType.allCases, id: \.self) { type in
                                Button(action: {
                                    selectedMediaType = type
                                }) {
                                    Label(type.rawValue.capitalized, systemImage: mediaSymbol(type))
                                        .foregroundColor(mediaColor(type))
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .foregroundColor(.duckSlate)
                        }
                        
                       // Button(action: NavigationLink(destination: <#T##() -> Destination#>, label: <#T##() -> Label#>) )
                    }
                }
            }
            .sheet(isPresented: $isShowingAddMedia) {
                AddMediaView()
            }
        }
    }
    
    private func deleteItem(_ item: MediaItem) {
        guard let modelContext = item.modelContext else { return }
        modelContext.delete(item)
        try? modelContext.save()
    }
}

// New view for adding media items
struct AddMediaView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title = ""
    @State private var creator = ""
    @State private var selectedType: MediaType = .book
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.duckCream
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    TextField("Title", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Creator", text: $creator)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("Media Type", selection: $selectedType) {
                        ForEach(MediaType.allCases, id: \.self) { type in
                            Label(type.rawValue.capitalized, systemImage: mediaSymbol(type))
                                .foregroundColor(mediaColor(type))
                                .tag(type)
                        }
                    }
                    .pickerStyle(.wheel)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Add Media")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Add") {
                    addMedia()
                    dismiss()
                }
                .disabled(title.isEmpty || creator.isEmpty)
            )
        }
    }
    
    private func addMedia() {
        let newItem = MediaItem(
            title: title,
            creator: creator,
            mediaType: selectedType
        )
        modelContext.insert(newItem)
        try? modelContext.save()
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
