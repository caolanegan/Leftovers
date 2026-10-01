# Decisions — web

Log of spec ambiguities and deviations, most recent first.

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
