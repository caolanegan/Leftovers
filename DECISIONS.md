# Decisions

Log of spec ambiguities and deviations, most recent first.

## 2026-09-14 — M3 fixes: navigation destinations and polish

- **All navigation is value-based, through `Shared/AppRoute.swift`.** Mixing a view-based `NavigationLink { Destination() }` (in `SettingsView`) with a value-based `.navigationDestination(for: Ingredient.self)` declared lower down (in `IngredientLibraryView`) caused SwiftUI to warn "A navigationDestination for MealPlanner.Ingredient was declared earlier on the stack" and silently do nothing on tap. Fixed by routing every push through a single `AppRoute` enum, with `.navigationDestination(for: AppRoute.self)` declared exactly once per tab, at the root, via the `.appRouteDestinations()` modifier. **No screen may declare its own `navigationDestination(for:)` — add new cases to `AppRoute` instead** (M4 will add `.meal(Meal)`).

## 2026-09-14 — M3: Ingredient library

- **"Used In" rows in `IngredientDetailView` aren't tappable yet.** §10.9 says tapping a used-in meal should push `MealDetailView`, but that screen doesn't exist until M4. Shown as plain, non-navigable text for now; M4 will wire up the navigation once `MealDetailView` exists.
- **Delete confirmation copy isn't specified.** §10.9 says swiping/tapping Delete needs "confirmation" but gives no exact wording (unlike the merge confirmation, which is quoted in full). Used `"Delete \"<name>\"? This can't be undone."` for both the library row's swipe-to-delete and the detail view's Delete Ingredient button, matching the tone of the specified merge copy.
- **`IngredientPickerSheet`'s create-row completion is simplified for M3.** §10.7 says creating a new ingredient from the picker's search "creates the ingredient immediately and continues to step 2" (`RecipeIngredientForm`), but that view doesn't exist until M4. For now, creating from the picker calls `onSelect` and dismisses the whole sheet; M4 will change the completion to push into the recipe-line form instead. Since none of M3's own flows (merge, which explicitly hides the create row per §10.9) exercise this path, coverage is via a unit test on the pure `IngredientPickerSheet.showsCreateRow` decision function rather than manual QA.
- **`SettingsView` is intentionally minimal.** M3 says "a temporary Settings screen is fine" — built only the "Library → Ingredients" link from §10.12 item 3. The Shopping Reminder, WhatsApp and About sections arrive in M11.

## 2026-09-14 — M2 fixes: test container lifetime and draft normalisation

- **Real cause of the M2 test crash: dangling `ModelContext`, not parallelism.** `IngredientStoreTests.makeStore()` and `MealStoreTests.makeContext()` created a local `ModelContainer`, handed out a store/context built on it, and let the container fall out of scope — a `ModelContext` doesn't retain its container, so once the container deallocated, the next fetch trapped inside SwiftData (`EXC_BREAKPOINT`/`SIGTRAP`). It looked parallelism-related because Swift Testing's concurrent scheduling changed which test's container got collected first, but the bug was present regardless. Fixed by storing the container as a `let` property built in each suite's `init() throws`, so it lives for the whole test's lifetime. No workaround (e.g. `-parallel-testing-enabled NO`, `.serialized`) needed or used.

## 2026-09-14 — M2: App shell, stores & sample data

- **Built `MealDraft` (and `RecipeLineDraft`/`StepDraft`) two milestones early.** §8.3 specifies `MealStore.create(from draft: MealDraft)` and `update(_:from:)` exactly, but `MealDraft` itself is formally introduced in M4 (§10.6) alongside the editor UI. Since M2 explicitly asks for a full `create`/`update`, and changing a service's signature later is worse than adding a small pure value type now, I added `Features/Meals/MealDraft.swift` early — data only, no UI, no view files. M4 will build `MealEditorView`/`RecipeIngredientForm` against this same struct without touching `MealStore`.
- **`IngredientStore`/`MealStore` don't yet call `ArchiveService.archiveEndedWeeks()` first.** §5.1 says every mutating service method must archive-first, but `ArchiveService` doesn't exist until M6, which explicitly says "Add archive-first calls to every mutating method in all stores." Not a deviation — just sequencing implied by the milestone breakdown.
- **`IngredientStore.merge` manual-item quantity combination.** §8.4 says "add A's quantity when the base units match" but the model stores a single raw `quantity` + `unit`, not a base-unit amount. I convert both to base units, sum, then convert back to the target item's unit (e.g. 500 g + 0.5 kg → 1 kg), since that's the simplest reading that produces one coherent merged amount in the target's existing unit.

## 2026-09-14 — M1: Models & domain foundations

- **`SchemaV1.versionIdentifier` is `static let`, not `static var`.** SPEC §6.5 writes `static var versionIdentifier = Schema.Version(1, 0, 0)`, but under Swift 6 with Default Actor Isolation = MainActor, a mutable (`var`) static stored property is flagged as "not concurrency-safe... nonisolated global shared mutable state" (the `VersionedSchema` protocol requirement is `nonisolated`). Since the value is never mutated, changing it to `let` is the simplest fix that satisfies both the protocol and Swift 6 strict concurrency, with no behaviour change.
- **`AppError` copy text for `.ingredientInUse` and `.invalidName`.** SPEC §13.3 gives exact copy only for `.weekIsArchived` ("This week has ended and can't be changed."), and §10.9/§10.6 give copy that maps naturally to `.duplicateIngredientName` and `.imageProcessingFailed`. No exact string is specified for `.ingredientInUse` or `.invalidName`, so I wrote minimal, reasonable placeholder copy ("Used in N meal(s)." / "Please enter a name."). These aren't exercised by any UI yet (that comes in M3/M9) — worth a final copy pass when those screens are built.
- **`QuantityParser` unicode fraction support limited to ½, ¼, ¾.** These are the only vulgar fractions in SPEC §7.2's test table and the only ones implied by the §10.7 hint text ("Enter a number like 2, 1.5 or 1/2"), so I didn't add other unicode fractions (⅓, ⅔, etc.) to avoid scope creep beyond what's specified.

## M0 setup mismatches found (for the human to fix in Xcode, not blocking)

- `IPHONEOS_DEPLOYMENT_TARGET` is `18.6` on both targets (SPEC §4.2 asks for `18.0`). Harmless for now since the installed runtime is 26.5.
- `MealPlannerTests` target is Swift language mode 5.0, while `MealPlanner` is 6.0 (SPEC §4.1 wants Swift 6 project-wide). Also missing `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on the test target (present on the app target). Not currently blocking since test suites are marked `@MainActor` explicitly, but worth aligning in Xcode.
- No `DEVELOPMENT_TEAM` found in `project.pbxproj` — couldn't confirm a personal signing team is selected (§4.2 step 2). Not needed for Simulator builds; check before running on a device.
