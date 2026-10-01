# Decisions — web

Log of spec ambiguities and deviations, most recent first.

## 2026-10-01 — W-M0: Accounts

- **Cloudflare output directory is `dist`, not `web/dist`.** §W3 sets the root directory to `web`, and Pages resolves the output directory relative to it, so `web/dist` would point at `web/web/dist`.
- **Staying on Cloudflare Pages although Cloudflare now labels it legacy.** It still works and is free, and it keeps separate Production and Preview variables (Preview → `leftovers-dev`, Production → `leftovers-prod`), which the Workers flow doesn't split by branch as simply. Moving to Workers later needs only a `wrangler.jsonc`, no app code changes; that would be a spec change.
- **Env var names:** `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` (§W3.1 doesn't name them; Vite only exposes `VITE_`-prefixed vars to the browser). The anon key slot holds the project's publishable key (`sb_publishable_…`).
- **pnpm is pinned to 10.** Corepack 0.33 (Node 24.2) can't start pnpm 12, whose bin moved to `pnpm.mjs`. W-M1 adds `"packageManager": "pnpm@10.34.6"` to `web/package.json` so local and Cloudflare builds match.
- **"`pnpm dev` runs" moves to W-M1.** There's no app to run until W-M1. W-M0 was checked instead by calling the dev project's auth health endpoint with the keys in `web/.env.local` (HTTP 200).
- The repo is `github.com/caolanegan/Leftovers` (renamed from `dinner-app`); the local remote now uses the new name.
