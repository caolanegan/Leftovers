# MealPlanner — instructions for Claude

A native iPhone meal-planning app (SwiftUI + SwiftData, iOS 18+). **`SPEC.md` is the source of truth.** Read the sections relevant to your task before writing any code.

## Workflow

- Build **one milestone at a time** (SPEC §16). Read every section it lists. Never start the next milestone unless asked.
- Before coding, briefly plan which files you'll create or change. Then implement, build, test and fix.
- Done means: **zero errors, zero warnings**, all tests passing, every acceptance criterion reported ✅/❌, and a git commit (e.g. `M4: Meals library, detail and editor`).
- If the spec is ambiguous, contradicts itself, or is impossible: choose the simplest option that fits it and add a dated entry to `DECISIONS.md`. Never invent behaviour silently.
- Don't add features, screens, settings or dependencies that aren't in the spec.
- **SPEC §18 (recipe photo import, M13–M15) is post-MVP.** Don't build or scaffold any of it until the human explicitly asks for M13.
- Never hard-code, log, print or commit API keys or API response bodies. Unit tests never call live APIs; use the fixtures.

## Commands

Run from `MealPlanner/`. Find a simulator with `xcrun simctl list devices available | grep iPhone`.

```bash
xcodebuild -project MealPlanner.xcodeproj -scheme MealPlanner -destination 'platform=iOS Simulator,name=<SIM>' -quiet build
```

```bash
xcodebuild -project MealPlanner.xcodeproj -scheme MealPlanner -destination 'platform=iOS Simulator,name=<SIM>' -quiet test
```

## Hard rules

- **No third-party packages.** **Never edit `project.pbxproj`.** New files go inside the synchronised `MealPlanner/` and `MealPlannerTests/` folders.
- Follow the SPEC §5.2 folder structure. Keep files under ~250 lines.
- Swift 6 with Default Actor Isolation = MainActor. Mark test suites `@MainActor`. Heavy work (image resizing) uses `@concurrent nonisolated` functions.
- `Domain/` imports only `Foundation`.
- Views never insert, delete, relink or edit models. They call services. Editors work on value drafts (`MealDraft`).
- **Every mutating service method:** calls `ArchiveService.archiveEndedWeeks()` first → throws `AppError.weekIsArchived` for ended weeks → finishes with `context.save()`.
- **Ended weeks are frozen.** Read them only from their JSON snapshots, never from live `Meal`/`Ingredient` data.
- **The shopping list merges by `Ingredient.id`, never by name.** `NameNormalizer` is only for library uniqueness and search.
- SwiftData (SPEC §6.1): defaults on every property, no `.unique`, optional relationships with the inverse declared only on the to-many side, enums stored as raw strings, `@Query` with runtime values built in `init`, `.externalStorage` for photos.
- Never persist `hashValue`. No force-unwraps outside tests (one documented exception in §7.6).
- UI copy is **British English**. Code identifiers are **US English**.
- Standard SwiftUI components, SF Symbols, system colours and text styles only. Every icon-only button has an `accessibilityLabel`.
- Don't use APIs newer than iOS 18 without `if #available`.

## Data model changes (schema versioning)

The app now holds real user data, so a model change must never make an existing store fail to open or lose data.

- **`SchemaV1` is frozen. Never edit it again**: no added, removed, renamed or retyped properties, no new models, no changed `versionIdentifier`. This applies to any milestone, including instructions written before this rule (e.g. SPEC M7.1's "add it to `SchemaV1` directly" was a one-off and doesn't carry forward).
- **Any change to a `@Model` class, or adding or removing a model, goes in a new schema version** (`SchemaV2`, then `SchemaV3`…):
  1. Snapshot the current models inside the old version first, e.g. `extension SchemaV1 { @Model final class Meal { … } }`, copied exactly as they are, so the old version keeps describing the old store.
  2. Define the new version (`enum SchemaV2: VersionedSchema`, `versionIdentifier = Schema.Version(2, 0, 0)`) with the changed models, and point the app's top-level names at the latest version (e.g. `typealias Meal = SchemaV2.Meal`).
  3. Add the new version to `MealPlannerMigrationPlan.schemas` and add a stage: `.lightweight(fromVersion:toVersion:)` for adding properties with defaults or adding models, or `.custom(…)` when data has to be transformed (type changes, splitting or merging fields, back-filling values).
  4. For renamed properties use `@Attribute(originalName: "oldName")`. Never simply delete and re-add a property.
  5. `ModelContainerFactory` always builds the **latest** schema, with the migration plan.
- **Every schema change needs a migration test:** create an **on-disk** store (a temp directory, not in-memory) with the previous schema, insert representative data, reopen it with the latest schema and the migration plan, and assert the data survived, with new fields having their expected default or back-filled values.
- Record every schema version bump in `DECISIONS.md`, with what changed and which stage type was used.
- Changes that don't touch `@Model` classes (views, services, domain structs, JSON snapshot types) don't need a new version. But the archive snapshot types (`ArchivedSlot`, `ArchivedShoppingList`) are saved as JSON: only add **optional** fields to them, so old saved JSON still decodes.
