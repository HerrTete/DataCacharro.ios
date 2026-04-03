import SwiftUI
import AVFoundation

struct ItemListView: View {
    @EnvironmentObject var storage: StorageService
    var filterTag: String? = nil
    @Binding var isSelecting: Bool
    @State private var selectedItem: DataItem?
    @State private var tagItem: DataItem?
    @State private var selectedIDs: Set<String> = []

    init(isSelecting: Binding<Bool>, filterTag: String? = nil) {
        self._isSelecting = isSelecting
        self.filterTag = filterTag
    }

    private var showingSelectionBar: Bool {
        isSelecting && !selectedIDs.isEmpty
    }

    private var displayedItems: [DataItem] {
        if let tag = filterTag {
            return storage.items.filter { $0.tags.contains(tag) }
        }
        return storage.items
    }

    var body: some View {
        List {
            ForEach(displayedItems) { item in
                ItemRowView(item: item, isSelecting: isSelecting, isSelected: selectedIDs.contains(item.id))
                    .accessibilityIdentifier("itemRow_\(item.id)")
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isSelecting {
                            toggleSelection(item)
                        } else if let url = item.url {
                            UIApplication.shared.open(url)
                        } else {
                            selectedItem = item
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        if !isSelecting {
                            Button {
                                tagItem = item
                            } label: {
                                Label("Tags", systemImage: "tag")
                            }
                            .tint(.blue)
                            .accessibilityIdentifier("swipeTagsButton")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if !isSelecting {
                            Button(role: .destructive) {
                                storage.deleteItem(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .contextMenu {
                        if !isSelecting {
                            Button {
                                tagItem = item
                            } label: {
                                Label("Manage Tags", systemImage: "tag")
                            }
                            Button {
                                prepareShare(item)
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            Button(role: .destructive) {
                                storage.deleteItem(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isSelecting {
                    Button("Cancel") {
                        isSelecting = false
                        selectedIDs = []
                    }
                    .accessibilityIdentifier("cancelSelectButton")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !displayedItems.isEmpty {
                    let allSelected = selectedIDs.count == displayedItems.count
                    Button(isSelecting ? (allSelected ? "Deselect All" : "Select All") : "Select") {
                        if isSelecting {
                            selectedIDs = allSelected ? [] : Set(displayedItems.map { $0.id })
                        } else {
                            isSelecting = true
                            selectedIDs = []
                        }
                    }
                    .accessibilityIdentifier("selectButton")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if showingSelectionBar {
                HStack {
                    HStack(spacing: 20) {
                        tabBarIcon("list.bullet", label: "Items")
                        tabBarIcon("gearshape", label: "Settings")
                        tabBarIcon("number", label: "Tags")
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                    Spacer()
                    Button(role: .destructive) {
                        storage.deleteItems(ids: selectedIDs)
                        isSelecting = false
                        selectedIDs = []
                    } label: {
                        Label("Delete (\(selectedIDs.count))", systemImage: "trash")
                    }
                    .accessibilityIdentifier("deleteSelectedButton")
                    .foregroundStyle(.red)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.bar)
                .overlay(alignment: .top) { Divider() }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Selection bar: \(selectedIDs.count) item(s) selected")
            }
        }
        .toolbar(showingSelectionBar ? .hidden : .visible, for: .tabBar)
        .sheet(item: $selectedItem) { item in
            ItemDetailView(item: item)
                .environmentObject(storage)
        }
        .sheet(item: $tagItem) { item in
            QuickTagView(item: item)
                .environmentObject(storage)
        }
        .overlay {
            if displayedItems.isEmpty {
                ContentUnavailableView(
                    filterTag != nil ? "No Items with this Tag" : "No Items",
                    systemImage: "tray",
                    description: Text(filterTag != nil ? "No items are tagged with \"\(filterTag!)\"." : "Share content from other apps or tap + to add text.")
                )
            }
        }
    }

    private func toggleSelection(_ item: DataItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    private func prepareShare(_ item: DataItem) {
        var items: [Any] = []
        if let text = item.textContent {
            items.append(text)
        } else if let url = storage.fileURL(for: item) {
            items.append(url)
        }
        guard !items.isEmpty else { return }
        SharePresenter.present(items: items)
    }

    @ViewBuilder
    private func tabBarIcon(_ systemImage: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage).font(.system(size: 20))
            Text(label).font(.caption2)
        }
    }
}

struct ItemRowView: View {
    let item: DataItem
    var isSelecting: Bool = false
    var isSelected: Bool = false
    @EnvironmentObject var storage: StorageService

    var body: some View {
        HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .animation(.easeInOut(duration: 0.15), value: isSelected)
            }
            itemIcon
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .lineLimit(2)
                    .font(.body)
                if !item.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(item.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                Text(item.createdDate, format: .dateTime)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let location = item.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var itemIcon: some View {
        switch item.type {
        case .text:
            Image(systemName: item.url != nil ? "link" : "text.quote")
                .font(.title2)
                .foregroundStyle(.blue)
        case .image:
            ThumbnailView(item: item)
        case .video:
            ThumbnailView(item: item)
        case .audio:
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(.purple)
        case .file:
            Image(systemName: "doc")
                .font(.title2)
                .foregroundStyle(.gray)
        }
    }
}

struct ThumbnailView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService
    @State private var thumbnail: UIImage?

    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task { await loadThumbnail() }
    }

    @ViewBuilder
    private var placeholder: some View {
        switch item.type {
        case .image:
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(.green)
        case .video:
            Image(systemName: "video")
                .font(.title2)
                .foregroundStyle(.orange)
        default:
            EmptyView()
        }
    }

    private func loadThumbnail() async {
        let cacheKey = item.id as NSString
        if let cached = ThumbnailView.cache.object(forKey: cacheKey) {
            thumbnail = cached
            return
        }
        guard let url = storage.fileURL(for: item) else { return }
        let loaded: UIImage?
        switch item.type {
        case .image:
            loaded = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: url.path)?.preparingThumbnail(of: CGSize(width: 72, height: 72))
            }.value
        case .video:
            loaded = await Task.detached(priority: .userInitiated) {
                let asset = AVAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                generator.maximumSize = CGSize(width: 72, height: 72)
                return (try? generator.copyCGImage(at: CMTime.zero, actualTime: nil)).map { UIImage(cgImage: $0) }
            }.value
        default:
            return
        }
        if let loaded {
            ThumbnailView.cache.setObject(loaded, forKey: cacheKey)
            thumbnail = loaded
        }
    }
}
