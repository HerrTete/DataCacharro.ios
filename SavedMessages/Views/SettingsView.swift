import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var storage: StorageService
    @State private var isSyncing = false
    @State private var syncResult: SyncResult?
    @State private var showSyncResult = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("App")
                    .accessibilityIdentifier("appSectionHeader")
                    .accessibilityAddTraits(.isStaticText)
            }

            Section {
                Button {
                    Task {
                        isSyncing = true
                        let result = await storage.manualSync()
                        isSyncing = false
                        syncResult = result
                        showSyncResult = true
                    }
                } label: {
                    HStack {
                        Text("Sync now")
                        Spacer()
                        if isSyncing {
                            ProgressView()
                        }
                    }
                }
                .disabled(isSyncing)
                .accessibilityIdentifier("syncNowButton")
            } header: {
                Text("iCloud")
            }
        }
        .alert("Sync Complete", isPresented: $showSyncResult, presenting: syncResult) { _ in
            Button("OK", role: .cancel) { }
        } message: { result in
            Text(syncSummaryMessage(for: result))
        }
    }

    private func syncSummaryMessage(for result: SyncResult) -> String {
        var lines: [String] = []

        if result.itemsAdded == 0 && result.itemsUpdated == 0 {
            lines.append(NSLocalizedString("No changes.", comment: ""))
        } else {
            if result.itemsAdded > 0 {
                lines.append(String(format: NSLocalizedString("%d item(s) added.", comment: ""), result.itemsAdded))
            }
            if result.itemsUpdated > 0 {
                lines.append(String(format: NSLocalizedString("%d item(s) updated.", comment: ""), result.itemsUpdated))
            }
        }

        if result.hasErrors {
            lines.append("")
            lines.append(NSLocalizedString("Errors:", comment: ""))
            lines.append(contentsOf: result.errors.map { "• \($0)" })
        }

        return lines.joined(separator: "\n")
    }
}
