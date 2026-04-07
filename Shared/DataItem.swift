import Foundation

enum DataItemType: String, Codable {
    case text, image, video, audio, file
}

struct DataItem: Identifiable, Codable {
    var id: String
    var type: DataItemType
    var title: String
    var customName: String?
    var tags: [String]
    var textContent: String?
    var fileName: String?
    var mimeType: String?
    var createdAt: TimeInterval
    var modifiedAt: TimeInterval?
    var sourceApp: String?
    var location: String?

    init(id: String = UUID().uuidString, type: DataItemType, title: String,
         customName: String? = nil, tags: [String] = [],
         textContent: String? = nil, fileName: String? = nil, mimeType: String? = nil,
         createdAt: TimeInterval = Date().timeIntervalSince1970, modifiedAt: TimeInterval? = nil,
         sourceApp: String? = nil, location: String? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.customName = customName
        self.tags = tags
        self.textContent = textContent
        self.fileName = fileName
        self.mimeType = mimeType
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.sourceApp = sourceApp
        self.location = location
    }

    var effectiveModifiedAt: TimeInterval { modifiedAt ?? createdAt }

    /// Deterministic fingerprint derived from all mutable content fields.
    /// Used as a tie-breaker when two versions of the same item have equal
    /// `effectiveModifiedAt`, ensuring the merge result is the same
    /// regardless of which side is "local" vs "remote".
    var mergeFingerprint: String {
        [
            title,
            customName ?? "",
            tags.joined(separator: ","),
            textContent ?? "",
            fileName ?? "",
            mimeType ?? "",
            sourceApp ?? "",
            location ?? "",
            type.rawValue
        ].joined(separator: "\u{1F}")
    }

    var displayName: String { customName.flatMap { $0.isEmpty ? nil : $0 } ?? title }

    var createdDate: Date { Date(timeIntervalSince1970: createdAt) }

    var url: URL? {
        guard type == .text, let text = textContent,
              let url = URL(string: text),
              let scheme = url.scheme,
              (scheme == "http" || scheme == "https"),
              let host = url.host(percentEncoded: false), !host.isEmpty else { return nil }
        return url
    }
}
