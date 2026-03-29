import SwiftUI
import UIKit
import UniformTypeIdentifiers
import CoreLocation

class ShareViewController: UIViewController, CLLocationManagerDelegate {

    // MARK: - Pending items (collected from all providers, saved once at the end)

    // These properties are accessed from nonisolated methods (called by
    // @Sendable completion handlers that run on arbitrary queues).  They are
    // protected by `itemsLock` (or, in the case of `sourceAppTag`, written
    // once on the main thread before any background callback is scheduled),
    // so the `nonisolated(unsafe)` annotation is safe.
    nonisolated(unsafe) private var pendingItems: [DataItem] = []
    private let itemsLock = NSLock()
    nonisolated(unsafe) private var sourceAppTag: String?

    // Generic bundle ID segments that do not carry a meaningful app name.
    private static let bundleIDSkipTokens: Set<String> = [
        "com", "net", "org", "io", "app", "ios", "co", "de", "uk", "eu", "gov", "edu", "main"
    ]

    // MARK: - Location

    private var locationManager: CLLocationManager?
    private let geocoder = CLGeocoder()
    private var currentLocationString: String?
    private let locationGroup = DispatchGroup()
    private var didLeaveLocationGroup = false
    private let locationLock = NSLock()

    // MARK: - HUD UI

