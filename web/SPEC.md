# Leftovers on the web — specification

> **Version:** 1.0 · **Date:** 2026-09-30 · **Stack:** React + TypeScript + Vite (PWA) · **Hosting:** Cloudflare Pages + Supabase
>
> **This document only covers what is different on the web.** Every product rule — how the randomiser picks, how leftovers work, how the shopping list merges, quantities, week maths, the exported text — lives in the iOS spec at `../SPEC.md` and is **unchanged**. Where this file cites e.g. "§7.4", that means `../SPEC.md` §7.4. If the two ever disagree about behaviour, `../SPEC.md` wins; if they disagree about platform (storage, screens, hosting), this file wins.

## W1. Why and what

The iPhone app can only reach real users through the App Store, which needs a paid Apple membership. This version runs in a browser, is added to the home screen on iPhone and iPad, and works on Android too.

**In scope for v1:** everything in `../SPEC.md` §2.1 except notifications, and with two people sharing one household's data.

**Not in v1:** notifications and the weekly reminder (§11); recipe photo import (§18); offline editing.

**Never:** rewriting the product rules. They are ported as they are.

## W2. Stack

- **React 19 + TypeScript + Vite.** React Router for routing, TanStack Query for data fetching and cache.
- **Tailwind CSS** for styling. No component library.
- **`vite-plugin-pwa`** for the manifest and service worker, so it installs to the home screen.
- **Supabase JS client** talking to Postgres directly, with row-level security doing the access control. No API server of our own.
- **Vitest** for unit tests, **Playwright** for a handful of end-to-end flows.
- **Lucide** (`lucide-react`) for icons (W8).
- **Build tooling** is allowed as dev dependencies without a spec change: TypeScript, `@vitejs/plugin-react`, Tailwind's Vite plugin, ESLint (with the TypeScript and React plugins) for `pnpm lint`, and the type packages these need. Log each one in `web/DECISIONS.md`.
- **pnpm 10**, pinned with `"packageManager": "pnpm@10.34.6"` in `web/package.json` so local and Cloudflare builds match.
- Nothing else. Adding a runtime dependency needs a spec change.

## W3. Hosting and deployment

| Piece | Where | Cost |
|---|---|---|
| Frontend | Cloudflare Pages, built on push to `master` | free |
| Database, auth, photo storage | Supabase free tier | free |
| Domain | optional | ~£10/yr |

- Two Supabase projects: `leftovers-dev` and `leftovers-prod`. Local development points at dev.
- Cloudflare Pages settings: root directory `web`, build command `pnpm install && pnpm build`, output directory `dist` (relative to the root directory). Production variables point at `leftovers-prod`, Preview variables at `leftovers-dev`. Every push to `master` deploys; branches get preview URLs.
- Database changes are SQL migration files in `web/supabase/migrations/`, applied to dev first, then prod. Never edit a migration that has run.

### W3.1 Secrets (the repo is public)

`github.com/caolanegan/Leftovers` is a **public repository**. Treat everything committed as readable by anyone.

| Value | Where it lives | Safe in the browser? |
|---|---|---|
| Supabase URL and **anon** (publishable) key, as `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` | Cloudflare Pages env vars, and `web/.env.local` locally | Yes — row-level security is what protects the data |
| Supabase **service-role** key | nowhere in this project | Never |
| Database connection string (for backups) | GitHub Actions secret | Never |

- `.env*` files are git-ignored, except a committed `.env.example` holding key **names** and no values.
- Never commit a database dump, a screenshot of real data, or anything holding the quick-send contact's name or number.
- Never log rows containing personal details.

### W3.2 Backups

Supabase's free tier takes no backups, so the project does its own.

- A GitHub Actions workflow, `.github/workflows/backup.yml`, runs every **Sunday at 03:00 UTC** and can also be run by hand.
- It runs `pg_dump` against prod using the `SUPABASE_DB_URL` GitHub Actions secret, gzips the result, and uploads it as a **private workflow artefact** (90-day retention). Cloudflare R2 is an acceptable alternative target. **It must never write the dump into this repository.**
- The run doubles as a keep-alive: free Supabase projects pause after seven days without activity, and a paused project serves nothing until it's restored by hand from the dashboard (data is kept).
- `web/README.md` documents the restore: download the artefact, `gunzip`, then `psql "$SUPABASE_DB_URL" -f dump.sql` against a fresh project.
- Test the restore once, into the dev project, as part of W-M8. A backup nobody has restored isn't a backup.

