import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "Settings")

/// §10.12: the root is a short list of rows; nothing is configured here
/// directly, each row opens its own page via `AppRoute`.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("reminder.enabled") private var reminderEnabled = false
    @AppStorage("reminder.weekday") private var reminderWeekday = 1
    @AppStorage("reminder.minutes") private var reminderMinutes = 1080
    @AppStorage("whatsapp.contactName") private var contactName = ""
    @AppStorage("whatsapp.contactPhone") private var contactPhone = ""
    @AppStorage("appearance") private var appearanceRawValue = AppearancePreference.system.rawValue
    @State private var addedMealsCount: Int?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                NavigationLink(value: AppRoute.reminderSettings) {
                    LabeledContent {
                        Text(reminderTrailingValue)
                    } label: {
                        Label("Shopping Reminder", systemImage: "bell")
                    }
                }
                NavigationLink(value: AppRoute.sharingSettings) {
                    LabeledContent {
                        Text(sharingTrailingValue)
                    } label: {
                        Label("Sharing", systemImage: "square.and.arrow.up")
                    }
                }
                NavigationLink(value: AppRoute.appearanceSettings) {
                    LabeledContent {
                        Text(AppearancePreference.resolved(fromRawValue: appearanceRawValue).displayName)
                    } label: {
                        Label("Appearance", systemImage: "circle.lefthalf.filled")
                    }
                }
            }
            Section("Library") {
                NavigationLink(value: AppRoute.ingredientLibrary) {
                    Label("Ingredients", systemImage: "carrot")
                }
                Button {
                    addSampleMeals()
                } label: {
                    Label("Add Example Meals", systemImage: "sparkles")
                }
            }
            Section("About") {
                NavigationLink(value: AppRoute.about) {
                    Label("About", systemImage: "info")
                }
            }
        }
        .navigationTitle("Settings")
        .alert(
            addedMealsAlertTitle,
            isPresented: Binding(get: { addedMealsCount != nil }, set: { if !$0 { addedMealsCount = nil } })
        ) {
            Button("OK", role: .cancel) {}
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var reminderTrailingValue: String {
        ReminderSettingsView.trailingValue(enabled: reminderEnabled, weekday: reminderWeekday, minutes: reminderMinutes)
    }

    /// The quick-send name, or "Not set" — matching `ShoppingListView`'s own
    /// "valid contact" check (a name, and a `.valid` phone) so the two rows
    /// never disagree about whether a contact is usable.
    private var sharingTrailingValue: String {
        let name = contactName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, case .valid = WhatsAppLink.normalizePhone(contactPhone) else { return "Not set" }
        return name
    }

    private var addedMealsAlertTitle: String {
        guard let addedMealsCount, addedMealsCount > 0 else {
            return "Those example meals are already in your library."
        }
        return "Added \(addedMealsCount) example meals."
    }

    private func addSampleMeals() {
        do {
            addedMealsCount = try MealStore(context: modelContext).addSampleMeals()
        } catch {
            logger.error("Failed to add sample meals: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .appRouteDestinations()
    }
    .modelContainer(PreviewContainer.shared)
}
