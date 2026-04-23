import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

private struct MediaFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .data) { file in
            SentTransferredFile(file.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var storage: StorageService
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingAddText = false
    @State private var showingAddAudio = false
    @State private var showingCamera = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isProcessingPhotos = false
    @State private var photoLoadFailedCount = 0
    @State private var showingPhotoLoadError = false
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
                                    Image(systemName: "mic")
                                }
                                .accessibilityIdentifier("addAudioButton")
                            }
                              ToolbarItem(placement: .navigationBarTrailing) {
                                  Button(action: { showingCamera = true }) {
                                      Image(systemName: "camera")
                                  }
                                  .accessibilityIdentifier("addCameraButton")
                              }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                PhotosPicker(
                                    selection: $selectedPhotoItems,
                                    maxSelectionCount: 10,
                                    matching: .any(of: [.images, .videos]),
                                    photoLibrary: .shared()
                                ) {
                                    Image(systemName: "photo")
                                }
                                .accessibilityIdentifier("addPhotoVideoButton")
                            }
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button(action: { showingAddText = true }) {
                                    Image(systemName: "square.and.pencil")
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
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPickerView { data, name, mimeType in
                    storage.addFileItem(data: data, fileName: name, mimeType: mimeType,
                                        location: LocationService.shared.currentAddress)
                }
                .ignoresSafeArea()
            }
            .onChange(of: selectedPhotoItems) {
                if !selectedPhotoItems.isEmpty {
                    Task { await saveSelectedPhotoItems() }
                }
            }
            .alert("Some Items Could Not Be Loaded", isPresented: $showingPhotoLoadError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\(photoLoadFailedCount) item(s) could not be imported.")
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

    @MainActor
    private func saveSelectedPhotoItems() async {
        let itemsToProcess = selectedPhotoItems
        selectedPhotoItems = []
        guard !itemsToProcess.isEmpty else { return }

        isProcessingPhotos = true
        photoLoadFailedCount = 0
        let location = LocationService.shared.currentAddress
        for pickerItem in itemsToProcess {
            let contentType = pickerItem.supportedContentTypes.first
            let mimeType = contentType?.preferredMIMEType ?? "application/octet-stream"
            let ext = contentType?.preferredFilenameExtension ?? "bin"
            let name = "\(UUID().uuidString).\(ext)"

            if let data = try? await pickerItem.loadTransferable(type: Data.self) {
                storage.addFileItem(data: data, fileName: name, mimeType: mimeType, location: location)
                continue
            }

            if let mediaFile = try? await pickerItem.loadTransferable(type: MediaFile.self) {
                let addedItem = await storage.addFileItem(from: mediaFile.url, mimeType: mimeType, location: location)
                if addedItem != nil {
                    try? FileManager.default.removeItem(at: mediaFile.url)
                } else {
                    photoLoadFailedCount += 1
                }
            } else {
                photoLoadFailedCount += 1
            }
        }
        isProcessingPhotos = false
        if photoLoadFailedCount > 0 {
            showingPhotoLoadError = true
        }
    }
}
