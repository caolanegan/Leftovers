# MealPlanner — instructions for Claude

A native iPhone meal-planning app (SwiftUI + SwiftData, iOS 18+). **`SPEC.md` is the source of truth.** Read the sections relevant to your task before writing any code.

## Workflow

- Build **one milestone at a time** (SPEC §16). Read every section it lists. Never start the next milestone unless asked.
- Before coding, briefly plan which files you'll create or change. Then implement, build, test and fix.
- Done means: **zero errors, zero warnings**, all tests passing, every acceptance criterion reported ✅/❌, and a git commit (e.g. `M4: Meals library, detail and editor`).
- If the spec is ambiguous, contradicts itself, or is impossible: choose the simplest option that fits it and add a dated entry to `DECISIONS.md`. Never invent behaviour silently.
- Don't add features, screens, settings or dependencies that aren't in the spec.

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
