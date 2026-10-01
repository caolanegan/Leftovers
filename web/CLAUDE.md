# Leftovers (web) — instructions for Claude

The web version of the Leftovers meal planner. **`web/SPEC.md` is the source of truth for the web app**, and it defers to the iOS spec at `SPEC.md` (repo root) for every product rule. Read both before writing code: `web/SPEC.md` in full, and the `SPEC.md` sections your milestone lists.

Work in `web/` only. Never touch the iOS app (`MealPlanner/`) in a web milestone.

## Workflow

- Build **one milestone at a time** (web/SPEC.md §W11). Never start the next unless asked.
- Before coding, briefly plan which files you'll create or change. Then implement, build, test and fix.
- Done means: zero TypeScript errors, zero lint warnings, all tests passing, every acceptance criterion reported ✅/❌, and a git commit (e.g. `W-M3: Domain port`).
- If the spec is ambiguous, contradicts itself, or is impossible: choose the simplest option that fits it and add a dated entry to `web/DECISIONS.md`. Never invent behaviour silently.
- Don't add features, screens, settings or dependencies that aren't in the spec.

## Commands

Run from `web/`.

```bash
pnpm install && pnpm dev
```

```bash
pnpm test && pnpm lint && pnpm build
```

## Hard rules

- **Dependencies are fixed** (web/SPEC.md §W2): React, React Router, TanStack Query, Tailwind, Supabase JS, vite-plugin-pwa, Vitest, Playwright, Lucide icons, plus the build tooling §W2 lists. Anything else needs a spec change first. pnpm is pinned to 10 via `packageManager`.
- **`domain/` is pure**: no React, no Supabase, no `Date.now()` passed implicitly — take the current time as an argument, as the Swift version does. It is a direct port of `SPEC.md` §7 and keeps the same behaviour, including the exporter's exact output.
- **Components never touch Supabase.** They call `data/`. `data/` owns every query and mutation.
- **Every mutating operation** archives ended weeks first, refuses to change an ended week, and saves once (`SPEC.md` §8, the same rule as the iOS app).
- **Ended weeks are frozen**: read them only from their JSON snapshots.
- **The shopping list merges by ingredient id, never by name.**
- **Row-level security is the access control.** Never rely on the client filtering by household; every table has RLS and every query works within it.
- **This GitHub repo is public** (§W3.1). Only the Supabase anon key may reach the browser or a committed file; the service-role key and the database connection string live in GitHub/Cloudflare secrets and nowhere else. `.env*` stays git-ignored apart from `.env.example`, which holds key names and no values. Never commit a database dump, real data, or the quick-send contact's name or number, and never log rows containing personal details.
- Database changes are new SQL migration files in `web/supabase/migrations/`. Never edit a migration that has already run.
- Files stay under ~250 lines. Keep the folder structure in §W7.
- UI copy is **British English**. Code identifiers are **US English**.
- Accessibility is not optional: labels on icon-only buttons, visible focus, full keyboard use, and it must work at large text sizes and at phone width.
