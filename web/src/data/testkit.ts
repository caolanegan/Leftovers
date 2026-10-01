// Helpers for data tests only. Reads the LOCAL stack's URL and keys at run time (never committed).
import { execFileSync } from 'node:child_process'
import { randomUUID } from 'node:crypto'
import { createSupabaseClient, type Client } from './client'

function localEnv(): Record<string, string> {
  const out = execFileSync('supabase', ['status', '-o', 'env'], { encoding: 'utf8' })
  const env: Record<string, string> = {}
  for (const line of out.split('\n')) {
    const m = line.match(/^([A-Z_]+)="?(.*?)"?$/)
    if (m) env[m[1]] = m[2]
  }
  return env
}

export const env = localEnv()
export const anon: Client = createSupabaseClient(env.API_URL, env.ANON_KEY)
/** Local-only service-role client: bypasses RLS, used to seed rows and create test users. */
export const admin: Client = createSupabaseClient(env.API_URL, env.SERVICE_ROLE_KEY)

export type TestUser = { id: string; client: Client }

export async function createUser(): Promise<TestUser> {
  const email = `test-${randomUUID()}@example.test`
  const password = randomUUID()
  const created = await admin.auth.admin.createUser({ email, password, email_confirm: true })
  if (created.error) throw created.error
  const client = createSupabaseClient(env.API_URL, env.ANON_KEY)
  const signed = await client.auth.signInWithPassword({ email, password })
  if (signed.error) throw signed.error
  return { id: created.data.user.id, client }
}

/** Runs SQL in the local database container (for catalogue checks the REST API can't do). */
export function sql(query: string): string {
  const container = `supabase_db_${env.PROJECT_ID ?? 'leftovers-web'}`
  return execFileSync('docker', ['exec', container, 'psql', '-U', 'postgres', '-tAc', query], { encoding: 'utf8' }).trim()
}

export function must<T>(result: { data: T; error: { message: string } | null }): NonNullable<T> {
  if (result.error) throw new Error(result.error.message)
  return result.data as NonNullable<T>
}

export type Seed = {
  householdId: string
  ids: Record<string, string>
}

/** One row in every data table for a household, written with the service role. */
export async function seedHousehold(owner: TestUser): Promise<Seed> {
  const { data: hid, error } = await owner.client.rpc('ensure_household')
  if (error) throw error
  const h = hid as string
  const ids: Record<string, string> = {}
  const add = async (table: string, row: Record<string, unknown>) => {
    const r = await admin.from(table).insert({ household_id: h, ...row }).select('id').single()
    ids[table] = must(r).id as string
    return ids[table]
  }
  const ing = await add('ingredient', { name: 'Salt', normalized_name: `salt-${randomUUID()}` })
  const meal = await add('meal', { name: 'Soup' })
  await add('recipe_ingredient', { meal_id: meal, ingredient_id: ing })
  await add('instruction_step', { meal_id: meal, text: 'Stir' })
  const week = await add('week_plan', { week_id: '2026-W38' })
  const slot = await add('meal_slot', { week_plan_id: week, day_index: 0, meal_type: 'dinner', meal_id: meal })
  await add('meal_slot', { week_plan_id: week, day_index: 1, meal_type: 'dinner', meal_id: meal, leftover_of_slot_id: slot })
  await add('manual_shopping_item', { week_plan_id: week, ingredient_id: ing })
  await add('shopping_item_state', { week_plan_id: week, item_key: ing })
  const invite = await add('household_invite', { created_by: owner.id })
  ids.invite = invite
  ids.slot = slot
  return { householdId: h, ids }
}

export const TABLES = [
  'household', 'household_member', 'household_invite', 'household_settings', 'ingredient', 'meal',
  'recipe_ingredient', 'instruction_step', 'week_plan', 'meal_slot', 'manual_shopping_item',
  'shopping_item_state',
] as const
