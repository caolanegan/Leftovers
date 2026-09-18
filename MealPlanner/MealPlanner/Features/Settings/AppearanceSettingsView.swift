import SwiftUI

/// §10.12 item 3 (added in v1.5).
struct AppearanceSettingsView: View {
    @AppStorage("appearance") private var appearanceRawValue = AppearancePreference.system.rawValue

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearanceRawValue) {
                    ForEach(AppearancePreference.allCases, id: \.rawValue) { preference in
                        Text(preference.displayName).tag(preference.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.inline)
            } footer: {
                Text("System matches your iPhone's setting.")
            }
        }
        .navigationTitle("Appearance")
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}
