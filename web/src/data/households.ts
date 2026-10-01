import type { Client } from './client'
import { toHouseholdError } from './errors'

/** Creates the user's household if they have none (SPEC W4). Returns the household id. */
export async function ensureHousehold(client: Client): Promise<string> {
  const { data, error } = await client.rpc('ensure_household')
  if (error) throw toHouseholdError(error)
  return data as string
}

/** Joins the household that issued the invite. Single use; refused if the user already has a household. */
export async function acceptInvite(client: Client, token: string): Promise<string> {
  const { data, error } = await client.rpc('accept_invite', { invite_token: token })
  if (error) throw toHouseholdError(error)
  return data as string
}

/** Creates an invite for the household and returns its token. */
export async function createInvite(client: Client, householdId: string, userId: string): Promise<string> {
  const { data, error } = await client
    .from('household_invite')
    .insert({ household_id: householdId, created_by: userId })
    .select('token')
    .single()
  if (error) throw toHouseholdError(error)
  return data.token as string
}

export function inviteLink(origin: string, token: string): string {
  return `${origin}/invite/${token}`
}
