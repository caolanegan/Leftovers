import SwiftUI
import SwiftData
import UIKit
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "WeekPlan")

/// §10.1.
struct WeekPlanView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        // Forces a fresh `@Query` filter (§6.1 rule 8) whenever the shown week changes.
        WeekPlanContentView(weekID: appState.selectedWeekID)
            .id(appState.selectedWeekID)
    }
}

private struct CopyRequest: Identifiable {
    let id = UUID()
    let source: String
    let target: String
}

private struct RandomizeRequest: Identifiable {
    let id = UUID()
    let title: String
    let itemsLabel: String
    let targets: [SlotKey]
    let hasDependents: Bool
}

private struct WeekPlanContentView: View {
    let weekID: String

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var plans: [WeekPlan]
    @State private var pickerPosition: PlanPosition?
    @State private var pendingClearWeek = false
    @State private var pendingCopy: CopyRequest?
    @State private var pendingRandomize: RandomizeRequest?
    @State private var pendingDependentRemoval: DependentLeftoversPrompt?
    @State private var infoMessage: String?
    @State private var errorMessage: String?

    init(weekID: String) {
        self.weekID = weekID
        let id = weekID
        _plans = Query(filter: #Predicate<WeekPlan> { $0.weekID == id })
    }

    private var plan: WeekPlan? { plans.first }
    private var currentWeekID: String { WeekMath.weekID(for: .now, calendar: WeekMath.appCalendar) }
    private var isReadOnly: Bool { WeekMath.isEnded(weekID, now: .now, calendar: WeekMath.appCalendar) }

    private var filledCount: Int {
        guard let plan else { return 0 }
        if plan.isArchived { return (plan.slots ?? []).count }
        return (plan.slots ?? []).filter { $0.meal != nil }.count
    }

    /// Built once per render (not once per row — §10.1 perf) so `DaySection`
    /// can derive every row's leftovers context-menu flags with no fetches
    /// of its own: this week's + the previous week's occurrences (for
    /// candidate lookups), every filled position across this week and next
    /// week's Monday (for "Leftovers for Tomorrow"), and source labels.
    private var planContext: PlanWeekContext {
        guard !isReadOnly else { return .empty }
        let service = WeekPlanService(context: modelContext)
        let occurrences = (try? service.occurrences(around: weekID)) ?? []

        var filled = Set((plan?.slots ?? []).map { PlanPosition(weekID: weekID, dayIndex: $0.dayIndex, mealType: $0.mealType) })
        let nextWeekID = WeekMath.weekID(weekID, adding: 1, calendar: WeekMath.appCalendar)
        if let nextPlan = try? service.plan(for: nextWeekID) {
            for slot in nextPlan.slots ?? [] where slot.dayIndex == 0 {
                filled.insert(PlanPosition(weekID: nextWeekID, dayIndex: 0, mealType: slot.mealType))
            }
        }

        let sourceLabels = Dictionary(occurrences.map { ($0.slotID, LeftoverRules.label(for: $0.position)) }, uniquingKeysWith: { first, _ in first })
        return PlanWeekContext(occurrences: occurrences, filledPositions: filled, sourceLabels: sourceLabels)
    }

    var body: some View {
        let context = planContext
        List {
            if isReadOnly {
                Section {
                    Label("This week has ended. It's kept as a record and can't be changed.", systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(0..<7, id: \.self) { dayIndex in
                DaySection(
                    weekID: weekID,
                    dayIndex: dayIndex,
                    isToday: isToday(dayIndex),
                    isReadOnly: isReadOnly,
                    plan: plan,
                    context: context,
                    onSelect: { pickerPosition = $0 },
                    onRemove: { remove(at: $0) },
                    onShuffle: { shuffle(at: $0) },
                    onMarkAsLeftovers: { markAsLeftovers(at: $0) },
                    onMarkAsCooked: { markAsCooked(at: $0) },
                    onAddLeftovers: { addLeftovers(from: $0, to: $1) },
                    onRandomizeDay: { randomizeDayTapped($0) }
                )
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .top) {
            WeekNavigator(
                title: navigatorTitle,
                subtitle: "\(filledCount) of 21 meals planned",
                onPrevious: { navigate(by: -1) },
                onNext: { navigate(by: 1) },
                onToday: { appState.selectedWeekID = currentWeekID }
            )
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isReadOnly {
                ToolbarItem(placement: .primaryAction) {
                    RandomizeMenu(onSelect: { randomizeScopeTapped($0) })
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if isReadOnly {
                        Button("Copy to This Week") { copyToThisWeekTapped() }
                    } else {
                        Button("Copy Last Week") { copyLastWeekTapped() }
                        Button("Clear Week", role: .destructive) { pendingClearWeek = true }
                            .disabled(filledCount == 0)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More")
            }
        }
        .sheet(item: $pickerPosition) { position in
            MealPickerSheet(
                weekID: position.weekID,
                dayIndex: position.dayIndex,
                mealType: position.mealType,
                currentMeal: (plan?.slots ?? []).first { $0.dayIndex == position.dayIndex && $0.mealType == position.mealType }?.meal
            )
        }
        .confirmationDialog("Clear Week", isPresented: $pendingClearWeek, titleVisibility: .visible) {
            Button("Clear Week", role: .destructive) { clearWeek() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(clearWeekMessage)
        }
        .sensoryFeedback(.warning, trigger: pendingClearWeek)
        .confirmationDialog(
            "Copy Meals",
            isPresented: Binding(get: { pendingCopy != nil }, set: { if !$0 { pendingCopy = nil } }),
            titleVisibility: .visible,
            presenting: pendingCopy
        ) { request in
            Button("Fill Empty Meals") { performCopy(request, mode: .fillEmpty) }
            Button("Replace This Week", role: .destructive) { performCopy(request, mode: .replaceAll) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Fill Empty Meals keeps what's already planned. Replace This Week removes it first.")
        }
        .sensoryFeedback(.warning, trigger: pendingCopy != nil)
        .confirmationDialog(
            pendingRandomize?.title ?? "",
            isPresented: Binding(get: { pendingRandomize != nil }, set: { if !$0 { pendingRandomize = nil } }),
            titleVisibility: .visible,
            presenting: pendingRandomize
        ) { request in
            Button("Fill Empty \(request.itemsLabel)") { performRandomize(targets: request.targets, mode: .fillEmpty) }
            Button("Replace All \(request.itemsLabel)", role: .destructive) { performRandomize(targets: request.targets, mode: .replaceAll) }
            Button("Cancel", role: .cancel) {}
        } message: { request in
            Text(randomizeMessage(hasDependents: request.hasDependents))
        }
        .sensoryFeedback(.warning, trigger: pendingRandomize != nil)
        .dependentLeftoversDialog($pendingDependentRemoval)
        .task(id: weekID) {
            guard isReadOnly, plan?.isArchived != true else { return }
            do {
                try ArchiveService(context: modelContext).archiveEndedWeeks()
            } catch {
                logger.error("Failed to archive ended weeks: \(error, privacy: .public)")
            }
        }
        .alert("Something to Note", isPresented: Binding(get: { infoMessage != nil }, set: { if !$0 { infoMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(infoMessage ?? "")
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var navigatorTitle: String {
        let title = WeekMath.title(for: weekID, now: .now, calendar: WeekMath.appCalendar, locale: .current)
        let dateRange = WeekMath.dateRangeText(for: weekID, calendar: WeekMath.appCalendar, locale: .current)
        return "\(title) · \(dateRange)"
    }

    private func isToday(_ dayIndex: Int) -> Bool {
        weekID == currentWeekID && dayIndex == WeekMath.dayIndex(for: .now, calendar: WeekMath.appCalendar)
    }

    private func navigate(by weeks: Int) {
        appState.selectedWeekID = WeekMath.weekID(weekID, adding: weeks, calendar: WeekMath.appCalendar)
    }

    private func remove(at position: PlanPosition) {
        do {
            let service = WeekPlanService(context: modelContext)
            let dependents = try service.dependentLeftovers(of: position)
            guard !dependents.isEmpty else {
                try service.clearSlot(at: position, dependents: .remove)
                return
            }
            pendingDependentRemoval = .make(for: position, dependents: dependents) { action in
                do {
                    try WeekPlanService(context: modelContext).clearSlot(at: position, dependents: action)
                } catch {
                    logger.error("Failed to remove slot: \(error, privacy: .public)")
                    errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
                }
            }
        } catch {
            logger.error("Failed to remove slot: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }

    private func markAsLeftovers(at position: PlanPosition) {
        do {
            try WeekPlanService(context: modelContext).markAsLeftovers(at: position)
        } catch {
            logger.error("Failed to mark as leftovers: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }

    private func markAsCooked(at position: PlanPosition) {
        do {
            try WeekPlanService(context: modelContext).markAsCooked(at: position)
        } catch {
            logger.error("Failed to mark as cooked: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }

    private func addLeftovers(from source: PlanPosition, to target: PlanPosition) {
        do {
            try WeekPlanService(context: modelContext).addLeftovers(from: source, to: target)
        } catch {
            logger.error("Failed to add leftovers: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }

    // MARK: - Randomising (§10.1)

    private func randomizeScopeTapped(_ scope: RandomizeScope) {
        switch scope {
        case .wholeWeek:
            startRandomize(title: "Randomise Whole Week", itemsLabel: "Meals", targets: allSlotKeys())
        case .mealType(let type):
            startRandomize(title: "Randomise \(type.pluralName)", itemsLabel: type.pluralName, targets: (0..<7).map { SlotKey(dayIndex: $0, mealType: type) })
        }
    }

    private func randomizeDayTapped(_ dayIndex: Int) {
        let dayName = WeekMath.fullDayName(dayIndex)
        startRandomize(title: "Randomise \(dayName)", itemsLabel: dayName, targets: MealType.allCases.map { SlotKey(dayIndex: dayIndex, mealType: $0) })
    }

    private func allSlotKeys() -> [SlotKey] {
        (0..<7).flatMap { day in MealType.allCases.map { SlotKey(dayIndex: day, mealType: $0) } }
    }

    /// Runs `.fillEmpty` straight away if none of the targets are filled;
    /// otherwise asks Fill Empty / Replace All (§10.1).
    private func startRandomize(title: String, itemsLabel: String, targets: [SlotKey]) {
        guard anyFilled(targets) else {
            performRandomize(targets: targets, mode: .fillEmpty)
            return
        }
        pendingRandomize = RandomizeRequest(title: title, itemsLabel: itemsLabel, targets: targets, hasDependents: hasDependents(targets))
    }

    private func anyFilled(_ targets: [SlotKey]) -> Bool {
        let slots = plan?.slots ?? []
        return targets.contains { key in
            slots.contains { $0.dayIndex == key.dayIndex && $0.mealType == key.mealType && $0.meal != nil }
        }
    }

    /// Whether replacing these targets would remove leftovers that depend on
    /// one of them — the dialog's extra sentence (§10.1) only applies then.
    private func hasDependents(_ targets: [SlotKey]) -> Bool {
        let service = WeekPlanService(context: modelContext)
        return targets.contains { key in
            let position = PlanPosition(weekID: weekID, dayIndex: key.dayIndex, mealType: key.mealType)
            return ((try? service.dependentLeftovers(of: position)) ?? []).isEmpty == false
        }
    }

    private func randomizeMessage(hasDependents: Bool) -> String {
        var message = "Meals planned last week won't be picked."
        if hasDependents {
            message += " Leftovers linked to replaced meals will be removed."
        }
        return message
    }

    private func performRandomize(targets: [SlotKey], mode: RandomizeMode) {
        do {
            let outcome = try WeekPlanService(context: modelContext).randomize(weekID: weekID, slots: targets, mode: mode)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if !outcome.skippedTypes.isEmpty {
                infoMessage = MealRandomizer.skippedCandidatesMessage(for: outcome.skippedTypes)
            } else if outcome.assigned == 0 {
                infoMessage = "Nothing to randomise — those meals are already planned."
            }
        } catch {
            logger.error("Failed to randomize: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }

    /// Row Shuffle (swipe, context menu): a single re-roll via `.replaceAll`,
    /// still going through the normal dependent-leftovers dialog (§10.1, §14).
    private func shuffle(at position: PlanPosition) {
        do {
            let service = WeekPlanService(context: modelContext)
            guard let meal = try service.randomMeal(for: position) else {
                infoMessage = MealRandomizer.skippedCandidatesMessage(for: [position.mealType])
                return
            }
            switch try service.dependentDecision(forCookedAssignmentOf: meal, at: position) {
            case .needsDependentPrompt(let dependents):
                pendingDependentRemoval = .make(for: position, dependents: dependents) { action in
                    self.finishShuffle(meal, at: position, dependents: action)
                }
            default:
                finishShuffle(meal, at: position, dependents: .keepAsCooked)
            }
        } catch {
            logger.error("Failed to shuffle: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }

    private func finishShuffle(_ meal: Meal, at position: PlanPosition, dependents: DependentLeftoversAction) {
        do {
            try WeekPlanService(context: modelContext).assign(meal, at: position, leftoversOf: nil, dependents: dependents)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            logger.error("Failed to shuffle: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }

    private var clearWeekMessage: String {
        let hasDependents = (try? WeekPlanService(context: modelContext).weekHasDependentLeftovers(weekID)) ?? false
        var message = "This removes every meal planned for this week. This can't be undone."
        if hasDependents {
            message += " Leftovers planned from these meals will also be removed."
        }
        return message
    }

    private func clearWeek() {
        do {
            try WeekPlanService(context: modelContext).clearWeek(weekID)
        } catch {
            logger.error("Failed to clear week: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }

    private func copyLastWeekTapped() {
        let lastWeekID = WeekMath.weekID(weekID, adding: -1, calendar: WeekMath.appCalendar)
        startCopy(source: lastWeekID, target: weekID)
    }

    private func copyToThisWeekTapped() {
        startCopy(source: weekID, target: currentWeekID)
    }

    /// Shared by "Copy Last Week" and "Copy to This Week" (§10.1): an empty
    /// source has nothing to offer; an empty target needs no confirmation
    /// since Fill Empty and Replace would do the same thing.
    private func startCopy(source: String, target: String) {
        let sourceIsEmpty = ((try? WeekPlanService(context: modelContext).mealIDs(inWeek: source)) ?? []).isEmpty
        guard !sourceIsEmpty else {
            infoMessage = "That week has no meals to copy."
            return
        }
        let targetIsEmpty = ((try? WeekPlanService(context: modelContext).mealIDs(inWeek: target)) ?? []).isEmpty
        if targetIsEmpty {
            performCopy(CopyRequest(source: source, target: target), mode: .fillEmpty)
        } else {
            pendingCopy = CopyRequest(source: source, target: target)
        }
    }

    private func performCopy(_ request: CopyRequest, mode: RandomizeMode) {
        do {
            let result = try WeekPlanService(context: modelContext).copyWeek(from: request.source, to: request.target, mode: mode)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if result.skippedDeletedMeals > 0 {
                let count = result.skippedDeletedMeals
                infoMessage = "\(count) meal\(count == 1 ? "" : "s") couldn't be copied because \(count == 1 ? "it's" : "they've") been deleted."
            }
        } catch {
            logger.error("Failed to copy week: \(error, privacy: .public)")
            errorMessage = (error as? AppError)?.errorDescription ?? "Something went wrong. Please try again."
        }
    }
}

extension PlanPosition: Identifiable {
    var id: String { "\(weekID)-\(dayIndex)-\(mealType.rawValue)" }
}

#Preview {
    NavigationStack {
        WeekPlanView()
            .appRouteDestinations()
    }
    .environment(AppState())
    .modelContainer(PreviewContainer.shared)
}
