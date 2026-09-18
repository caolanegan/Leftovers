import SwiftUI

/// §10.12 page 2 (replaces `WhatsAppContactSection`, v1.6): the quick-send
/// contact (§12.2) plus the export options that used to live on the Shopping
/// list's share menu.
struct SharingSettingsView: View {
    @AppStorage("whatsapp.contactName") private var contactName = ""
    @AppStorage("whatsapp.contactPhone") private var contactPhone = ""
    @AppStorage("export.includeChecked") private var includeChecked = false
    @AppStorage("export.includeMealPlan") private var includeMealPlan = true
    @Environment(\.openURL) private var openURL

    private var phone: WhatsAppLink.Phone { WhatsAppLink.normalizePhone(contactPhone) }
    private var isInvalid: Bool {
        if case .invalid = phone { return true }
        return false
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $contactName)
                TextField("Mobile number", text: $contactPhone)
                    .keyboardType(.phonePad)
                    .keyboardDoneButton()
                if isInvalid {
                    Text("Add the country code (e.g. +44) and check the number.")
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
                Button("Send Test Message", action: sendTestMessage)
            } header: {
                Text("Quick Send")
            } footer: {
                Text("Save someone you often send your list to. The share button on your shopping list will offer to send it straight to their WhatsApp chat. Include the country code, e.g. +44 7700 900123. Saved only on this iPhone.")
            }
            Section("What to Include") {
                Toggle("Include Ticked Items", isOn: $includeChecked)
                Toggle("Include Meal Plan", isOn: $includeMealPlan)
            }
        }
        .navigationTitle("Sharing")
        .keyboardDismissible()
    }

    private func sendTestMessage() {
        var digits: String?
        if case .valid(let value) = phone { digits = value }
        guard let url = WhatsAppLink.url(text: "Test from MealPlanner 👋", phoneDigits: digits) else { return }
        openURL(url)
    }
}

#Preview {
    NavigationStack {
        SharingSettingsView()
    }
}
