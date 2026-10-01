import { beforeAll, describe, expect, it } from 'vitest'
import { admin, anon, createUser, must, seedHousehold, sql, TABLES, type Seed, type TestUser } from './testkit'

let alice: TestUser
let bob: TestUser
let aliceSeed: Seed
let bobSeed: Seed

beforeAll(async () => {
  alice = await createUser()
  bob = await createUser()
  aliceSeed = await seedHousehold(alice)
  bobSeed = await seedHousehold(bob)
})

describe('RLS is enabled on every table', () => {
  it('has row security on for all public tables', () => {
    const off = sql("select relname from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity")
    expect(off).toBe('')
    const on = sql("select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity")
    expect(Number(on)).toBe(TABLES.length)
  })
})

describe.each(TABLES)('table %s', (table) => {
  const mine = (seed: Seed) => (table === 'household' ? { id: seed.householdId } : { household_id: seed.householdId })

  it('shows a user only their own household’s rows', async () => {
    const own = must(await alice.client.from(table).select('*').match(mine(aliceSeed)))
    expect(own.length).toBeGreaterThan(0)
    const all = must(await alice.client.from(table).select('*'))
    const key = table === 'household' ? 'id' : 'household_id'
    for (const row of all) expect((row as Record<string, string>)[key]).toBe(aliceSeed.householdId)
    // The other household's rows exist (seen via the service role) but are invisible to Alice.
    const theirs = must(await alice.client.from(table).select('*').match(mine(bobSeed)))
    expect(theirs).toEqual([])
    expect(must(await admin.from(table).select('*').match(mine(bobSeed))).length).toBeGreaterThan(0)
  })

  it('refuses signed-out reads', async () => {
    const { data, error } = await anon.from(table).select('*')
    expect(error !== null || (data ?? []).length === 0).toBe(true)
  })

  it('cannot update or delete another household’s rows', async () => {
    const upd = await alice.client.from(table).update({ created_at: new Date().toISOString() }).match(mine(bobSeed)).select()
    expect(upd.data ?? []).toEqual([])
    const del = await alice.client.from(table).delete().match(mine(bobSeed)).select()
    expect(del.data ?? []).toEqual([])
    expect(must(await admin.from(table).select('*').match(mine(bobSeed))).length).toBeGreaterThan(0)
  })
})

describe('writing into another household', () => {
  const dataTables: [string, Record<string, unknown>][] = [
    ['ingredient', { name: 'X', normalized_name: 'x-intruder' }],
    ['meal', { name: 'X' }],
    ['week_plan', { week_id: '2030-W01' }],
    ['household_settings', {}],
  ]
  it.each(dataTables)('refuses an insert into %s', async (table, row) => {
    const { error } = await alice.client.from(table).insert({ household_id: bobSeed.householdId, ...row })
    expect(error).not.toBeNull()
  })

  it('refuses to move a row into another household', async () => {
    const { data } = await alice.client.from('meal').update({ household_id: bobSeed.householdId }).eq('id', aliceSeed.ids.meal).select()
    expect(data ?? []).toEqual([])
  })

  it('refuses to create invites for another household or add members directly', async () => {
    const invite = await alice.client.from('household_invite').insert({ household_id: bobSeed.householdId, created_by: alice.id })
    expect(invite.error).not.toBeNull()
    const member = await alice.client.from('household_member').insert({ household_id: bobSeed.householdId, user_id: alice.id })
    expect(member.error).not.toBeNull()
  })
})
