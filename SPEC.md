# MealPlanner — Product & Technical Specification

> **Version:** 1.4 (MVP + post-MVP §18) · **Date:** 2026-09-15 · **Platform:** iOS (iPhone) · **Stack:** SwiftUI + SwiftData
>
> **To the implementing model:** This document is the source of truth. Build the app **one milestone at a time** (§16). Each milestone lists the spec sections it needs and the acceptance criteria that must pass before it counts as done. If something here is ambiguous, pick the simplest option that fits the spec and write it down in `DECISIONS.md`. Do **not** add features that are not in this document.

### Changelog

| Version | Changes |
|---------|---------|
| 1.4 | The Plan screen no longer scrolls to today when it opens; it always starts at Monday (§10.1). |
| 1.3 | **"Good as Leftovers"** toggle per meal: the leftovers prompt and leftover actions only appear for meals that keep well (§3, §6.4, §7.7, §8.2, §10.1, §10.3, §10.6, §14, Appendix A). New milestone **M7.1**. |
| 1.2 | Added §18, **post-MVP** recipe photo import via the Claude API (milestones M13–M15). Nothing in M1–M12 changes. |
| 1.1 | Past weeks become a frozen record (§6.7, §7.8, §8.1). A master ingredient library, with shopping-list merging by ingredient ID instead of name (§6.4, §10.9). Shopping items can be added by hand (§10.11). Leftovers (§7.7, §10.3). Randomising: last week's meals are excluded; randomise by meal type; re-roll a single slot (§7.6, §10.1). Meal photos (§8.5, §10.6). WhatsApp via `wa.me` links, including sending straight to a saved contact (§12). The "need more" logic is now explained in plain English (§7.5). |
| 1.0 | First version. |

---

## Table of contents

