import SwiftUI
import SwiftData
import UIKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "AddToPlan")

/// §10.8. The leftovers prompt and dependent-leftovers dialog (§10.3) arrive
/// in M7 — no leftover slots can exist yet, so "Add" always assigns cooked.
struct AddToPlanSheet: View {
    let meal: Meal

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var weekOffset = 0
    @State private var selectedDayIndex: Int
    @State private var selectedMealType: MealType
    @State private var errorMessage: String?

    init(meal: Meal) {
        self.meal = meal
        _selectedMealType = State(initialValue: meal.mealTypes.sorted().first ?? .dinner)
        _selectedDayIndex = State(initialValue: WeekMath.dayIndex(for: .now, calendar: WeekMath.appCalendar))
    }

    private var availableMealTypes: [MealType] { meal.mealTypes.sorted() }

    private var weekID: String {
        let current = WeekMath.weekID(for: .now, calendar: WeekMath.appCalendar)
        return weekOffset == 0 ? current : WeekMath.weekID(current, adding: 1, calendar: WeekMath.appCalendar)
    }

    private var existingMealNames: [Int: String] {
        guard let plan = try? WeekPlanService(context: modelContext).plan(for: weekID) else { return [:] }
        var result: [Int: String] = [:]
        for slot in plan.slots ?? [] where slot.mealType == selectedMealType {
            if let name = slot.meal?.name { result[slot.dayIndex] = name }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Week", selection: $weekOffset) {
                        Text("This Week").tag(0)
                        Text("Next Week").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                if availableMealTypes.count > 1 {
                    Section {
                        Picker("Meal", selection: $selectedMealType) {
                            ForEach(availableMealTypes) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Section {
                    ForEach(0..<7, id: \.self) { dayIndex in
                        dayRow(dayIndex)
                    }
                }
            }
            .navigationTitle("Add to Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { add() }
                }
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func dayRow(_ dayIndex: Int) -> some View {
        Button {
            selectedDayIndex = dayIndex
        } label: {
            HStack {
                Text(dayLabel(dayIndex))
                    .foregroundStyle(.primary)
                Spacer()
                if let existingName = existingMealNames[dayIndex] {
                    Text("Replaces \(existingName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if selectedDayIndex == dayIndex {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayLabel(_ dayIndex: Int) -> String {
        guard let date = WeekMath.date(dayIndex: dayIndex, in: weekID, calendar: WeekMath.appCalendar) else {
            return WeekMath.shortDayName(dayIndex)
        }
        let formatter = DateFormatter()
        formatter.calendar = WeekMath.appCalendar
        formatter.timeZone = WeekMath.appCalendar.timeZone
        formatter.locale = .current
        formatter.dateFormat = "d MMM"
        return "\(WeekMath.shortDayName(dayIndex)) \(formatter.string(from: date))"
    }

    private func add() {
        do {
            let position = PlanPosition(weekID: weekID, dayIndex: selectedDayIndex, mealType: selectedMealType)
            try WeekPlanService(context: modelContext).assign(meal, at: position)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            logger.error("Failed to add to plan: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }
}

#Preview {
    AddToPlanSheet(meal: Meal(name: "Chicken fajitas"))
        .modelContainer(PreviewContainer.shared)
}
