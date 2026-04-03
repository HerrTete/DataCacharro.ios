import SwiftUI

struct SettingsView: View {
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
        }
    }
}