1. [Product overview](#1-product-overview)
2. [Scope](#2-scope)
3. [Decisions & assumptions](#3-decisions--assumptions)
4. [Tech stack & project setup](#4-tech-stack--project-setup)
5. [Architecture](#5-architecture)
6. [Data model](#6-data-model)
7. [Domain logic (pure Swift)](#7-domain-logic-pure-swift)
8. [Services](#8-services)
9. [App shell & navigation](#9-app-shell--navigation)
10. [Screens](#10-screens)
11. [Notifications](#11-notifications)
12. [Sharing, export & WhatsApp](#12-sharing-export--whatsapp)
13. [UX, accessibility & copy](#13-ux-accessibility--copy)
14. [Edge cases](#14-edge-cases)
15. [Testing](#15-testing)
16. [Implementation milestones](#16-implementation-milestones)
17. [Future roadmap](#17-future-roadmap)
18. [Post-MVP: Recipe photo import](#18-post-mvp-recipe-photo-import)
- [Appendix A — Sample data](#appendix-a--sample-data)
- [Appendix B — Prompt templates](#appendix-b--prompt-templates)

---

## 1. Product overview

MealPlanner is a clean, minimal, native iPhone app. It helps a household decide what to eat each week and turns that plan into a shopping list.

**Core loop**

1. The user keeps an **ingredient library**, e.g. "Onion — Fruit & Veg — usually counted as items".
2. The user saves **meals** (recipes). Each meal has a photo, ingredients chosen from the library with amounts, and step-by-step instructions.
3. The user fills a 7-day plan (Monday–Sunday) with up to one **breakfast**, **lunch** and **dinner** per day. Meals can be picked by hand or randomised. A meal can also be marked as **leftovers** of an earlier meal.
4. The app builds a **live shopping list** from the plan plus anything added by hand. Amounts of the same ingredient are added together and the list is grouped by supermarket aisle.
5. The user ticks items off in the app, or sends the list over **WhatsApp**. The person receiving it doesn't need the app and can be on Android.
6. When a week ends, it becomes a **read-only record** of what was planned and bought.
7. A weekly reminder, on a day and time the user chooses, prompts them to plan and shop.

**Design principles**

- **Native and minimal.** Standard SwiftUI components, SF Symbols, system colours, Dynamic Type and dark mode.
- **Nothing is lost.** Everything is saved on the device as soon as it changes.
- **The present is live; the past is frozen.** Changes to meals and ingredients apply to the current and future weeks only. Weeks that have ended never change.

---

## 2. Scope

### 2.1 MVP (in scope)

| # | Feature | Section |
|---|---------|---------|
| F1 | **Ingredient library:** browse, search, create, rename, change aisle or default unit, merge duplicates, delete unused ingredients | §10.9 |
| F2 | Create and edit meals: name, photo, meal types, servings, time, notes, ingredients picked from the library with amounts, ordered steps | §10.6, §10.7 |
| F3 | Browse, search, filter, favourite, duplicate and delete meals | §10.4, §10.5 |
| F4 | **Meal photos** from the camera or the photo library | §8.5, §10.6 |
| F5 | Weekly plan (Mon–Sun) × (breakfast, lunch, dinner). Any slot can be left empty. | §10.1 |
| F6 | Add meals to the plan from the Plan screen or from a meal's detail screen | §10.2, §10.8 |
| F7 | **Leftovers:** a slot can be leftovers of an earlier meal, which adds nothing to the shopping list. Only offered for meals marked "Good as Leftovers". | §7.7, §10.3 |
| F8 | **Randomise:** whole week, one meal type for the week (e.g. all dinners), one day, or one slot. Last week's meals are never picked. | §7.6, §10.1 |
| F9 | **Week history:** past weeks are read-only records. Last week can be copied into this week. | §6.7, §10.1 |
| F10 | Live shopping list: amounts added together by ingredient, grouped by aisle, tick-off with "need more" detection | §7.4, §7.5, §10.10 |
| F11 | **Add shopping items by hand** to a week's list | §10.11 |
| F12 | Export: share sheet (text), `.txt` file, **WhatsApp (chat picker or a saved contact)**, "changed since shared" banner | §12 |
| F13 | Weekly reminder notification | §11 |
| F14 | Data saved on the device with SwiftData | §6 |
| F15 | "Add example meals" for first run and testing | Appendix A |

### 2.2 Out of scope for MVP (do NOT build)

- iPad layout, widgets, Apple Watch, Siri/Shortcuts
- iCloud sync or sharing inside the app with other people (the data model is ready for it, §6.1)
- Recipe import from URLs, nutrition information
- Recipe import from photos (specified in §18 as post-MVP milestones M13–M15)
- Scaling ingredients by servings, "pantry staples" exclusion
- A configurable first day of the week (always Monday)
- Android app, Tesco integration (§17)
- Localisation beyond English (UK)

---

## 3. Decisions & assumptions

| Topic | Decision |
|-------|----------|
| Platform | iPhone only, portrait, iOS **18.0**+. SwiftUI + SwiftData. No third-party dependencies. |
| Week | 7 days, **Monday first**, identified by ISO-8601 week key (`"2026-W38"`). All weeks are kept. |
| **Past weeks** | A week is **ended** once its Sunday has passed. Ended weeks are **archived**: a snapshot of their slots and final shopping list is saved, and after that nothing can change them. Editing or deleting meals or ingredients only affects the **current and future** weeks. The current week stays editable, including days that have already gone by. |
| **Ingredients** | A master library of `Ingredient` records. Recipes and hand-added shopping items **point to** library ingredients. The shopping list merges by ingredient **ID**, never by comparing names. Each ingredient has a unique name (ignoring case and spacing). The aisle belongs to the ingredient; the amount and unit belong to each recipe line. |
| Meal types | A meal can suit one or more of breakfast, lunch and dinner. At least one is required. |
| Plan slots | At most one meal per (week, day, meal type). An empty slot has no database row. |
| **Leftovers** | A slot can be marked as leftovers of an earlier "cooked" slot with the same meal, up to 3 days before. Leftover slots add **nothing** to the shopping list. When the user plans a meal that was cooked in the previous 3 days, the app asks "Leftovers or cook again?" **Only for meals with "Good as Leftovers" switched on** (default on; off for things like scrambled eggs). For other meals, planning them again is always a normal cooked meal, with no prompt and no leftover actions. |
| **Randomiser** | Never picks a meal that was planned in the **previous week**, even if that leaves a slot empty. Tries not to repeat meals within the week. Never creates leftovers and never overwrites leftover slots unless their source meal is being replaced. |
| Same meal cooked twice | If a meal is in two *cooked* slots, its ingredients count twice. |
| Shopping list | Worked out live for current and future weeks; only tick states are saved. Ended weeks show their archived snapshot. |
| Hand-added items | At most one per (week, ingredient). They merge with recipe amounts for the same ingredient. |
| Photos | One photo per meal, from the camera or photo library. Resized before saving, with a thumbnail stored separately. |
| Export | In-app checklist, system share sheet (text or `.txt` file), and WhatsApp via `https://wa.me/` links. The person receiving it needs only WhatsApp (iOS or Android). |
| Reminder | One weekly repeating local notification. Defaults: Sunday 18:00, off. |
| Language | UI copy in **British English**. Code identifiers in **US English**. |

---

## 4. Tech stack & project setup

### 4.1 Stack

| Concern | Choice |
|---------|--------|
| Language | Swift 6 language mode (Swift 6.2+ toolchain) |
| Concurrency | **Default Actor Isolation = MainActor**, **Approachable Concurrency = Yes** |
| UI | SwiftUI (`TabView` with `Tab`, `NavigationStack`, `List`, `Form`), PhotosUI (`PhotosPicker`) |
| Persistence | SwiftData with a `VersionedSchema` |
| Images | UIKit `UIGraphicsImageRenderer` for resizing, `UIImagePickerController` for the camera |
| Notifications | `UserNotifications` (local) |
| Sharing | `UIActivityViewController` (wrapped), `openURL` with `https://wa.me/` links |
| Tests | Swift Testing (`import Testing`) |
| Tooling | Latest stable Xcode (26+), `xcodebuild` |

### 4.2 One-time project setup (done by the human in Xcode — Milestone 0)

1. Xcode → **File → New → Project → iOS → App**.
   - Product Name `MealPlanner`, Interface SwiftUI, Language Swift, Testing System **Swift Testing**, Storage **None**.
   - Untick "Create Git repository". Save inside `dinner-app/`.
2. Select the `MealPlanner` target:
   - **General → Supported Destinations:** iPhone only.
   - **General → Minimum Deployments:** iOS 18.0.
   - **General → Deployment Info → iPhone Orientation:** Portrait only.
   - **Signing & Capabilities:** your personal team.
   - **Info → Custom iOS Target Properties →** add `Privacy - Camera Usage Description` with the value `Take a photo of your finished meal.`
   - **Build Settings:** check Swift Language Version = Swift 6, Default Actor Isolation = MainActor, Approachable Concurrency = Yes.
3. Check that the `MealPlanner` and `MealPlannerTests` folders are **blue folders** (synchronised groups).
4. Delete the `MealPlannerUITests` target (not used).
5. Set up git at the `dinner-app/` root. Run each of these in Terminal:
   ```bash
   cd ~/Developer/claude/dinner-app
   ```
   ```bash
   curl -fsSL https://raw.githubusercontent.com/github/gitignore/main/Swift.gitignore -o .gitignore
   ```
   ```bash
   printf '\n# macOS\n.DS_Store\n' >> .gitignore
   ```
   ```bash
   git init && git add . && git commit -m "Initial project setup"
   ```

### 4.3 Repository layout

```
dinner-app/
├── .gitignore
├── CLAUDE.md
├── SPEC.md
├── DECISIONS.md                  # created by the implementer
└── MealPlanner/
    ├── MealPlanner.xcodeproj
    ├── MealPlanner/              # app sources (synchronised folder) — §5.2
    └── MealPlannerTests/         # unit tests (synchronised folder) — §15
```

### 4.4 Build & test commands

Run these from `dinner-app/MealPlanner/`. Pick a simulator with `xcrun simctl list devices available | grep iPhone`.

```bash
xcodebuild -project MealPlanner.xcodeproj -scheme MealPlanner -destination 'platform=iOS Simulator,name=<SIM>' -quiet build
```

```bash
xcodebuild -project MealPlanner.xcodeproj -scheme MealPlanner -destination 'platform=iOS Simulator,name=<SIM>' -quiet test
```

A milestone is done only with **zero errors, zero warnings**, and all tests passing.

---

## 5. Architecture

### 5.1 Layers

```
┌──────────────────────────────────────────────────────────────┐
│ Features (SwiftUI views)                                     │
│   @Query for reads · Services for every write                │
├──────────────────────────────────────────────────────────────┤
│ Services (@MainActor structs wrapping ModelContext / system)  │
│   ArchiveService · WeekPlanService · MealStore ·             │
│   IngredientStore · ImageProcessor · NotificationScheduler · │
│   ShareService · SampleData                                  │
├──────────────────────────────────────────────────────────────┤
│ Domain (pure Swift value types; Foundation only)             │
│   WeekMath · QuantityParser · QuantityFormatter ·            │
│   NameNormalizer · ShoppingListBuilder ·                     │
│   ShoppingCheckEvaluator · MealRandomizer · LeftoverRules ·  │
│   ArchiveSnapshots · ShoppingListExporter · WhatsAppLink     │
├──────────────────────────────────────────────────────────────┤
│ Models (SwiftData @Model classes + enums)                    │
└──────────────────────────────────────────────────────────────┘
```

**Rules**

- **Domain** imports only `Foundation`, and takes and returns plain structs.
- **Views** read with `@Query`, and **never** insert, delete, relink or edit models directly. They call services. (The one exception is `MealDraft`/form drafts, which are values.)
- **Every service method that changes data:**
  1. calls `ArchiveService.archiveEndedWeeks()` first (§8.1);
  2. throws `AppError.weekIsArchived` if it would change an ended week;
  3. finishes with `try context.save()`.
- Shared UI state lives in `@Observable AppState` (§9.2).
- Views catch service errors and show a friendly alert (§13.3), logging with `os.Logger`.

### 5.2 Folder structure (inside `MealPlanner/MealPlanner/`)

```
App/
  MealPlannerApp.swift
  AppDelegate.swift
  AppState.swift
  RootTabView.swift
Models/
  SchemaV1.swift
  Meal.swift
  RecipeIngredient.swift
  Ingredient.swift
  InstructionStep.swift
  WeekPlan.swift
  MealSlot.swift
  ManualShoppingItem.swift
  ShoppingItemState.swift
  MealType.swift
  IngredientUnit.swift
  ShoppingCategory.swift
Domain/
  WeekMath.swift
  QuantityParser.swift
  QuantityFormatter.swift
  NameNormalizer.swift
  ShoppingListBuilder.swift
  ShoppingCheckEvaluator.swift
  MealRandomizer.swift
  LeftoverRules.swift
  ArchiveSnapshots.swift
  ShoppingListExporter.swift
  WhatsAppLink.swift
Services/
  AppError.swift
  ArchiveService.swift
  WeekPlanService.swift
  WeekPlanService+Leftovers.swift
  WeekPlanService+Randomize.swift
  WeekPlanService+Shopping.swift
  MealStore.swift
  IngredientStore.swift
  ImageProcessor.swift
  NotificationScheduler.swift
  ShareService.swift
  SampleData.swift
Features/
  Plan/
    WeekPlanView.swift
    WeekNavigator.swift
    DaySection.swift
    MealSlotRow.swift
    MealPickerSheet.swift
    RandomizeMenu.swift
    ArchivedSlotDetailView.swift
  Meals/
    MealLibraryView.swift
    MealRow.swift
    MealThumbnail.swift
    MealDetailView.swift
    MealEditorView.swift
    MealEditorPhotoSection.swift
    MealDraft.swift
    RecipeIngredientForm.swift
    AddToPlanSheet.swift
    CameraPicker.swift
  Ingredients/
    IngredientLibraryView.swift
    IngredientDetailView.swift
    IngredientPickerSheet.swift
    NewIngredientForm.swift
  Shopping/
    ShoppingListView.swift
    ShoppingItemRow.swift
    SharedChangedBanner.swift
    AddShoppingItemSheet.swift
  Settings/
    SettingsView.swift
    WhatsAppContactSection.swift
Shared/
  PreviewContainer.swift
  DependentLeftoversDialog.swift     # reusable confirmationDialog modifier (§10.3)
Resources/
  Assets.xcassets
```

Keep files **under ~250 lines**. Split out subviews and extensions as needed.

---

## 6. Data model

### 6.1 SwiftData rules (follow exactly)

1. **Every stored property has a default value** or is optional.
2. **No `@Attribute(.unique)`.** Services enforce uniqueness.
3. **All relationships are optional.** To-many relationships are `[Child]? = []`. Add non-optional computed helpers.
4. Declare `@Relationship(deleteRule:inverse:)` **only on the to-many side**.
5. **Store enums as raw `String`s** with a computed enum property.
6. **Never persist `hashValue`.**
7. The container uses `cloudKitDatabase: .none`.
8. When `@Query` needs a runtime value, build it in `init` and copy the value into a local `let` for `#Predicate`:
   ```swift
   init(weekID: String) {
       let id = weekID
       _plans = Query(filter: #Predicate<WeekPlan> { $0.weekID == id })
   }
   ```
9. Large binary data uses `@Attribute(.externalStorage)`.

### 6.2 Enums

```swift
enum MealType: String, Codable, CaseIterable, Identifiable, Comparable {
    case breakfast, lunch, dinner
    var id: String { rawValue }
    var displayName: String      // "Breakfast", "Lunch", "Dinner"
    var pluralName: String       // "Breakfasts", "Lunches", "Dinners"
    var symbolName: String       // "sunrise", "sun.max", "moon.stars"
    var sortOrder: Int           // 0, 1, 2
    static func < (l: Self, r: Self) -> Bool { l.sortOrder < r.sortOrder }
}

enum ShoppingCategory: String, Codable, CaseIterable, Identifiable {
    // Declaration order == display order
    case produce, meatFish, dairyEggs, bakery, pantry, frozen, drinks, household, other
    var id: String { rawValue }
    var displayName: String
    // "Fruit & Veg", "Meat & Fish", "Dairy & Eggs", "Bakery", "Food Cupboard",
    // "Frozen", "Drinks", "Household", "Other"
}
```

### 6.3 `IngredientUnit`

```swift
enum IngredientUnit: String, Codable, CodingKeyRepresentable, CaseIterable, Identifiable {
    // Declaration order == picker order == order when joining amounts
    case item, g, kg, ml, l, tsp, tbsp, cup, clove, slice, tin, pack, bunch, handful, pinch
    var id: String { rawValue }
    var baseUnit: IngredientUnit { switch self { case .kg: .g; case .l: .ml; default: self } }
    var toBaseMultiplier: Double { switch self { case .kg, .l: 1000; default: 1 } }
    var pickerLabel: String            // item → "item (whole)", others → rawValue
    var hasPlural: Bool                // cup, clove, slice, tin, pack, bunch, handful, pinch
    func label(for amount: Double) -> String
}
```

`CodingKeyRepresentable` makes `[IngredientUnit: Double]` encode as a JSON object (`{"g": 200}`).

### 6.4 Models

```swift
// MARK: Ingredient library

@Model
final class Ingredient {
    var id: UUID = UUID()
    var name: String = ""                                   // unique by NameNormalizer.key (service-enforced)
    var defaultUnitRaw: String = IngredientUnit.item.rawValue
    var categoryRaw: String = ShoppingCategory.other.rawValue
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \RecipeIngredient.ingredient)
    var recipeUses: [RecipeIngredient]? = []
    @Relationship(deleteRule: .nullify, inverse: \ManualShoppingItem.ingredient)
    var manualUses: [ManualShoppingItem]? = []

    init(name: String, defaultUnit: IngredientUnit, category: ShoppingCategory)
    var defaultUnit: IngredientUnit
    var category: ShoppingCategory
    var usedInMeals: [Meal]        // distinct meals from recipeUses, sorted by name
}

// MARK: Meals

@Model
final class Meal {
    var id: UUID = UUID()
    var name: String = ""
    var isBreakfast: Bool = false
    var isLunch: Bool = false
    var isDinner: Bool = false
    var servings: Int = 2
    var totalMinutes: Int? = nil
    var notes: String = ""
    var isFavorite: Bool = false
    var goodAsLeftovers: Bool = true                              // §7.7: false = never offered as leftovers
    @Attribute(.externalStorage) var photoData: Data? = nil       // JPEG, long edge ≤ 1600 px
    @Attribute(.externalStorage) var thumbnailData: Data? = nil   // JPEG, 300×300
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.meal)
    var ingredients: [RecipeIngredient]? = []
    @Relationship(deleteRule: .cascade, inverse: \InstructionStep.meal)
    var steps: [InstructionStep]? = []
    @Relationship(deleteRule: .nullify, inverse: \MealSlot.meal)
    var slots: [MealSlot]? = []

    init(name: String)
    var mealTypes: Set<MealType>          // get/set over the three Bools
    func suits(_ type: MealType) -> Bool
    var sortedIngredients: [RecipeIngredient]
    var sortedSteps: [InstructionStep]
}

@Model
final class RecipeIngredient {                 // one line in a recipe
    var id: UUID = UUID()
    var quantity: Double? = nil                // nil = unquantified ("to taste")
    var unitRaw: String = IngredientUnit.item.rawValue
    var note: String = ""                      // e.g. "finely chopped"
    var sortIndex: Int = 0
    var meal: Meal?
    var ingredient: Ingredient?

    init(ingredient: Ingredient, quantity: Double?, unit: IngredientUnit, note: String, sortIndex: Int)
    var unit: IngredientUnit
}

@Model
final class InstructionStep {
    var id: UUID = UUID()
    var text: String = ""
    var sortIndex: Int = 0
    var meal: Meal?
    init(text: String, sortIndex: Int)
}

// MARK: Planning

@Model
final class WeekPlan {
    var id: UUID = UUID()
    var weekID: String = ""                    // "2026-W38"; unique (service-enforced)
    var createdAt: Date = Date.now
    var isArchived: Bool = false               // §6.7
    var archivedAt: Date? = nil
    var archivedShoppingJSON: String? = nil    // ArchivedShoppingList (§7.8), set on archive
    var lastSharedAt: Date? = nil
    var lastSharedSignature: String? = nil

    @Relationship(deleteRule: .cascade, inverse: \MealSlot.weekPlan)
    var slots: [MealSlot]? = []
    @Relationship(deleteRule: .cascade, inverse: \ManualShoppingItem.weekPlan)
    var manualItems: [ManualShoppingItem]? = []
    @Relationship(deleteRule: .cascade, inverse: \ShoppingItemState.weekPlan)
    var itemStates: [ShoppingItemState]? = []

    init(weekID: String)
}

@Model
final class MealSlot {
    var id: UUID = UUID()
    var dayIndex: Int = 0                      // 0 = Monday … 6 = Sunday
    var mealTypeRaw: String = MealType.dinner.rawValue
    var leftoverOfSlotID: UUID? = nil          // set = this slot is leftovers of that cooked slot (§7.7)
    var archivedSnapshotJSON: String? = nil    // ArchivedSlot (§7.8), set on archive
    var weekPlan: WeekPlan?
    var meal: Meal?

    init(dayIndex: Int, mealType: MealType)
    var mealType: MealType
    var isLeftovers: Bool { leftoverOfSlotID != nil }
}

// MARK: Shopping

@Model
final class ManualShoppingItem {               // added by hand to a week's list
    var id: UUID = UUID()
    var quantity: Double? = nil
    var unitRaw: String = IngredientUnit.item.rawValue
    var createdAt: Date = Date.now
    var weekPlan: WeekPlan?
    var ingredient: Ingredient?

    init(ingredient: Ingredient, quantity: Double?, unit: IngredientUnit)
    var unit: IngredientUnit
}

@Model
final class ShoppingItemState {
    var id: UUID = UUID()
    var itemKey: String = ""                   // Ingredient.id.uuidString
    var isChecked: Bool = false
    var checkedAmountsJSON: String = "{}"      // [IngredientUnit: Double] captured when ticked (§7.5)
    var weekPlan: WeekPlan?

    init(itemKey: String)
    var checkedAmounts: [IngredientUnit: Double]   // get/set via JSONEncoder (sortedKeys)
}
```

### 6.5 Schema & container (`SchemaV1.swift`)

> **From v1.3 on, `SchemaV1` is frozen.** Every later model change needs a new schema version plus a migration stage and a migration test. See "Data model changes" in `CLAUDE.md`, which overrides any older instruction in this spec to edit `SchemaV1` directly.

```swift
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Ingredient.self, Meal.self, RecipeIngredient.self, InstructionStep.self,
         WeekPlan.self, MealSlot.self, ManualShoppingItem.self, ShoppingItemState.self]
    }
}
enum MealPlannerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
enum ModelContainerFactory {
    static func make(inMemory: Bool = false) throws -> ModelContainer
}
```

If the container can't be created at launch → `fatalError` with a clear message.

### 6.6 Data lifecycle rules

| Event | Behaviour |
|-------|-----------|
| Browsing a week with no plan | Don't create a `WeekPlan`. |
| First slot or hand-added item in a week | `fetchOrCreatePlan(weekID)`. |
| Assigning to an occupied slot | Reuse the `MealSlot` row: set `meal`, and set `leftoverOfSlotID` as chosen. |
| Clearing a slot | Delete the row (dependent leftovers: §7.7). |
| Clear week | Delete that week's slots, manual items and item states. Reset `lastSharedSignature`. |
| Deleting a meal | Delete its slots in **non-archived** weeks (plus leftovers that depend on them), then the meal. Archived slots keep their snapshot, and their `meal` becomes nil automatically. |
| Editing a meal | `MealStore.update` replaces recipe lines and steps. Current and future weeks see the change; archived weeks don't. |
| Editing an ingredient (name/aisle) | Current and future lists see the change. Archived weeks don't. |
| Deleting an ingredient | Only allowed if no recipe uses it. Its manual items in non-archived weeks are deleted. |
| Merging ingredient A into B | Every recipe line and non-archived manual item moves from A to B, then A is deleted (§8.4). |
| A shopping item disappears | Leave its `ShoppingItemState` alone. If the item comes back, its tick comes back. |
| Old weeks | Kept forever. |

### 6.7 Archived (ended) weeks

- A week is **ended** when `WeekMath.isEnded(weekID, now:)` is true, meaning its Sunday is over.
- **Archiving** (§8.1) stores a JSON snapshot on every slot (`ArchivedSlot`) and on the plan (`ArchivedShoppingList`), then sets `isArchived = true`.
- Once archived, the UI and every service read **only the snapshots** for that week, never `slot.meal` or live ingredients.
- Archived weeks can't be changed: no assigning, clearing, randomising, ticking, hand-added items or marking as shared. Services throw `AppError.weekIsArchived`.
- An ended week that has no `WeekPlan` is simply shown as empty and read-only.

---

## 7. Domain logic (pure Swift)

Everything here lives in `Domain/`, imports only `Foundation`, and **must have unit tests** (§15). Functions that depend on time or locale take `now: Date`, `calendar: Calendar` and `locale: Locale` as parameters.

### 7.1 `WeekMath`

```swift
enum WeekMath {
    static var appCalendar: Calendar                                        // Calendar(identifier: .iso8601) + TimeZone.current
    static func weekID(for date: Date, calendar: Calendar) -> String        // "YYYY-Www" (yearForWeekOfYear)
    static func startDate(of weekID: String, calendar: Calendar) -> Date?   // Monday 00:00
    static func weekID(_ weekID: String, adding weeks: Int, calendar: Calendar) -> String
    static func date(dayIndex: Int, in weekID: String, calendar: Calendar) -> Date?
    static func dayIndex(for date: Date, calendar: Calendar) -> Int         // Monday = 0 … Sunday = 6
    static func isEnded(_ weekID: String, now: Date, calendar: Calendar) -> Bool  // weekID < current weekID
    static func compare(_ a: String, _ b: String) -> ComparisonResult       // chronological
    static func dayDistance(from: (weekID: String, dayIndex: Int),
                            to: (weekID: String, dayIndex: Int), calendar: Calendar) -> Int
    static func nextDay(weekID: String, dayIndex: Int, calendar: Calendar) -> (weekID: String, dayIndex: Int)
    static func shortDayName(_ dayIndex: Int) -> String                     // "Mon" … "Sun" (fixed English)
    static func title(for weekID: String, now: Date, calendar: Calendar, locale: Locale) -> String
    static func dateRangeText(for weekID: String, calendar: Calendar, locale: Locale) -> String
    static func weekCommencingText(for weekID: String, calendar: Calendar, locale: Locale) -> String
}
```

- `title`: "This week" / "Next week" / "Last week", otherwise "w/c 7 Sep". Add the year if it isn't the current year.
- `dateRangeText`: "14–20 Sep", or "28 Sep – 4 Oct".
- `weekCommencingText`: "w/c 14 Sep".

| Test | Expected |
|------|----------|
| `weekID(2026-09-14)` | `"2026-W38"` |
| `weekID(2026-09-20)`, `dayIndex` | `"2026-W38"`, `6` |
| `weekID(2027-01-01)` | `"2026-W53"` |
| `weekID(2027-01-04)` | `"2027-W01"` |
| `weekID("2026-W53", adding: 1)` | `"2027-W01"` |
| `isEnded("2026-W37", now: 2026-09-14 09:00)` | `true` |
| `isEnded("2026-W38", now: 2026-09-20 23:59)` | `false` |
| `isEnded("2026-W38", now: 2026-09-21 00:00)` | `true` |
| `dayDistance(("2026-W38", 6) → ("2026-W39", 0))` | `1` |
| `nextDay("2026-W38", 6)` | `("2026-W39", 0)` |
| `title("2026-W39", now: 2026-09-14)` | `"Next week"` |
| `dateRangeText("2026-W40")` | `"28 Sep – 4 Oct"` |

### 7.2 `QuantityParser` / `QuantityFormatter`

```swift
enum QuantityParser {
    enum Result: Equatable { case empty, value(Double), invalid }
    static func parse(_ text: String) -> Result
}
enum QuantityFormatter {
    static func number(_ value: Double) -> String                        // ≤2 dp, trailing zeros trimmed, "."
    static func format(_ amount: Double, unit: IngredientUnit) -> String
    static func format(amounts: [IngredientUnit: Double]) -> String    // " + " joined in allCases order; "" if empty
}
```

| Parser input | Result |
|--------------|--------|
| `""`, `"  "` | `.empty` |
| `"2"`, `"1.5"`, `"1,5"` | `.value(2)`, `.value(1.5)`, `.value(1.5)` |
| `"1/2"`, `"1 1/2"` | `.value(0.5)`, `.value(1.5)` |
| `"½"`, `"¼"`, `"¾"` | `.value(0.5)`, `.value(0.25)`, `.value(0.75)` |
| `"0"`, `"-1"`, `"abc"`, `"1/0"` | `.invalid` |

**Formatter rules:** `.g` amounts ≥ 1000 are shown in kg, and `.ml` amounts ≥ 1000 in l. Never convert downwards. Put a space between the number and the unit. `.item` shows only the number. Plural units use their plural form when the amount ≠ 1.

| Formatter input | Output |
|-----------------|--------|
| `(400, .g)` / `(1500, .g)` | `"400 g"` / `"1.5 kg"` |
| `(1000, .ml)` / `(0.3, .kg)` | `"1 l"` / `"0.3 kg"` |
| `(1/3, .tsp)` / `(3, .item)` | `"0.33 tsp"` / `"3"` |
| `(1, .tin)` / `(2, .bunch)` | `"1 tin"` / `"2 bunches"` |
| `amounts: [.g: 200, .item: 2]` | `"2 + 200 g"` |

### 7.3 `NameNormalizer`

```swift
enum NameNormalizer {
    static func key(_ name: String) -> String   // trim, lowercase, strip diacritics, collapse whitespace
    static func clean(_ name: String) -> String // trim + collapse whitespace (keeps case) — used when saving names
}
```

Used **only** to stop duplicate ingredient names in the library and to rank search results. It is **not** used to merge items on the shopping list.

Tests: `key("  Crème  Fraîche ")` == `"creme fraiche"`, `clean("  Red   onion ")` == `"Red onion"`.

### 7.4 `ShoppingListBuilder`

**Input:** one `ShoppingLine` for every recipe line of every **cooked** (non-leftover) filled slot, in plan order (day ascending, then B → L → D, then `sortIndex`), followed by the week's hand-added items in `createdAt` order. Recipe lines whose `ingredient` is nil are skipped.

```swift
enum ShoppingLineSource: Hashable, Codable, Sendable { case meal(String), manual }

struct ShoppingLine: Equatable, Sendable {
    let ingredientKey: String        // Ingredient.id.uuidString
    let name: String                 // Ingredient.name
    let category: ShoppingCategory   // Ingredient.category
    let quantity: Double?
    let unit: IngredientUnit
    let source: ShoppingLineSource
}

struct ShoppingListItem: Identifiable, Equatable, Codable, Sendable {
    var id: String { key }
    let key: String                          // ingredientKey
    let displayName: String
    let category: ShoppingCategory
    let amounts: [IngredientUnit: Double]    // base units only; empty = unquantified
    let usedIn: [String]                     // unique meal names, first-seen order
    let hasManualEntry: Bool
}

struct ShoppingListSection: Identifiable, Equatable, Codable, Sendable {
    var id: ShoppingCategory { category }
    let category: ShoppingCategory
    let items: [ShoppingListItem]
}

enum ShoppingListBuilder {
    static func build(from lines: [ShoppingLine]) -> [ShoppingListSection]
    static func signature(of sections: [ShoppingListSection]) -> String
}
```

**Algorithm**

1. Group lines by `ingredientKey`. **Lines with different keys are never merged, even if their names match.**
2. For each group: `displayName` and `category` come from the first line. For each line with a quantity, `amounts[unit.baseUnit] += quantity × unit.toBaseMultiplier`. `usedIn` = unique names from `.meal` sources. `hasManualEntry` = true if any line is `.manual`.
3. Sections follow `ShoppingCategory.allCases` order, with empty sections left out. Items within a section are sorted by `displayName` (`localizedStandardCompare`).
4. `signature`: a deterministic string of every item's key, its amounts (unit raw values sorted, numbers rounded to 3 dp) and `hasManualEntry`, in list order.

**Required tests**

| Lines in | Expected |
|----------|----------|
| Chicken (key A) 200 g from Fajitas + Chicken (key A) 0.3 kg from Wrap | one item, `[.g: 500]`, usedIn `["Fajitas", "Wrap"]` |
| "Onion" key A 1 item + "Onion" key **B** 2 item | **two** items (different keys) |
| Garlic 2 clove + Garlic (no qty) | `[.clove: 2]` |
| Milk 500 ml + Milk 1 l | `[.ml: 1500]` |
| Salt (no qty) | `[:]` |
| Same meal cooked in 2 slots, Oats 50 g | `[.g: 100]` |
| Rice 250 g (meal) + Rice 1 pack (manual) | `[.g: 250, .pack: 1]`, `hasManualEntry` true |
| Toilet roll 1 pack (manual only) | usedIn `[]`, `hasManualEntry` true |

### 7.5 `ShoppingCheckEvaluator`

**What it's for (plain English).** You tick "Chicken breast" in the shop. Later you add another chicken meal to the plan. The row shouldn't still look finished, because you now need more chicken. So when you tick an item, the app **remembers how much the list needed at that moment**. Each time the list is drawn, it compares what the list needs **now** with what it needed **when you ticked it**:

- Now needs **the same or less** → still ticked. You already bought enough.
- Now needs **more** → the row turns orange: "Need 150 g more".

**Worked example**

| What happens | List needs | Remembered at tick | Row shows |
|--------------|-----------|--------------------|-----------|
| Plan Fajitas (200 g chicken) | 200 g | — | ○ Chicken breast · 200 g |
| Tick it in the shop | 200 g | 200 g | ✓ Chicken breast · 200 g |
| Add Caesar wraps (+150 g) | 350 g | 200 g | ⚠ Chicken breast · 350 g · **Need 150 g more** |
| Tick it again after buying more | 350 g | 350 g | ✓ Chicken breast · 350 g |
| Remove the wraps | 200 g | 350 g | ✓ Chicken breast · 200 g (you have enough) |

In code, "need 150 g more" is `CheckStatus.needsMore([.g: 150])`. The value is a dictionary of *unit → extra amount*, because one item can be needed in several units (e.g. `[.g: 250, .pack: 1]` for rice).

```swift
enum CheckStatus: Equatable, Codable, Sendable {
    case unchecked
    case checked
    case needsMore([IngredientUnit: Double])
}

enum ShoppingCheckEvaluator {
    static func status(for item: ShoppingListItem,
                       isChecked: Bool?,
                       checkedAmounts: [IngredientUnit: Double]) -> CheckStatus
}
```

**Rules**

- `isChecked` is nil or false → `.unchecked`.
- Otherwise, for each `(unit, amount)` in `item.amounts`: `extra = amount − (checkedAmounts[unit] ?? 0)`. Keep extras above 0.0001. None → `.checked`. Some → `.needsMore(extras)`.
- **Ticking** stores `isChecked = true` and `checkedAmounts = item.amounts`. **Unticking** stores `isChecked = false`.

**Tests:** same → `.checked`; 200 → 400 g → `.needsMore([.g: 200])`; 400 → 200 g → `.checked`; `[.g: 200]` → `[.g: 200, .pack: 1]` → `.needsMore([.pack: 1])`; unquantified + ticked → `.checked`.

### 7.6 `MealRandomizer`

```swift
struct SlotKey: Hashable, Comparable, Sendable {
    let dayIndex: Int
    let mealType: MealType      // Comparable: dayIndex, then mealType
}

enum RandomizeMode: String, CaseIterable, Sendable { case fillEmpty, replaceAll }

struct RandomizeResult: Equatable, Sendable {
    var assignments: [SlotKey: UUID]        // only slots to (re)assign
    var skippedNoCandidates: [SlotKey]       // targets left alone because the pool was empty
}

enum MealRandomizer {
    static func randomize(
        targetSlots: [SlotKey],
        current: [SlotKey: UUID],            // every assignment in the week (cooked + leftovers)
        lockedSlots: Set<SlotKey>,           // never assigned (leftover slots, §8.2)
        candidates: [MealType: [UUID]],      // eligible meal IDs per type, sorted by name
        excludedMealIDs: Set<UUID>,          // meals planned in the PREVIOUS week — never picked
        mode: RandomizeMode,
        using rng: inout some RandomNumberGenerator
    ) -> RandomizeResult
}
```

**Algorithm**

1. `targets` = `targetSlots` minus `lockedSlots`, sorted. `week = current`, `previous = current`.
2. If `.replaceAll`, remove every target from `week`.
3. For each `slot` in `targets`:
   1. If `.fillEmpty` and `week[slot] != nil` → skip.
   2. `pool = (candidates[slot.mealType] ?? []).filter { !excludedMealIDs.contains($0) }`. If empty → add to `skippedNoCandidates` and skip.
   3. `usedInWeek` = meal IDs in `week` other than this slot. `nearby` = meal IDs in `week` on days `dayIndex−1…dayIndex+1`, other than this slot. `prev = previous[slot]`.
   4. Take the first tier that isn't empty. **T1:** pool − usedInWeek − prev. **T2:** pool − nearby − prev. **T3:** pool − prev. **T4:** pool.
   5. `pick = tier.randomElement(using: &rng)!`. Set `week[slot] = pick` and `assignments[slot] = pick`.

In plain terms: never last week's meals; avoid repeats this week; failing that, avoid the same meal on neighbouring days; and when re-rolling, try to give something different from before.

**Required tests** (seeded `SplitMix64`):
- `.fillEmpty` never touches filled slots. Locked slots never appear in `assignments`.
- Excluded meals are never picked, **even when that means skipping** (3 dinners, all excluded → 7 skipped).
- 7 candidates, 7 empty dinner slots → 7 different meals.
- 3 candidates, 7 empty dinner slots → no meal on two days in a row.
- 1 candidate → every slot gets it.
- **Re-roll one slot:** week of 7 dinners, `.replaceAll` on Tuesday dinner only, 10 candidates → only Tuesday changes, the new meal ≠ the old one, and it isn't used elsewhere in the week.
- Same seed → same result.

### 7.7 `LeftoverRules`

```swift
struct PlanPosition: Hashable, Sendable {
    let weekID: String
    let dayIndex: Int
    let mealType: MealType
}

struct PlanOccurrence: Hashable, Sendable {
    let slotID: UUID
    let position: PlanPosition
    let mealID: UUID
    let isLeftovers: Bool
}

enum LeftoverRules {
    static let maxDaysLater = 3

    /// Cooked occurrences of `mealID` that `target` could be leftovers of, nearest first.
    static func sourceCandidates(mealID: UUID, target: PlanPosition,
                                 occurrences: [PlanOccurrence], calendar: Calendar) -> [PlanOccurrence]

    /// Human label for a source, e.g. "Mon dinner".
    static func label(for position: PlanPosition) -> String
}
```

**A candidate** has the same `mealID`, is **not** leftovers itself, and comes **before** the target by at most 3 days:
- `d = WeekMath.dayDistance(candidate → target)`
- valid if `1 ≤ d ≤ 3`, or `d == 0` with an earlier meal type (e.g. lunch leftovers from the same day's breakfast).
- Sort by `d` ascending, then later meal type first.

`occurrences` covers the target's week and the previous week, so Sunday dinner → Monday lunch works.

**"Good as Leftovers" (v1.3):** `LeftoverRules` stays a pure function of occurrences and doesn't know about the flag. The **service** applies it: when the meal's `goodAsLeftovers` is false, `WeekPlanService.leftoverSourceCandidates` returns `[]` without calling `LeftoverRules`. Everything built on candidates (prompt A, "Mark as Leftovers") then disappears automatically.

**Tests:** Mon dinner → Tue lunch is a candidate; Mon dinner → Fri dinner is not (4 days); Sun dinner (W38) → Mon lunch (W39) is a candidate; Tue lunch → Mon dinner is not (it comes later); a leftovers slot is never a candidate; same-day dinner → lunch is not (dinner is later).

### 7.8 `ArchiveSnapshots`

```swift
struct ArchivedIngredientLine: Codable, Equatable, Sendable {
    let name: String
    let amountText: String       // QuantityFormatter output at archive time ("" if none)
    let note: String
}

struct ArchivedSlot: Codable, Equatable, Sendable {
    let slotID: UUID
    let mealID: UUID?
    let mealName: String
    let leftoverOfSlotID: UUID?
    let leftoverSourceLabel: String?          // "Mon dinner"
    let ingredients: [ArchivedIngredientLine] // empty for leftovers
}

struct ArchivedShoppingList: Codable, Equatable, Sendable {
    let sections: [ShoppingListSection]
    let statuses: [String: CheckStatus]
}

enum ArchiveCoding {
    static func encode<T: Encodable>(_ value: T) throws -> String   // JSONEncoder, .sortedKeys
    static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T
}
```

Test: round-trip an `ArchivedShoppingList` that has every `CheckStatus` case.

### 7.9 `ShoppingListExporter`

```swift
struct ExportOptions: Equatable, Sendable {
    var includeChecked = false
    var includeMealPlan = true
}

struct ExportMeal: Equatable, Sendable {
    let name: String
    let isLeftovers: Bool
}

struct ExportDay: Equatable, Sendable {
    let dayIndex: Int
    let meals: [ExportMeal]                           // B/L/D order
}

enum ShoppingListExporter {
    static func text(weekCommencing: String,
                     sections: [ShoppingListSection],
                     statuses: [String: CheckStatus],
                     mealPlan: [ExportDay],
                     options: ExportOptions) -> String
    static func hasExportableItems(sections: [ShoppingListSection],
                                   statuses: [String: CheckStatus],
                                   options: ExportOptions) -> Bool
}
```

**Format.** WhatsApp shows `*text*` as bold; it reads fine as plain text too. This example has `includeChecked = true`, Salt ticked, and Chicken `needsMore([.g: 200])`:

```
*Shopping list · w/c 14 Sep*

*Fruit & Veg*
• Garlic – 2 cloves
• Onion – 3

*Meat & Fish*
• Chicken breast – 200 g more

*Food Cupboard*
• Olive oil
✓ Salt

*Household*
• Toilet roll – 1 pack

*Meals*
Mon: Overnight oats, Chicken fajitas
Tue: Chicken fajitas (leftovers)
```

**Rules**

- The title, a blank line, then each non-empty section (`*Name*` + lines), with a blank line between sections.
- `.unchecked` → `• Name – <full amount>`.
- `.needsMore(x)` → `• Name – <x> more`.
- `.checked` → left out, unless `includeChecked`, in which case `✓ Name – <full amount>`.
- If the amount is empty, drop the ` – ` part.
- The meal block appears only if `includeMealPlan` and at least one day has meals: a blank line, `*Meals*`, then `Mon: A, B (leftovers)`.
- No trailing newline.

Test the exact string above.

### 7.10 `WhatsAppLink`

```swift
enum WhatsAppLink {
    enum Phone: Equatable { case empty, valid(digits: String), invalid }
    static func normalizePhone(_ input: String) -> Phone
    static func url(text: String, phoneDigits: String?) -> URL?
    // "https://wa.me/?text=<enc>" or "https://wa.me/<digits>?text=<enc>"
}
```

- **Phone:** remove spaces, `-`, `(`, `)` and `.`, then a leading `+` or `00`. The result must be 8–15 digits and must not start with `0`. Empty input → `.empty`.
- **Encoding:** percent-encode everything except the unreserved characters `A–Z a–z 0–9 - . _ ~` (UTF-8).

| Test | Expected |
|------|----------|
| `normalizePhone("+44 7700 900123")` | `.valid("447700900123")` |
| `normalizePhone("0044 (7700) 900-123")` | `.valid("447700900123")` |
| `normalizePhone("07700 900123")` | `.invalid` (no country code) |
| `normalizePhone("")` | `.empty` |
| `url(text: "Hi & bye\n*List*", phoneDigits: nil)` | `https://wa.me/?text=Hi%20%26%20bye%0A%2AList%2A` |
| `url(text: "•", phoneDigits: "447700900123")` | `https://wa.me/447700900123?text=%E2%80%A2` |

---

## 8. Services

Every service is an `@MainActor struct` initialised with `context: ModelContext` and optional `now: Date = .now` and `calendar: Calendar = WeekMath.appCalendar` for tests. Mutating methods follow the three rules in §5.1.

```swift
enum AppError: LocalizedError, Equatable {
    case weekIsArchived
    case duplicateIngredientName(existingName: String)
    case ingredientInUse(mealCount: Int)
    case invalidName
    case imageProcessingFailed
}
```

### 8.1 `ArchiveService`

```swift
@MainActor struct ArchiveService {
    func archiveEndedWeeks() throws -> Int       // number of weeks archived
    func archivedSlot(_ slot: MealSlot) -> ArchivedSlot?
    func archivedShoppingList(_ plan: WeekPlan) -> ArchivedShoppingList?
}
```

`archiveEndedWeeks`:
1. Fetch `WeekPlan`s where `isArchived == false`. Keep those where `WeekMath.isEnded(weekID, now:)`.
2. For each plan and each slot: build an `ArchivedSlot` from the **live** meal and ingredients (if `meal` is nil, delete the slot). For leftovers, use the source label and leave `ingredients` empty.
3. Build the shopping list (`WeekPlanService.shoppingLines` → `ShoppingListBuilder.build` → statuses) and store it as `ArchivedShoppingList`.
4. Set `isArchived = true` and `archivedAt = now`, then `save()`.

**Where it's called:** at launch; whenever `scenePhase` becomes `.active`; at the start of every mutating method in every service; and in `.task(id: weekID)` on the Plan and Shopping screens when the shown week is ended but not yet archived. That covers the app being left open past midnight on Sunday.

**Tests:** edit a meal after its week is archived → the archived snapshot is unchanged. Delete a meal → the archived slot still shows its name. Rename an ingredient → the archived list is unchanged. `assign` on an ended week throws `.weekIsArchived`. Archiving is idempotent.

### 8.2 `WeekPlanService`

```swift
@MainActor struct WeekPlanService {
    // Reading
    func plan(for weekID: String) throws -> WeekPlan?
    func fetchOrCreatePlan(for weekID: String) throws -> WeekPlan
    func isReadOnly(_ weekID: String) -> Bool                          // WeekMath.isEnded
    func mealIDs(inWeek weekID: String) throws -> Set<UUID>            // live slots or archived snapshots
    func occurrences(around weekID: String) throws -> [PlanOccurrence] // this week + previous week

    // Slots
    func assign(_ meal: Meal, at position: PlanPosition, leftoversOf sourceSlotID: UUID? = nil) throws
    func clearSlot(at position: PlanPosition, dependents: DependentLeftoversAction) throws
    func dependentLeftovers(of position: PlanPosition) throws -> [MealSlot]
    func clearWeek(_ weekID: String) throws
    func copyWeek(from source: String, to target: String, mode: RandomizeMode) throws -> CopyResult
}

enum DependentLeftoversAction { case remove, keepAsCooked }
struct CopyResult { let copied: Int; let skippedDeletedMeals: Int }
```

- If `assign` or `clearSlot` would change or remove a **cooked** slot's meal while leftovers depend on it: `.remove` deletes those leftover slots, and `.keepAsCooked` sets their `leftoverOfSlotID = nil`. The UI asks first (§10.3). `assign` of the *same* meal to the same slot (e.g. switching cooked ↔ leftovers) does not affect dependents.
- `copyWeek` reads the source from snapshots if it's archived, and skips meals that no longer exist. Leftover links are remapped when the source slot is copied too; otherwise the copy becomes cooked. `.fillEmpty` only fills empty target slots; `.replaceAll` clears target slots first (and removes their dependents). Tick states and hand-added items are not copied.

**`WeekPlanService+Leftovers.swift`**

```swift
extension WeekPlanService {
    func leftoverSourceCandidates(mealID: UUID, target: PlanPosition) throws -> [PlanOccurrence]  // [] if the meal isn't goodAsLeftovers
    func markAsLeftovers(at position: PlanPosition) throws   // uses nearest candidate; no-op if none
    func markAsCooked(at position: PlanPosition) throws
    func addLeftovers(from source: PlanPosition, to target: PlanPosition) throws  // target must be empty & editable; no-op if the meal isn't goodAsLeftovers
    func sourceLabel(for slot: MealSlot) throws -> String?   // "Mon dinner"
}
```

- **Turning "Good as Leftovers" off doesn't change existing plans.** Slots already marked as leftovers of that meal stay leftovers, and still offer "Mark as Cooked". Only *new* prompts and actions are suppressed.
- The randomiser never creates leftovers, so the flag doesn't affect it. `copyWeek` copies leftover links as it always has.

**`WeekPlanService+Randomize.swift`**

```swift
extension WeekPlanService {
    func randomize(weekID: String, slots: [SlotKey], mode: RandomizeMode) throws -> RandomizeOutcome
}
struct RandomizeOutcome { let assigned: Int; let skippedTypes: Set<MealType>; let removedLeftovers: Int }
```

1. Load all meals → `candidates` by `suits(type)`, sorted by name.
2. `excludedMealIDs = mealIDs(inWeek: weekID − 1)`.
3. For `.replaceAll`: find leftover slots (anywhere) that depend on target slots which are **cooked**, and delete them. Count them in `removedLeftovers`. For target slots that are themselves leftovers of a meal **outside** the targets, add them to `lockedSlots`.
4. For `.fillEmpty`: every leftover slot is filled, so it's skipped naturally.
5. Build `current`, call `MealRandomizer.randomize` with `SystemRandomNumberGenerator`, apply with `assign` (cooked), and `save()` once.

**`WeekPlanService+Shopping.swift`**

```swift
extension WeekPlanService {
    func shoppingLines(for plan: WeekPlan) -> [ShoppingLine]               // §7.4 input order
    func statuses(for plan: WeekPlan, sections: [ShoppingListSection]) -> [String: CheckStatus]
    func setChecked(_ checked: Bool, item: ShoppingListItem, weekID: String) throws
    func uncheckAll(weekID: String) throws
    func upsertManualItem(ingredient: Ingredient, quantity: Double?, unit: IngredientUnit, weekID: String) throws
    func removeManualItem(ingredientID: UUID, weekID: String) throws
    func manualItem(ingredientID: UUID, weekID: String) throws -> ManualShoppingItem?
    func markShared(weekID: String, signature: String) throws               // no-op on archived weeks
}
```

### 8.3 `MealStore`

```swift
@MainActor struct MealStore {
    func create(from draft: MealDraft) throws -> Meal
    func update(_ meal: Meal, from draft: MealDraft) throws   // replaces recipe lines + steps; sets photo; updatedAt
    func duplicate(_ meal: Meal) throws -> Meal               // "<name> (copy)", same photo and goodAsLeftovers, not favourite
    func toggleFavorite(_ meal: Meal) throws
    func delete(_ meal: Meal) throws                          // §6.6 rules
    func upcomingPlanCount(for meal: Meal) -> Int             // slots in non-archived weeks
    func addSampleMeals() throws -> Int                       // Appendix A; skips existing meal names
}
```

### 8.4 `IngredientStore`

```swift
@MainActor struct IngredientStore {
    func all() throws -> [Ingredient]                                      // sorted by name
    func search(_ text: String) throws -> [Ingredient]                    // key contains text; prefix matches first, then A–Z
    func find(named name: String) throws -> Ingredient?                   // by NameNormalizer.key
    func create(name: String, defaultUnit: IngredientUnit, category: ShoppingCategory) throws -> Ingredient
    func update(_ ingredient: Ingredient, name: String, defaultUnit: IngredientUnit, category: ShoppingCategory) throws
    func delete(_ ingredient: Ingredient) throws                          // throws .ingredientInUse if any recipe uses it
    func merge(_ source: Ingredient, into target: Ingredient) throws
    func findOrCreate(name: String, defaultUnit: IngredientUnit, category: ShoppingCategory) throws -> Ingredient
}
```

- `create`/`update`: the name is stored as `NameNormalizer.clean`. It must not be empty (`.invalidName`), and no *other* ingredient may have the same `key` (`.duplicateIngredientName`).
- `merge(A into B)`: archive first. Move every `RecipeIngredient` from A to B. For each non-archived week with a manual item for A: if B also has one, add A's quantity when the base units match (otherwise keep B's), then delete A's; if not, repoint A's item to B. Delete `ShoppingItemState`s keyed to A in non-archived weeks. Delete A.

**Tests:** duplicate name (different case or spacing) throws; deleting an ingredient that's in use throws; merge moves recipe lines and combines manual items; search ranks prefix matches first.

### 8.5 `ImageProcessor`

```swift
struct PreparedPhoto: Sendable { let photo: Data; let thumbnail: Data }

enum ImageProcessor {
    @concurrent nonisolated static func prepare(_ data: Data) async throws -> PreparedPhoto
}
```

- Decode with `UIImage(data:)` (throw `.imageProcessingFailed` if nil). Redraw with `UIGraphicsImageRenderer` (format `scale = 1`), which also fixes orientation.
- **Photo:** scale so the long edge is at most 1600 px, JPEG quality 0.8.
- **Thumbnail:** crop to a centred square, 300×300 px, JPEG quality 0.7.
- `@concurrent` runs this off the main actor. Never call it synchronously from a view body.

### 8.6 `NotificationScheduler` — see §11

```swift
protocol NotificationScheduling {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func scheduleWeeklyReminder(weekday: Int, hour: Int, minute: Int) async throws
    func cancelWeeklyReminder()
}
```

### 8.7 `ShareService` — see §12

---

## 9. App shell & navigation

### 9.1 Tabs

| Tab | Title | SF Symbol | Root |
|-----|-------|-----------|------|
| `.plan` | Plan | `calendar` | `WeekPlanView` |
| `.meals` | Meals | `fork.knife` | `MealLibraryView` |
| `.shopping` | Shopping | `cart` | `ShoppingListView` |
| `.settings` | Settings | `gearshape` | `SettingsView` |

- Each tab has its own `NavigationStack`.
- The **ingredient library** is reached from the Meals tab toolbar (a `carrot` button labelled "Ingredients") and from Settings → Library → Ingredients.
- The Shopping tab badge shows the count of `.unchecked` + `.needsMore` items for the selected week, only when the week isn't archived and the count is above 0.

### 9.2 `AppState`

```swift
@Observable final class AppState {
    enum AppTab: Hashable { case plan, meals, shopping, settings }
    var selectedTab: AppTab = .plan
    var selectedWeekID: String = WeekMath.weekID(for: .now, calendar: WeekMath.appCalendar)
}
```

- Plan and Shopping share `selectedWeekID`.
- `AppDelegate` (`@UIApplicationDelegateAdaptor`) owns `AppState` and is the `UNUserNotificationCenter` delegate.
- On `scenePhase == .active`: `archiveEndedWeeks()`, then re-sync the reminder (§11).

---

## 10. Screens

Wireframes show layout intent only. Use standard components.

### 10.1 Plan — `WeekPlanView`

```
┌───────────────────────────────────────┐
│ Plan                        🎲    ⋯   │  🎲 = RandomizeMenu
├───────────────────────────────────────┤
│  ‹     This week · 14–20 Sep     ›    │  WeekNavigator
│         12 of 21 meals planned        │
├───────────────────────────────────────┤
│ MONDAY 14 SEP · TODAY            🎲   │
│  🌅 Breakfast   Overnight oats     ›  │
│  ☀️ Lunch       Add lunch             │
│  🌙 Dinner      Spaghetti bolognese › │
│ TUESDAY 15 SEP                   🎲   │
│  🌅 Breakfast   Add breakfast         │
│  ☀️ Lunch       Spaghetti bolognese › │
│                 ↩ Leftovers · Mon dinner│
│  🌙 Dinner      Chicken fajitas     › │
└───────────────────────────────────────┘
```

**Layout**

- `List(.insetGrouped)` with 7 `DaySection`s, each holding 3 `MealSlotRow`s.
- Section header: weekday and date in upper case, plus " · TODAY" when it applies. The list always opens at Monday; there's no automatic scroll to today.
- `WeekNavigator` sits in a `safeAreaInset(edge: .top)` with `.bar` material. Chevrons move ±1 week, and tapping the title jumps to this week. The title is `WeekMath.title · dateRangeText`, with the subtitle "N of 21 meals planned" (leftovers count as planned).

**Read-only (ended) weeks**

- Show a banner under the navigator: 🔒 "This week has ended. It's kept as a record and can't be changed."
- Rows come from `ArchivedSlot` snapshots. No swipe actions, context menus or dice buttons.
- Tapping a filled row → `ArchivedSlotDetailView`: meal name, leftovers label, and ingredients *as they were*. If the meal still exists, add a "View Current Recipe" button.
- Toolbar: the 🎲 menu is hidden. The ⋯ menu has only "Copy to This Week" (confirmation: Fill Empty Meals / Replace This Week).

**`MealSlotRow` (editable weeks)**

- Leading: meal type icon and name, secondary colour, fixed width. Trailing: meal name, or "Add lunch" in secondary colour.
- For leftovers, add a second line: `arrow.uturn.backward` "Leftovers · Mon dinner" (caption, secondary).
- **Tap** → `MealPickerSheet` (§10.2).
- **Swipe leading:** "Shuffle" (dice, accent) → re-roll **only this slot** (§10.1 Randomising).
- **Swipe trailing** (filled): "Remove" (destructive) → dependent-leftovers dialog if needed (§10.3) → `clearSlot`.
- **Context menu** (filled):
  - "View Recipe"
  - "Shuffle"
  - "Mark as Leftovers" (cooked, meal is Good as Leftovers, with a candidate) or "Mark as Cooked" (leftovers, always shown)
  - "Leftovers for Tomorrow's Lunch" and "Leftovers for Tomorrow's Dinner" (cooked only, **meal is Good as Leftovers**, shown when that slot is empty and editable; Sunday → next week's Monday)
  - "Remove"
- VoiceOver: "Tuesday lunch, Spaghetti bolognese, leftovers from Monday dinner".

**Randomising**

| Control | Targets | Behaviour |
|---------|---------|-----------|
| Toolbar 🎲 `RandomizeMenu` → **Randomise Whole Week** | all 21 slots | see below |
| 🎲 → **Randomise Breakfasts / Lunches / Dinners** | that type × 7 days | see below |
| Section header 🎲 **Randomise <Day>** | that day's 3 slots | see below |
| Row **Shuffle** (swipe, context menu, or the picker's Shuffle button) | that one slot | `.replaceAll` straight away (dependent-leftovers dialog first if needed) |

- If none of the targets are filled → run `.fillEmpty` straight away.
- Otherwise → `confirmationDialog` titled e.g. "Randomise Dinners", with buttons **Fill Empty Dinners**, **Replace All Dinners** and **Cancel**. The message is always "Meals planned last week won't be picked." Add " Leftovers linked to replaced meals will be removed." when that applies.
- **Typical flow (acceptance):** Randomise Dinners → the user dislikes Tuesday → swipes Tuesday dinner → Shuffle → only Tuesday dinner changes. The new meal isn't last week's, isn't the meal that was there, and isn't used elsewhere this week when there are enough meals.
- After running, give a success haptic. If `skippedTypes` isn't empty, show the alert "Not enough dinners to choose from. Meals from last week are left out — add more dinners or pick one yourself." (list the types). If `assigned == 0` and nothing was skipped: "Nothing to randomise — those meals are already planned."

**Toolbar ⋯ menu (editable weeks)**

- **"Copy Last Week"**: if last week is empty, show an alert. If this week is empty, copy straight away. Otherwise ask Fill Empty / Replace This Week. Report skipped deleted meals: "2 meals couldn't be copied because they've been deleted."
- **"Clear Week"**: destructive, with confirmation.

### 10.2 `MealPickerSheet`

- A `NavigationStack` titled e.g. "Tuesday Dinner", at the large detent.
- Top section: **Shuffle** button ("Pick a Random Dinner", dice icon) → same as row Shuffle, then dismiss.
- `.searchable`. Meals that suit the type, favourites first then A–Z. A `Toggle("Show All Meals")` turns off the type filter.
- Rows: `MealThumbnail` (40 pt), name, the current meal checkmarked, and the caption "Had last week" for meals in the previous week.
- **Tap a meal** → if `leftoverSourceCandidates` isn't empty → leftovers prompt (§10.3). Otherwise assign it as cooked. If the slot was a cooked slot with dependents and the meal changed → dependent-leftovers dialog. Then dismiss.
- Toolbar: Cancel, and "＋" New Meal (editor preset to this type; after saving, run the same assign flow).
- If the slot is filled: a destructive "Remove from Plan" button at the bottom.
- Empty state: `ContentUnavailableView` "No dinner meals" with a **New Meal** button.

### 10.3 Leftovers prompts (shared)

**A. "Leftovers or cook again?"** Shown when assigning meal M to a slot that has source candidates (from the picker, Add to Plan, or New Meal → assign). **Never shown for a meal with "Good as Leftovers" switched off**, because it has no candidates (§7.7); it's assigned as cooked straight away (after dialog B if needed).
- `confirmationDialog` title: "Leftovers or cook again?"
- Message: "Spaghetti bolognese is planned for Mon dinner. Leftovers won't add anything to your shopping list."
- Buttons: **"Leftovers from Mon Dinner"** (nearest candidate), **"Cook Again"**, **Cancel**.

**B. Dependent leftovers** (`DependentLeftoversDialog`). Shown when removing, shuffling or changing the meal of a cooked slot that has leftovers depending on it:
- Title: "Monday dinner has leftovers planned"
- Message: "Tuesday lunch is leftovers from this meal."
- Buttons: **"Remove Leftovers Too"** (destructive) → `.remove`; **"Keep as Cooked Meal"** → `.keepAsCooked`; **Cancel**.

The randomiser never shows prompt A. Randomised meals are always cooked.

### 10.4 Meals tab — `MealLibraryView`

```
┌───────────────────────────────────────┐
│ Meals                    🥕   ↕︎    +  │  Ingredients · Sort · New
│ 🔍 Search meals or ingredients        │
│ [ All | Breakfast | Lunch | Dinner ]  │
├───────────────────────────────────────┤
│ [img] Chicken fajitas              ★  │
│       Dinner · 6 ingredients · 30 min │
│ [img] Overnight oats                  │
│       Breakfast · 5 ingredients · 5 min│
└───────────────────────────────────────┘
```

- `@Query` meals, then filter in memory. `.searchable` matches the meal name or any library ingredient name in the recipe.
- Segmented type filter. Sort menu (`@AppStorage("mealSort")`): A–Z, Recently Added, Favourites First.
- `MealRow`: `MealThumbnail` (56 pt, rounded 10; placeholder `fork.knife` on `.secondarySystemFill`), name + star, subtitle "Types · N ingredients · time".
- Tap → `MealDetailView`. Swipe leading → Favourite. Swipe trailing → Delete (confirmation, §10.5).
- `🥕` pushes `IngredientLibraryView`. `+` opens `MealEditorView` as a sheet.
- Empty state: "No meals yet" with **Add Meal** and **Add Example Meals** buttons. No search results: `ContentUnavailableView.search`.

### 10.5 `MealDetailView`

```
┌───────────────────────────────────────┐
│ ‹ Meals                  ☆   Edit  ⋯  │
│ ┌───────────────────────────────────┐ │
│ │          [ meal photo ]           │ │  full-width, 240 pt, aspect fill (if photo)
│ └───────────────────────────────────┘ │
│ Chicken fajitas                       │
│ [Dinner]  Serves 4 · 30 min           │
│ [ Add to Plan ]                       │
│ INGREDIENTS                           │
│ Chicken breast               400 g    │
│   sliced                              │
│ METHOD                                │
│ 1  Slice the chicken and peppers.     │
│ NOTES                                 │
└───────────────────────────────────────┘
```

- The photo row uses `listRowInsets(EdgeInsets())` and is hidden when there's no photo.
- Ingredient rows show `ingredient.name`, the note as a caption, and `QuantityFormatter.format(quantity, unit)`.
- Toolbar: star, Edit (sheet), ⋯ → Add to Plan, Duplicate, Delete.
- **Delete confirmation:** "Delete "<name>"?". Message: "It's planned N times in this and upcoming weeks and will be removed from those plans. Past weeks won't change. This can't be undone." Leave out the first sentence when N = 0.

### 10.6 `MealEditorView` + `MealDraft`

A sheet with its own `NavigationStack`, used for both create and edit. It **edits a `MealDraft` value**, never the model.

```swift
struct MealDraft: Equatable {
    var name = ""
    var mealTypes: Set<MealType> = [.dinner]
    var servings = 2
    var totalMinutes: Int? = nil
    var notes = ""
    var photo: Data? = nil
    var thumbnail: Data? = nil
    var lines: [RecipeLineDraft] = []
    var steps: [StepDraft] = []
    init(); init(meal: Meal)
    var goodAsLeftovers = true
    var isValid: Bool                  // clean name non-empty && mealTypes non-empty
    func normalized() -> MealDraft
}
struct RecipeLineDraft: Identifiable, Equatable {
    let id: UUID
    var ingredientID: UUID
    var ingredientName: String         // display cache
    var quantity: Double?
    var unit: IngredientUnit
    var note: String
}
struct StepDraft: Identifiable, Equatable { let id: UUID; var text: String }
```

**Form sections**

1. **Photo (`MealEditorPhotoSection`).**
   - With a photo: the image (200 pt tall, aspect fill, rounded 12) and a `Menu("Change Photo")`.
   - Without a photo: a large tappable placeholder, `camera` icon + "Add Photo", which opens the same menu.
   - Menu items: **Take Photo** (only if `UIImagePickerController.isSourceTypeAvailable(.camera)`) → `CameraPicker` in `.fullScreenCover`; **Choose from Library** → `PhotosPicker(selection:, matching: .images)`; **Remove Photo** (destructive, only when a photo is set).
   - After picking: show a `ProgressView` overlay, run `ImageProcessor.prepare`, then set `draft.photo` and `draft.thumbnail`. On failure, alert "That photo couldn't be used. Please try another."
   - Camera permission: if `AVCaptureDevice.authorizationStatus(for: .video) == .denied`, alert "Camera access is off" with **Open Settings**.
2. **Details:** Name (autofocus on create), `Stepper` "Serves N" (1…12), Time `Picker` (Not set, 5, 10, 15, 20, 25, 30, 40, 45, 60, 75, 90, 120, 150, 180).
3. **Suitable For:** 3 toggles, with a red footer "Choose at least one." when none are on. Below them, in the same section, `Toggle("Good as Leftovers")` with the icon `arrow.uturn.backward`. Footer: "When on, planning this meal again within 3 days asks if it's leftovers." When the "Choose at least one." error is showing, show that first, then the leftovers footer.
4. **Ingredients:** rows show name, note caption and amount. Tap → `RecipeIngredientForm` (edit). Swipe to delete, `.onMove` to reorder. "＋ Add Ingredient" → §10.7 flow.
5. **Method:** numbered `TextField(axis: .vertical)` rows, delete and reorder, "＋ Add Step".
6. **Notes:** `TextField(axis: .vertical)`, `lineLimit(3...8)`.

**Toolbar:** Cancel / Save (disabled unless valid). If Cancel is tapped with changes → "Discard Changes?" dialog. Set `.interactiveDismissDisabled(hasChanges)`.

### 10.7 Adding ingredients to a recipe

This is one sheet containing a `NavigationStack`:

**Step 1 — `IngredientPickerSheet`** (shared with §10.11 and merge):
- `.searchable` (search is active on appear). Results come from `IngredientStore.search`, each row showing name + aisle caption.
- If the search text isn't empty and there's **no exact key match**, the first row is **"＋ Create "Chorizo""** → pushes `NewIngredientForm` (name prefilled, Default Unit picker, Aisle picker, "Create" button). It creates the ingredient immediately and continues to step 2.
- An empty library shows: "Your ingredient library is empty. Type a name to create one."
- `onSelect: (Ingredient) -> Void`.

**Step 2 — `RecipeIngredientForm`** (pushed):
- Header: ingredient name + aisle, with a "Change" button that goes back to step 1.
- **Amount:** `TextField` with `.numbersAndPunctuation`, parsed by `QuantityParser`. Invalid input shows the red footer "Enter a number like 2, 1.5 or 1/2" and disables saving.
- **Unit:** `Picker(.menu)`, preset to `ingredient.defaultUnit`.
- **Note:** optional, with the placeholder "e.g. finely chopped".
- Buttons: **Add** (adds the line and closes the sheet) and **Add & Next** (adds the line and returns to step 1 with the search cleared).
- In edit mode: **Done** only.

Ingredients created here stay in the library even if the meal is cancelled. That's intended.

### 10.8 `AddToPlanSheet`

- Opened from `MealDetailView`. Medium and large detents.
- Week: segmented "This Week" / "Next Week". Day list shows "Mon 14 Sep" with what's already planned for that meal type as a caption. Meal type: segmented, limited to the meal's types (hidden if there's only one).
- The caption "Replaces <meal>" appears when the slot is taken.
- **Add** → leftovers prompt (§10.3 A) if there are candidates → dependent-leftovers dialog if needed → `assign` → success haptic → dismiss.

### 10.9 Ingredient library — `IngredientLibraryView` / `IngredientDetailView`

**`IngredientLibraryView`**
- `List` grouped into sections by aisle (in `ShoppingCategory` order). Rows: name, with the caption "Used in 3 meals" or "Not used in any meals".
- `.searchable`. Toolbar "＋" → `NewIngredientForm` sheet.
- Swipe trailing: Delete, only when not used in any meal (confirmation). If the ingredient is used, the swipe shows "Merge…" instead.
- Tap → `IngredientDetailView`.

**`IngredientDetailView`** (a `Form` backed by a local draft, with Save in the toolbar):
- **Details:** Name, Default Unit (`Picker`), Aisle (`Picker`).
  - Footer: "Changes apply to all recipes and to this week's and future shopping lists. Past weeks won't change."
  - Saving with a duplicate name → alert "An ingredient called "Onion" already exists." with buttons **Merge Into "Onion"** and **OK**.
- **Used In:** the meals that use it (tap → `MealDetailView`), or "Not used in any meals".
- **Actions:**
  - "Merge Into Another Ingredient…" → `IngredientPickerSheet` (without this ingredient and without the create row) → confirmation: "Merge "Onions" into "Onion"? Every recipe will use "Onion". This can't be undone." → `merge` → pop.
  - "Delete Ingredient" (destructive). Disabled when in use, with the footer "Used in N meals. Remove it from those meals or merge it into another ingredient first."

### 10.10 Shopping — `ShoppingListView`

```
┌───────────────────────────────────────┐
│ Shopping                 +   ⬆︎    ⋯  │  Add item · Share menu · More
├───────────────────────────────────────┤
│  ‹     This week · 14–20 Sep     ›    │
├───────────────────────────────────────┤
│ ⓘ Your list has changed since you     │  SharedChangedBanner (conditional)
│   shared it.            [Share Again] │
│ ▓▓▓▓▓▓▓░░░░░  8 of 23 ticked          │
├───────────────────────────────────────┤
│ FRUIT & VEG                           │
│ ○ Garlic                    5 cloves  │
│   Bolognese, Veggie chilli            │
│ ✓ ~~Onion~~                       3   │
│ MEAT & FISH                           │
│ ⚠ Chicken breast              350 g   │
│   Need 150 g more                     │
│   Fajitas, Caesar wrap                │
│ HOUSEHOLD                             │
│ ○ Toilet roll                  1 pack │
│   Added by you                        │
└───────────────────────────────────────┘
```

**Editable weeks — data flow:** plan → `shoppingLines` → `ShoppingListBuilder.build` → `statuses`, computed while rendering. It must update live when the plan changes, a recipe changes, or an ingredient is renamed or re-aisled in another tab.

**Ended weeks:** decode `ArchivedShoppingList`. Rows are **not tappable**, with no add, untick or manual actions. Banner: 🔒 "This is the list as it was when the week ended." Sharing is still allowed but doesn't call `markShared`.

**`ShoppingItemRow`**

- The row is a `Button`: `.unchecked`/`.needsMore` → tick; `.checked` → untick.
- Icons: `circle`; `checkmark.circle.fill` (accent); `exclamationmark.circle.fill` (orange).
- The name is struck through and secondary when checked.
- Captions: "Need <x> more" (orange, needsMore only), then `usedIn` joined with ", ", with "Added by you" appended when `hasManualEntry`.
- Trailing: `QuantityFormatter.format(amounts:)`, secondary, monospaced digits.
- **Context menu / swipe trailing** (only when `hasManualEntry`): "Edit Added Item…" → `AddShoppingItemSheet` in edit mode; "Remove Added Item" → `removeManualItem`.
- `.sensoryFeedback(.selection, trigger: status)`. Accessibility: label "Garlic, 5 cloves", value "ticked" / "not ticked" / "need 150 grams more".
- Rows don't move when ticked.

**Header:** a progress bar ("N of M ticked"; needsMore counts as not ticked), and `SharedChangedBanner` when `lastSharedSignature != nil && != signature(current)`.

**Toolbar**

- `+` → `AddShoppingItemSheet`.
- `square.and.arrow.up` menu (§12): Share List…, Send via WhatsApp, Send to <Name> on WhatsApp (if a contact is set), Save as Text File…, a divider, then the toggles "Include Ticked Items" and "Include Meal Plan" (`@AppStorage("export.includeChecked")` false, `@AppStorage("export.includeMealPlan")` true). Share actions are disabled when `hasExportableItems` is false.
- ⋯ → "Untick All" (confirmation).

**Empty states:** no slots and no hand-added items → "No meals planned" + **Go to Plan** + **Add Item**. Slots but no lines → "Nothing to buy".

### 10.11 `AddShoppingItemSheet`

- Step 1: `IngredientPickerSheet` (§10.7) → Step 2: a form with Amount (optional) + Unit (default from the ingredient).
- If this week already has a hand-added item for that ingredient, step 2 opens **pre-filled in edit mode** with the title "Edit Added Item".
- Buttons: **Add** / **Save** → `upsertManualItem`; in edit mode also **Remove** (destructive).
- Hand-added items merge with recipe amounts on the list (§7.4).

### 10.12 `SettingsView`

1. **Shopping Reminder** (§11): toggle, Day picker (Monday…Sunday → Calendar weekday 2…7, 1), Time `DatePicker`, and a footer showing the next reminder or the permission warning.
2. **WhatsApp (`WhatsAppContactSection`):**
   - `TextField("Name")` (`@AppStorage("whatsapp.contactName")`) and `TextField("Mobile number")` with `.phonePad` (`@AppStorage("whatsapp.contactPhone")`).
   - Footer: "Include the country code, e.g. +44 7700 900123. Your list will open straight in this person's WhatsApp chat. Saved only on this iPhone."
   - When `normalizePhone` is `.invalid`, show a red caption "Add the country code (e.g. +44) and check the number."
   - A **"Send Test Message"** button opens `WhatsAppLink.url(text: "Test from MealPlanner 👋", phoneDigits:)`.
3. **Library:** Ingredients (push `IngredientLibraryView`), "Add Example Meals" → alert "Added N example meals."
4. **About:** version and build.

---

## 11. Notifications

### 11.1 Storage

| `@AppStorage` key | Type | Default |
|-------------------|------|---------|
| `reminder.enabled` | Bool | `false` |
| `reminder.weekday` | Int (1 = Sunday … 7 = Saturday) | `1` |
| `reminder.minutes` | Int (minutes after midnight) | `1080` |

### 11.2 Scheduling

- Identifier `"weekly-shopping-reminder"`. Trigger: `UNCalendarNotificationTrigger(dateMatching: [weekday, hour, minute], repeats: true)`.
- Content: title "Time to plan your meals", body "Pick this week's meals and your shopping list will build itself.", default sound.
- Always remove the pending request with that identifier before adding a new one.

### 11.3 Flows

| Situation | Behaviour |
|-----------|-----------|
| Toggle on, `.notDetermined` | Request `[.alert, .sound, .badge]`. Granted → schedule. Denied → toggle off + alert "Notifications are off" with **Open Settings** / **OK**. |
| Toggle on, `.denied` | Same alert, toggle off. |
| Toggle on, authorised/provisional | Schedule. |
| Toggle off | Cancel. |
| Day or time changed while on | Reschedule. |
| App becomes active | If enabled: authorised → reschedule; denied → Settings footer warning (don't change the stored toggle). |

Footer: "Next reminder: Sunday 20 Sep at 18:00" (`Calendar.nextDate(after:matching:)`).

### 11.4 Delegate

- `willPresent` → `[.banner, .sound]`.
- `didReceive` (reminder) → `selectedTab = .plan`, and `selectedWeekID` = next week on Fri/Sat/Sun, otherwise this week.

---

## 12. Sharing, export & WhatsApp

### 12.1 How the WhatsApp link works

`https://wa.me/` is WhatsApp's official "click to chat" web link.

- **`https://wa.me/?text=<message>`** (no number): opens WhatsApp on this iPhone with the message pre-filled and asks the user to **choose a chat**. The user picks a chat and taps Send.
- **`https://wa.me/447700900123?text=<message>`** (number in international format, digits only): opens **that person's chat straight away** with the message pre-filled. The user just taps Send.
- iOS opens `wa.me` links in the WhatsApp app when it's installed. If it isn't installed, the link opens in Safari, which offers to install WhatsApp.
- **The person receiving it doesn't need MealPlanner and can be on Android.** They get an ordinary WhatsApp text message. Bold headings show as bold.
- **Limits** (by design for the MVP): the message is a **snapshot**. It doesn't update itself, and the person receiving it can't tick items in the app. When the plan changes after sharing, `SharedChangedBanner` prompts "Share Again". For live shared ticking, see §17.1–17.2.

### 12.2 Share menu actions

| Action | Implementation | On success |
|--------|----------------|------------|
| **Share List…** | `ShareService.present(items: [text])`: share sheet, with WhatsApp, Messages, Notes etc. available | `markShared` if `completed` |
| **Send via WhatsApp** | `openURL(WhatsAppLink.url(text:, phoneDigits: nil))` | `markShared` if `accepted` |
| **Send to <Name> on WhatsApp** (only if the saved phone is `.valid`) | `openURL(WhatsAppLink.url(text:, phoneDigits: digits))` | `markShared` if `accepted` |
| **Save as Text File…** | `ShareService.makeTextFile` → `present(items: [fileURL])` (named `"Shopping list <weekID>.txt"`). Can be saved to Files or sent as a WhatsApp document. | `markShared` if `completed` |

`markShared` is skipped for archived weeks.

### 12.3 `ShareService`

```swift
@MainActor enum ShareService {
    static func present(items: [Any], completion: @escaping (Bool) -> Void)   // UIActivityViewController from top-most VC
    static func makeTextFile(text: String, fileName: String) throws -> URL    // temporaryDirectory
}
```

To find the top-most view controller: take the key window of the foreground-active `UIWindowScene`, then walk `presentedViewController`. Use `completionWithItemsHandler`.

---

## 13. UX, accessibility & copy

### 13.1 Visual

- Accent colour: `AccentColor` light `#2E7D32`, dark `#66BB6A`.
- System backgrounds, list and form styles, SF Symbols. No custom bar backgrounds.
- System text styles only. Photos use `.scaledToFill()` + `.clipped()` and rounded corners (10–12 pt).
- Haptics: `.selection` when ticking; `.success` after randomise, add to plan or merge; `.warning` on destructive confirmations.

### 13.2 Accessibility (required)

- Every icon-only button has a label ("Randomise", "Previous week", "Next week", "Shuffle", "Ingredients", "Add item", "Share", "More").
- Photos: `accessibilityLabel("Photo of <meal name>")`. Placeholders are hidden from VoiceOver.
- Dynamic Type up to accessibility sizes. Amounts stack under names at accessibility sizes.
- Never use colour alone to show status. Tap targets are at least 44 pt. Test in light and dark mode.

### 13.3 Copy

- Title Case for buttons and menus. Sentence case for text and alerts. British spelling.
- Generic error alert: "Something went wrong. Please try again."
- `AppError.weekIsArchived` → "This week has ended and can't be changed."

---

## 14. Edge cases

| Case | Expected behaviour |
|------|--------------------|
| Meal with 0 ingredients ("Eat out") | Allowed. Adds nothing to the list. |
| Meal's types edited so it no longer suits a slot it's in | Stays planned. |
| "Onion" vs "Onions" in the library | Two separate ingredients. The library prevents exact duplicates (ignoring case and spacing) and offers **Merge**. |
| Rename an ingredient | Current and future lists show the new name straight away. Ticks are kept (keyed by ID). Past weeks are unchanged. |
| Same ingredient with different units | One row: "2 + 200 g". |
| Ticked item, then more is needed | "Need X more" (§7.5). |
| Hand-added item for an ingredient also in a recipe | Merged into one row. Caption includes "Added by you". |
| Meal planned again within 3 days | Prompt "Leftovers or cook again?", but only if the meal is Good as Leftovers. Otherwise it's cooked, with no prompt. |
| "Good as Leftovers" switched off for a meal that already has leftover slots | Those slots stay leftovers (and still show "Mark as Cooked"). No new leftover prompts or actions for that meal. |
| Meal planned again after 4+ days | No prompt. It's cooked. |
| Leftovers slot planned before its cooked meal | Not offered. The user can plan the cooked meal first, then use "Mark as Leftovers". |
| Removing, changing or shuffling a cooked meal with leftovers | Dialog: remove leftovers too / keep as cooked. |
| Randomise "Replace All" with linked leftovers | Leftovers of replaced meals are removed (the confirmation says so). Leftovers of meals outside the targets are kept and locked. |
| Randomise when every candidate was used last week | The slot stays empty, with an explanation alert. |
| Sunday dinner leftovers on Monday lunch | Supported across weeks. |
| App left open past Sunday midnight | The Plan/Shopping `.task` and the next mutation archive the week before any change. |
| Delete a meal that's in past and future weeks | Future and current slots removed. Past weeks still show it (snapshot). |
| Copy last week containing a deleted meal | Skipped, with a count shown. |
| Very large photo (48 MP) | Downscaled off the main thread. The UI shows a progress overlay. |
| No camera (Simulator) | "Take Photo" is hidden. |
| WhatsApp not installed | The `wa.me` link opens Safari. No crash, no special handling. |
| Invalid saved WhatsApp number | "Send to <Name>" is hidden. Settings shows the error. |
| Year boundary, week 53 / time zone change | Handled by `WeekMath` (week keys, not stored dates). |
| App killed right after an edit | Data kept (services `save()` immediately). |

---

## 15. Testing

### 15.1 Unit tests (Swift Testing, `MealPlannerTests/`)

Mark every suite `@MainActor`. Use `#expect` / `#require`, and `@Test(arguments:)` for tables.

| File | Covers |
|------|--------|
| `SeededRandomNumberGenerator.swift` | `SplitMix64` helper |
| `WeekMathTests` | §7.1 |
| `QuantityParserTests`, `QuantityFormatterTests` | §7.2 |
| `NameNormalizerTests` | §7.3 |
| `ShoppingListBuilderTests` | §7.4 (including the different-keys-same-name case) |
| `ShoppingCheckEvaluatorTests` | §7.5 (including the worked example as a sequence) |
| `MealRandomizerTests` | §7.6 (including the exclusion and single-slot re-roll cases) |
| `LeftoverRulesTests` | §7.7 |
| `ArchiveSnapshotsTests` | §7.8 round-trip |
| `ShoppingListExporterTests` | §7.9 exact string, options |
| `WhatsAppLinkTests` | §7.10 |
| `ArchiveServiceTests` | §8.1 tests (in-memory container, injected `now`) |
| `WeekPlanServiceTests` | assign replaces; clearSlot; dependents remove/keep; copyWeek fill/replace/remap leftovers/skip deleted; leftover slots add no shopping lines; manual items merge; setChecked stores amounts; randomize excludes the previous week and removes dependent leftovers on replace |
| `MealStoreTests` | create/update round-trip (including `goodAsLeftovers`); delete keeps archived snapshots; duplicate copies `goodAsLeftovers`; addSampleMeals is idempotent and sets `goodAsLeftovers` per Appendix A |
| `IngredientStoreTests` | §8.4 tests |

### 15.2 Manual QA checklist

- [ ] Fresh install → Add Example Meals → the library has 8 meals and 28 ingredients.
- [ ] Create a meal: take or choose a photo, add 3 ingredients (create one new, one amount written `1/2`), 2 steps → the detail view shows everything; the thumbnail appears in the list.
- [ ] Ingredient library: rename "Onion" → "Brown onion" → recipes and this week's list show the new name, and ticks are kept.
- [ ] Create "Onions" → merge into "Brown onion" → the recipes that used it now show "Brown onion".
- [ ] Plan Mon dinner Bolognese → plan Tue lunch Bolognese → choose Leftovers → the shopping list amounts don't change.
- [ ] Remove Mon dinner → the dialog appears → choosing "Keep as Cooked Meal" makes Tue lunch add its ingredients.
- [ ] Plan Scrambled eggs on toast for Mon breakfast and Wed breakfast → **no** leftovers prompt, and the eggs count twice.
- [ ] Randomise Dinners → no dinner is one of last week's meals → Shuffle Tuesday dinner → only Tuesday changes.
- [ ] Tick chicken → add another chicken meal → "Need X more" appears.
- [ ] Add "Toilet roll 1 pack" by hand → it's under Household with "Added by you", and it's included in the export.
- [ ] Send via WhatsApp to a real contact (ideally an Android phone) → the message is readable and bold headings show.
- [ ] Save a WhatsApp contact → "Send to <Name>" opens that chat directly.
- [ ] Change the plan after sharing → the banner appears → share again → the banner goes away.
- [ ] Set the device date forward a week (or use a test build flag) → last week is read-only; editing a meal doesn't change it.
- [ ] Force-quit and relaunch → everything is still there.
- [ ] Reminder set 2 minutes ahead → notification arrives → tapping it opens Plan.
- [ ] Dark mode and the largest text size look correct on every screen.

---

## 16. Implementation milestones

Do these **in order**, one per session. Each milestone ends with a clean build, all tests passing, acceptance criteria reported ✅/❌, and a git commit.

### M0 — Project setup (human)

§4.2. **Done when:** the template app runs in the Simulator, the camera usage string is set, `.gitignore` exists, and there's an initial commit.

### M1 — Models & domain foundations

**Read:** §5, §6, §7.1, §7.2, §7.3, §7.10, §15.1.
**Build:** all `Models/`, `SchemaV1`, `WeekMath`, `QuantityParser`, `QuantityFormatter`, `NameNormalizer`, `WhatsAppLink`, `AppError`, and their tests.
- [ ] Every §6.1 rule is followed.
- [ ] An in-memory container can save and fetch a `Meal` → `RecipeIngredient` → `Ingredient` chain.
- [ ] Every table row in §7.1, §7.2, §7.3 and §7.10 has a passing test.

### M2 — App shell, stores & sample data

**Read:** §5.2, §8.3 (create/update/addSampleMeals), §8.4, §9, Appendix A.
**Build:** `MealPlannerApp`, `AppDelegate` (stub delegate), `AppState`, `RootTabView` (placeholder screens), `IngredientStore` (full), `MealStore` (create, update, duplicate, toggleFavorite, addSampleMeals; a simple `delete` for now), `SampleData`, `PreviewContainer`. Delete `ContentView.swift`.
- [ ] 4 tabs with the correct titles and icons. Data persists across launches.
- [ ] `IngredientStoreTests` pass. `addSampleMeals` adds 8 meals + 28 ingredients, and a second run adds 0.

### M3 — Ingredient library

**Read:** §10.7 (picker, new-ingredient form), §10.9, §13.
**Build:** `IngredientLibraryView`, `IngredientDetailView`, `IngredientPickerSheet`, `NewIngredientForm`. Link them from Settings (a temporary Settings screen is fine).
- [ ] Create, rename (duplicate alert → merge), change aisle or unit, delete unused, merge.
- [ ] The picker's "Create" row appears only when there's no exact match.

### M4 — Meals

**Read:** §8.3, §10.4, §10.5, §10.6 (no photo section), §10.7.
**Build:** `MealLibraryView`, `MealRow`, `MealThumbnail` (placeholder only), `MealDetailView`, `MealEditorView`, `MealDraft`, `RecipeIngredientForm`. Add the 🥕 toolbar link.
- [ ] Create, view, edit, duplicate, favourite and delete all work and persist.
- [ ] Add ingredients from the library or create them inline. "Add & Next" returns to the picker.
- [ ] Discard dialog on Cancel. Invalid amount is blocked.
- [ ] Search matches ingredient names.

### M5 — Meal photos

**Read:** §8.5, §10.4 (thumbnail), §10.5 (header), §10.6 (photo section).
**Build:** `ImageProcessor`, `CameraPicker`, `MealEditorPhotoSection`, thumbnail and header display.
- [ ] Choosing from the library works in the Simulator. Taking a photo works on a device.
- [ ] A saved photo is ≤ 1600 px on the long edge, and the thumbnail is 300×300 (test `ImageProcessor` with a generated 4000×3000 image).
- [ ] The UI stays responsive while processing.

### M6 — Weekly plan & archiving

**Read:** §6.6, §6.7, §7.8, §8.1 (slots only; the shopping snapshot comes in M9), §8.2 (reading, slots, copy), §10.1 (no randomise, no leftovers), §10.2, §10.8.
**Build:** `ArchiveService`, `WeekPlanService` core, `ArchiveSnapshots`, `WeekPlanView`, `WeekNavigator`, `DaySection`, `MealSlotRow`, `MealPickerSheet`, `AddToPlanSheet`, `ArchivedSlotDetailView`. Upgrade `MealStore.delete` to follow §6.6. Add archive-first calls to every mutating method in all stores.
- [ ] Plan, change and remove slots. Week navigation. Browsing empty weeks creates no plans.
- [ ] Ended weeks are read-only and show snapshots. Editing or deleting a meal doesn't change them (tested).
- [ ] Copy Last Week / Copy to This Week / Clear Week.

### M7 — Leftovers

**Read:** §7.7, §8.2 (leftovers, dependents), §10.1 (row and context menu), §10.3.
**Build:** `LeftoverRules` + tests, `WeekPlanService+Leftovers`, both prompts, the context menu actions, and leftover display. Update `copyWeek` remapping.
- [ ] The prompt appears within 3 days, including Sun → Mon across weeks.
- [ ] "Leftovers for Tomorrow's Lunch/Dinner" works.
- [ ] Both dependent-leftovers dialog options work.
- [ ] `LeftoverRulesTests` + related service tests pass.

### M7.1 — "Good as Leftovers" (added in v1.3)

Do this **after M7 (and its fixes) and before M8**.

**Read:** §3 (Leftovers row), §6.4 (`Meal.goodAsLeftovers`), §7.7 (the v1.3 note), §8.2 (`+Leftovers` and the bullets under it), §8.3 (`duplicate`), §10.1 (context menu), §10.3 A, §10.6 (Suitable For + `MealDraft`), §14, Appendix A.2.
**Build:**
- `Meal.goodAsLeftovers` (default `true`).
  - Add it to `SchemaV1` directly: the app hasn't been released, so no migration stage is needed.
  - If the existing Simulator store fails to open, delete the app from the Simulator.
  - Record this in `DECISIONS.md`.
- `MealDraft.goodAsLeftovers`, round-tripped by `MealStore.create/update/duplicate`.
- The editor toggle and footer.
- Service gating in `leftoverSourceCandidates` and `addLeftovers`, plus hiding the context menu leftover actions.
- `SampleData` values from Appendix A.2.
- [ ] Toggle off → planning the meal again within 3 days assigns it as cooked with no prompt (in the picker and Add to Plan). The dependent-leftovers dialog still appears when replacing a cooked meal that has leftovers.
- [ ] Toggle off → "Mark as Leftovers" and "Leftovers for Tomorrow's …" aren't offered for that meal. Existing leftover slots stay and still offer "Mark as Cooked".
- [ ] Service tests: `leftoverSourceCandidates` returns `[]` and `addLeftovers` is a no-op when the flag is off. `assignmentDecision` goes straight to `.readyToAssign`/`.needsDependentPrompt`.
- [ ] `MealStoreTests` cover create/update/duplicate and the sample data values.
- [ ] Manual: Scrambled eggs on toast (example meal) on Mon and Wed breakfast → no prompt.

### M8 — Randomiser

**Read:** §7.6, §8.2 (randomize), §10.1 (Randomising), §10.2 (Shuffle).
**Build:** `MealRandomizer` + tests, `WeekPlanService+Randomize`, `RandomizeMenu`, day 🎲, row Shuffle, the picker Shuffle button, and the "Had last week" caption.
- [ ] Every §7.6 test passes.
- [ ] Whole week, per meal type, per day and per slot all work in both modes. Last week's meals are never picked.
- [ ] The "Typical flow" in §10.1 works exactly as described.

### M9 — Shopping list & hand-added items

**Read:** §7.4, §7.5, §8.1 (shopping snapshot), §8.2 (shopping), §9.1 (badge), §10.10, §10.11.
**Build:** `ShoppingListBuilder`, `ShoppingCheckEvaluator` + tests, `WeekPlanService+Shopping`, `ShoppingListView`, `ShoppingItemRow`, `AddShoppingItemSheet`, the archived list display, the badge, Untick All. Extend `ArchiveService` to store `ArchivedShoppingList`.
- [ ] Live updates on plan, recipe and ingredient changes. Leftovers add nothing.
- [ ] Ticks persist. needsMore works. Hand-added items merge and can be edited or removed.
- [ ] Ended weeks show the frozen list.

### M10 — Export & WhatsApp

**Read:** §7.9, §12, §10.10 (share menu, banner), §10.12 (WhatsApp section).
**Build:** `ShoppingListExporter` + tests, `ShareService`, the share menu, `WhatsAppContactSection`, `SharedChangedBanner`.
- [ ] The exact-string exporter test passes.
- [ ] Share sheet, `.txt` export, WhatsApp chat picker, and a direct-to-contact link all work on a device.
- [ ] The banner logic works.

### M11 — Notifications & Settings

**Read:** §8.6, §9.2, §10.12, §11.
**Build:** `NotificationScheduler`, the full `SettingsView`, delegate behaviour, scene-phase re-sync.
- [ ] Every §11.3 flow works. The footer shows the correct next date. Tapping the notification opens the correct week.

### M12 — Polish & QA

**Read:** §13, §14, §15.2.
- [ ] Every §15.2 item passes. No warnings, no `print`, no force-unwraps outside tests (except §7.6).

---

## 17. Future roadmap

Not part of the MVP.

### 17.1 iCloud sync & sharing inside the app

The model follows CloudKit rules (§6.1) and photos use external storage (which syncs as CloudKit assets). Sync between the user's own Apple devices means turning on the iCloud capability and setting `cloudKitDatabase: .automatic`. Sharing with another **iPhone** user needs `CKShare`.

### 17.2 Android

- A SwiftUI app can't run on Android. Options: a Kotlin + Jetpack Compose app, or Kotlin Multiplatform for shared logic. §7 is written to be language-neutral so it can be ported.
- **Live shared lists between an iPhone and an Android phone** (both people ticking the same list) need a cross-platform backend such as Supabase or Firebase, because CloudKit is Apple-only. Until then, WhatsApp export (§12) is the way to share.

### 17.3 Tesco integration

> ⚠️ **Check feasibility first.** As far as we know, Tesco doesn't currently offer an open public grocery API for third-party developers (the old Tesco Labs developer API was retired). Prices, images, and especially adding items to a Tesco basket would probably need a commercial partnership. Unofficial approaches may break Tesco's terms of service.

If a data source becomes available:
- The ingredient library (§6.4) is the natural place to link products: add `productID: String?` to `Ingredient` in `SchemaV2`.
- Add a `ProductCatalog` protocol (search, price, image, pack size). `ShoppingListBuilder` output stays the same; a pricing layer adds a price to each `ShoppingListItem`.
- A running total needs pack sizes, to convert needed amounts into packs to buy.

### 17.4 Other ideas

Import recipe from URL (can reuse the §18 pipeline with page text instead of photos) · scale by servings · pantry staples · favourites weighting in the randomiser · configurable first day of the week · widget with today's meals · multiple photos per meal.

---

## 18. Post-MVP: Recipe photo import

> **POST-MVP. Do not build any of this until milestones M1–M12 are complete and the human asks for M13.** This section is written in advance so it's ready.
>
> Scope of M13–M15: **personal use** — the user pastes their own Anthropic API key into Settings. Publishing the feature to the public (a backend, subscriptions, quotas) is described in §18.11 as a design note only and is **not** part of M13–M15.

### 18.1 What it does

The user photographs a recipe (cookbook page, magazine, handwritten card, or a screenshot). The app sends the photo(s) to Claude, gets the recipe back as structured JSON, matches it to the ingredient library, and opens the normal meal editor pre-filled for review. **Nothing is saved until the user taps Save.**

```
Meals tab ＋ ▸ "Import from Photo"
   │
   ▼
RecipeImportView ── add 1–3 pages (camera / library) ── "Read Recipe"
   │
   ▼
ImageProcessor.prepareForUpload ─► ClaudeRecipeExtractor ─► RecipeExtraction (JSON)
   │                                        (HTTPS, ~10–40 s)
   ▼
RecipeImportMapper (pure) ── library snapshot ─► MealDraft + ImportReport
   │
   ▼
MealEditorView (review mode) ── user fixes anything flagged ── Save
   │
   ▼
MealStore.create ── creates any new ingredients ─► Meal saved
```

### 18.2 Decisions

| Topic | Decision |
|-------|----------|
| Extraction engine | **Claude API** (`claude-opus-5`), sent the photos directly, with **structured outputs** (`output_config.format` JSON schema), so the reply always parses. Behind a `RecipeExtracting` protocol so an on-device engine (e.g. Apple Vision + Foundation Models) can be added later. |
| Transport | Raw HTTPS with `URLSession` (there is no official Anthropic Swift SDK). **No third-party packages.** |
| API key (M13–M15) | Entered by the user in Settings, stored in the **Keychain**. Never hard-coded, never logged, never committed. |
| Unit handling | Claude picks a unit from a fixed list (our `IngredientUnit` cases plus a few imperial units and `other`). The app converts imperial units deterministically (§18.6) so conversions are testable. |
| Ingredient matching | The prompt includes the user's existing ingredient names so Claude reuses them. The app then matches deterministically (§18.7). Unmatched ingredients become **pending new ingredients**, created only on Save. |
| Review | Always shown. Flags draw attention to new ingredients, approximate matches, converted or unrecognised units, and warnings from Claude. |
| Privacy | A one-time consent sheet explains that photos are sent to Anthropic to read the recipe. |
| Pages | 1–3 photos per import, sent in one request, in order. |

### 18.3 Files

```
Domain/
  RecipeExtraction.swift        # Codable types mirroring the JSON schema (§18.5)
  RecipeExtractionSchema.swift  # the JSON schema as a static string/dictionary
  ImportUnitConverter.swift     # imperial → metric rules (§18.6)
  RecipeImportMapper.swift      # extraction + library snapshot → MealDraft + ImportReport (§18.7)
Services/
  RecipeExtracting.swift        # protocol
  ClaudeRecipeExtractor.swift   # URLSession implementation (§18.4)
  APIKeyStore.swift             # Keychain wrapper
  ImageProcessor.swift          # + prepareForUpload(_:) (§18.4)
Features/
  Import/
    RecipeImportView.swift      # page capture + "Read Recipe" + progress/errors (§18.9)
    ImportConsentSheet.swift
    ImportReviewBanner.swift    # shown at the top of MealEditorView in review mode
  Settings/
    RecipeImportSettingsSection.swift
MealPlannerTests/
  Fixtures/                     # canned API responses (§18.10)
```

**Changes to existing code**

- `RecipeLineDraft` (value type, **no SwiftData schema change**):
  ```swift
  struct PendingIngredient: Equatable { var name: String; var defaultUnit: IngredientUnit; var category: ShoppingCategory }

  struct RecipeLineDraft: Identifiable, Equatable {
      let id: UUID
      var ingredientID: UUID?               // nil ⇔ pendingIngredient != nil
      var pendingIngredient: PendingIngredient?
      var ingredientName: String            // display cache (library name or pending name)
      var quantity: Double?
      var unit: IngredientUnit
      var note: String
      var importFlags: Set<ImportFlag> = [] // §18.7; empty for manually added lines
      var originalText: String? = nil       // the line as printed, for review
  }
  ```
- `MealDraft` gains `var importWarnings: [String] = []` (not saved to the model).
- `MealDraft.isValid` additionally requires every line to have either `ingredientID` or a `pendingIngredient` with a non-empty clean name.
- `MealStore.create/update`: before building recipe lines, resolve each pending ingredient with `IngredientStore.findOrCreate(name:defaultUnit:category:)` (reuses an ingredient if one with the same name was added in the meantime). All of this happens in the same save.
- `RecipeIngredientForm` in `.edit` mode supports pending lines. The header shows "New ingredient", with an editable **Name** and **Aisle**, plus **"Use Existing Ingredient…"**, which opens `IngredientPickerSheet` and replaces the pending ingredient with the chosen library ingredient (clears `pendingIngredient` and the `.newIngredient`/`.approximateMatch` flags).
- `MealEditorView` gains an optional `importReport: ImportReport?`. When set: the title is "Review Recipe", `ImportReviewBanner` is shown at the top, rows show flag badges, and Cancel **always** asks "Discard Imported Recipe?".
- Meals tab `+` becomes a `Menu`: "New Meal" / "Import from Photo". The empty state gets a third button, "Import from Photo".
- Settings gains the "Recipe Import" section (§18.8).

### 18.4 API request

**Photos:** `ImageProcessor.prepareForUpload(_ data: Data) async throws -> Data` (`@concurrent nonisolated`) returns a JPEG with the long edge ≤ 1568 px, quality 0.8, orientation applied (same ImageIO approach as §8.5). Pages keep the order the user added them in.

**Endpoint and headers**

```
POST https://api.anthropic.com/v1/messages
content-type: application/json
x-api-key: <key from Keychain>
anthropic-version: 2023-06-01
anthropic-beta: server-side-fallback-2026-07-01
```

**Body** (built with `JSONSerialization` or `Encodable`; the schema is §18.5)

```json
{
  "model": "claude-opus-5",
  "max_tokens": 16000,
  "fallbacks": "default",
  "system": "<SYSTEM PROMPT below>",
  "output_config": {
    "format": { "type": "json_schema", "schema": { "...": "§18.5" } }
  },
  "messages": [{
    "role": "user",
    "content": [
      { "type": "image", "source": { "type": "base64", "media_type": "image/jpeg", "data": "<page 1>" } },
      { "type": "image", "source": { "type": "base64", "media_type": "image/jpeg", "data": "<page 2>" } },
      { "type": "text", "text": "<USER PROMPT below>" }
    ]
  }]
}
```

- `thinking` is omitted: Opus 5 uses adaptive thinking by default.
- `fallbacks: "default"` with the `server-side-fallback-2026-07-01` header means that if the model declines, the API automatically retries on Anthropic's recommended fallback model within the same call. Check `stop_reason` anyway (§18.4 response handling).
- `effort` is left at the default. M15 may set `output_config.effort` to `"medium"` **only if** the accuracy check (§18.12 M15) shows no loss in quality. Record the result in `DECISIONS.md`.
- `URLSessionConfiguration`: `timeoutIntervalForRequest = 120`. The request must be cancellable, because the user can tap Cancel.

**System prompt** (a constant in `ClaudeRecipeExtractor`):

```
You extract recipes from photos for a UK meal-planning app. Return only data that is
actually in the photos. If something isn't shown (servings, time), use null rather than
guessing. The photos may be several pages of one recipe, in order.
```

**User prompt** (built per request):

```
Extract the recipe in these photos.

Ingredients:
- One entry per ingredient. "Salt and pepper" is two entries.
- name: the generic ingredient only, singular or plural as usually shopped
  ("Chopped tomatoes", "Onion"). Put preparation and size in note ("finely chopped",
  "large"). If an ingredient matches one of the EXISTING INGREDIENTS below, use that
  exact name.
- quantity: a number in the chosen unit (½ → 0.5). For a range like "2–3" use the
  larger number and put "2–3" in note. null if no amount is given ("to taste").
- unit: choose from the allowed values. Use "item" for countable things with no unit
  ("2 onions"). For "1 x 400g tin chopped tomatoes" use quantity 1, unit "tin",
  note "400g". Use "other" only if nothing fits, and put the original unit in note.
- originalText: the ingredient line exactly as printed.
- aisle: your best guess from the allowed values.

steps: the method, one string per step, without step numbers.
warnings: short notes for the user about anything unclear, cut off or unreadable.
isRecipe: false if the photos don't contain a recipe.

EXISTING INGREDIENTS:
<one name per line, sorted A–Z, max 500>
```

**Response handling** (check in this order):

| Situation | Handling |
|-----------|----------|
| No network / `URLError.notConnectedToInternet` | `ImportError.offline` |
| User cancelled | `ImportError.cancelled` (no alert) |
| HTTP 401 / 403 | `ImportError.invalidAPIKey` |
| HTTP 429, 500, 529, or a timeout | Retry **once** after 2 s, then `ImportError.serviceBusy` |
| Other non-2xx | `ImportError.unexpected(statusCode)`. Log the status only, never the body or key. |
| `stop_reason == "refusal"` | `ImportError.declined` |
| `stop_reason == "max_tokens"` | `ImportError.tooLong` |
| `stop_reason == "end_turn"` | Take the **first `content` block with `type == "text"`** (ignore other block types, e.g. `fallback`) and decode it as `RecipeExtraction`. A decode failure → `ImportError.unreadableResponse`. |
| Decoded `isRecipe == false` | `ImportError.noRecipeFound` |

Every `ImportError` has user-facing copy (§18.9).

### 18.5 JSON schema (`RecipeExtractionSchema`)

Every object has `additionalProperties: false` and lists every property in `required` (nullable values use `anyOf` with `null`).

```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["isRecipe", "title", "servings", "totalMinutes", "mealTypes", "ingredients", "steps", "notes", "warnings"],
  "properties": {
    "isRecipe": { "type": "boolean" },
    "title": { "type": "string" },
    "servings": { "anyOf": [{ "type": "integer" }, { "type": "null" }] },
    "totalMinutes": { "anyOf": [{ "type": "integer" }, { "type": "null" }] },
    "mealTypes": {
      "type": "array",
      "items": { "type": "string", "enum": ["breakfast", "lunch", "dinner"] }
    },
    "ingredients": {
      "type": "array",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["name", "quantity", "unit", "note", "originalText", "aisle"],
        "properties": {
          "name": { "type": "string" },
          "quantity": { "anyOf": [{ "type": "number" }, { "type": "null" }] },
          "unit": {
            "type": "string",
            "enum": ["item", "g", "kg", "ml", "l", "tsp", "tbsp", "cup", "clove", "slice", "tin", "pack", "bunch", "handful", "pinch",
                     "oz", "lb", "fl_oz", "pint", "stick", "other"]
          },
          "note": { "type": "string" },
          "originalText": { "type": "string" },
          "aisle": {
            "type": "string",
            "enum": ["produce", "meatFish", "dairyEggs", "bakery", "pantry", "frozen", "drinks", "household", "other"]
          }
        }
      }
    },
    "steps": { "type": "array", "items": { "type": "string" } },
    "notes": { "type": "string" },
    "warnings": { "type": "array", "items": { "type": "string" } }
  }
}
```

Swift mirror (`RecipeExtraction.swift`): `struct RecipeExtraction: Codable, Equatable, Sendable` with nested `Ingredient` and `enum ExtractedUnit: String, Codable` (all 21 raw values above). Decoding must **fail** on an unknown enum value (no silent defaults), so it surfaces as `unreadableResponse`.

### 18.6 Unit conversion (`ImportUnitConverter`)

```swift
enum ImportUnitConverter {
    struct Result: Equatable { let quantity: Double?; let unit: IngredientUnit; let noteSuffix: String?; let flag: ImportFlag? }
    static func convert(quantity: Double?, unit: ExtractedUnit) -> Result
}
```

| Extracted unit | Result unit | Quantity rule | Note suffix | Flag |
|----------------|-------------|---------------|-------------|------|
| any of our 15 units | same | unchanged | — | — |
| `oz` | `g` | × 28.35, round to nearest 5 (min 5) | `"(8 oz)"` | `.unitConverted` |
| `lb` | `g` | × 453.6, round to nearest 5 | `"(1 lb)"` | `.unitConverted` |
| `fl_oz` | `ml` | × 28.41 (UK), round to nearest 5 | `"(10 fl oz)"` | `.unitConverted` |
| `pint` | `ml` | × 568, round to nearest 5 | `"(1 pint)"` | `.unitConverted` |
| `stick` | `g` | × 113, round to nearest 5 | `"(1 stick)"` | `.unitConverted` |
| `other` | `item` | unchanged | — (Claude already put the unit in `note`) | `.unitUnrecognised` |
| any unit with `quantity == nil` | as above | nil | none for conversions | none for conversions (`other` still flags) |

The note suffix uses `QuantityFormatter.number` for the original amount. It is appended to any existing note with a space.

**Tests:** 8 oz → 225 g; 1 lb → 455 g; 0.5 oz → 15 g; 10 fl oz → 285 ml; 1 pint → 570 ml; 1 stick → 115 g; `other` → item + flag; nil quantity for oz → nil, g, no suffix, no flag.

### 18.7 Mapping (`RecipeImportMapper`)

```swift
enum ImportFlag: String, Hashable, Sendable { case newIngredient, approximateMatch, unitConverted, unitUnrecognised, noQuantity }

struct LibraryEntry: Equatable, Sendable { let id: UUID; let name: String; let defaultUnit: IngredientUnit; let category: ShoppingCategory }

struct ImportReport: Equatable, Sendable {
    var newIngredientCount: Int
    var flaggedLineCount: Int
    var warnings: [String]          // Claude's warnings + mapper warnings, de-duplicated
}

enum RecipeImportMapper {
    static let timeOptions = [5, 10, 15, 20, 25, 30, 40, 45, 60, 75, 90, 120, 150, 180]   // same list as MealEditorView
    static func map(_ extraction: RecipeExtraction, library: [LibraryEntry]) -> (MealDraft, ImportReport)
}
```

**Rules**

1. **Title:** `NameNormalizer.clean(title)`. If empty → `"Imported recipe"` plus the warning "No title found — please add one."
2. **Meal types:** from `mealTypes`. If empty → `[.dinner]` plus the warning "Check which meals this suits."
3. **Servings:** clamp to 1…12. nil → 2.
4. **Time:** nil → nil. Otherwise snap to the **nearest** value in `timeOptions` (ties go to the larger value).
5. **Steps:** trim each step; strip a leading `^\s*(\d+[.)]|step\s*\d+[:.]?)\s*` (case-insensitive); drop empty steps.
6. **Notes:** `extraction.notes`, trimmed.
7. **Ingredients**, in the extracted order, for each one:
   1. Skip it if `NameNormalizer.clean(name)` is empty.
   2. Convert the unit (§18.6).
   3. **Match:**
      - (a) Exact: `NameNormalizer.key(name)` equals a library key → use that library entry.
      - (b) Approximate: compare `singularKey` of both, where `singularKey` removes a trailing `"es"` if the key ends in `"oes"`, `"ches"` or `"shes"`, otherwise a trailing `"s"` (not `"ss"`). A single match → use it and flag `.approximateMatch`. More than one match → treat as no match.
      - (c) No match → `pendingIngredient = PendingIngredient(name: clean(name), defaultUnit: convertedUnit, category: aisle)` and flag `.newIngredient`.
      - Two extracted lines that map to the **same pending name** (by key) share one pending ingredient, and `newIngredientCount` counts it once.
   4. `quantity == nil` → flag `.noQuantity`.
   5. `note` = the trimmed extracted note plus the conversion suffix. `originalText` is kept.
8. **Report:** `flaggedLineCount` = lines with any flag other than `.noQuantity`. Warnings = Claude's warnings (trimmed, non-empty, de-duplicated) followed by mapper warnings.
9. `photo`/`thumbnail` stay nil (a recipe page is not a photo of the cooked meal).

**Required tests** (a library of Onion, Chopped tomatoes, Garlic, Olive oil):

| Case | Expected |
|------|----------|
| "onion" | matched to Onion, no flag |
| "Onions" | matched to Onion, `.approximateMatch` |
| "Tomatoes", with "Tomato" and "Tomatoes (tinned)" added to the library | only one singular-key match → matched to Tomato, `.approximateMatch` |
| "Chorizo" twice | one pending ingredient, `newIngredientCount == 1`, both lines `.newIngredient` |
| "Salt", quantity nil | `.newIngredient` + `.noQuantity`; `flaggedLineCount` counts it (because of `.newIngredient`) |
| title "" | "Imported recipe" + warning |
| totalMinutes 35 / 50 / 200 | 40 / 45 / 180 |
| steps "1. Heat oil", "Step 2: Fry", "  " | "Heat oil", "Fry" |
| oz line | converted per §18.6 with `.unitConverted` |

### 18.8 Settings: "Recipe Import" section

- `SecureField("Anthropic API Key")`. On submit → `APIKeyStore.save`.
  - Keychain: `kSecClassGenericPassword`, service `"MealPlanner.AnthropicAPIKey"`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- Status row: "Not set" / "Saved" / "Checking…" / "Key works ✓" / "Key rejected".
- **"Test Key"** → `GET https://api.anthropic.com/v1/models?limit=1` with the same auth headers: 200 → works, 401/403 → rejected, other → "Couldn't check — try again".
- **"Remove Key"** (destructive, with confirmation).
- Footer: "Photos you import are sent to Anthropic to read the recipe. Your key is stored only on this iPhone. API usage is billed to your Anthropic account (roughly a few cents per recipe)."
- Never display the stored key. Show `sk-ant-…` plus the last 4 characters.

### 18.9 Screens & copy

**`RecipeImportView`** (sheet with its own `NavigationStack`, title "Import Recipe")

1. **If no API key is set:** a `ContentUnavailableView` "Add your API key" with the description "Recipe import uses Claude to read photos. Add your Anthropic API key in Settings." and the button **Open Settings** (switches to the Settings tab and dismisses).
2. **If consent hasn't been given** (`@AppStorage("import.consentGiven")`): present `ImportConsentSheet` first. Title "Before you import". Body "Your photos will be sent to Anthropic's Claude service to read the recipe. They aren't saved in the app." Buttons **Continue** (sets consent) and **Cancel**.
3. **Pages:** a horizontal row of up to 3 page thumbnails, each with a remove button and a "Page N" label.
   - Buttons: **Take Photo** (camera, one page) and **Choose from Library** (`PhotosPicker`, `maxSelectionCount` = remaining pages).
   - Tip text: "Lay the page flat, fit the whole recipe in, and use good light."
4. **"Read Recipe"** (prominent, disabled with 0 pages) → progress state: `ProgressView` with "Reading your recipe…" and the caption "This usually takes under a minute." plus a **Cancel** button.
5. **Success** → dismiss this sheet and present `MealEditorView(draft:importReport:)`.
6. **Error** → inline `ContentUnavailableView` with the copy below, plus **Try Again** (keeps pages) and **Close**.

| `ImportError` | Title | Message |
|---------------|-------|---------|
| `offline` | You're offline | Connect to the internet and try again. |
| `invalidAPIKey` | API key not accepted | Check your key in Settings. |
| `serviceBusy` | Service busy | Claude is busy right now. Try again in a minute. |
| `declined` | Couldn't read this recipe | Try a different photo. |
| `tooLong` | Recipe too long | Try importing fewer pages at a time. |
| `noRecipeFound` | No recipe found | Make sure the photo shows the ingredients and method. |
| `unreadableResponse`, `unexpected` | Something went wrong | Please try again. |

**Review mode** (`MealEditorView` with `importReport`)

- Title "Review Recipe". Save button "Save Meal".
- `ImportReviewBanner` (a section at the top of the form):
  - Headline: "Check everything before saving."
  - Lines (only when non-zero): "**N new ingredients** will be added to your library.", "**N items** need a quick check."
  - Then each warning as a bullet (secondary colour).
- Ingredient rows show badges after the name:
  - `.newIngredient` → green capsule "New"
  - `.approximateMatch`, `.unitConverted` or `.unitUnrecognised` → orange capsule "Check"
  - `.noQuantity` → no badge
  - Rows with a badge also show `originalText` as a caption: "Printed: 8 oz chorizo, sliced".
- Editing a flagged line (§18.3) and tapping **Done** clears its `.approximateMatch`/`.unitConverted`/`.unitUnrecognised` flags; the banner counts update live.
- Cancel → "Discard Imported Recipe?" with **Discard** (destructive) and **Keep Editing**.
- After saving: push the new meal's detail screen (same path mechanism as Duplicate).

### 18.10 Testing

- **No live API calls in unit tests.** `ClaudeRecipeExtractor` takes a `URLSession` that tests build with a `URLProtocol` stub that serves fixtures.
- **Fixtures** (`MealPlannerTests/Fixtures/`, JSON Messages API responses):
  - `extract-success.json`: two pages' worth of ingredients, including oz, "Salt and pepper", a range, and "1 x 400g tin"
  - `extract-refusal.json`: `stop_reason: "refusal"`
  - `extract-max-tokens.json`
  - `extract-not-a-recipe.json`: `isRecipe: false`
  - `extract-with-fallback-block.json`: a `fallback` block before the `text` block
  - `extract-bad-json.json`: the text block isn't valid JSON
- **`ClaudeRecipeExtractorTests`:** the request has the correct URL, the headers (including `anthropic-beta`), `model`, `fallbacks`, `output_config.format.type == "json_schema"`, image blocks in page order followed by the text block, and the existing ingredient names in the prompt. Every row of the §18.4 response table maps to the right result or error. Retry-once on 529 then `serviceBusy`. The API key never appears in logged output.
- **`ImportUnitConverterTests`**, **`RecipeImportMapperTests`**: every table in §18.6/§18.7.
- **`MealStoreTests`:** saving a draft with pending ingredients creates each one once, reuses an ingredient created in the meantime with the same name, and links the lines.
- **`APIKeyStoreTests`:** save / read / delete round-trip (Keychain works in the simulator test host).

### 18.11 Design note: public release (NOT part of M13–M15)

If the app is published with this as a paid feature, change the following. Each needs its own spec update first.

1. **Backend proxy.** The app must not hold an Anthropic key.
   - Add `ProxyRecipeExtractor: RecipeExtracting`, which sends pages to your own endpoint (e.g. a Cloudflare Worker). The endpoint holds the key, calls Claude with the same request as §18.4, and returns the `RecipeExtraction` JSON.
   - Remove the Settings API-key section.
2. **Subscription (StoreKit 2).** An auto-renewable subscription unlocks import.
   - The app sends the signed transaction (JWS from `Transaction.currentEntitlements`) with each request.
   - The backend verifies it (signature, or the App Store Server API) before calling Claude.
3. **Quotas enforced on the server**, keyed by the subscription's original transaction ID: e.g. 30 imports per calendar month, 3 pages per import, and a per-minute rate limit. The app shows the number remaining ("12 imports left this month"). A client-side counter is never trusted.
4. **Cost controls:** a monthly spend limit on the Anthropic account, logging `usage` tokens per request on the server, and alerts.
5. **Privacy:** an App Store privacy label (photos sent to a third party), consent before first use, a privacy policy that names Anthropic as a processor.

### 18.12 Milestones (post-MVP)

Same rules as §16: one per session, clean build, all tests passing, criteria reported ✅/❌, commit.

#### M13 — Extraction service

**Read:** §18.1–§18.6, §18.8, §18.10.
**Build:** `RecipeExtraction`, `RecipeExtractionSchema`, `ImportUnitConverter`, `RecipeExtracting`, `ClaudeRecipeExtractor`, `APIKeyStore`, `ImageProcessor.prepareForUpload`, the Settings "Recipe Import" section, fixtures and tests. A `#if DEBUG` "Test Import" button in Settings that picks a library photo and logs the decoded `RecipeExtraction` (title and ingredient count only).
- [ ] Every §18.4 response-table row is covered by a fixture test.
- [ ] Every §18.6 conversion test passes.
- [ ] The key is stored in the Keychain, masked in the UI, and "Test Key" works with a real key and fails with a fake one.
- [ ] Grepping the repo finds no key, and no key or response body is written to logs.
- [ ] The debug import of a real cookbook photo decodes successfully (manual, on a device or the Simulator with a real key).

#### M14 — Mapping & review

**Read:** §18.3, §18.7, §18.9 (review mode), §10.6, §10.7.
**Build:** `RecipeImportMapper` + tests, the `RecipeLineDraft`/`MealDraft` changes, pending-ingredient support in `RecipeIngredientForm` and `MealStore`, review mode in `MealEditorView`, `ImportReviewBanner`, and badges.
- [ ] Every §18.7 mapping test passes.
- [ ] Saving an imported draft creates new ingredients exactly once and never duplicates library ingredients.
- [ ] "Use Existing Ingredient…" replaces a pending ingredient and clears its flags.
- [ ] Cancelling an import creates **no** ingredients.
- [ ] Manually created meals behave exactly as before (existing tests still pass).

#### M15 — Capture flow, polish & accuracy check

**Read:** §18.9, §18.2, §13.
**Build:** the Meals `+` menu and empty-state entry, `ImportConsentSheet`, `RecipeImportView` (pages, progress, cancel, errors), and navigating to the saved meal. Remove the debug "Test Import" button.
- [ ] The full flow works on a real iPhone: 2-page cookbook recipe → review → fix one flagged line → save → meal detail.
- [ ] Cancel during reading stops the request. Airplane mode shows "You're offline".
- [ ] **Accuracy check:** import 10 real recipes (at least 4 printed cookbook pages, 2 magazine/printout, 2 handwritten cards, 2 website screenshots). For each, record in `DECISIONS.md` the title correct?, ingredients missed or extra, quantities wrong, and steps missing. Target: ≤ 1 error per recipe on printed sources.
- [ ] Optional effort tuning: repeat the accuracy check with `effort: "medium"`. Adopt it only if there's no loss in accuracy, and record the decision and average time taken.

---

## Appendix A — Sample data

Used by `MealStore.addSampleMeals()` (through `IngredientStore.findOrCreate`) and `PreviewContainer`.

### A.1 Ingredient library (28)

| Name | Default unit | Aisle |
|------|--------------|-------|
| Rolled oats | g | pantry |
| Milk | ml | dairyEggs |
| Greek yoghurt | tbsp | dairyEggs |
| Honey | tsp | pantry |
| Blueberries | handful | produce |
| Eggs | item | dairyEggs |
| Butter | g | dairyEggs |
| Bread | slice | bakery |
| Salt | pinch | pantry |
| Black pepper | pinch | pantry |
| Tortilla wraps | item | bakery |
| Chicken breast | g | meatFish |
| Romaine lettuce | item | produce |
| Parmesan | g | dairyEggs |
| Caesar dressing | tbsp | pantry |
| Onion | item | produce |
| Garlic | clove | produce |
| Chopped tomatoes | tin | pantry |
| Vegetable stock | ml | pantry |
| Olive oil | tbsp | pantry |
| Beef mince | g | meatFish |
| Spaghetti | g | pantry |
| Peppers | item | produce |
| Fajita seasoning | pack | pantry |
| Soured cream | ml | dairyEggs |
| Kidney beans | tin | pantry |
| Chilli powder | tsp | pantry |
| Rice | g | pantry |

### A.2 Meals (8)

Format: *name* (types, serves, minutes) → `ingredient | qty | unit | note` → steps.

**Good as Leftovers** (v1.3): **on** for Tomato soup, Spaghetti bolognese, Chicken fajitas and Veggie chilli. **Off** for Overnight oats, Scrambled eggs on toast, Chicken Caesar wrap and Eat out.

1. **Overnight oats** (breakfast, 1, 5)
   - Rolled oats | 50 | g
   - Milk | 150 | ml
   - Greek yoghurt | 2 | tbsp
   - Honey | 1 | tsp
   - Blueberries | 1 | handful
   - Steps: Mix the oats, milk, yoghurt and honey in a jar. · Cover and refrigerate overnight. · Top with blueberries before serving.
2. **Scrambled eggs on toast** (breakfast, 1, 10)
   - Eggs | 3 | item
   - Butter | 10 | g
   - Bread | 2 | slice
   - Salt | – | pinch
   - Black pepper | – | pinch
   - Steps: Whisk the eggs with a pinch of salt and pepper. · Melt the butter over a low heat. · Stir the eggs gently until just set. · Serve on hot buttered toast.
3. **Chicken Caesar wrap** (lunch, 2, 15)
   - Tortilla wraps | 2 | item
   - Chicken breast | 150 | g | cooked, sliced
   - Romaine lettuce | 1 | item
   - Parmesan | 20 | g | grated
   - Caesar dressing | 2 | tbsp
   - Steps: Toss the lettuce with the dressing. · Fill the wraps with lettuce, chicken and parmesan. · Roll up tightly and slice in half.
4. **Tomato soup** (lunch + dinner, 4, 30)
   - Onion | 1 | item | chopped
   - Garlic | 2 | clove
   - Chopped tomatoes | 2 | tin
   - Vegetable stock | 500 | ml
   - Olive oil | 1 | tbsp
   - Steps: Soften the onion and garlic in the oil for 5 minutes. · Add the tomatoes and stock and simmer for 15 minutes. · Blend until smooth and season to taste.
5. **Spaghetti bolognese** (dinner, 4, 45)
   - Beef mince | 500 | g
   - Onion | 1 | item | finely chopped
   - Garlic | 2 | clove
   - Chopped tomatoes | 1 | tin
   - Spaghetti | 300 | g
   - Olive oil | 1 | tbsp
   - Steps: Brown the mince in the oil. · Add the onion and garlic and cook for 5 minutes. · Add the tomatoes and simmer for 25 minutes. · Cook the spaghetti and serve with the sauce.
6. **Chicken fajitas** (dinner, 4, 30)
   - Chicken breast | 400 | g | sliced
   - Peppers | 2 | item | sliced
   - Onion | 1 | item | sliced
   - Fajita seasoning | 1 | pack
   - Tortilla wraps | 8 | item
   - Soured cream | 150 | ml
   - Steps: Coat the chicken and vegetables in the seasoning. · Fry over a high heat for 10–12 minutes. · Warm the wraps and serve with soured cream.
7. **Veggie chilli** (dinner, 4, 40)
   - Onion | 1 | item
   - Garlic | 3 | clove
   - Kidney beans | 2 | tin | drained
   - Chopped tomatoes | 1 | tin
   - Chilli powder | 2 | tsp
   - Rice | 250 | g
   - Steps: Soften the onion and garlic. · Add the chilli powder, beans and tomatoes and simmer for 25 minutes. · Serve with rice.
8. **Eat out** (lunch + dinner, 1, –) — no ingredients or steps. Notes: "Night off from cooking."

---

## Appendix B — Prompt templates

Paste into a fresh Claude Code session (Sonnet) at `dinner-app/`.

**Start a milestone**

```
Implement milestone M<N> from SPEC.md. Read CLAUDE.md and every SPEC section listed
under M<N> before writing code. Follow the folder structure and rules exactly.
When finished: build, run the tests, fix all errors and warnings, report each
acceptance criterion as ✅/❌ with a one-line note, log deviations in DECISIONS.md,
and commit. Do not start the next milestone.
```

**Fix a bug**

```
Bug in MealPlanner: <what I did> → <what happened> (expected: <what should happen>,
per SPEC §<section>). Find the root cause, fix it, add a unit test if the bug is in
Domain/ or Services/, build and test, then summarise the fix.
```

**Review before moving on**

```
Review milestone M<N> against SPEC.md: check §5.1 rules, §6.1 rules, archive-first
behaviour on every mutating service method, and the M<N> acceptance criteria.
List gaps, fix them, and re-run build + tests.
```
