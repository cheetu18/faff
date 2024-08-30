import SwiftUI
import SwiftData

func ItemStack(type: MediaType, description: String) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: 8) {
            Text(type.rawValue.capitalized)
                .font(.title2)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        Spacer()
        Image(systemName: mediaSymbol(type))
            .font(.title)
            .foregroundColor(.primary)
    }
    .padding()
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
}

struct CategoryView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(MediaType.allCases, id: \.rawValue) { item in
                        NavigationLink(destination: MediaItemListView(mediaType: item)) {
                            ItemStack(type: item, description: "View all \(item.rawValue)s")
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitle("Menu")
        }
    }
}

#Preview {
    do {
         let config = ModelConfiguration(isStoredInMemoryOnly: true)
         let container = try ModelContainer(for: MediaItem.self, configurations: config)
         
         // Generate sample data
         SampleData.generateSampleData(modelContext: container.mainContext)
         
         return CategoryView()
             .modelContainer(container)
     } catch {
         return Text("Failed to create preview: \(error.localizedDescription)")
     }
 }
