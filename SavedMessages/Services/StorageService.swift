import Foundation
import UIKit

struct SyncResult {
    let itemsAdded: Int
    let itemsUpdated: Int
    let errors: [String]

    var hasChanges: Bool { itemsAdded > 0 || itemsUpdated > 0 }
    var hasErrors: Bool { !errors.isEmpty }
}

class StorageService: ObservableObject {
    static let shared = StorageService()

    @Published var items: [DataItem] = []

    private var deletedIDs: Set<String> = []
    private var isSyncing = false
    private var pendingSyncCompletions: [() -> Void] = []
    private var metadataQuery: NSMetadataQuery?
    private static let syncDebounceDelay: TimeInterval = 2

    private var iCloudURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: StorageConstants.iCloudContainerID)?
            .appendingPathComponent("Documents")
    }

    init() {
        setupDirectories()
        loadDeletedIDs()
        loadItems()
        registerForShareExtensionNotifications()
        startMonitoringiCloudChanges()
        syncFromiCloud()
    }

    deinit {
        metadataQuery?.stop()
        NotificationCenter.default.removeObserver(self)
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveEveryObserver(center, Unmanaged.passUnretained(self).toOpaque())
    }

    private func registerForShareExtensionNotifications() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = StorageConstants.itemsChangedNotification as CFString
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            center, observer,
            { _, observer, _, _, _ in
                guard let observer = observer else { return }
                let service = Unmanaged<StorageService>.fromOpaque(observer).takeUnretainedValue()
                service.loadItems()
            },
            name, nil, .deliverImmediately
        )
    }

    private func setupDirectories() {
        guard let filesURL = StorageConstants.filesURL else { return }
        try? FileManager.default.createDirectory(at: filesURL, withIntermediateDirectories: true)
    }

    func loadItems() {
        guard let url = StorageConstants.itemsFileURL else { return }

        // Use NSFileCoordinator to read data written by the share extension
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var loadedItems: [DataItem]?

        coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { coordinatedURL in
            guard let data = try? Data(contentsOf: coordinatedURL) else { return }
            loadedItems = try? JSONDecoder().decode([DataItem].self, from: data)
        }

        if let coordError = coordError {
            print("StorageService.loadItems coordination error: \(coordError)")
            // Fallback to uncoordinated read when coordination fails
            if let data = try? Data(contentsOf: url) {
                loadedItems = try? JSONDecoder().decode([DataItem].self, from: data)
            }
        }

        if let loaded = loadedItems {
            DispatchQueue.main.async {
                self.items = loaded.sorted { $0.createdAt > $1.createdAt }
            }
        }
    }

    func saveItems() {
        saveItemsLocally()
        // Only sync to iCloud if we're not in the middle of a syncFromiCloud
        // (which already handles uploading the merged result)
        if !isSyncing {
            syncToiCloud()
        }
    }

    /// Writes the current items array to disk using file coordination,
    /// without triggering an iCloud sync. Used internally to avoid
    /// re-entrant sync cycles.
    private func saveItemsLocally() {
        guard let url = StorageConstants.itemsFileURL else { return }
        guard let data = try? JSONEncoder().encode(items) else { return }

        // Use NSFileCoordinator so the share extension sees the latest state
        let coordinator = NSFileCoordinator()
        var coordError: NSError?

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
            } catch {
                print("StorageService.saveItemsLocally write error: \(error)")
            }
        }

        if let coordError = coordError {
            print("StorageService.saveItemsLocally coordination error: \(coordError)")
        }
    }

    func addTextItem(text: String, sourceApp: String? = nil, location: String? = nil) {
        var tags = [isURLString(text) ? "URL" : DataItemType.text.defaultTag]
        if let appTag = sourceApp, !tags.contains(appTag) {
            tags.append(appTag)
        }
        let item = DataItem(type: .text, title: String(text.prefix(50)), tags: tags, textContent: text, sourceApp: sourceApp, location: location)
        items.insert(item, at: 0)
        saveItems()
    }

    @discardableResult
    func addFileItem(data: Data, fileName: String, mimeType: String, sourceApp: String? = nil, location: String? = nil) -> DataItem? {
        guard let filesURL = StorageConstants.filesURL else { return nil }
        let ext = URL(fileURLWithPath: fileName).pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let fileURL = filesURL.appendingPathComponent(uniqueName)
        do {
            try data.write(to: fileURL)
        } catch {
            return nil
        }
        let type = DataItemType(mimeType: mimeType, fileName: fileName)
        var tags = [type.defaultTag]
        if let appTag = sourceApp, !tags.contains(appTag) {
            tags.append(appTag)
        }
        let item = DataItem(type: type, title: fileName, tags: tags, fileName: uniqueName, mimeType: mimeType, sourceApp: sourceApp, location: location)
        items.insert(item, at: 0)
        saveItems()
        return item
    }

    @discardableResult
    func addFileItem(from sourceURL: URL, mimeType: String, sourceApp: String? = nil, location: String? = nil) async -> DataItem? {
        guard let filesURL = StorageConstants.filesURL else { return nil }
        let ext = sourceURL.pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let fileURL = filesURL.appendingPathComponent(uniqueName)

        let copySucceeded: Bool = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: fileURL)
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }

        guard copySucceeded else { return nil }

        let originalName = sourceURL.lastPathComponent
        let type = DataItemType(mimeType: mimeType, fileName: originalName)
        var tags = [type.defaultTag]
        if let appTag = sourceApp, !tags.contains(appTag) {
            tags.append(appTag)
        }
        let item = DataItem(type: type, title: originalName, tags: tags, fileName: uniqueName, mimeType: mimeType, sourceApp: sourceApp, location: location)

        await MainActor.run {
            self.items.insert(item, at: 0)
            self.saveItems()
        }
        return item
    }

    func fileURL(for item: DataItem) -> URL? {
        guard let fileName = item.fileName, let filesURL = StorageConstants.filesURL else { return nil }
        return filesURL.appendingPathComponent(fileName)
    }

    func updateItem(_ item: DataItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        updated.modifiedAt = Date().timeIntervalSince1970
        items[index] = updated
        saveItems()
    }

    var allTags: [String] {
        Array(Set(items.flatMap { $0.tags })).sorted()
    }

    func deleteItem(_ item: DataItem) {
        if let fileName = item.fileName, let filesURL = StorageConstants.filesURL {
            try? FileManager.default.removeItem(at: filesURL.appendingPathComponent(fileName))
            // Also remove from iCloud so the file doesn't linger or get re-downloaded
            if let iCloudURL = iCloudURL {
                let iCloudFile = iCloudURL
                    .appendingPathComponent(StorageConstants.filesDirectoryName)
                    .appendingPathComponent(fileName)
                try? FileManager.default.removeItem(at: iCloudFile)
            }
        }
        items.removeAll { $0.id == item.id }
        deletedIDs.insert(item.id)
        saveDeletedIDs()
        saveItems()
    }

    func deleteItems(ids: Set<String>) {
        let toDelete = items.filter { ids.contains($0.id) }
        for item in toDelete {
            if let fileName = item.fileName, let filesURL = StorageConstants.filesURL {
                try? FileManager.default.removeItem(at: filesURL.appendingPathComponent(fileName))
                // Also remove from iCloud so the file doesn't linger or get re-downloaded
                if let iCloudURL = iCloudURL {
                    let iCloudFile = iCloudURL
                        .appendingPathComponent(StorageConstants.filesDirectoryName)
                        .appendingPathComponent(fileName)
                    try? FileManager.default.removeItem(at: iCloudFile)
                }
            }
        }
        items.removeAll { ids.contains($0.id) }
        deletedIDs.formUnion(ids)
        saveDeletedIDs()
        saveItems()
    }

    // MARK: - iCloud Change Monitoring

    private func startMonitoringiCloudChanges() {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, StorageConstants.itemsFileName)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )

        query.start()
        metadataQuery = query
    }

    @objc private func metadataQueryDidUpdate() {
        syncFromiCloud()
    }

    // MARK: - Deleted IDs Tracking

    private func loadDeletedIDs() {
        guard let url = StorageConstants.deletedIDsFileURL else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        do {
            deletedIDs = try JSONDecoder().decode(Set<String>.self, from: data)
        } catch {
            print("StorageService.loadDeletedIDs decode error: \(error)")
        }
    }

    private func saveDeletedIDs() {
        guard let url = StorageConstants.deletedIDsFileURL,
              let data = try? JSONEncoder().encode(deletedIDs) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Bidirectional Sync

    func syncFromiCloudAsync() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            syncFromiCloud {
                continuation.resume()
            }
        }
    }

    /// Performs a manual sync and returns a summary of what changed.
    func manualSync() async -> SyncResult {
        guard iCloudURL != nil else {
            return SyncResult(
                itemsAdded: 0,
                itemsUpdated: 0,
                errors: [NSLocalizedString("iCloud is not available.", comment: "")]
            )
        }

        // Snapshot the items before syncing (keyed by id → effectiveModifiedAt).
        // Use uniquingKeysWith to tolerate any duplicate IDs in corrupted data.
        let beforeMap: [String: Double] = Dictionary(
            items.map { ($0.id, $0.effectiveModifiedAt) },
            uniquingKeysWith: { max($0, $1) }
        )

        await syncFromiCloudAsync()

        let afterItems = items
        var added = 0
        var updated = 0

        for item in afterItems {
            if let beforeModified = beforeMap[item.id] {
                if item.effectiveModifiedAt > beforeModified {
                    updated += 1
                }
            } else {
                added += 1
            }
        }

        return SyncResult(itemsAdded: added, itemsUpdated: updated, errors: [])
    }

    func syncFromiCloud() {
        syncFromiCloud(completion: nil)
    }

    private func syncFromiCloud(completion: (() -> Void)?) {
        guard !isSyncing else {
            if let completion = completion {
                pendingSyncCompletions.append(completion)
            }
            return
        }
        isSyncing = true

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion?() }
                return
            }

            guard let iCloudURL = self.iCloudURL else {
                DispatchQueue.main.async {
                    self.finishSync(completion: completion)
                }
                return
            }

            // Trigger download of iCloud metadata files if they are placeholders
            let remoteItemsURL = iCloudURL.appendingPathComponent(StorageConstants.itemsFileName)
            let remoteDeletedIDsURL = iCloudURL.appendingPathComponent(StorageConstants.deletedIDsFileName)
            try? FileManager.default.startDownloadingUbiquitousItem(at: remoteItemsURL)
            try? FileManager.default.startDownloadingUbiquitousItem(at: remoteDeletedIDsURL)

            // Load local items directly from file
            let localItems: [DataItem]
            if let url = StorageConstants.itemsFileURL,
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([DataItem].self, from: data) {
                localItems = decoded
            } else {
                localItems = []
            }

            // Load remote items
            let remoteItems: [DataItem]
            if let data = try? Data(contentsOf: remoteItemsURL),
               let decoded = try? JSONDecoder().decode([DataItem].self, from: data) {
                remoteItems = decoded
            } else {
                remoteItems = []
            }

            // Load and merge deleted IDs
            let localDeletedIDs: Set<String>
            if let url = StorageConstants.deletedIDsFileURL,
               let data = try? Data(contentsOf: url),
               let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
                localDeletedIDs = ids
            } else {
                localDeletedIDs = []
            }


            let remoteDeletedIDs: Set<String>
            if let data = try? Data(contentsOf: remoteDeletedIDsURL),
               let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
                remoteDeletedIDs = ids
            } else {
                remoteDeletedIDs = []
            }

            let mergedDeletedIDs = localDeletedIDs.union(remoteDeletedIDs)

            // Merge items using LWW-Element-Set strategy
            let mergedItems = SyncMergeHelper.mergeItems(local: localItems, remote: remoteItems, deletedIDs: mergedDeletedIDs)

            // Download files for items from iCloud that are missing locally
            self.downloadMissingFiles(from: iCloudURL, for: mergedItems)

            // Upload merged result to iCloud before updating local state
            // so that other devices see the merged data as soon as possible.
            if let data = try? JSONEncoder().encode(mergedItems) {
                let url = iCloudURL.appendingPathComponent(StorageConstants.itemsFileName)
                try? data.write(to: url, options: .atomic)
            }
            if let data = try? JSONEncoder().encode(mergedDeletedIDs) {
                let url = iCloudURL.appendingPathComponent(StorageConstants.deletedIDsFileName)
                try? data.write(to: url, options: .atomic)
            }

            // Upload local files to iCloud
            if let localFilesURL = StorageConstants.filesURL {
                let iCloudFilesURL = iCloudURL.appendingPathComponent(StorageConstants.filesDirectoryName)
                try? FileManager.default.createDirectory(at: iCloudFilesURL, withIntermediateDirectories: true)
                if let files = try? FileManager.default.contentsOfDirectory(atPath: localFilesURL.path) {
                    for file in files {
                        let src = localFilesURL.appendingPathComponent(file)
                        let dst = iCloudFilesURL.appendingPathComponent(file)
                        if !FileManager.default.fileExists(atPath: dst.path) {
                            try? FileManager.default.copyItem(at: src, to: dst)
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                self.deletedIDs = mergedDeletedIDs
                self.items = mergedItems
                self.saveDeletedIDs()
                self.saveItemsLocally()
                self.finishSync(completion: completion)
            }
        }
    }

    /// Invokes the given completion together with any coalesced pending
    /// completions, then resets `isSyncing` after the debounce delay.
    /// Must be called on the main queue.
    private func finishSync(completion: (() -> Void)?) {
        let pending = pendingSyncCompletions
        pendingSyncCompletions = []

        completion?()
        for cb in pending { cb() }

        // Delay resetting isSyncing to prevent re-entrant sync
        // triggered by NSMetadataQuery detecting our own upload
        DispatchQueue.main.asyncAfter(deadline: .now() + StorageService.syncDebounceDelay) {
            self.isSyncing = false
        }
    }

    /// Delegates to SyncMergeHelper for the shared LWW-Element-Set merge logic.
    static func mergeItems(local: [DataItem], remote: [DataItem], deletedIDs: Set<String>) -> [DataItem] {
        SyncMergeHelper.mergeItems(local: local, remote: remote, deletedIDs: deletedIDs)
    }

    private func downloadMissingFiles(from iCloudURL: URL, for items: [DataItem]) {
        guard let localFilesURL = StorageConstants.filesURL else { return }
        let iCloudFilesURL = iCloudURL.appendingPathComponent(StorageConstants.filesDirectoryName)

        let neededFiles = Set(items.compactMap { $0.fileName })

        for fileName in neededFiles {
            let localFile = localFilesURL.appendingPathComponent(fileName)
            let remoteFile = iCloudFilesURL.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: localFile.path) {
                // Trigger download of iCloud placeholder files
                try? FileManager.default.startDownloadingUbiquitousItem(at: remoteFile)
                if FileManager.default.fileExists(atPath: remoteFile.path) {
                    try? FileManager.default.copyItem(at: remoteFile, to: localFile)
                }
            }
        }
    }

    private var isSyncingToiCloud = false

    private func syncToiCloud() {
        guard !isSyncingToiCloud else { return }
        isSyncingToiCloud = true

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            defer { DispatchQueue.main.async { self.isSyncingToiCloud = false } }
            guard let iCloudURL = self.iCloudURL else { return }
            try? FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true)

            // Trigger download of remote files before reading to avoid treating
            // evicted iCloud placeholders as empty state
            let remoteItemsURL = iCloudURL.appendingPathComponent(StorageConstants.itemsFileName)
            let remoteDeletedIDsURL = iCloudURL.appendingPathComponent(StorageConstants.deletedIDsFileName)
            try? FileManager.default.startDownloadingUbiquitousItem(at: remoteItemsURL)
            try? FileManager.default.startDownloadingUbiquitousItem(at: remoteDeletedIDsURL)

            // Load local items from disk
            let localItems: [DataItem]
            if let url = StorageConstants.itemsFileURL,
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([DataItem].self, from: data) {
                localItems = decoded
            } else {
                localItems = []
            }

            let localDeletedIDs: Set<String>
            if let url = StorageConstants.deletedIDsFileURL,
               let data = try? Data(contentsOf: url),
               let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
                localDeletedIDs = ids
            } else {
                localDeletedIDs = []
            }

            // Load remote items from iCloud
            let remoteItems: [DataItem]
            if let data = try? Data(contentsOf: remoteItemsURL),
               let decoded = try? JSONDecoder().decode([DataItem].self, from: data) {
                remoteItems = decoded
            } else {
                remoteItems = []
            }


            let remoteDeletedIDs: Set<String>
            if let data = try? Data(contentsOf: remoteDeletedIDsURL),
               let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
                remoteDeletedIDs = ids
            } else {
                remoteDeletedIDs = []
            }

            // Merge local + remote using LWW-Element-Set strategy
            let mergedDeletedIDs = localDeletedIDs.union(remoteDeletedIDs)
            let mergedItems = SyncMergeHelper.mergeItems(local: localItems, remote: remoteItems, deletedIDs: mergedDeletedIDs)

            // Write merged items to iCloud
            if let data = try? JSONEncoder().encode(mergedItems) {
                try? data.write(to: remoteItemsURL, options: .atomic)
            }

            // Write merged deletedIDs to iCloud
            if let data = try? JSONEncoder().encode(mergedDeletedIDs) {
                try? data.write(to: remoteDeletedIDsURL, options: .atomic)
            }

            // Upload local files to iCloud
            if let localFilesURL = StorageConstants.filesURL {
                let iCloudFilesURL = iCloudURL.appendingPathComponent(StorageConstants.filesDirectoryName)
                try? FileManager.default.createDirectory(at: iCloudFilesURL, withIntermediateDirectories: true)
                if let files = try? FileManager.default.contentsOfDirectory(atPath: localFilesURL.path) {
                    for file in files {
                        let src = localFilesURL.appendingPathComponent(file)
                        let dst = iCloudFilesURL.appendingPathComponent(file)
                        if !FileManager.default.fileExists(atPath: dst.path) {
                            try? FileManager.default.copyItem(at: src, to: dst)
                        }
                    }
                }
            }
        }
    }
}
