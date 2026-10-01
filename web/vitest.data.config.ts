import { defineConfig } from 'vitest/config'

// Data tests run against the local Supabase stack (`supabase start`). They are not part of `pnpm test`.
export default defineConfig({
  test: {
    environment: 'node',
    include: ['src/**/*.data.test.ts'],
    fileParallelism: false,
    testTimeout: 30_000,
    hookTimeout: 60_000,
  },
})
