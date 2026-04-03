import SwiftUI

struct ContentView: View {
    @EnvironmentObject var storage: StorageService
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingAddText = false
    @State private var showingAddAudio = false
    @State private var showingAddPhotoVideo = false
    @State private var isSelecting = false

    var body: some View {
        TabView {
            NavigationStack {
                ItemListView(isSelecting: $isSelecting)
                    .navigationTitle("SavedMessages")
                    .toolbar {
                        if !isSelecting {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: { showingAddAudio = true }) {
                                    Image(systemName: "mic.badge.plus")
                                }
                                .accessibilityIdentifier("addAudioButton")
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: { showingAddPhotoVideo = true }) {
                                    Image(systemName: "photo.badge.plus")
                                }
                                .accessibilityIdentifier("addPhotoVideoButton")
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: { showingAddText = true }) {
                                    Image(systemName: "text.badge.plus")
                                }
                                .accessibilityIdentifier("addTextButton")
                            }
                        }
                    }
            }
            .sheet(isPresented: $showingAddText) {
                AddTextView()
                    .environmentObject(storage)
            }
            .sheet(isPresented: $showingAddAudio) {
                AddAudioView()
                    .environmentObject(storage)
            }
            .sheet(isPresented: $showingAddPhotoVideo) {
                AddPhotoVideoView()
                    .environmentObject(storage)
            }
            .tabItem {
                Label("Items", systemImage: "list.bullet")
            }
            .accessibilityIdentifier("itemsTab")

            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .accessibilityIdentifier("settingsTab")

            NavigationStack {
                TagsView()
                    .navigationTitle("Tags")
            }
            .tabItem {
                Label("Tags", systemImage: "number")
            }
            .accessibilityIdentifier("tagsTab")
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                storage.loadItems()
                storage.syncFromiCloud()
            }
        }
    }
}
