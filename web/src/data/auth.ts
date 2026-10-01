import type { Client } from './client'

/** Emails a magic link that returns to `redirectTo`. Never creates a household by itself. */
export async function sendMagicLink(client: Client, email: string, redirectTo: string): Promise<void> {
  const { error } = await client.auth.signInWithOtp({ email, options: { emailRedirectTo: redirectTo } })
  if (error) throw new Error('Couldn’t send the link. Check the address and try again.')
}

export async function signOut(client: Client): Promise<void> {
  const { error } = await client.auth.signOut()
  if (error) throw new Error('Couldn’t sign out. Please try again.')
}
