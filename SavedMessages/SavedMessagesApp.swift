import SwiftUI

@main
struct SavedMessagesApp: App {
    @StateObject private var storage = StorageService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storage)
                .onAppear { LocationService.shared.start() }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                // Reload items whenever the app comes to the foreground so that
                // anything saved by the Share Extension while the app was
                // inactive (or not running) appears immediately.
                print("SavedMessagesApp: scene became active – reloading items")
                StorageService.shared.loadItems()
            }
        }
    }
}
