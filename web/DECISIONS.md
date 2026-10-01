# Decisions — web

Log of spec ambiguities and deviations, most recent first.

## 2026-10-01 — W-M2: Database and auth

- **Runtime dependencies added:** `@supabase/supabase-js` and `@tanstack/react-query` (both in the §W2 list). No new dev dependencies; the Supabase CLI is a Homebrew tool, not a package.
- **One migration**, `supabase/migrations/20261001000000_initial_schema.sql`, holds every §W5 table, RLS and the two `security definer` functions. Later schema changes go in new files.
- **RLS shape.** `household_member` is readable only for your own row, which keeps every other policy (`household_id in (select household_id from household_member where user_id = auth.uid())`) free of recursion. Signed-in clients get no insert/update/delete on `household` or `household_member`; those happen only inside `ensure_household()` / `accept_invite()`. Invites are insertable and readable by members of the household but not updatable or deletable from the client (only `accept_invite` marks one used). `anon` has no table privileges.
- **Snapshot columns:** `week_plan.archived_shopping` and `meal_slot.archived_snapshot` are `jsonb` (§7.8). `shopping_item_state.checked_amounts` is `jsonb` too; `item_key` stays text (an ingredient id).
- **`household_settings`** columns: `quick_send_name`, `quick_send_phone`, `include_checked` (default false), `include_meal_plan` (default true), per §10.12.
- **`ingredient.normalized_name`** is a plain required column; the client writes `NameNormalizer`'s output (W-M3/W-M4). Updated-at columns are set by the client, with no trigger.
- **Invite errors:** `accept_invite(invite_token)` raises `invite_invalid` for an unknown or used token (deliberately not distinguishing the two) and `already_in_household`; `data/errors.ts` maps them to British English copy.
- **Route structure:** `/sign-in` and `/invite/:token` sit outside the signed-in gate. The gate calls `ensure_household()` on first sign-in, so opening an invite while signed in never creates a household. A signed-out visit to any other path redirects to `/sign-in` and returns there after sign-in.
- **Data tests** (`pnpm test:data`, config `vitest.data.config.ts`, files `src/**/*.data.test.ts`, helper `src/data/testkit.ts`) run against the local stack. `pnpm test` excludes them. The RLS-enabled catalogue check uses `docker exec` into the local database container, since PostgREST can't read `pg_class`.
- **`pnpm dev:local`** (`scripts/dev-local.mjs`) runs Vite against the local stack, reading the URL and anon key from `supabase status -o env` into the process environment only. Nothing is written to disk.
- **Local `config.toml`:** `project_id = "leftovers-web"`, `site_url` and redirect allow-list set to `http://localhost:5173` / `http://127.0.0.1:5173` so magic links land on the dev server.
- **Bundle size limit raised** (`build.chunkSizeWarningLimit: 700`): the single bundle is about 524 kB with Supabase JS, which tripped the default 500 kB warning and §W10 requires zero warnings. Route-level code splitting can replace this later.

## 2026-10-01 — W-M1: Foundations

- **Dev dependencies added (build tooling, §W2):** `vite`, `@vitejs/plugin-react`, `typescript`, `tailwindcss`, `@tailwindcss/vite`, `vite-plugin-pwa`, `vitest`, `eslint`, `@eslint/js`, `typescript-eslint`, `eslint-plugin-react`, `eslint-plugin-react-hooks`, `globals`, `@types/react`, `@types/react-dom`, `@types/node`.
- **Runtime dependencies installed this milestone:** `react`, `react-dom`, `react-router`, `lucide-react`. TanStack Query, Supabase JS and Playwright are in the §W2 list but aren't installed yet because nothing uses them; they arrive with the milestone that does.
- **TypeScript pinned to 6.x (`~6`), not 7.** `typescript-eslint` 8.71 refuses TS 7, which would break `pnpm lint`.
- **ESLint pinned to 9.x (with `@eslint/js` 9), not 10.** `eslint-plugin-react` 7.37 crashes on ESLint 10 (`getFilename is not a function`).
- **Lint runs with `--max-warnings 0`** so warnings fail the command.
- **Placeholder icons** come from `web/scripts/generate-icons.mjs` (Node built-ins only; run with `pnpm icons`): a white "L" on accent green, written to `public/` and committed. The 512 px icon doubles as the maskable icon.
- **Navigation:** four tabs as in the iOS app (Plan, Meals, Shopping, Settings). `/ingredients` and `/settings/sharing` are the other routes in §W8; they're reached from a link on Meals and on Settings, as in §9.1. The five "screens" in the W-M1 checklist are Plan, Meals, Ingredients, Shopping and Settings (plus an empty Sharing page for `/settings/sharing`).
- **Appearance setting** (System / Light / Dark, stored in `localStorage` as `leftovers.appearance`) is on the Settings page now, since §W9 puts dark mode in this milestone. An inline script in `index.html` applies it before first paint to avoid a flash.
- **Meal detail and editor routes** (`/meals/:id`, `/meals/:id/edit`, `/ingredients/:id`) are left to W-M4, which builds those screens.
- **`.gitignore`** now also ignores `*.tsbuildinfo` (written by `tsc -b`).

## 2026-10-01 — W-M0: Accounts

- **Cloudflare output directory is `dist`, not `web/dist`.** §W3 sets the root directory to `web`, and Pages resolves the output directory relative to it, so `web/dist` would point at `web/web/dist`.
- **Staying on Cloudflare Pages although Cloudflare now labels it legacy.** It still works and is free, and it keeps separate Production and Preview variables (Preview → `leftovers-dev`, Production → `leftovers-prod`), which the Workers flow doesn't split by branch as simply. Moving to Workers later needs only a `wrangler.jsonc`, no app code changes; that would be a spec change.
- **Env var names:** `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` (§W3.1 doesn't name them; Vite only exposes `VITE_`-prefixed vars to the browser). The anon key slot holds the project's publishable key (`sb_publishable_…`).
- **pnpm is pinned to 10.** Corepack 0.33 (Node 24.2) can't start pnpm 12, whose bin moved to `pnpm.mjs`. W-M1 adds `"packageManager": "pnpm@10.34.6"` to `web/package.json` so local and Cloudflare builds match.
- **"`pnpm dev` runs" moves to W-M1.** There's no app to run until W-M1. W-M0 was checked instead by calling the dev project's auth health endpoint with the keys in `web/.env.local` (HTTP 200).
- The repo is `github.com/caolanegan/Leftovers` (renamed from `dinner-app`); the local remote now uses the new name.
