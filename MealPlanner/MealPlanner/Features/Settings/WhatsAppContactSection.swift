import SwiftUI

/// §10.12 item 2.
struct WhatsAppContactSection: View {
    @AppStorage("whatsapp.contactName") private var contactName = ""
    @AppStorage("whatsapp.contactPhone") private var contactPhone = ""
    @Environment(\.openURL) private var openURL

    private var phone: WhatsAppLink.Phone { WhatsAppLink.normalizePhone(contactPhone) }
    private var isInvalid: Bool {
        if case .invalid = phone { return true }
        return false
    }

    var body: some View {
        Section {
            TextField("Name", text: $contactName)
            TextField("Mobile number", text: $contactPhone)
                .keyboardType(.phonePad)
            if isInvalid {
                Text("Add the country code (e.g. +44) and check the number.")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
            Button("Send Test Message", action: sendTestMessage)
        } header: {
            Text("WhatsApp")
        } footer: {
            Text("Include the country code, e.g. +44 7700 900123. Your list will open straight in this person's WhatsApp chat. Saved only on this iPhone.")
        }
    }

    private func sendTestMessage() {
        var digits: String?
        if case .valid(let value) = phone { digits = value }
        guard let url = WhatsAppLink.url(text: "Test from MealPlanner 👋", phoneDigits: digits) else { return }
        openURL(url)
    }
}

#Preview {
    Form {
        WhatsAppContactSection()
    }
}