    private let hudContainer = UIView()
    private let iconView = UIImageView()
    private let statusLabel = UILabel()
    private var spinner: UIActivityIndicatorView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHUD()
        setupLocation()
    }

    private var didStartProcessing = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Start processing only once. viewDidAppear also fires when the
        // tag-picker sheet is dismissed, so the guard prevents a second run.
        guard !didStartProcessing else { return }
        didStartProcessing = true
        processSharedItems()
    }

    // MARK: - HUD Setup

    private func setupHUD() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.15)

        hudContainer.backgroundColor = .systemBackground
        hudContainer.layer.cornerRadius = 16
        hudContainer.layer.shadowColor = UIColor.black.cgColor
        hudContainer.layer.shadowOpacity = 0.15
        hudContainer.layer.shadowRadius = 10
        hudContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hudContainer)

        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.startAnimating()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        hudContainer.addSubview(activityIndicator)
        spinner = activityIndicator

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isHidden = true
        hudContainer.addSubview(iconView)

        statusLabel.text = "Saving…"
        statusLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        statusLabel.textColor = .label
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        hudContainer.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            hudContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hudContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            hudContainer.widthAnchor.constraint(equalToConstant: 160),
            hudContainer.heightAnchor.constraint(equalToConstant: 130),

            activityIndicator.centerXAnchor.constraint(equalTo: hudContainer.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: hudContainer.topAnchor, constant: 24),

            iconView.centerXAnchor.constraint(equalTo: hudContainer.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: hudContainer.topAnchor, constant: 24),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalToConstant: 44),

            statusLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: hudContainer.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: hudContainer.trailingAnchor, constant: -8),
        ])
    }

    private func showResult(success: Bool, count: Int) {
        spinner?.stopAnimating()
        spinner?.isHidden = true
        iconView.isHidden = false

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        if success {
            iconView.tintColor = .systemGreen
            iconView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: symbolConfig)
            statusLabel.text = count == 1 ? "Saved" : "\(count) items saved"
        } else {
            iconView.tintColor = .systemRed
            iconView.image = UIImage(systemName: "xmark.circle.fill", withConfiguration: symbolConfig)
            statusLabel.text = "Error"
        }

        let hudDismissDelay: TimeInterval = 1.2
        DispatchQueue.main.asyncAfter(deadline: .now() + hudDismissDelay) {
            self.completeRequest()
        }
    }

    // MARK: - Location

    private func setupLocation() {
        let mgr = CLLocationManager()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager = mgr
        locationGroup.enter()
        // locationManagerDidChangeAuthorization fires shortly after delegate is set
        // and handles all authorization states; requestWhenInUseAuthorization triggers
        // the dialog when status is .notDetermined.
        mgr.requestWhenInUseAuthorization()
    }

    /// Leave the location dispatch group at most once to prevent crashes from
    /// unbalanced enter/leave pairs (e.g. when the delegate fires multiple times).
    private func leaveLocationGroup() {
        locationLock.lock()
        defer { locationLock.unlock() }
        guard !didLeaveLocationGroup else { return }
        didLeaveLocationGroup = true
        locationGroup.leave()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            leaveLocationGroup()
        case .notDetermined:
            break
        @unknown default:
            leaveLocationGroup()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            leaveLocationGroup()
            return
        }
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            // Geocoding errors are intentionally ignored; location is a best-effort feature.
            if let placemark = placemarks?.first {
                var parts: [String] = []
                if let locality = placemark.locality { parts.append(locality) }
                if let adminArea = placemark.administrativeArea { parts.append(adminArea) }
                if let country = placemark.country { parts.append(country) }
                if !parts.isEmpty {
                    self?.currentLocationString = parts.joined(separator: ", ")
                }
            }
            self?.leaveLocationGroup()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        leaveLocationGroup()
    }

    // MARK: - Processing

    private let locationTimeout: TimeInterval = 5.0
    private let providerProcessingTimeout: TimeInterval = 20.0

    private func processSharedItems() {
        sourceAppTag = resolveSourceAppName()
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            showResult(success: false, count: 0)
            return
        }

        let group = DispatchGroup()

        for extensionItem in extensionItems {
            guard let attachments = extensionItem.attachments else { continue }
            for provider in attachments {
                group.enter()
                processProvider(provider) {
                    group.leave()
                }
            }
        }

        // Safety net: if a provider's async callback never fires (system bug),
        // the DispatchGroup would never notify. Proceed after 20 s with whatever
        // items were collected so the extension never hangs forever.
        let providerTimeoutItem = DispatchWorkItem { [weak self] in
            print("ShareExtension: provider processing timed out – proceeding with collected items")
            self?.showTagPickerIfNeeded()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + providerProcessingTimeout, execute: providerTimeoutItem)

        group.notify(queue: .main) {
            providerTimeoutItem.cancel()
            // Schedule a 5-second timeout so we always proceed even if location never arrives.
            let timeoutItem = DispatchWorkItem { [weak self] in self?.showTagPickerIfNeeded() }
            DispatchQueue.main.asyncAfter(deadline: .now() + self.locationTimeout, execute: timeoutItem)
            // Show tag picker as soon as location result is available (or immediately if already done).
            self.locationGroup.notify(queue: .main) { [weak self] in
                timeoutItem.cancel()
                self?.showTagPickerIfNeeded()
            }
        }
    }

    private var tagPickerShown = false

    private func showTagPickerIfNeeded() {
        guard !tagPickerShown else { return }
        tagPickerShown = true
        itemsLock.lock()
        let collected = pendingItems.count
        itemsLock.unlock()

        guard collected > 0 else {
            showResult(success: false, count: 0)
            return
        }

        showTagPicker()
    }

    // MARK: - Tag picker

    private func showTagPicker() {
        spinner?.stopAnimating()
        spinner?.isHidden = true

        // If the view is not yet attached to a window (e.g. due to an extension
        // lifecycle race), skip the interactive picker and commit immediately so
        // items are never silently lost.
        guard view.window != nil else {
            print("ShareExtension: view not in window hierarchy – committing directly without tag picker")
            itemsLock.lock()
            let count = pendingItems.count
            itemsLock.unlock()
            let success = commitPendingItems()
            showResult(success: success, count: count)
            return
        }

        hudContainer.isHidden = true

        let tags = loadExistingTags()
        let tagView = ShareTagPickerView(existingTags: tags) { [weak self] selectedTags in
            guard let self else { return }
            self.applySelectedTags(selectedTags)
            self.dismiss(animated: true) {
                DispatchQueue.main.async {
                    let success = self.commitPendingItems()
                    self.itemsLock.lock()
                    let count = self.pendingItems.count
                    self.itemsLock.unlock()
                    self.hudContainer.isHidden = false
                    self.showResult(success: success, count: count)
                }
            }
        } onCancel: { [weak self] in
            self?.dismiss(animated: true) {
                self?.completeRequest()
            }
        }

        let hostingController = UIHostingController(rootView: tagView)
        hostingController.isModalInPresentation = true
        print("ShareExtension: presenting tag picker")
        present(hostingController, animated: true) {
            print("ShareExtension: tag picker presented successfully")
        }
    }

    private func applySelectedTags(_ selectedTags: Set<String>) {
        guard !selectedTags.isEmpty else { return }
        itemsLock.lock()
        for i in 0..<pendingItems.count {
            let newTags = selectedTags.filter { !pendingItems[i].tags.contains($0) }
            pendingItems[i].tags.append(contentsOf: newTags.sorted())
        }
        itemsLock.unlock()
    }

    private func loadExistingTags() -> [String] {
        guard let url = StorageConstants.itemsFileURL,
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([DataItem].self, from: data) else { return [] }
        return Array(Set(items.flatMap { $0.tags })).sorted()
    }

    // MARK: - Provider handling

    private func processProvider(_ provider: NSItemProvider, completion: @escaping () -> Void) {
        // Check specific media types first to avoid the greedy plainText match.
        // Many providers (e.g. images shared from Safari) conform to both
        // public.plain-text and public.image; checking text first would lose the file.
        let mediaTypes: [UTType] = [.image, .movie, .audio]
        for utType in mediaTypes {
            if provider.hasItemConformingToTypeIdentifier(utType.identifier) {
                // Use loadFileRepresentation instead of loadItem so the system
                // creates a readable temporary copy. loadItem may return URLs
                // that point into the source app's sandbox (e.g. Photos),
                // causing FileManager.copyItem to fail silently.
                _ = provider.loadFileRepresentation(for: utType) { url, _, error in
                    if let url = url, let dataItem = self.copyFileToContainer(url: url) {
                        self.addPendingItem(dataItem)
                        completion()
                    } else {
                        // loadFileRepresentation failed – fall back to loadItem which can
                        // return Data or UIImage representations directly.
                        if let error = error {
                            print("ShareExtension: loadFileRepresentation failed for \(utType.identifier) – \(error.localizedDescription), trying loadItem fallback")
                        }
                        self.loadItemFallback(provider: provider, typeIdentifier: utType.identifier, completion: completion)
                    }
                }
                return
            }
        }

        // File URLs (e.g. PDFs, documents shared from Files app)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadFileRepresentation(for: .fileURL) { url, _, error in
                if let url = url, let dataItem = self.copyFileToContainer(url: url) {
                    self.addPendingItem(dataItem)
                    completion()
                } else {
                    if let error = error {
                        print("ShareExtension: loadFileRepresentation failed for fileURL – \(error.localizedDescription), trying loadItem fallback")
                    }
                    self.loadItemFallback(provider: provider, typeIdentifier: UTType.fileURL.identifier, completion: completion)
                }
            }
            return
        }

        // Web URLs
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                if let url = item as? URL {
                    if url.isFileURL {
                        if let dataItem = self.copyFileToContainer(url: url) {
                            self.addPendingItem(dataItem)
                        }
                    } else {
                        self.addPendingItem(self.makeTextItem(text: url.absoluteString))
                    }
                }
                completion()
            }
            return
        }

        // Plain text before generic data, because plainText conforms to
        // UTType.data — checking data first would swallow text shares.
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                var text: String?
                if let t = item as? String {
                    text = t
                } else if let url = item as? URL {
                    text = url.absoluteString
                } else if let data = item as? Data {
                    text = String(data: data, encoding: .utf8)
                }
                if let text = text {
                    self.addPendingItem(self.makeTextItem(text: text))
                }
                completion()
            }
            return
        }

        // Generic data / files that didn't match any specific type above
        if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            _ = provider.loadFileRepresentation(for: .data) { url, _, error in
                if let url = url, let dataItem = self.copyFileToContainer(url: url) {
                    self.addPendingItem(dataItem)
                    completion()
                } else {
                    if let error = error {
                        print("ShareExtension: loadFileRepresentation failed for data – \(error.localizedDescription), trying loadItem fallback")
                    }
                    self.loadItemFallback(provider: provider, typeIdentifier: UTType.data.identifier, completion: completion)
                }
            }
            return
        }

        completion()
    }

    /// Fallback for when `loadFileRepresentation` fails. Uses the older
    /// `loadItem(forTypeIdentifier:)` which can return URLs, raw `Data`, or
    /// `UIImage` objects directly.
    nonisolated private func loadItemFallback(provider: NSItemProvider, typeIdentifier: String, completion: @escaping () -> Void) {
        provider.loadItem(forTypeIdentifier: typeIdentifier) { [weak self] item, loadError in
            guard let self else {
                print("ShareExtension: loadItem fallback – view controller deallocated before completion")
                completion()
                return
            }
            if let url = item as? URL {
                if let dataItem = self.copyFileToContainer(url: url) {
                    self.addPendingItem(dataItem)
                }
            } else if let data = item as? Data {
                let name = provider.suggestedName ?? "file"
                let mimeType = UTType(typeIdentifier)?.preferredMIMEType ?? "application/octet-stream"
                if let dataItem = self.writeDataToContainer(data: data, name: name, mimeType: mimeType) {
                    self.addPendingItem(dataItem)
                }
            } else if let image = item as? UIImage {
                let name = provider.suggestedName ?? "image"
                if let jpegData = image.jpegData(compressionQuality: 0.9) {
                    if let dataItem = self.writeDataToContainer(data: jpegData, name: name + ".jpg", mimeType: "image/jpeg") {
                        self.addPendingItem(dataItem)
                    }
                } else if let pngData = image.pngData() {
                    if let dataItem = self.writeDataToContainer(data: pngData, name: name + ".png", mimeType: "image/png") {
                        self.addPendingItem(dataItem)
                    }
                }
            } else if let loadError = loadError {
                print("ShareExtension: loadItem fallback also failed for \(typeIdentifier) – \(loadError.localizedDescription)")
            }
            completion()
        }
    }

    // MARK: - Item helpers

    nonisolated private func addPendingItem(_ item: DataItem) {
        var item = item
        if let appTag = sourceAppTag, !item.tags.contains(appTag) {
            item.tags.append(appTag)
        }
        if item.sourceApp == nil {
            item.sourceApp = sourceAppTag
        }
        itemsLock.lock()
        pendingItems.append(item)
        itemsLock.unlock()
    }

    nonisolated private func makeTextItem(text: String) -> DataItem {
        let tag = isURLString(text) ? "URL" : DataItemType.text.defaultTag
        return DataItem(type: .text, title: String(text.prefix(50)), tags: [tag], textContent: text)
    }

    // MARK: - File operations

    nonisolated private func copyFileToContainer(url: URL) -> DataItem? {
        guard let containerURL = StorageConstants.appGroupURL else {
            print("ShareExtension: appGroupURL is nil – cannot copy file to container")
            return nil
        }
        let filesDir = containerURL.appendingPathComponent(StorageConstants.filesDirectoryName)
        try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)

        let origName = url.lastPathComponent
        let ext = url.pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let dest = filesDir.appendingPathComponent(uniqueName)

        do {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                try FileManager.default.copyItem(at: url, to: dest)
            } else {
                try FileManager.default.copyItem(at: url, to: dest)
            }
        } catch {
            print("ShareExtension: copyItem failed from \(url.lastPathComponent) to \(uniqueName) – \(error.localizedDescription)")
            return nil
        }

        let mimeType = mimeTypeForExtension(ext)
        let type = DataItemType(mimeType: mimeType, fileName: origName)
        return DataItem(type: type, title: origName, tags: [type.defaultTag], fileName: uniqueName, mimeType: mimeType)
    }

    nonisolated private func writeDataToContainer(data: Data, name: String, mimeType: String) -> DataItem? {
        guard let containerURL = StorageConstants.appGroupURL else { return nil }
        let filesDir = containerURL.appendingPathComponent(StorageConstants.filesDirectoryName)
        try? FileManager.default.createDirectory(at: filesDir, withIntermediateDirectories: true)

        let ext = URL(fileURLWithPath: name).pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let dest = filesDir.appendingPathComponent(uniqueName)

        do {
            try data.write(to: dest)
        } catch {
            return nil
        }

        let type = DataItemType(mimeType: mimeType, fileName: name)
        return DataItem(type: type, title: name, tags: [type.defaultTag], fileName: uniqueName, mimeType: mimeType)
    }

    // MARK: - Persistence (single atomic save of all collected items)

    private func commitPendingItems() -> Bool {
        guard let containerURL = StorageConstants.appGroupURL else {
            print("ShareExtension: appGroupURL is nil – cannot commit items")
            return false
        }
        let url = containerURL.appendingPathComponent(StorageConstants.itemsFileName)

        var existing: [DataItem] = []
        let fileManager = FileManager.default

        // Use NSFileCoordinator so the main app process sees the update
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var writeSuccess = false

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { coordinatedURL in
            if fileManager.fileExists(atPath: coordinatedURL.path),
               let data = try? Data(contentsOf: coordinatedURL),
               let decoded = try? JSONDecoder().decode([DataItem].self, from: data) {
                existing = decoded
            }
            // If the file is missing or unreadable the write still proceeds
            // with an empty baseline so the new items are never lost.

            self.itemsLock.lock()
            let newItems = self.pendingItems.map { item -> DataItem in
                var updated = item
                updated.location = self.currentLocationString
                return updated
            }
            self.itemsLock.unlock()

            guard !newItems.isEmpty else { return }

            existing.insert(contentsOf: newItems, at: 0)

            guard let encoded = try? JSONEncoder().encode(existing) else {
                print("ShareExtension: failed to encode \(existing.count) items")
                return
            }
            do {
                try encoded.write(to: coordinatedURL, options: .atomic)
                writeSuccess = true
            } catch {
                print("ShareExtension: failed to write items.json – \(error.localizedDescription)")
                return
            }
        }

        if let coordError = coordError {
            print("ShareExtension: file coordination error – \(coordError.localizedDescription)")
        }

        guard coordError == nil, writeSuccess else { return false }
        notifyMainApp()
        return true
    }

    // MARK: - Cross-process notification

    private func notifyMainApp() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = CFNotificationName(StorageConstants.itemsChangedNotification as CFString)
        CFNotificationCenterPostNotification(center, name, nil, nil, true)
    }

    // MARK: - Helpers

    private func resolveSourceAppName() -> String? {
        // `_hostBundleIdentifier` is a private KVC key on NSExtensionContext that returns
        // the bundle ID of the host app. There is no public API equivalent on iOS.
        // This is a widely-used pattern in share extensions and has not caused App Store
        // rejections in practice, but the behaviour could change in future OS versions.
        guard let bundleID = extensionContext?.value(forKeyPath: "_hostBundleIdentifier") as? String else {
            return nil
        }

        let knownApps: [String: String] = [
            "com.apple.mobilesafari": "Safari",
            "com.apple.news": "News",
            "com.apple.mobilemail": "Mail",
            "com.apple.mobilenotes": "Notes",
            "com.apple.reminders": "Reminders",
            "com.apple.MobileSMS": "Messages",
            "com.apple.mobileslideshow": "Photos",
            "com.apple.maps": "Maps",
            "com.apple.podcasts": "Podcasts",
            "com.google.chrome.ios": "Chrome",
            "com.google.Gmail": "Gmail",
            "org.mozilla.ios.Firefox": "Firefox",
            "com.atebits.Tweetie2": "Twitter",
            "com.burbn.instagram": "Instagram",
            "com.facebook.Facebook": "Facebook",
            "com.linkedin.LinkedIn": "LinkedIn",
            "com.reddit.Reddit": "Reddit",
            "ph.telegra.Telegraph": "Telegram",
            "net.whatsapp.WhatsApp": "WhatsApp",
            "com.microsoft.Office.Outlook": "Outlook",
            "com.tiktok.TikTok": "TikTok",
            "com.spotify.client": "Spotify",
            "com.snapchat.snapchat": "Snapchat",
            "com.discord.discord": "Discord",
            "com.slack.slack": "Slack",
        ]

        if let name = knownApps[bundleID] {
            return name
        }

        // Fallback: derive a name from the bundle ID components
        let components = bundleID.split(separator: ".")
        for component in components.reversed() {
            let token = String(component)
            if !ShareViewController.bundleIDSkipTokens.contains(token.lowercased()) && token.count > 2 {
                return token.prefix(1).uppercased() + String(token.dropFirst())
            }
        }
        return nil
    }

    nonisolated private func mimeTypeForExtension(_ ext: String) -> String {
        if let utType = UTType(filenameExtension: ext) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
