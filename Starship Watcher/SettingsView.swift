import SwiftUI

struct SettingsView: View {
    @Binding var usesUTC: Bool
    @Binding var notificationsEnabled: Bool
    @Binding var liveActivityEnabled: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Use UTC", isOn: $usesUTC)
                    Toggle("Launch reminders", isOn: $notificationsEnabled)
                    Toggle("Live Activity", isOn: $liveActivityEnabled)
                }
                .listRowBackground(Color.black)
                .listRowSeparatorTint(Theme.hairline)

                Section {
                    LabeledContent("Version", value: appVersion)
                }
                .listRowBackground(Color.black)
            }
            .font(.subheadline.weight(.light))
            .tint(Color(white: 0.55))
            .scrollContentBackground(.hidden)
            .blackScreen()
            .navigationTitle("SETTINGS")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
