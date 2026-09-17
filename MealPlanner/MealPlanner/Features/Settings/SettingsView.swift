import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "Settings")

/// §10.12.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var addedMealsCount: Int?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            ReminderSection()
            WhatsAppContactSection()
            Section("Library") {
                NavigationLink("Ingredients", value: AppRoute.ingredientLibrary)
                Button("Add Example Meals") { addSampleMeals() }
            }
            Section("About") {
                LabeledContent("Version", value: versionText)
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

    private var addedMealsAlertTitle: String {
        guard let addedMealsCount, addedMealsCount > 0 else {
            return "Those example meals are already in your library."
        }
        return "Added \(addedMealsCount) example meals."
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
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
