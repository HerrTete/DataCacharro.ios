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

    // When both sides have the same effectiveModifiedAt, a deterministic
    // fingerprint comparison decides the winner so that both devices
    // converge to the same result regardless of which side is "local".
    func testEqualTimestampsUseDeterministicTieBreaker() {
        let local = [textItem(id: "x", title: "Local")]
        let remote = [textItem(id: "x", title: "Remote")]
        let resultLR = StorageService.mergeItems(local: local, remote: remote, deletedIDs: [])
        let resultRL = StorageService.mergeItems(local: remote, remote: local, deletedIDs: [])

        XCTAssertEqual(resultLR.count, 1)
        XCTAssertEqual(resultRL.count, 1)
        // Both merges must pick the same winner
        XCTAssertEqual(resultLR[0].title, resultRL[0].title)
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

    // MARK: - Cross-Device Convergence (Equal Timestamps)

    /// When two devices independently edit the same item at the exact same
    /// timestamp, both must converge to the same winner after syncing.
    func testEqualTimestampsMergeIsCommutative() {
        let deviceA = textItem(id: "x", title: "Edit-A", tags: ["Text", "A"], modifiedAt: 500)
        let deviceB = textItem(id: "x", title: "Edit-B", tags: ["Text", "B"], modifiedAt: 500)

        let resultAB = StorageService.mergeItems(local: [deviceA], remote: [deviceB], deletedIDs: [])
        let resultBA = StorageService.mergeItems(local: [deviceB], remote: [deviceA], deletedIDs: [])

        XCTAssertEqual(resultAB.count, 1)
        XCTAssertEqual(resultBA.count, 1)
        // Both merges must pick the same winner
        XCTAssertEqual(resultAB[0].title, resultBA[0].title,
                        "Both devices must converge to the same item when timestamps tie")
        XCTAssertEqual(resultAB[0].tags, resultBA[0].tags)
    }

    /// File items with equal timestamps must also converge deterministically.
    func testEqualTimestampsFileItemsConverge() {
        let a = fileItem(id: "f1", title: "Photo.jpg", tags: ["Photo", "Beach"],
                         fileName: "abc.jpg", modifiedAt: 500)
        let b = fileItem(id: "f1", title: "Photo.jpg", tags: ["Photo", "Mountain"],
                         fileName: "abc.jpg", modifiedAt: 500)

        let ab = StorageService.mergeItems(local: [a], remote: [b], deletedIDs: [])
        let ba = StorageService.mergeItems(local: [b], remote: [a], deletedIDs: [])

        XCTAssertEqual(ab[0].tags, ba[0].tags,
                        "File items must also converge when timestamps tie")
    }

    /// Items that were never modified (modifiedAt=nil, same createdAt)
    /// must still converge if their content differs.
    func testNeverModifiedItemsWithSameCreatedAtConverge() {
        let a = DataItem(id: "x", type: .text, title: "Alpha", tags: ["Text"],
                         textContent: "aaa", createdAt: 100)
        let b = DataItem(id: "x", type: .text, title: "Beta", tags: ["Text"],
                         textContent: "bbb", createdAt: 100)

        XCTAssertNil(a.modifiedAt)
        XCTAssertNil(b.modifiedAt)
        XCTAssertEqual(a.effectiveModifiedAt, b.effectiveModifiedAt)

        let ab = StorageService.mergeItems(local: [a], remote: [b], deletedIDs: [])
        let ba = StorageService.mergeItems(local: [b], remote: [a], deletedIDs: [])

        XCTAssertEqual(ab[0].title, ba[0].title,
                        "Items without modifiedAt must converge via fingerprint")
    }

    // MARK: - Three-Device Convergence

    /// Three devices with different local states must all converge to the
    /// same item set after pairwise merges.
    func testThreeDeviceConvergence() {
        let a = [textItem(id: "a1", title: "From-A", createdAt: 100)]
        let b = [textItem(id: "b1", title: "From-B", createdAt: 200)]
        let c = [textItem(id: "c1", title: "From-C", createdAt: 300)]

        // A syncs with B, then result syncs with C
        let ab = StorageService.mergeItems(local: a, remote: b, deletedIDs: [])
        let abc = StorageService.mergeItems(local: ab, remote: c, deletedIDs: [])

        // B syncs with C, then result syncs with A
        let bc = StorageService.mergeItems(local: b, remote: c, deletedIDs: [])
        let bca = StorageService.mergeItems(local: bc, remote: a, deletedIDs: [])

        // C syncs with A, then result syncs with B
        let ca = StorageService.mergeItems(local: c, remote: a, deletedIDs: [])
        let cab = StorageService.mergeItems(local: ca, remote: b, deletedIDs: [])

        let idsABC = Set(abc.map { $0.id })
        let idsBCA = Set(bca.map { $0.id })
        let idsCAB = Set(cab.map { $0.id })

        XCTAssertEqual(idsABC, ["a1", "b1", "c1"])
        XCTAssertEqual(idsABC, idsBCA)
        XCTAssertEqual(idsABC, idsCAB)
    }

    /// Three devices with conflicting edits on the same item must all
    /// converge to the same winner.
    func testThreeDeviceConflictConvergence() {
        let a = textItem(id: "x", title: "A-edit", modifiedAt: 300)
        let b = textItem(id: "x", title: "B-edit", modifiedAt: 400)
        let c = textItem(id: "x", title: "C-edit", modifiedAt: 400) // ties with B

        // All pairwise merge orderings
        let ab_c = StorageService.mergeItems(
            local: StorageService.mergeItems(local: [a], remote: [b], deletedIDs: []),
            remote: [c], deletedIDs: [])
        let ac_b = StorageService.mergeItems(
            local: StorageService.mergeItems(local: [a], remote: [c], deletedIDs: []),
            remote: [b], deletedIDs: [])
        let bc_a = StorageService.mergeItems(
            local: StorageService.mergeItems(local: [b], remote: [c], deletedIDs: []),
            remote: [a], deletedIDs: [])

        // All must converge to the same winner
        XCTAssertEqual(ab_c[0].title, ac_b[0].title)
        XCTAssertEqual(ab_c[0].title, bc_a[0].title)
    }

    /// Three devices: one adds, one edits a shared item, one deletes it.
    func testThreeDeviceAddEditDelete() {
        let shared = textItem(id: "x", title: "Shared", createdAt: 100)
        let deviceA = [shared, textItem(id: "a1", title: "New-A", createdAt: 200)]
        let deviceB = [textItem(id: "x", title: "Edited", createdAt: 100, modifiedAt: 300)]
        let deviceC: [DataItem] = [] // deleted "x"
        let deletedIDs: Set<String> = ["x"]

        // Merge A with B first, then with C's perspective
        let ab = StorageService.mergeItems(local: deviceA, remote: deviceB, deletedIDs: deletedIDs)
        let result = StorageService.mergeItems(local: ab, remote: deviceC, deletedIDs: deletedIDs)

        // "x" should be deleted (tombstone wins), "a1" survives
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].id, "a1")
    }

    // MARK: - Merge Associativity

    /// Associativity: merge(merge(A,B), C) must equal merge(A, merge(B,C))
    /// for items with distinct IDs.
    func testMergeIsAssociativeForDistinctItems() {
        let a = [textItem(id: "a", title: "A", createdAt: 100)]
        let b = [textItem(id: "b", title: "B", createdAt: 200)]
        let c = [textItem(id: "c", title: "C", createdAt: 300)]

        let ab_c = StorageService.mergeItems(
            local: StorageService.mergeItems(local: a, remote: b, deletedIDs: []),
            remote: c, deletedIDs: [])
        let a_bc = StorageService.mergeItems(
            local: a,
            remote: StorageService.mergeItems(local: b, remote: c, deletedIDs: []),
            deletedIDs: [])

        XCTAssertEqual(Set(ab_c.map { $0.id }), Set(a_bc.map { $0.id }))
    }

    /// Associativity with conflicting items.
    func testMergeIsAssociativeForConflicts() {
        let a = [textItem(id: "x", title: "A", modifiedAt: 100)]
        let b = [textItem(id: "x", title: "B", modifiedAt: 200)]
        let c = [textItem(id: "x", title: "C", modifiedAt: 300)]

        let ab_c = StorageService.mergeItems(
            local: StorageService.mergeItems(local: a, remote: b, deletedIDs: []),
            remote: c, deletedIDs: [])
        let a_bc = StorageService.mergeItems(
            local: a,
            remote: StorageService.mergeItems(local: b, remote: c, deletedIDs: []),
            deletedIDs: [])

        XCTAssertEqual(ab_c[0].title, "C")
        XCTAssertEqual(a_bc[0].title, "C")
    }

    // MARK: - Multiple Sync Rounds

    /// Repeated merges between two devices must converge and stay stable.
    func testMultipleSyncRoundsConverge() {
        var stateA = [
            textItem(id: "x", title: "A-v1", modifiedAt: 100),
            textItem(id: "a", title: "Only-A", createdAt: 50)
        ]
        var stateB = [
            textItem(id: "x", title: "B-v1", modifiedAt: 200),
            textItem(id: "b", title: "Only-B", createdAt: 150)
        ]

        // Round 1: both sync
        let round1A = StorageService.mergeItems(local: stateA, remote: stateB, deletedIDs: [])
        let round1B = StorageService.mergeItems(local: stateB, remote: stateA, deletedIDs: [])

        // Round 2: sync again with each other's round 1 result
        stateA = round1A
        stateB = round1B
        let round2A = StorageService.mergeItems(local: stateA, remote: stateB, deletedIDs: [])
        let round2B = StorageService.mergeItems(local: stateB, remote: stateA, deletedIDs: [])

        // Both must have converged after round 1 already
        XCTAssertEqual(Set(round1A.map { $0.id }), Set(round1B.map { $0.id }))
        // And round 2 must be stable (same as round 1)
        XCTAssertEqual(round2A.map { $0.id }, round1A.map { $0.id })
        XCTAssertEqual(round2B.map { $0.id }, round1B.map { $0.id })
        // Both sides must agree on conflict resolution
        let xA = round2A.first { $0.id == "x" }
        let xB = round2B.first { $0.id == "x" }
        XCTAssertEqual(xA?.title, "B-v1") // B had the newer timestamp
        XCTAssertEqual(xB?.title, "B-v1")
    }

    /// Two devices with equal-timestamp edits must converge after multiple
    /// rounds thanks to the deterministic tie-breaker.
    func testEqualTimestampConvergesAfterMultipleRounds() {
        let a = textItem(id: "x", title: "Alpha", modifiedAt: 500)
        let b = textItem(id: "x", title: "Bravo", modifiedAt: 500)

        // Round 1
        let r1a = StorageService.mergeItems(local: [a], remote: [b], deletedIDs: [])
        let r1b = StorageService.mergeItems(local: [b], remote: [a], deletedIDs: [])

        // Both must already agree
        XCTAssertEqual(r1a[0].title, r1b[0].title)

        // Round 2 (should be stable)
        let r2a = StorageService.mergeItems(local: r1a, remote: r1b, deletedIDs: [])
        let r2b = StorageService.mergeItems(local: r1b, remote: r1a, deletedIDs: [])

        XCTAssertEqual(r2a[0].title, r1a[0].title)
        XCTAssertEqual(r2b[0].title, r1b[0].title)
    }

    // MARK: - Tombstone Edge Cases

    /// A new item added with an ID that matches a tombstone must be blocked.
    /// This prevents "zombie" items when UUIDs theoretically collide or
    /// items are recreated with the same ID.
    func testReAddWithTombstonedIDIsBlocked() {
        let item = textItem(id: "recycled", title: "Resurrected", modifiedAt: 9999)
        let deletedIDs: Set<String> = ["recycled"]

        let result = StorageService.mergeItems(local: [item], remote: [], deletedIDs: deletedIDs)
        XCTAssertTrue(result.isEmpty,
                       "Tombstone must block items even if they have very recent timestamps")
    }

    /// Tombstones from remote must block local items and vice versa.
    func testCrossDeviceTombstoneBlocking() {
        let localItem = textItem(id: "x", title: "Local-X", modifiedAt: 100)
        let remoteItem = textItem(id: "y", title: "Remote-Y", modifiedAt: 200)
        let localDeleted: Set<String> = ["y"] // local deleted y
        let remoteDeleted: Set<String> = ["x"] // remote deleted x
        let merged = localDeleted.union(remoteDeleted)

        let result = StorageService.mergeItems(
            local: [localItem], remote: [remoteItem], deletedIDs: merged)
        XCTAssertTrue(result.isEmpty,
                       "Cross-device deletions must remove items from both sides")
    }

    // MARK: - MergeFingerprint

    /// The merge fingerprint must differ when any mutable field changes.
    func testMergeFingerprintChangesWithContent() {
        let base = textItem(id: "x", title: "Note")
        var edited = base
        edited.customName = "Custom"

        XCTAssertNotEqual(base.mergeFingerprint, edited.mergeFingerprint)
    }

    /// Two items with identical content must have the same fingerprint.
    func testMergeFingerprintIdenticalForSameContent() {
        let a = textItem(id: "x", title: "Note", tags: ["Text"], text: "hello", createdAt: 100)
        let b = textItem(id: "x", title: "Note", tags: ["Text"], text: "hello", createdAt: 100)

        XCTAssertEqual(a.mergeFingerprint, b.mergeFingerprint)
    }

    /// Fingerprint must distinguish between different optional field states.
    func testMergeFingerprintDistinguishesOptionalFields() {
        let withApp = DataItem(id: "x", type: .text, title: "Note", tags: ["Text"],
                               createdAt: 100, sourceApp: "Safari")
        let withLocation = DataItem(id: "x", type: .text, title: "Note", tags: ["Text"],
                                    createdAt: 100, location: "Berlin")
        let plain = DataItem(id: "x", type: .text, title: "Note", tags: ["Text"],
                             createdAt: 100)

        XCTAssertNotEqual(withApp.mergeFingerprint, withLocation.mergeFingerprint)
        XCTAssertNotEqual(withApp.mergeFingerprint, plain.mergeFingerprint)
        XCTAssertNotEqual(withLocation.mergeFingerprint, plain.mergeFingerprint)
    }

    // MARK: - Realistic Multi-Device Scenario

    /// Full scenario: Device A and B start in sync, then both go offline,
    /// make independent changes, come back online, and sync.
    func testOfflineEditsThenSync() {
        // Initial shared state (both devices are in sync)
        let shared = [
            textItem(id: "s1", title: "Shopping List", tags: ["Text", "Personal"],
                     text: "Milk, Eggs", createdAt: 100, modifiedAt: 100),
            textItem(id: "s2", title: "Meeting Notes", tags: ["Text", "Work"],
                     text: "Discuss Q2", createdAt: 200, modifiedAt: 200),
            textItem(id: "s3", title: "Old Note", tags: ["Text"],
                     text: "Delete me", createdAt: 50)
        ]

        // Device A offline changes:
        // - Edits s1 (adds item to shopping list)
        // - Deletes s3
        // - Adds new item a1
        var deviceA = shared
        deviceA[0] = textItem(id: "s1", title: "Shopping List", tags: ["Text", "Personal"],
                              text: "Milk, Eggs, Bread", createdAt: 100, modifiedAt: 400)
        deviceA.removeAll { $0.id == "s3" }
        deviceA.append(textItem(id: "a1", title: "Vacation Plan", createdAt: 350))
        let deletedA: Set<String> = ["s3"]

        // Device B offline changes:
        // - Edits s2 (updates meeting notes)
        // - Adds new item b1
        var deviceB = shared
        deviceB[1] = textItem(id: "s2", title: "Meeting Notes", tags: ["Text", "Work"],
                              text: "Discuss Q2 + Q3", createdAt: 200, modifiedAt: 500)
        deviceB.append(textItem(id: "b1", title: "Recipe", createdAt: 450))
        let deletedB: Set<String> = []

        let mergedDeleted = deletedA.union(deletedB)

        // Both sync
        let resultA = StorageService.mergeItems(local: deviceA, remote: deviceB, deletedIDs: mergedDeleted)
        let resultB = StorageService.mergeItems(local: deviceB, remote: deviceA, deletedIDs: mergedDeleted)

        // Both must converge
        XCTAssertEqual(Set(resultA.map { $0.id }), Set(resultB.map { $0.id }))
        XCTAssertEqual(resultA.count, 4) // s1, s2, a1, b1 (s3 deleted)

        let byIdA = Dictionary(uniqueKeysWithValues: resultA.map { ($0.id, $0) })
        XCTAssertEqual(byIdA["s1"]?.textContent, "Milk, Eggs, Bread") // A's edit
        XCTAssertEqual(byIdA["s2"]?.textContent, "Discuss Q2 + Q3")   // B's edit
        XCTAssertNotNil(byIdA["a1"])
        XCTAssertNotNil(byIdA["b1"])
        XCTAssertNil(byIdA["s3"]) // deleted by A
    }

    /// Both devices edit the same item and also add new items, with some
    /// items being deleted by one device.
    func testComplexConcurrentChanges() {
        let shared = [
            textItem(id: "x", title: "X", createdAt: 100, modifiedAt: 100),
            textItem(id: "y", title: "Y", createdAt: 200, modifiedAt: 200),
            textItem(id: "z", title: "Z", createdAt: 300, modifiedAt: 300)
        ]

        // Device A: edit x, delete y, add a1
        let deviceA = [
            textItem(id: "x", title: "X-A", createdAt: 100, modifiedAt: 600),
            textItem(id: "z", title: "Z", createdAt: 300, modifiedAt: 300),
            textItem(id: "a1", title: "A1", createdAt: 500)
        ]
        let deletedA: Set<String> = ["y"]

        // Device B: edit x (older), edit z, delete nothing, add b1
        let deviceB = [
            textItem(id: "x", title: "X-B", createdAt: 100, modifiedAt: 550),
            textItem(id: "y", title: "Y", createdAt: 200, modifiedAt: 200),
            textItem(id: "z", title: "Z-B", createdAt: 300, modifiedAt: 700),
            textItem(id: "b1", title: "B1", createdAt: 450)
        ]
        let deletedB: Set<String> = []

        let mergedDeleted = deletedA.union(deletedB)

        let resultA = StorageService.mergeItems(local: deviceA, remote: deviceB, deletedIDs: mergedDeleted)
        let resultB = StorageService.mergeItems(local: deviceB, remote: deviceA, deletedIDs: mergedDeleted)

        // Must converge
        XCTAssertEqual(Set(resultA.map { $0.id }), Set(resultB.map { $0.id }))
        XCTAssertEqual(resultA.count, 4) // x, z, a1, b1

        let byIdA = Dictionary(uniqueKeysWithValues: resultA.map { ($0.id, $0) })
        let byIdB = Dictionary(uniqueKeysWithValues: resultB.map { ($0.id, $0) })
        XCTAssertEqual(byIdA["x"]?.title, "X-A")  // A newer (600 > 550)
        XCTAssertEqual(byIdB["x"]?.title, "X-A")
        XCTAssertEqual(byIdA["z"]?.title, "Z-B")  // B newer (700 > 300)
        XCTAssertEqual(byIdB["z"]?.title, "Z-B")
    }
}
