// Runs the dev server against the local Supabase stack. Keys are read from `supabase status` at run time
// and passed in the environment only; nothing is written to disk.
import { execFileSync, spawn } from 'node:child_process'

const env = {}
for (const line of execFileSync('supabase', ['status', '-o', 'env'], { encoding: 'utf8' }).split('\n')) {
  const m = line.match(/^([A-Z_]+)="?(.*?)"?$/)
  if (m) env[m[1]] = m[2]
}
if (!env.API_URL || !env.ANON_KEY) {
  console.error('Local Supabase is not running. Start it with `supabase start`.')
  process.exit(1)
}
spawn('pnpm', ['exec', 'vite', ...process.argv.slice(2)], {
  stdio: 'inherit',
  env: { ...process.env, VITE_SUPABASE_URL: env.API_URL, VITE_SUPABASE_ANON_KEY: env.ANON_KEY },
}).on('exit', (code) => process.exit(code ?? 0))
