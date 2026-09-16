import SwiftUI
import SwiftData
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealPlanner", category: "ShoppingList")

/// §10.10.
struct ShoppingListView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        // Forces a fresh `@Query` filter (§6.1 rule 8) whenever the shown week changes.
        ShoppingListContentView(weekID: appState.selectedWeekID)
            .id(appState.selectedWeekID)
    }
}

private struct ShoppingListData {
    var sections: [ShoppingListSection] = []
    var statuses: [String: CheckStatus] = [:]
}

private struct ShoppingListContentView: View {
    let weekID: String

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query private var plans: [WeekPlan]
    /// Unfiltered, and never read for their contents — declaring them is
    /// enough to make this view (and so `sections`/`statuses` below) refresh
    /// live when a recipe's ingredients change or an ingredient is renamed or
    /// re-aisled in another tab (§10.10's data-flow note).
    @Query private var meals: [Meal]
    @Query private var ingredients: [Ingredient]
    @State private var showingIngredientPicker = false
    @State private var manualItemIngredient: Ingredient?
    @State private var pendingUntickAll = false
    @State private var errorMessage: String?
    @AppStorage("export.includeChecked") private var includeChecked = false
    @AppStorage("export.includeMealPlan") private var includeMealPlan = true
    @AppStorage("whatsapp.contactName") private var contactName = ""
    @AppStorage("whatsapp.contactPhone") private var contactPhone = ""
    @Environment(\.openURL) private var openURL

