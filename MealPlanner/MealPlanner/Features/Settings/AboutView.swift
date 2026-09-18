import SwiftUI

/// §10.12 page 4.
struct AboutView: View {
    var body: some View {
        Form {
            LabeledContent("Version", value: versionText)
        }
        .navigationTitle("About")
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
