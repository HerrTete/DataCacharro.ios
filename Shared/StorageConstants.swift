import Foundation

enum StorageConstants {
    static let appGroupID = "group.com.HerrTete.SavedMessagesGroup"
    static let iCloudContainerID = "iCloud.com.HerrTete.SavedMessages"
    static let itemsFileName = "items.json"
    static let filesDirectoryName = "Files"

    static var appGroupURL: URL? {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return url
        }
        print("StorageConstants: App Group '\(appGroupID)' not available. Check that the App Group capability is enabled in all relevant targets.")
        return nil
    }

    static var filesURL: URL? {
        appGroupURL?.appendingPathComponent(filesDirectoryName, isDirectory: true)
    }

    static var itemsFileURL: URL? {
        appGroupURL?.appendingPathComponent(itemsFileName)
    }

    static let itemsChangedNotification = "com.HerrTete.SavedMessages.itemsChanged"
    static let deletedIDsFileName = "deletedIDs.json"

    static var deletedIDsFileURL: URL? {
        appGroupURL?.appendingPathComponent(deletedIDsFileName)
    }
}
