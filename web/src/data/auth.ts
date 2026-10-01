import type { Client } from './client'

/**
 * Emails a magic link that returns to `redirectTo`, plus a 6-digit code (W4). The code is for iPhone home-screen
 * apps, which don't share Safari's storage, so a link opened from Mail can't sign them in. Never creates a household.
 */
export async function sendSignInEmail(client: Client, email: string, redirectTo: string): Promise<void> {
  const { error } = await client.auth.signInWithOtp({ email, options: { emailRedirectTo: redirectTo } })
  if (error) throw new Error('Couldn’t send the email. Check the address and try again.')
}

/** Signs in with the 6-digit code from the sign-in email. */
export async function verifySignInCode(client: Client, email: string, code: string): Promise<void> {
  const { error } = await client.auth.verifyOtp({ email, token: code, type: 'email' })
  if (error) throw new Error('That code didn’t work. Check it, or send a new one.')
}

export async function signOut(client: Client): Promise<void> {
  const { error } = await client.auth.signOut()
  if (error) throw new Error('Couldn’t sign out. Please try again.')
}