    init(weekID: String) {
        self.weekID = weekID
        let id = weekID
        _plans = Query(filter: #Predicate<WeekPlan> { $0.weekID == id })
    }

    private var plan: WeekPlan? { plans.first }
    private var isReadOnly: Bool { WeekMath.isEnded(weekID, now: .now, calendar: WeekMath.appCalendar) }

    /// `nil` if the week has no plan, or was archived before M9 started
    /// saving this snapshot.
    private var archivedList: ArchivedShoppingList? {
        guard let plan else { return nil }
        return ArchiveService(context: modelContext).archivedShoppingList(plan)
    }

    private var listData: ShoppingListData {
        if isReadOnly {
            guard let archivedList else { return ShoppingListData() }
            return ShoppingListData(sections: archivedList.sections, statuses: archivedList.statuses)
        }
        guard let plan else { return ShoppingListData() }
        let service = WeekPlanService(context: modelContext)
        let sections = ShoppingListBuilder.build(from: service.shoppingLines(for: plan))
        return ShoppingListData(sections: sections, statuses: service.statuses(for: plan, sections: sections))
    }

    private var hasNoSlotsOrManualItems: Bool {
        (plan?.slots ?? []).isEmpty && (plan?.manualItems ?? []).isEmpty
    }

    // MARK: - Export (§7.9, §12)

    private var exportOptions: ExportOptions {
        ExportOptions(includeChecked: includeChecked, includeMealPlan: includeMealPlan)
    }

    private var currentSignature: String { ShoppingListBuilder.signature(of: listData.sections) }

    private var hasExportableItems: Bool {
        ShoppingListExporter.hasExportableItems(sections: listData.sections, statuses: listData.statuses, options: exportOptions)
    }

    private var exportText: String {
        let weekCommencing = WeekMath.weekCommencingText(for: weekID, calendar: WeekMath.appCalendar, locale: .current)
        return ShoppingListExporter.text(
            weekCommencing: weekCommencing, sections: listData.sections, statuses: listData.statuses,
            mealPlan: exportMealPlan, options: exportOptions
        )
    }

    /// Cooked and leftover meals per day, B/L/D order — from the archived
    /// snapshot for an ended week, otherwise straight off the live slots.
    private var exportMealPlan: [ExportDay] {
        guard let plan else { return [] }
        let slots = (plan.slots ?? []).sorted { lhs, rhs in
            lhs.dayIndex != rhs.dayIndex ? lhs.dayIndex < rhs.dayIndex : lhs.mealType < rhs.mealType
        }

        let entries: [(dayIndex: Int, meal: ExportMeal)]
        if plan.isArchived {
            let archiveService = ArchiveService(context: modelContext)
            entries = slots.compactMap { slot in
                guard let snapshot = archiveService.archivedSlot(slot) else { return nil }
                return (slot.dayIndex, ExportMeal(name: snapshot.mealName, isLeftovers: snapshot.leftoverOfSlotID != nil))
            }
        } else {
            entries = slots.compactMap { slot in
                guard let meal = slot.meal else { return nil }
                return (slot.dayIndex, ExportMeal(name: meal.name, isLeftovers: slot.isLeftovers))
            }
        }

        var byDay: [Int: [ExportMeal]] = [:]
        for entry in entries { byDay[entry.dayIndex, default: []].append(entry.meal) }
        return byDay.keys.sorted().map { ExportDay(dayIndex: $0, meals: byDay[$0] ?? []) }
    }

    /// "Send to <Name> on WhatsApp" is only offered for a saved, valid number
    /// with a name to show (§10.12, §14 "Invalid saved WhatsApp number").
    private var whatsAppContact: (name: String, digits: String)? {
        let name = contactName.trimmingCharacters(in: .whitespaces)
        guard case .valid(let digits) = WhatsAppLink.normalizePhone(contactPhone), !name.isEmpty else { return nil }
        return (name, digits)
    }

    private var showsSharedChangedBanner: Bool {
        guard !isReadOnly, let signature = plan?.lastSharedSignature else { return false }
        return signature != currentSignature
    }

    var body: some View {
        let data = listData
        let allItems = data.sections.flatMap(\.items)
        let tickedCount = allItems.filter { isChecked(data.statuses[$0.key]) }.count
        let missingArchivedList = isReadOnly && archivedList == nil

        List {
            if isReadOnly {
                Section {
                    Label("This is the list as it was when the week ended.", systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                }
            }
            if showsSharedChangedBanner {
                Section {
                    SharedChangedBanner(onShareAgain: shareList)
                }
            }
            if !data.sections.isEmpty {
                Section {
                    ProgressView(value: Double(tickedCount), total: Double(allItems.count))
                }
            }
            ForEach(data.sections) { section in
                Section(section.category.displayName) {
                    ForEach(section.items) { item in
                        ShoppingItemRow(
                            item: item,
                            status: data.statuses[item.key] ?? .unchecked,
                            isReadOnly: isReadOnly,
                            onToggle: { toggle(item, checked: $0) },
                            onEdit: { editManualItem(item) },
                            onRemove: { removeManualItem(item) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if missingArchivedList {
                ContentUnavailableView(
                    "No Shopping List", systemImage: "cart",
                    description: Text("No shopping list was saved for this week.")
                )
            } else if data.sections.isEmpty, !isReadOnly {
                if hasNoSlotsOrManualItems {
                    ContentUnavailableView {
                        Label("No Meals Planned", systemImage: "cart")
                    } description: {
                        Text("Plan some meals to build a shopping list, or add an item by hand.")
                    } actions: {
                        Button("Go to Plan") { appState.selectedTab = .plan }
                        Button("Add Item") { showingIngredientPicker = true }
                    }
                } else {
                    ContentUnavailableView("Nothing to Buy", systemImage: "cart", description: Text("Nothing planned this week needs shopping for."))
                }
            }
        }
        .safeAreaInset(edge: .top) {
            WeekNavigator(
                title: navigatorTitle,
                subtitle: data.sections.isEmpty ? "" : "\(tickedCount) of \(allItems.count) ticked",
                onPrevious: { navigate(by: -1) },
                onNext: { navigate(by: 1) },
                onToday: { appState.selectedWeekID = currentWeekID }
            )
        }
        .navigationTitle("Shopping")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isReadOnly {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Item", systemImage: "plus") { showingIngredientPicker = true }
                        .accessibilityLabel("Add Item")
                }
            }
            // Sharing is still allowed for an ended week's frozen list (§10.10);
            // it just never updates `lastSharedSignature` (`markShared` no-ops).
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Share List…", action: shareList)
                        .disabled(!hasExportableItems)
                    Button("Send via WhatsApp") { sendWhatsApp(phoneDigits: nil) }
                        .disabled(!hasExportableItems)
                    if let contact = whatsAppContact {
                        Button("Send to \(contact.name) on WhatsApp") { sendWhatsApp(phoneDigits: contact.digits) }
                            .disabled(!hasExportableItems)
                    }
                    Button("Save as Text File…", action: saveTextFile)
                        .disabled(!hasExportableItems)
                    Divider()
                    Toggle("Include Ticked Items", isOn: $includeChecked)
                    Toggle("Include Meal Plan", isOn: $includeMealPlan)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share")
            }
            if !isReadOnly {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Untick All", role: .destructive) { pendingUntickAll = true }
                            .disabled(tickedCount == 0)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
            }
        }
        .sheet(isPresented: $showingIngredientPicker) {
            IngredientPickerSheet { ingredient in
                manualItemIngredient = ingredient
            }
        }
        .sheet(item: $manualItemIngredient) { ingredient in
            AddShoppingItemSheet(
                weekID: weekID, ingredient: ingredient,
                existingItem: try? WeekPlanService(context: modelContext).manualItem(ingredientID: ingredient.id, weekID: weekID)
            )
        }
        .confirmationDialog("Untick All", isPresented: $pendingUntickAll, titleVisibility: .visible) {
            Button("Untick All", role: .destructive) { uncheckAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This unticks every item on this week's list.")
        }
        .task(id: weekID) {
            guard isReadOnly, plan?.isArchived != true else { return }
            do {
                try ArchiveService(context: modelContext).archiveEndedWeeks()
            } catch {
                logger.error("Failed to archive ended weeks: \(error, privacy: .public)")
            }
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func isChecked(_ status: CheckStatus?) -> Bool {
        if case .checked = status { return true }
        return false
    }

    private var navigatorTitle: String {
        let title = WeekMath.title(for: weekID, now: .now, calendar: WeekMath.appCalendar, locale: .current)
        let dateRange = WeekMath.dateRangeText(for: weekID, calendar: WeekMath.appCalendar, locale: .current)
        return "\(title) · \(dateRange)"
    }

    private var currentWeekID: String { WeekMath.weekID(for: .now, calendar: WeekMath.appCalendar) }

    private func navigate(by weeks: Int) {
        appState.selectedWeekID = WeekMath.weekID(weekID, adding: weeks, calendar: WeekMath.appCalendar)
    }

    // MARK: - Share (§12.2)

    private func shareList() {
        ShareService.present(items: [exportText]) { completed in
            if completed { markSharedIfNeeded() }
        }
    }

    private func sendWhatsApp(phoneDigits: String?) {
        guard let url = WhatsAppLink.url(text: exportText, phoneDigits: phoneDigits) else { return }
        openURL(url) { accepted in
            if accepted { markSharedIfNeeded() }
        }
    }

    private func saveTextFile() {
        do {
            let fileName = "Shopping list \(weekID).txt"
            let fileURL = try ShareService.makeTextFile(text: exportText, fileName: fileName)
            ShareService.present(items: [fileURL]) { completed in
                if completed { markSharedIfNeeded() }
            }
        } catch {
            logger.error("Failed to create text file: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }

    /// No-ops on an archived week — `markShared` itself skips the write
    /// (§10.10, §12.2's "skipped for archived weeks").
    private func markSharedIfNeeded() {
        do {
            try WeekPlanService(context: modelContext).markShared(weekID: weekID, signature: currentSignature)
        } catch {
            logger.error("Failed to record share: \(error, privacy: .public)")
        }
    }

    private func toggle(_ item: ShoppingListItem, checked: Bool) {
        do {
            try WeekPlanService(context: modelContext).setChecked(checked, item: item, weekID: weekID)
        } catch {
            logger.error("Failed to update tick state: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func editManualItem(_ item: ShoppingListItem) {
        guard let ingredient = fetchIngredient(key: item.key) else { return }
        manualItemIngredient = ingredient
    }

    private func removeManualItem(_ item: ShoppingListItem) {
        guard let id = UUID(uuidString: item.key) else { return }
        do {
            try WeekPlanService(context: modelContext).removeManualItem(ingredientID: id, weekID: weekID)
        } catch {
            logger.error("Failed to remove hand-added item: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func uncheckAll() {
        do {
            try WeekPlanService(context: modelContext).uncheckAll(weekID: weekID)
        } catch {
            logger.error("Failed to untick all: \(error, privacy: .public)")
            errorMessage = "Something went wrong. Please try again."
        }
    }

    private func fetchIngredient(key: String) -> Ingredient? {
        guard let id = UUID(uuidString: key) else { return nil }
        var descriptor = FetchDescriptor<Ingredient>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }
}

#Preview {
    NavigationStack {
        ShoppingListView()
            .appRouteDestinations()
    }
    .environment(AppState())
    .modelContainer(PreviewContainer.shared)
}
