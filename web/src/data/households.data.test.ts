import { beforeAll, describe, expect, it } from 'vitest'
import { acceptInvite, createInvite, ensureHousehold } from './households'
import { HouseholdError } from './errors'
import { admin, anon, createUser, must, type TestUser } from './testkit'

let alice: TestUser
let aliceHousehold: string

beforeAll(async () => {
  alice = await createUser()
  aliceHousehold = await ensureHousehold(alice.client)
})

describe('ensure_household', () => {
  it('creates a household, a member row and settings, and is idempotent', async () => {
    expect(await ensureHousehold(alice.client)).toBe(aliceHousehold)
    const members = must(await admin.from('household_member').select('*').eq('household_id', aliceHousehold))
    expect(members.map((m) => m.user_id)).toEqual([alice.id])
    expect(must(await admin.from('household_settings').select('*').eq('household_id', aliceHousehold))).toHaveLength(1)
    expect(must(await alice.client.from('household').select('id'))).toEqual([{ id: aliceHousehold }])
  })

  it('refuses signed-out callers', async () => {
    const { error } = await anon.rpc('ensure_household')
    expect(error).not.toBeNull()
  })
})

describe('invites', () => {
  it('adds a second person to the same household, once', async () => {
    const bob = await createUser()
    const token = await createInvite(alice.client, aliceHousehold, alice.id)
    expect(await acceptInvite(bob.client, token)).toBe(aliceHousehold)

    // Both now see the same household rows.
    const meal = must(await alice.client.from('meal').insert({ household_id: aliceHousehold, name: 'Shared' }).select('id').single())
    expect(must(await bob.client.from('meal').select('id').eq('id', meal.id))).toHaveLength(1)

    const invite = must(await admin.from('household_invite').select('*').eq('token', token).single())
    expect(invite.used_by).toBe(bob.id)
    expect(invite.used_at).not.toBeNull()

    // The token is now spent.
    const carol = await createUser()
    await expect(acceptInvite(carol.client, token)).rejects.toMatchObject({ code: 'invite_invalid' })
    expect(must(await admin.from('household_member').select('*').eq('user_id', carol.id))).toHaveLength(0)
  })

  it('refuses a user who already has a household, and leaves the token unused', async () => {
    const dave = await createUser()
    await ensureHousehold(dave.client)
    const token = await createInvite(alice.client, aliceHousehold, alice.id)
    const attempt = acceptInvite(dave.client, token)
    await expect(attempt).rejects.toBeInstanceOf(HouseholdError)
    await expect(attempt).rejects.toMatchObject({ code: 'already_in_household' })
    expect(must(await admin.from('household_invite').select('used_at').eq('token', token).single()).used_at).toBeNull()
  })

  it('refuses an unknown token', async () => {
    const erin = await createUser()
    await expect(acceptInvite(erin.client, crypto.randomUUID())).rejects.toMatchObject({ code: 'invite_invalid' })
  })

  it('refuses signed-out callers', async () => {
    const token = await createInvite(alice.client, aliceHousehold, alice.id)
    const { error } = await anon.rpc('accept_invite', { invite_token: token })
    expect(error).not.toBeNull()
  })

  it('does not let other households read an invite by token', async () => {
    const frank = await createUser()
    await ensureHousehold(frank.client)
    const token = await createInvite(alice.client, aliceHousehold, alice.id)
    expect(must(await frank.client.from('household_invite').select('*').eq('token', token))).toEqual([])
  })

  it('does not let members mark invites used or delete them', async () => {
    const token = await createInvite(alice.client, aliceHousehold, alice.id)
    const upd = await alice.client.from('household_invite').update({ used_at: new Date().toISOString() }).eq('token', token).select()
    expect(upd.error !== null || (upd.data ?? []).length === 0).toBe(true)
    expect(must(await admin.from('household_invite').select('used_at').eq('token', token).single()).used_at).toBeNull()
  })
})
