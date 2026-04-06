import SwiftUI
import AVKit
import QuickLook

struct ItemDetailView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService
    @Environment(\.dismiss) var dismiss
    @State private var showingQuickLook = false
    @State private var quickLookURL: URL?
    @State private var showingEdit = false

    var currentItem: DataItem {
        storage.items.first(where: { $0.id == item.id }) ?? item
    }

    var body: some View {
        NavigationStack {
            Group {
                switch currentItem.type {
                case .text:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(currentItem.textContent ?? "")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if let url = currentItem.url {
                                Button {
                                    UIApplication.shared.open(url)
                                } label: {
                                    Label("Open in Browser", systemImage: "safari")
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.horizontal)
                            }
                        }
                    }
                case .image:
                    ImageDetailView(item: currentItem)
                case .video:
                    VideoDetailView(item: currentItem)
                case .audio:
                    AudioDetailView(item: currentItem)
                case .file:
                    FileDetailView(item: currentItem) { url in
                        quickLookURL = url
                        showingQuickLook = true
                    }
                }
            }
            .navigationTitle(currentItem.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("doneButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingEdit = true }) {
                        Image(systemName: "pencil")
                    }
                    .accessibilityIdentifier("editButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: share) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("shareButton")
                }
            }
        }
        .sheet(isPresented: $showingQuickLook) {
            if let url = quickLookURL {
                QuickLookView(url: url)
            }
        }
        .sheet(isPresented: $showingEdit) {
            EditItemView(item: currentItem)
                .environmentObject(storage)
        }
    }

    private func share() {
        var items: [Any] = []
        if let text = currentItem.textContent {
            items.append(text)
        } else if let url = storage.fileURL(for: currentItem) {
            items.append(url)
        }
        SharePresenter.present(items: items)
    }
}

struct EditItemView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService
    @Environment(\.dismiss) var dismiss
    @State private var customName: String
    @State private var tags: [String]
    @State private var tagInput = ""

    private var suggestions: [String] {
        let existing = storage.allTags
        let query = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        return existing.filter { $0.lowercased().hasPrefix(query) && !tags.contains($0) }
    }

    init(item: DataItem) {
        self.item = item
        _customName = State(initialValue: item.customName ?? "")
        _tags = State(initialValue: item.tags)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField(item.title, text: $customName)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("nameTextField")
                }

                Section("Tags") {
                    if !tags.isEmpty {
                        ForEach(tags, id: \.self) { tag in
                            HStack {
                                Label(tag, systemImage: "tag")
                                Spacer()
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("removeTag_\(tag)")
                            }
                        }
                    }

                    HStack {
                        TextField("Add tag…", text: $tagInput)
                            .autocorrectionDisabled()
                            .autocapitalization(.none)
                            .onSubmit { addTagFromInput() }
                            .accessibilityIdentifier("tagInputField")
                        if !tagInput.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button(action: addTagFromInput) {
                                Image(systemName: "plus.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("addTagButton")
                        }
                    }

                    if !suggestions.isEmpty {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                guard !tags.contains(suggestion) else { return }
                                tags.append(suggestion)
                                tagInput = ""
                            } label: {
                                Label(suggestion, systemImage: "tag")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        addTagFromInput()
                        let trimmed = customName.trimmingCharacters(in: .whitespaces)
                        var updated = item
                        updated.customName = trimmed.isEmpty ? nil : trimmed
                        updated.tags = tags
                        storage.updateItem(updated)
                        dismiss()
                    }
                    .accessibilityIdentifier("saveButton")
                }
            }
        }
    }

    private func addTagFromInput() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !tags.contains(tag) else { return }
        tags.append(tag)
        tagInput = ""
    }
}

struct ImageDetailView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService

    var body: some View {
        if let url = storage.fileURL(for: item), let image = UIImage(contentsOfFile: url.path) {
            ZoomableImageView(image: image)
        } else {
            ContentUnavailableView("Image not found", systemImage: "photo.slash")
        }
    }
}

struct VideoDetailView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService

    var body: some View {
        if let url = storage.fileURL(for: item) {
            VideoPlayer(player: AVPlayer(url: url))
        } else {
            ContentUnavailableView("Video not found", systemImage: "video.slash")
        }
    }
}

struct AudioDetailView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService
    @State private var player: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.purple)

            Text(item.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.purple)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let url = storage.fileURL(for: item) {
                player = AVPlayer(url: url)
            }
        }
        .onDisappear {
            player?.pause()
        }
    }

    private func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }
}

struct FileDetailView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService
    let onOpenExternal: (URL) -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.fill")
                .font(.system(size: 80))
                .foregroundStyle(.gray)

            Text(item.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let mimeType = item.mimeType {
                Text(mimeType)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let url = storage.fileURL(for: item) {
                Button("Open in External App") {
                    onOpenExternal(url)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct QuickTagView: View {
    let item: DataItem
    @EnvironmentObject var storage: StorageService
    @Environment(\.dismiss) var dismiss
    @State private var tags: [String]
    @State private var tagInput = ""

    private var suggestions: [String] {
        let query = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return [] }
        return storage.allTags.filter { $0.lowercased().hasPrefix(query) && !tags.contains($0) }
    }

    init(item: DataItem) {
        self.item = item
        _tags = State(initialValue: item.tags)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if !storage.allTags.isEmpty {
                    ScrollView {
                        FlowLayout(spacing: 8) {
                            ForEach(storage.allTags, id: \.self) { tag in
                                let selected = tags.contains(tag)
                                Button {
                                    if selected {
                                        tags.removeAll { $0 == tag }
                                    } else {
                                        tags.append(tag)
                                    }
                                } label: {
                                    Label(tag, systemImage: selected ? "checkmark" : "tag")
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(selected ? Color.accentColor : Color.accentColor.opacity(0.12))
                                        .foregroundStyle(selected ? Color.white : Color.accentColor)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                HStack {
                    TextField("New tag…", text: $tagInput)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addTagFromInput() }
                        .accessibilityIdentifier("newTagField")
                    if !tagInput.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button(action: addTagFromInput) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("addTagButton")
                    }
                }
                .padding(.horizontal)

                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                tags.append(suggestion)
                                tagInput = ""
                            } label: {
                                Label(suggestion, systemImage: "tag")
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                            }
                            Divider().padding(.leading)
                        }
                    }
                }

                Spacer()
            }
            .padding(.top, 12)
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        addTagFromInput()
                        var updated = item
                        updated.tags = tags
                        storage.updateItem(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("saveButton")
                }
            }
        }
    }

    private func addTagFromInput() {
        let tag = tagInput.trimmingCharacters(in: .whitespaces)
        guard !tag.isEmpty, !tags.contains(tag) else { return }
        tags.append(tag)
        tagInput = ""
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let rowHeights = rows.map { row in row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }
        let totalSpacing = CGFloat(max(rowHeights.count - 1, 0)) * spacing
        let height = rowHeights.reduce(0, +) + totalSpacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubview]] = [[]]
        var currentWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth, !(rows.last?.isEmpty ?? true) {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(subview)
            currentWidth += size.width + spacing
        }
        return rows
    }
}

enum SharePresenter {
    static func present(items: [Any]) {
        guard !items.isEmpty,
              let windowScene = UIApplication.shared.connectedScenes
                  .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.keyWindow?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        topVC.present(activityVC, animated: true)
    }
}

struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let vc = QLPreviewController()
        vc.dataSource = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            url as NSURL
        }
    }
}