## W4. Accounts and households

- **Sign-in:** Supabase magic link by email. No passwords.
- **Household:** one row per household. Every piece of data belongs to a household, not a user.
- A user joins a household by opening an invite link containing a single-use token. The first user to sign in creates a household automatically.
- **Row-level security on every table:** a row is readable and writable only if its `household_id` is one the signed-in user belongs to. RLS is the only access control; the browser is never trusted.
- Two people editing at once is normal. Last write wins on a field. The shopping list subscribes to Supabase realtime so a tick by one person appears for the other.

## W5. Data model (Postgres)

Mirrors `../SPEC.md` §6.4 one-to-one, with these platform changes:

- Every table gets `household_id uuid not null references household(id)`, `created_at timestamptz default now()`.
- Ids are `uuid` (`gen_random_uuid()`). Enums are stored as `text` with a check constraint, exactly the raw values in §6.2 and §6.3.
- Tables: `household`, `household_member`, `ingredient`, `meal`, `recipe_ingredient`, `instruction_step`, `week_plan`, `meal_slot`, `manual_shopping_item`, `shopping_item_state`, `household_settings`.
- **Constraints the app used to enforce in code** (allowed here, and an improvement): `unique (household_id, week_id)` on `week_plan`; `unique (household_id, normalized_name)` on `ingredient`; `unique (week_plan_id, day_index, meal_type)` on `meal_slot`; `unique (week_plan_id, item_key)` on `shopping_item_state`.
- **The shopping list still merges by `ingredient.id`, never by name** (§7.4).
- Archived weeks keep the same JSON snapshots (§7.8) in `jsonb` columns. Ended weeks are read only from those snapshots.
- Deletes follow §6.6. Use `on delete cascade` for slots, recipe lines, steps, manual items and item states.
- `household_settings` holds what `@AppStorage` held: the quick-send contact name and phone, and the two export options. Appearance is per person, in the browser's own storage.

## W6. Photos

- Resized in the browser before upload: longest side 1024 px, JPEG quality 0.8, plus a 256 px thumbnail. This replaces `ImageProcessor` (§8.5).
- Stored in a Supabase Storage bucket keyed by household, with the paths on the `meal` row. The bucket is private; images are read through signed URLs.
- Taking a photo uses `<input type="file" accept="image/*" capture="environment">`.

## W7. Code layout (`web/src/`)

```
domain/        pure functions, no React, no network — the port of ../SPEC.md §7
  weekMath.ts  quantity.ts  nameNormalizer.ts  shoppingList.ts
  shoppingCheck.ts  randomizer.ts  leftoverRules.ts  archiveSnapshots.ts
  exporter.ts  whatsAppLink.ts
data/          Supabase client, queries and mutations — the port of §8 services
features/      plan/  meals/  ingredients/  shopping/  settings/
components/    shared UI
app/           routing, layout, auth
```

- `domain/` is pure: given the same inputs it returns the same output, and it never imports React or Supabase. Its tests port directly from `MealPlannerTests/`.
- Components never write to the database directly; they call `data/`.
- Files stay under ~250 lines.

## W8. Screens

Behaviour comes from `../SPEC.md` §10. The routes are:

| Route | Screen | iOS equivalent |
|---|---|---|
| `/plan` | week plan (default) | §10.1 |
| `/meals`, `/meals/:id`, `/meals/:id/edit` | library, detail, editor | §10.4–§10.6 |
| `/ingredients`, `/ingredients/:id` | ingredient library | §10.9 |
| `/shopping` | shopping list | §10.10 |
| `/settings`, `/settings/sharing` | settings pages | §10.12 |

Platform differences, and nothing else:

- **Tab bar** becomes a bottom bar on phones and a sidebar from tablet width up.
- **Sheets** become modal dialogs; on phones they slide up from the bottom and fill most of the screen.
- **Swipe actions** (Shuffle, Remove) become a "⋯" button on each row, opening the same list of actions. Long-press context menus become the same menu.
- **Confirmation dialogs** become the same buttons in a modal, destructive actions in red.
- **Haptics** are dropped.
- **Sharing** uses the Web Share API (`navigator.share`) where available, falling back to copy-to-clipboard. The quick-send contact still opens a `wa.me` link (§7.10, §12.1). The exported text is byte-for-byte what §7.9 specifies.

