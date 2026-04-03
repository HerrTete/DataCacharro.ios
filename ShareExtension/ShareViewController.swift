import UIKit
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    // MARK: - Pending items

    nonisolated(unsafe) private var pendingItems: [DataItem] = []
    nonisolated(unsafe) private let itemsLock = NSLock()
    nonisolated(unsafe) private var sourceAppTag: String?

    // Generic bundle ID segments that do not carry a meaningful app name.
    private static let bundleIDSkipTokens: Set<String> = [
        "com", "net", "org", "io", "app", "ios", "co", "de", "uk", "eu", "gov", "edu", "main"
    ]

    // MARK: - HUD UI

    private let hudContainer = UIView()
    private let iconView = UIImageView()
    private let statusLabel = UILabel()
    private var spinner: UIActivityIndicatorView?
    private let hudDismissDelay: TimeInterval = 1.2

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHUD()
    }

    private var didStartProcessing = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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

        DispatchQueue.main.asyncAfter(deadline: .now() + hudDismissDelay) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    // MARK: - Processing

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

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.itemsLock.lock()
            let count = self.pendingItems.count
            self.itemsLock.unlock()
            guard count > 0 else {
                self.showResult(success: false, count: 0)
                return
            }
            let success = self.commitPendingItems()
            self.showResult(success: success, count: count)
        }
    }

    // MARK: - Provider handling

    private func processProvider(_ provider: NSItemProvider, completion: @escaping () -> Void) {
        // 1. Try specific media types first (image, movie, audio) – they often
        //    also conform to plainText/URL, so checking them first avoids losing
        //    the actual file.
        let mediaTypes: [UTType] = [.image, .movie, .audio]
        for utType in mediaTypes {
            if provider.hasItemConformingToTypeIdentifier(utType.identifier) {
                loadFile(from: provider, utType: utType, completion: completion)
                return
            }
        }

        // 2. File URLs (documents, PDFs, etc.)
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            loadFile(from: provider, utType: .fileURL, completion: completion)
            return
        }

        // 3. Web URLs
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] item, _ in
                guard let self else { completion(); return }
                if let url = item as? URL {
                    if url.isFileURL, let dataItem = self.copyFileToContainer(url: url) {
                        self.addPendingItem(dataItem)
                    } else {
                        self.addPendingItem(self.makeTextItem(text: url.absoluteString))
                    }
                }
                completion()
            }
            return
        }

        // 4. Plain text
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] item, _ in
                guard let self else { completion(); return }
                var text: String?
                if let t = item as? String { text = t }
                else if let url = item as? URL { text = url.absoluteString }
                else if let data = item as? Data { text = String(data: data, encoding: .utf8) }
                if let text {
                    self.addPendingItem(self.makeTextItem(text: text))
                }
                completion()
            }
            return
        }

        // 5. Any other data type
        if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            loadFile(from: provider, utType: .data, completion: completion)
            return
        }

        completion()
    }

    /// Loads a file representation from the provider. Falls back to loadItem if
    /// the file representation cannot be produced.
    private func loadFile(from provider: NSItemProvider, utType: UTType, completion: @escaping () -> Void) {
        _ = provider.loadFileRepresentation(for: utType) { [weak self] url, _, error in
            guard let self else { completion(); return }
            if let url, let dataItem = self.copyFileToContainer(url: url) {
                self.addPendingItem(dataItem)
                completion()
            } else {
                // Fallback: loadItem can return URL, Data, or UIImage
                self.loadItemFallback(provider: provider, typeIdentifier: utType.identifier, completion: completion)
            }
        }
    }

    nonisolated private func loadItemFallback(provider: NSItemProvider, typeIdentifier: String, completion: @escaping () -> Void) {
        let suggestedName = provider.suggestedName
        provider.loadItem(forTypeIdentifier: typeIdentifier) { [weak self] item, _ in
            if let url = item as? URL {
                if let dataItem = self?.copyFileToContainer(url: url) {
                    self?.addPendingItem(dataItem)
                }
            } else if let data = item as? Data {
                let name = suggestedName ?? "file"
                let mimeType = UTType(typeIdentifier)?.preferredMIMEType ?? "application/octet-stream"
                if let dataItem = self?.writeDataToContainer(data: data, name: name, mimeType: mimeType) {
                    self?.addPendingItem(dataItem)
                }
            } else if let image = item as? UIImage {
                let name = suggestedName ?? "image"
                if let jpegData = image.jpegData(compressionQuality: 0.9),
                   let dataItem = self?.writeDataToContainer(data: jpegData, name: name + ".jpg", mimeType: "image/jpeg") {
                    self?.addPendingItem(dataItem)
                } else if let pngData = image.pngData(),
                          let dataItem = self?.writeDataToContainer(data: pngData, name: name + ".png", mimeType: "image/png") {
                    self?.addPendingItem(dataItem)
                }
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

    private func makeTextItem(text: String) -> DataItem {
        let tag = isURLString(text) ? "URL" : DataItemType.text.defaultTag
        return DataItem(type: .text, title: String(text.prefix(50)), tags: [tag], textContent: text)
    }

    // MARK: - File operations

    nonisolated private func copyFileToContainer(url: URL) -> DataItem? {
        guard let containerURL = StorageConstants.appGroupURL else { return nil }
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

    // MARK: - Persistence

    private func commitPendingItems() -> Bool {
        guard let containerURL = StorageConstants.appGroupURL else { return false }
        let url = containerURL.appendingPathComponent(StorageConstants.itemsFileName)

        var existing: [DataItem] = []
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var writeSuccess = false

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordError) { coordinatedURL in
            if FileManager.default.fileExists(atPath: coordinatedURL.path),
               let data = try? Data(contentsOf: coordinatedURL),
               let decoded = try? JSONDecoder().decode([DataItem].self, from: data) {
                existing = decoded
            }

            self.itemsLock.lock()
            let newItems = self.pendingItems
            self.itemsLock.unlock()
            guard !newItems.isEmpty else { return }

            existing.insert(contentsOf: newItems, at: 0)

            guard let encoded = try? JSONEncoder().encode(existing) else { return }
            do {
                try encoded.write(to: coordinatedURL, options: .atomic)
                writeSuccess = true
            } catch { return }
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

    // `_hostBundleIdentifier` is an undocumented/private KVC key on the extension context.
    // We use it here because there is no public API to identify the host app for a share
    // extension. If this lookup stops working in a future OS release, fall back to `nil`
    // so the UI simply omits the source-app label instead of failing.
    private func resolveSourceAppName() -> String? {
        let key = "_hostBundleIdentifier"
        let selector = NSSelectorFromString(key)

        guard let context = extensionContext,
              context.responds(to: selector),
              let bundleID = context.value(forKeyPath: key) as? String,
              !bundleID.isEmpty else {
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

        if let name = knownApps[bundleID] { return name }

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
        UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
    }
}
