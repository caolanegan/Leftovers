import { randomUUID } from 'node:crypto'
import { describe, expect, it } from 'vitest'
import { createSupabaseClient } from './client'
import { sendSignInEmail, verifySignInCode } from './auth'
import { env } from './testkit'

type MailpitList = { messages: { ID: string }[] }
type MailpitMessage = { Subject: string; HTML: string }

/** Polls the local stack's Mailpit for the newest email to `to`. */
async function latestEmail(to: string): Promise<MailpitMessage> {
  for (let attempt = 0; attempt < 50; attempt++) {
    const list = (await (await fetch(`${env.MAILPIT_URL}/api/v1/search?query=${encodeURIComponent(`to:"${to}"`)}`)).json()) as MailpitList
    if (list.messages.length > 0) {
      return (await (await fetch(`${env.MAILPIT_URL}/api/v1/message/${list.messages[0].ID}`)).json()) as MailpitMessage
    }
    await new Promise((resolve) => setTimeout(resolve, 100))
  }
  throw new Error(`No email arrived for ${to}`)
}

function codeIn(message: MailpitMessage): string {
  const match = message.HTML.match(/>\s*(\d{6})\s*</)
  if (!match) throw new Error('No 6-digit code in the email')
  return match[1]
}

async function signInWithCode(email: string) {
  const client = createSupabaseClient(env.API_URL, env.ANON_KEY)
  await sendSignInEmail(client, email, 'http://localhost:5173/plan')
  const message = await latestEmail(email)
  await verifySignInCode(client, email, codeIn(message))
  return { client, message }
}

describe('Sign-in email (W4)', () => {
  it('a new user signs in with the code, and the email carries the link too', async () => {
    const email = `code-${randomUUID()}@example.test`
    const { client, message } = await signInWithCode(email)
    expect(message.Subject).toBe('Your Leftovers sign-in code')
    expect(message.HTML).toContain('/auth/v1/verify')
    const { data } = await client.auth.getUser()
    expect(data.user?.email).toBe(email)
  })

  it('a returning user signs in with a fresh code', async () => {
    const email = `code-${randomUUID()}@example.test`
    const first = await signInWithCode(email)
    await first.client.auth.signOut()
    await new Promise((resolve) => setTimeout(resolve, 1100)) // the local stack spaces out repeat emails
    const { client } = await signInWithCode(email)
    const { data } = await client.auth.getUser()
    expect(data.user?.email).toBe(email)
  })

  it('a wrong code is refused', async () => {
    const email = `code-${randomUUID()}@example.test`
    const client = createSupabaseClient(env.API_URL, env.ANON_KEY)
    await sendSignInEmail(client, email, 'http://localhost:5173/plan')
    const code = codeIn(await latestEmail(email))
    const wrong = code === '000000' ? '111111' : '000000'
    await expect(verifySignInCode(client, email, wrong)).rejects.toThrow('That code didn’t work')
    const { data } = await client.auth.getSession()
    expect(data.session).toBeNull()
  })
})