Everything else — copy, British English, empty states, the personality decisions in §13.5 (colour per meal type, aisle icons, photos on plan rows, the Tonight card, "All done!") — carries over. Use Lucide icons as the stand-in for SF Symbols, and the same accent green (`#2E7D32` light, `#66BB6A` dark).

## W9. Behaviour on the web

- **Online only in v1.** The service worker caches the app shell so it opens instantly; data needs a connection. A clear "You're offline" banner when requests fail.
- **Dark mode** follows the system by default, with the same System / Light / Dark setting, saved per browser.
- **Accessibility:** §13.2 applies. Every icon-only button has a label, focus is visible, the whole app works from a keyboard, and text scales when the browser's font size changes.
- **Weeks and dates** use the same Monday-first week and `Europe/London` behaviour as §7.1. Week ids stay `2026-W38`.

## W10. Testing

- **Vitest** covers `domain/` — port every test in `MealPlannerTests/` that tests domain logic (§15.1: week maths, quantities, name normalising, shopping list building, check evaluation, randomiser, leftover rules, archive snapshots, exporter, WhatsApp links).
- **Data tests** run against a local Supabase instance: the §8 service behaviours, including that ended weeks reject writes and that RLS blocks another household's rows.
- **Playwright** covers four flows: plan a meal, randomise a week, tick a shopping item and see "need more", share the list.
- Done means zero TypeScript errors, zero lint warnings, all tests passing.

## W11. Milestones

Same working rules as `../CLAUDE.md`: one milestone per session, read the sections it lists, report each acceptance criterion ✅/❌, log deviations in `web/DECISIONS.md`, commit and push.

### W-M0 — Accounts (human)
Create the two Supabase projects and the Cloudflare Pages project, and put the keys in `.env.local` and Pages. **Done when:** the dev project answers its auth health endpoint with the keys in `web/.env.local`. (`pnpm dev` is checked in W-M1, once there's an app.)

### W-M1 — Foundations
Vite + React + TypeScript + Tailwind, routing, the PWA manifest and service worker, app shell with the bottom bar/sidebar, dark mode.
- [ ] Installs to the iPhone home screen and opens full screen.
- [ ] Empty screens for all five routes, with the right titles.
- [ ] `pnpm dev` runs locally, and the push to `master` gives the first successful Cloudflare Pages build.
- [ ] Home-screen icons are simple placeholders in the accent green, generated without new dependencies.

### W-M2 — Database and auth
Migrations for every table in W5 with RLS, household creation and invite links, magic-link sign-in, `data/` client.
- [ ] A signed-in user sees only their household's rows; another household's rows are invisible in a test.
- [ ] An invite link adds a second person to the same household.

### W-M3 — Domain port
Every module in W7's `domain/`, and the ported tests.
- [ ] Every §7 table of test cases passes, including the exporter's exact string.

### W-M4 — Meals and ingredients
Library, detail, editor, ingredient library, photos.
- [ ] Create, edit, duplicate, favourite and delete meals; photos upload, resize and display.
- [ ] Ingredient rename, merge and delete follow §6.6 and §8.4.

### W-M5 — Plan
Week grid, picker, leftovers, copy week, randomiser, archiving ended weeks.
- [ ] §10.1's typical flow works, including the leftovers prompts and dependent-leftovers dialog.
- [ ] Ended weeks are read-only and read from snapshots.

### W-M6 — Shopping
List, ticks, "need more", hand-added items, realtime updates between two signed-in browsers.
- [ ] §7.4 and §7.5 behaviours hold in the app, not just in tests.
- [ ] A tick in one browser appears in the other.

### W-M7 — Export and share
Exporter, Web Share API, `wa.me` links, quick-send contact, the changed-since-shared banner.
- [ ] The shared text matches §7.9 exactly, and WhatsApp receives it correctly from a phone.

### W-M8 — Polish, QA and launch
§13 polish, §15.2 walked through in a browser on a real iPhone and iPad, the backup workflow (§W3.2), and the production deploy.
- [ ] Light, dark and large text all read correctly on phone and tablet widths.
- [ ] The backup workflow runs on demand, uploads a private artefact, and the dump restores into the dev project.
- [ ] Nothing in the repo holds a secret or personal data (§W3.1), and `.env.example` lists the key names only.
