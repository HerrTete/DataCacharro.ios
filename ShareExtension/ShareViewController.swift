import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    private var pendingItems: [DataItem] = []
    private let itemsLock = NSLock()

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        view.backgroundColor = .clear
        processSharedItems()
    }

    // MARK: - Processing

    private func processSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            finish()
            return
        }

        let group = DispatchGroup()

        for extensionItem in extensionItems {
            for provider in extensionItem.attachments ?? [] {
                group.enter()
                processProvider(provider) { group.leave() }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.itemsLock.lock()
            let items = self.pendingItems
            self.itemsLock.unlock()
            if !items.isEmpty { self.commitItems(items) }
            self.finish()
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    // MARK: - Provider handling

    private func processProvider(_ provider: NSItemProvider, completion: @escaping () -> Void) {
        // 1. Media types (image, movie, audio)
        for utType in [UTType.image, .movie, .audio] as [UTType] {
            if provider.hasItemConformingToTypeIdentifier(utType.identifier) {
                loadFile(from: provider, utType: utType, completion: completion)
                return
            }
        }

        // 2. File URLs
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            loadFile(from: provider, utType: .fileURL, completion: completion)
            return
        }

        // 3. Web URLs
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, _ in
                if let url = item as? URL {
                    if url.isFileURL {
                        if let dataItem = self?.copyFileToContainer(url: url) {
                            self?.addItem(dataItem)
                        }
                    } else {
                        self?.addItem(DataItem(type: .text, title: String(url.absoluteString.prefix(50)),
                                               tags: ["URL"], textContent: url.absoluteString))
                    }
                }
                completion()
            }
            return
        }

        // 4. Plain text
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, _ in
                var text: String?
                if let t = item as? String { text = t }
                else if let data = item as? Data { text = String(data: data, encoding: .utf8) }
                if let text {
                    let tag = isURLString(text) ? "URL" : DataItemType.text.defaultTag
                    self?.addItem(DataItem(type: .text, title: String(text.prefix(50)),
                                           tags: [tag], textContent: text))
                }
                completion()
            }
            return
        }

        // 5. Any other data
        if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            loadFile(from: provider, utType: .data, completion: completion)
            return
        }

        completion()
    }

    private func loadFile(from provider: NSItemProvider, utType: UTType, completion: @escaping () -> Void) {
        _ = provider.loadFileRepresentation(for: utType) { [weak self] url, _, _ in
            if let url, let item = self?.copyFileToContainer(url: url) {
                self?.addItem(item)
            }
            completion()
        }
    }

    private func addItem(_ item: DataItem) {
        itemsLock.lock()
        pendingItems.append(item)
        itemsLock.unlock()
    }

    // MARK: - File operations

    private func copyFileToContainer(url: URL) -> DataItem? {
        guard let containerURL = StorageConstants.appGroupURL else { return nil }
        let filesDir = containerURL.appendingPathComponent(StorageConstants.filesDirectoryName)
        try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)

        let origName = url.lastPathComponent
        let ext = url.pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let dest = filesDir.appendingPathComponent(uniqueName)

        do {
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            try FileManager.default.copyItem(at: url, to: dest)
        } catch {
            return nil
        }

        let mimeType = UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
        let type = DataItemType(mimeType: mimeType, fileName: origName)
        return DataItem(type: type, title: origName, tags: [type.defaultTag],
                        fileName: uniqueName, mimeType: mimeType)
    }

    // MARK: - Persistence

    private func commitItems(_ items: [DataItem]) {
        guard let containerURL = StorageConstants.appGroupURL else { return }
        let url = containerURL.appendingPathComponent(StorageConstants.itemsFileName)

        let coordinator = NSFileCoordinator()
        var coordError: NSError?

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { coordURL in
            var existing: [DataItem] = []
            if let data = try? Data(contentsOf: coordURL),
               let decoded = try? JSONDecoder().decode([DataItem].self, from: data) {
                existing = decoded
            }
            existing.insert(contentsOf: items, at: 0)
            if let encoded = try? JSONEncoder().encode(existing) {
                try? encoded.write(to: coordURL, options: .atomic)
            }
        }

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = CFNotificationName(StorageConstants.itemsChangedNotification as CFString)
        CFNotificationCenterPostNotification(center, name, nil, nil, true)
    }
}
