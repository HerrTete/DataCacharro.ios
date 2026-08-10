import Foundation

/// Shared merge logic for bidirectional iCloud sync.
/// Used by both the main app (StorageService) and the Share Extension.
enum SyncMergeHelper {

    /// Merges local and remote items using a Last-Writer-Wins Element-Set strategy.
    /// Items are matched by ID. For items existing on both sides, the one with
    /// the newer `effectiveModifiedAt` wins. When timestamps are equal, a
    /// deterministic fingerprint comparison ensures both devices converge to
    /// the same result regardless of which side is treated as "local".
    /// Deleted IDs are removed from the result.
    static func mergeItems(
        local: [DataItem],
        remote: [DataItem],
        deletedIDs: Set<String>
    ) -> [DataItem] {
        var merged: [String: DataItem] = [:]

        for item in local {
            merged[item.id] = item
        }

        for item in remote {
            if let existing = merged[item.id] {
                if item.effectiveModifiedAt > existing.effectiveModifiedAt ||
                   (item.effectiveModifiedAt == existing.effectiveModifiedAt &&
                    item.mergeFingerprint > existing.mergeFingerprint) {
                    merged[item.id] = item
                }
            } else {
                merged[item.id] = item
            }
        }

        for id in deletedIDs {
            merged.removeValue(forKey: id)
        }

        return Array(merged.values).sorted { $0.createdAt > $1.createdAt }
    }

    /// Convenience: merges deleted ID sets from both sides into a union,
    /// then merges items.
    static func mergeItems(
        local: [DataItem],
        remote: [DataItem],
        localDeletedIDs: Set<String>,
        remoteDeletedIDs: Set<String>
    ) -> (items: [DataItem], deletedIDs: Set<String>) {
        let mergedDeletedIDs = localDeletedIDs.union(remoteDeletedIDs)
        let mergedItems = mergeItems(local: local, remote: remote, deletedIDs: mergedDeletedIDs)
        return (mergedItems, mergedDeletedIDs)
    }
}
