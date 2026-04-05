import SwiftUI

struct TagsView: View {
    @EnvironmentObject var storage: StorageService
    @State private var tagListSelecting = false

    private var tagsWithCounts: [(tag: String, count: Int)] {
        let counts = Dictionary(grouping: storage.items.flatMap { $0.tags }, by: { $0 })
            .mapValues { $0.count }
        return storage.allTags.map { tag in
            (tag: tag, count: counts[tag] ?? 0)
        }
    }

    var body: some View {
        List {
            ForEach(tagsWithCounts, id: \.tag) { entry in
                NavigationLink {
                    ItemListView(isSelecting: $tagListSelecting, filterTag: entry.tag)
                        .navigationTitle(entry.tag)
                } label: {
                    HStack {
                        Label(entry.tag, systemImage: "tag")
                        Spacer()
                        Text("\(entry.count)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .accessibilityIdentifier("tagCount_\(entry.tag)")
                    }
                }
            }
        }
        .overlay {
            if storage.allTags.isEmpty {
                ContentUnavailableView(
                    "No Tags",
                    systemImage: "tag.slash",
                    description: Text("Add tags to your items to organize them.")
                )
            }
        }
    }
}
