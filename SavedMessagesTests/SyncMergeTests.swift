import XCTest
@testable import SavedMessages

final class SyncMergeTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a text DataItem with the given properties.
    private func textItem(
        id: String, title: String = "", tags: [String] = ["Text"],
        text: String? = nil, createdAt: TimeInterval = 100, modifiedAt: TimeInterval? = nil
    ) -> DataItem {
        DataItem(id: id, type: .text, title: title, tags: tags,
                 textContent: text, createdAt: createdAt, modifiedAt: modifiedAt)
    }

    /// Creates a file DataItem (image / video / audio / file).
    private func fileItem(
        id: String, type: DataItemType = .image, title: String = "",
        tags: [String] = ["Photo"], fileName: String = "img.jpg",
        mimeType: String = "image/jpeg", createdAt: TimeInterval = 100,
        modifiedAt: TimeInterval? = nil
    ) -> DataItem {
        DataItem(id: id, type: type, title: title, tags: tags,
                 fileName: fileName, mimeType: mimeType,
                 createdAt: createdAt, modifiedAt: modifiedAt)
    }

    // MARK: - Union Merge

    func testLocalOnlyItemsArePreserved() {
        let local = [textItem(id: "a", title: "Local", text: "hello")]
        let result = StorageService.mergeItems(local: local, remote: [], deletedIDs: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "a")
    }

    func testRemoteOnlyItemsAreDownloaded() {
        let remote = [textItem(id: "b", title: "Remote", text: "world", createdAt: 200)]
        let result = StorageService.mergeItems(local: [], remote: remote, deletedIDs: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "b")
    }

    func testUnionOfLocalAndRemoteItems() {
        let local = [textItem(id: "a", title: "A")]
        let remote = [textItem(id: "b", title: "B", createdAt: 200)]
        let result = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])
        XCTAssertEqual(result.count, 2)
        let ids = Set(result.map { $0.id })
        XCTAssertTrue(ids.contains("a"))
        XCTAssertTrue(ids.contains("b"))
    }

    // MARK: - LWW Conflict Resolution

    func testRemoteWinsWhenNewerModifiedAt() {
        let local = [textItem(id: "x", title: "Old", modifiedAt: 150)]
        let remote = [textItem(id: "x", title: "New", tags: ["Text", "Updated"], modifiedAt: 200)]
        let result = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "New")
        XCTAssertTrue(result[0].tags.contains("Updated"))
    }

    func testLocalWinsWhenNewerModifiedAt() {
        let local = [textItem(id: "x", title: "Newer", modifiedAt: 300)]
        let remote = [textItem(id: "x", title: "Older", modifiedAt: 200)]
        let result = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "Newer")
    }

    // When both sides have the same effectiveModifiedAt, the local item is
    // preserved because local items are inserted first into the merge dictionary
    // and remote items only overwrite when strictly newer. This avoids
    // unnecessary overwrites and keeps the merge deterministic.
    func testEqualTimestampsPreservesLocalItem() {
        let local = [textItem(id: "x", title: "Local")]
        let remote = [textItem(id: "x", title: "Remote")]
        let result = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "Local")
    }

    // MARK: - Deleted IDs (Tombstones)

    func testDeletedIDsAreRemoved() {
        let local = [
            textItem(id: "a", title: "Keep"),
            textItem(id: "b", title: "Delete", createdAt: 200)
        ]
        let result = StorageService.mergeItems(local: local, remote: [], deletedIDs: ["b"])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "a")
    }

    func testBothLocalAndRemoteDeletionsApplied() {
        let items = [
            textItem(id: "a", title: "A"),
            textItem(id: "b", title: "B", createdAt: 200),
            textItem(id: "c", title: "C", createdAt: 300)
        ]
        let localDeleted: Set<String> = ["a"]
        let remoteDeleted: Set<String> = ["c"]
        let mergedDeleted = localDeleted.union(remoteDeleted)
        let result = StorageService.mergeItems(local: items, remote: [], deletedIDs: mergedDeleted)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "b")
    }

    func testDeletedRemoteItemNotAdded() {
        let remote = [textItem(id: "r", title: "Deleted")]
        let result = StorageService.mergeItems(local: [], remote: remote, deletedIDs: ["r"])
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Edge Cases

    func testEmptyMergeProducesEmptyResult() {
        let result = StorageService.mergeItems(local: [], remote: [], deletedIDs: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testResultSortedByCreatedAtDescending() {
        let local = [
            textItem(id: "a", title: "Oldest"),
            textItem(id: "c", title: "Newest", createdAt: 300)
        ]
        let remote = [textItem(id: "b", title: "Middle", createdAt: 200)]
        let result = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].id, "c")
        XCTAssertEqual(result[1].id, "b")
        XCTAssertEqual(result[2].id, "a")
    }

    // MARK: - Backward Compatibility

    func testModifiedAtFallsBackToCreatedAt() {
        let item = textItem(id: "old", title: "Old")
        XCTAssertNil(item.modifiedAt)
        XCTAssertEqual(item.effectiveModifiedAt, 100)
    }

    func testModifiedAtTakesPrecedence() {
        let oldItem = textItem(id: "x", title: "Old")
        let newItem = textItem(id: "x", title: "Updated", tags: ["Text", "New"], modifiedAt: 200)
        let result = StorageService.mergeItems(local: [oldItem], remote: [newItem], deletedIDs: [])
        XCTAssertEqual(result[0].title, "Updated")
    }

    func testJSONRoundtripPreservesModifiedAt() throws {
        let item = DataItem(id: "test", type: .text, title: "Test", tags: ["Text"], createdAt: 100, modifiedAt: 200)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(DataItem.self, from: data)
        XCTAssertEqual(decoded.modifiedAt, 200)
        XCTAssertEqual(decoded.effectiveModifiedAt, 200)
    }

    func testJSONWithoutModifiedAtDecodesAsNil() throws {
        let json = """
        {"id":"old","type":"text","title":"Old","tags":["Text"],"createdAt":100}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(DataItem.self, from: json)
        XCTAssertNil(decoded.modifiedAt)
        XCTAssertEqual(decoded.effectiveModifiedAt, 100)
    }

    // MARK: - Two-Device Sync Scenarios

    /// Simulates two devices making independent additions. Both items must
    /// survive the merge regardless of which device syncs first.
    func testConcurrentAdditionsFromTwoDevices() {
        // Device A adds item "a", device B adds item "b"
        let deviceA = [textItem(id: "a", title: "From A", createdAt: 100)]
        let deviceB = [textItem(id: "b", title: "From B", createdAt: 200)]

        // Device A syncs (local=A, remote=B)
        let resultA = StorageService.mergeItems(local: deviceA, remote: deviceB, deletedIDs: [])
        // Device B syncs (local=B, remote=A)
        let resultB = StorageService.mergeItems(local: deviceB, remote: deviceA, deletedIDs: [])

        XCTAssertEqual(resultA.count, 2)
        XCTAssertEqual(resultB.count, 2)
        XCTAssertEqual(Set(resultA.map { $0.id }), Set(resultB.map { $0.id }))
    }

    /// When both devices edit the same item, the one with the newer
    /// modifiedAt timestamp must win on both sides.
    func testConcurrentEditsNewerTimestampWins() {
        let deviceA = [textItem(id: "x", title: "Edit A", modifiedAt: 300)]
        let deviceB = [textItem(id: "x", title: "Edit B", modifiedAt: 400)]

        let resultA = StorageService.mergeItems(local: deviceA, remote: deviceB, deletedIDs: [])
        let resultB = StorageService.mergeItems(local: deviceB, remote: deviceA, deletedIDs: [])

        // Device B's edit (modifiedAt=400) wins on both sides
        XCTAssertEqual(resultA.count, 1)
        XCTAssertEqual(resultA[0].title, "Edit B")
        XCTAssertEqual(resultB.count, 1)
        XCTAssertEqual(resultB[0].title, "Edit B")
    }

    /// Device A deletes an item while device B still has it. The deletion
    /// must propagate and the item must be removed from the merged result.
    func testDeleteOnOneDeviceRemovesFromOther() {
        let shared = textItem(id: "x", title: "Shared")
        // Device A deleted "x", device B still has it
        let deviceA: [DataItem] = []
        let deviceB = [shared]
        let deletedIDs: Set<String> = ["x"]

        let result = StorageService.mergeItems(local: deviceA, remote: deviceB, deletedIDs: deletedIDs)
        XCTAssertTrue(result.isEmpty, "Deleted item should not reappear from the other device")
    }

    /// Deletion tombstones must override even a newer modification. This
    /// prevents "zombie" items from reappearing after deletion.
    func testDeletionTrumpsNewerModification() {
        let modified = textItem(id: "x", title: "Edited", modifiedAt: 9999)
        let deletedIDs: Set<String> = ["x"]

        let result = StorageService.mergeItems(local: [modified], remote: [], deletedIDs: deletedIDs)
        XCTAssertTrue(result.isEmpty, "Tombstone should always win over modification")
    }

    /// When devices have overlapping plus unique items, the merge must
    /// produce the correct union minus deletions.
    func testMixedOverlappingAndUniqueItems() {
        let local = [
            textItem(id: "shared", title: "V1", modifiedAt: 100),
            textItem(id: "localOnly", title: "Local", createdAt: 50)
        ]
        let remote = [
            textItem(id: "shared", title: "V2", modifiedAt: 200),
            textItem(id: "remoteOnly", title: "Remote", createdAt: 150)
        ]
        let result = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])

        XCTAssertEqual(result.count, 3)
        let byId = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
        XCTAssertEqual(byId["shared"]?.title, "V2")   // remote is newer
        XCTAssertNotNil(byId["localOnly"])
        XCTAssertNotNil(byId["remoteOnly"])
    }

    // MARK: - DeletedIDs Union

    /// The merged deletedIDs set must be the union of both sides so that
    /// deletions from either device are respected.
    func testDeletedIDsUnionFromBothSides() {
        let localDeleted: Set<String> = ["a", "b"]
        let remoteDeleted: Set<String> = ["b", "c"]
        let merged = localDeleted.union(remoteDeleted)

        XCTAssertEqual(merged, ["a", "b", "c"])

        let items = [
            textItem(id: "a", title: "A"),
            textItem(id: "b", title: "B", createdAt: 200),
            textItem(id: "c", title: "C", createdAt: 300),
            textItem(id: "d", title: "D", createdAt: 400)
        ]
        let result = StorageService.mergeItems(local: items, remote: [], deletedIDs: merged)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "d")
    }

    /// DeletedIDs that don't match any item should be harmlessly ignored.
    func testDeletedIDsForNonexistentItemsAreIgnored() {
        let local = [textItem(id: "a", title: "A")]
        let deletedIDs: Set<String> = ["nonexistent"]
        let result = StorageService.mergeItems(local: local, remote: [], deletedIDs: deletedIDs)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "a")
    }

    // MARK: - Merge Properties (CRDT-like guarantees)

    /// Merging an item set with itself must produce the same set (idempotency).
    func testMergeIsIdempotent() {
        let items = [
            textItem(id: "a", title: "A"),
            textItem(id: "b", title: "B", createdAt: 200)
        ]
        let once = StorageService.mergeItems(local: items, remote: items, deletedIDs: [])
        let twice = StorageService.mergeItems(local: once, remote: once, deletedIDs: [])

        XCTAssertEqual(once.count, twice.count)
        XCTAssertEqual(once.map { $0.id }, twice.map { $0.id })
    }

    /// For items with distinct IDs the merge must be commutative:
    /// merge(A, B) == merge(B, A).
    func testMergeIsCommutativeForDistinctItems() {
        let a = [textItem(id: "a", title: "A")]
        let b = [textItem(id: "b", title: "B", createdAt: 200)]

        let ab = StorageService.mergeItems(local: a, remote: b, deletedIDs: [])
        let ba = StorageService.mergeItems(local: b, remote: a, deletedIDs: [])

        XCTAssertEqual(Set(ab.map { $0.id }), Set(ba.map { $0.id }))
    }

    /// For conflicting items with different timestamps the merge must be
    /// commutative: the item with the newer timestamp wins regardless of
    /// which side is "local".
    func testMergeIsCommutativeForConflictingItems() {
        let older = textItem(id: "x", title: "Older", modifiedAt: 100)
        let newer = textItem(id: "x", title: "Newer", modifiedAt: 200)

        let lr = StorageService.mergeItems(local: [older], remote: [newer], deletedIDs: [])
        let rl = StorageService.mergeItems(local: [newer], remote: [older], deletedIDs: [])

        XCTAssertEqual(lr[0].title, "Newer")
        XCTAssertEqual(rl[0].title, "Newer")
    }

    // MARK: - File Items in Merge

    /// File-type items (image, video, audio, file) must be preserved
    /// through the merge just like text items.
    func testFileItemsSurviveMerge() {
        let localImg = fileItem(id: "img1", title: "Photo.jpg", fileName: "abc.jpg")
        let remoteVid = fileItem(id: "vid1", type: .video, title: "Movie.mov",
                                  tags: ["Video"], fileName: "def.mov",
                                  mimeType: "video/quicktime", createdAt: 200)

        let result = StorageService.mergeItems(local: [localImg], remote: [remoteVid], deletedIDs: [])
        XCTAssertEqual(result.count, 2)

        let byId = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
        XCTAssertEqual(byId["img1"]?.fileName, "abc.jpg")
        XCTAssertEqual(byId["vid1"]?.type, .video)
    }

    /// When two devices update the same file item, the newer version's
    /// metadata (tags, customName, etc.) must win.
    func testFileItemConflictResolution() {
        let local = fileItem(id: "img1", title: "Photo.jpg", tags: ["Photo"],
                             fileName: "abc.jpg", modifiedAt: 100)
        var remote = fileItem(id: "img1", title: "Photo.jpg", tags: ["Photo", "Vacation"],
                              fileName: "abc.jpg", modifiedAt: 200)
        remote.customName = "Beach Sunset"

        let result = StorageService.mergeItems(local: [local], remote: [remote], deletedIDs: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].customName, "Beach Sunset")
        XCTAssertTrue(result[0].tags.contains("Vacation"))
    }

    // MARK: - Tag Changes

    /// Tags are part of the whole-item LWW: if the remote version is newer
    /// its tags replace the local tags entirely.
    func testTagChangesFollowLWW() {
        let local = textItem(id: "x", title: "Note", tags: ["Text", "Work"], modifiedAt: 100)
        let remote = textItem(id: "x", title: "Note", tags: ["Text", "Personal"], modifiedAt: 200)

        let result = StorageService.mergeItems(local: [local], remote: [remote], deletedIDs: [])
        XCTAssertEqual(result[0].tags, ["Text", "Personal"])
    }

    // MARK: - CustomName Changes

    func testCustomNamePreservedByNewerVersion() {
        var local = textItem(id: "x", title: "Note", modifiedAt: 100)
        local.customName = "Old Name"
        var remote = textItem(id: "x", title: "Note", modifiedAt: 200)
        remote.customName = "New Name"

        let result = StorageService.mergeItems(local: [local], remote: [remote], deletedIDs: [])
        XCTAssertEqual(result[0].customName, "New Name")
    }

    // MARK: - Multiple Conflicts in a Single Merge

    /// Several items conflict simultaneously; each must be resolved
    /// independently using LWW.
    func testMultipleSimultaneousConflicts() {
        let local = [
            textItem(id: "a", title: "A-local", modifiedAt: 300),  // local newer
            textItem(id: "b", title: "B-local", modifiedAt: 100),  // remote newer
            textItem(id: "c", title: "C-local", modifiedAt: 200),  // equal → local wins
            textItem(id: "d", title: "D-only-local", createdAt: 50)
        ]
        let remote = [
            textItem(id: "a", title: "A-remote", modifiedAt: 200),
            textItem(id: "b", title: "B-remote", modifiedAt: 400),
            textItem(id: "c", title: "C-remote", modifiedAt: 200),
            textItem(id: "e", title: "E-only-remote", createdAt: 250)
        ]

        let result = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])

        let byId = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
        XCTAssertEqual(result.count, 5)
        XCTAssertEqual(byId["a"]?.title, "A-local")
        XCTAssertEqual(byId["b"]?.title, "B-remote")
        XCTAssertEqual(byId["c"]?.title, "C-local")
        XCTAssertNotNil(byId["d"])
        XCTAssertNotNil(byId["e"])
    }

    // MARK: - Large Item Sets

    func testMergeWithManyItems() {
        let local = (0..<500).map { textItem(id: "item-\($0)", title: "L\($0)", createdAt: TimeInterval($0)) }
        let remote = (250..<750).map { textItem(id: "item-\($0)", title: "R\($0)", createdAt: TimeInterval($0), modifiedAt: TimeInterval($0 + 1000)) }

        let result = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])

        // Union of 0..<500 and 250..<750 = 0..<750 → 750 unique items
        XCTAssertEqual(result.count, 750)

        // Items 250-499 should have remote version (newer modifiedAt)
        let byId = Dictionary(uniqueKeysWithValues: result.map { ($0.id, $0) })
        XCTAssertEqual(byId["item-300"]?.title, "R300")
        // Items 0-249 should have local version
        XCTAssertEqual(byId["item-100"]?.title, "L100")
    }

    // MARK: - Mixed Item Types

    func testMergeMixedItemTypes() {
        let local: [DataItem] = [
            textItem(id: "t1", title: "Text", createdAt: 100),
            fileItem(id: "i1", type: .image, title: "Image", createdAt: 200),
        ]
        let remote: [DataItem] = [
            fileItem(id: "a1", type: .audio, title: "Audio", tags: ["Audio"],
                     fileName: "rec.m4a", mimeType: "audio/mp4", createdAt: 300),
            fileItem(id: "f1", type: .file, title: "Doc.pdf", tags: ["File"],
                     fileName: "doc.pdf", mimeType: "application/pdf", createdAt: 400),
        ]

        let result = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])
        XCTAssertEqual(result.count, 4)

        let types = Set(result.map { $0.type })
        XCTAssertTrue(types.contains(.text))
        XCTAssertTrue(types.contains(.image))
        XCTAssertTrue(types.contains(.audio))
        XCTAssertTrue(types.contains(.file))
    }

    // MARK: - Sorting Stability

    /// Items with the same createdAt must all appear in the result; none
    /// should be dropped by the sort.
    func testItemsWithSameCreatedAtAllPreserved() {
        let local = [
            textItem(id: "a", title: "A", createdAt: 100),
            textItem(id: "b", title: "B", createdAt: 100),
            textItem(id: "c", title: "C", createdAt: 100)
        ]
        let result = StorageService.mergeItems(local: local, remote: [], deletedIDs: [])
        XCTAssertEqual(result.count, 3)
    }

    // MARK: - Simulated Multi-Step Sync Scenario

    /// Simulates a realistic multi-step sync between two devices:
    /// 1. Device A adds items, syncs to cloud
    /// 2. Device B pulls from cloud, adds its own items, syncs back
    /// 3. Device A pulls the updated cloud state
    /// Both devices must converge to the same item set.
    func testTwoDeviceRoundtripConverges() {
        // Step 1: Device A creates items and "uploads" to cloud
        let deviceA_items = [
            textItem(id: "a1", title: "A-Note", createdAt: 100),
            textItem(id: "a2", title: "A-Link", createdAt: 200)
        ]
        // Cloud initially has device A's items
        let cloud_v1 = deviceA_items

        // Step 2: Device B pulls cloud_v1, adds its own items, merges, and
        // uploads back. On first pull B has no local items.
        let deviceB_local: [DataItem] = []
        let afterB_pull = StorageService.mergeItems(local: deviceB_local, remote: cloud_v1, deletedIDs: [])
        // B adds a new item
        let deviceB_new = textItem(id: "b1", title: "B-Photo", createdAt: 300)
        let deviceB_all = afterB_pull + [deviceB_new]
        // B uploads (merge with cloud before uploading)
        let cloud_v2 = StorageService.mergeItems(local: deviceB_all, remote: cloud_v1, deletedIDs: [])

        // Step 3: Device A pulls cloud_v2
        let afterA_pull = StorageService.mergeItems(local: deviceA_items, remote: cloud_v2, deletedIDs: [])

        // Both must converge: 3 items total
        XCTAssertEqual(afterA_pull.count, 3)
        XCTAssertEqual(Set(afterA_pull.map { $0.id }), Set(cloud_v2.map { $0.id }))
    }

    /// Simulates two devices making concurrent edits and deletions, then
    /// syncing. Both must converge after exchanging states.
    func testConcurrentEditAndDeleteConverges() {
        let shared = [
            textItem(id: "x", title: "Shared-X", createdAt: 100),
            textItem(id: "y", title: "Shared-Y", createdAt: 200),
            textItem(id: "z", title: "Shared-Z", createdAt: 300)
        ]

        // Device A edits "x" and deletes "y"
        let deviceA_items = [
            textItem(id: "x", title: "X-edited-A", createdAt: 100, modifiedAt: 500),
            textItem(id: "z", title: "Shared-Z", createdAt: 300)
        ]
        let deviceA_deleted: Set<String> = ["y"]

        // Device B edits "z" and deletes nothing
        let deviceB_items = [
            textItem(id: "x", title: "Shared-X", createdAt: 100),
            textItem(id: "y", title: "Shared-Y", createdAt: 200),
            textItem(id: "z", title: "Z-edited-B", createdAt: 300, modifiedAt: 600)
        ]
        let deviceB_deleted: Set<String> = []

        let mergedDeleted = deviceA_deleted.union(deviceB_deleted)

        let resultA = StorageService.mergeItems(local: deviceA_items, remote: deviceB_items, deletedIDs: mergedDeleted)
        let resultB = StorageService.mergeItems(local: deviceB_items, remote: deviceA_items, deletedIDs: mergedDeleted)

        // Both should produce the same two items: x (edited by A) and z (edited by B)
        XCTAssertEqual(resultA.count, 2)
        XCTAssertEqual(resultB.count, 2)
        XCTAssertEqual(Set(resultA.map { $0.id }), Set(resultB.map { $0.id }))

        let byIdA = Dictionary(uniqueKeysWithValues: resultA.map { ($0.id, $0) })
        XCTAssertEqual(byIdA["x"]?.title, "X-edited-A")
        XCTAssertEqual(byIdA["z"]?.title, "Z-edited-B")
    }

    // MARK: - Effective ModifiedAt with createdAt Only

    /// An item without modifiedAt uses createdAt for conflict resolution.
    /// A remote item with an explicit modifiedAt > createdAt should win.
    func testUnmodifiedItemLosesToModifiedRemote() {
        let local = textItem(id: "x", title: "Unmodified", createdAt: 100)
        let remote = textItem(id: "x", title: "Modified", createdAt: 100, modifiedAt: 200)

        let result = StorageService.mergeItems(local: [local], remote: [remote], deletedIDs: [])
        XCTAssertEqual(result[0].title, "Modified")
        XCTAssertEqual(result[0].modifiedAt, 200)
    }

    // MARK: - Optional Fields Preserved Through Merge

    func testSourceAppAndLocationPreservedByWinner() {
        let local = DataItem(id: "x", type: .text, title: "Note", tags: ["Text"],
                             textContent: "hello", createdAt: 100, modifiedAt: 100,
                             sourceApp: "OldApp", location: "Old Location")
        let remote = DataItem(id: "x", type: .text, title: "Note", tags: ["Text"],
                              textContent: "hello updated", createdAt: 100, modifiedAt: 200,
                              sourceApp: "Safari", location: "Berlin")

        let result = StorageService.mergeItems(local: [local], remote: [remote], deletedIDs: [])
        XCTAssertEqual(result[0].sourceApp, "Safari")
        XCTAssertEqual(result[0].location, "Berlin")
        XCTAssertEqual(result[0].textContent, "hello updated")
    }

    // MARK: - Duplicate Items Within Same Array

    /// If the local array somehow contains duplicates of the same ID,
    /// the merge should handle it gracefully (last occurrence wins for local).
    func testDuplicateIDsInLocalArray() {
        let local = [
            textItem(id: "x", title: "First", modifiedAt: 100),
            textItem(id: "x", title: "Second", modifiedAt: 100)
        ]
        // The second occurrence overwrites the first in the dictionary
        let result = StorageService.mergeItems(local: local, remote: [], deletedIDs: [])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].title, "Second")
    }

    /// If the remote array contains duplicates, the one with the newer
    /// modifiedAt should win.
    func testDuplicateIDsInRemoteArray() {
        let remote = [
            textItem(id: "x", title: "OlderDup", modifiedAt: 100),
            textItem(id: "x", title: "NewerDup", modifiedAt: 200)
        ]
        let result = StorageService.mergeItems(local: [], remote: remote, deletedIDs: [])
        XCTAssertEqual(result.count, 1)
        // The second remote item replaces the first since it's newer
        XCTAssertEqual(result[0].title, "NewerDup")
    }

    // MARK: - syncFromiCloudAsync Completion

    /// Verifies that syncFromiCloudAsync completes even when iCloud is
    /// unavailable (iCloudURL == nil), so .refreshable never hangs.
    func testSyncFromiCloudAsyncCompletesWhenICloudUnavailable() async {
        let storage = StorageService()
        // In unit-test environments iCloudURL is nil because there is no
        // ubiquity container. The async wrapper must still resume.
        await storage.syncFromiCloudAsync()
        // Reaching this line means the continuation resumed – test passes.
    }
}
