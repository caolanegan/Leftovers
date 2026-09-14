# Decisions

Log of spec ambiguities and deviations, most recent first.

## 2026-09-14 — M1: Models & domain foundations

- **`SchemaV1.versionIdentifier` is `static let`, not `static var`.** SPEC §6.5 writes `static var versionIdentifier = Schema.Version(1, 0, 0)`, but under Swift 6 with Default Actor Isolation = MainActor, a mutable (`var`) static stored property is flagged as "not concurrency-safe... nonisolated global shared mutable state" (the `VersionedSchema` protocol requirement is `nonisolated`). Since the value is never mutated, changing it to `let` is the simplest fix that satisfies both the protocol and Swift 6 strict concurrency, with no behaviour change.
- **`AppError` copy text for `.ingredientInUse` and `.invalidName`.** SPEC §13.3 gives exact copy only for `.weekIsArchived` ("This week has ended and can't be changed."), and §10.9/§10.6 give copy that maps naturally to `.duplicateIngredientName` and `.imageProcessingFailed`. No exact string is specified for `.ingredientInUse` or `.invalidName`, so I wrote minimal, reasonable placeholder copy ("Used in N meal(s)." / "Please enter a name."). These aren't exercised by any UI yet (that comes in M3/M9) — worth a final copy pass when those screens are built.
- **`QuantityParser` unicode fraction support limited to ½, ¼, ¾.** These are the only vulgar fractions in SPEC §7.2's test table and the only ones implied by the §10.7 hint text ("Enter a number like 2, 1.5 or 1/2"), so I didn't add other unicode fractions (⅓, ⅔, etc.) to avoid scope creep beyond what's specified.

## M0 setup mismatches found (for the human to fix in Xcode, not blocking)

- `IPHONEOS_DEPLOYMENT_TARGET` is `18.6` on both targets (SPEC §4.2 asks for `18.0`). Harmless for now since the installed runtime is 26.5.
- `MealPlannerTests` target is Swift language mode 5.0, while `MealPlanner` is 6.0 (SPEC §4.1 wants Swift 6 project-wide). Also missing `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` on the test target (present on the app target). Not currently blocking since test suites are marked `@MainActor` explicitly, but worth aligning in Xcode.
- No `DEVELOPMENT_TEAM` found in `project.pbxproj` — couldn't confirm a personal signing team is selected (§4.2 step 2). Not needed for Simulator builds; check before running on a device.
