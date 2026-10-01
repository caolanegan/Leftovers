import { useState, type FormEvent } from 'react'
import { Navigate, useLocation } from 'react-router'
import { useAuth } from './auth'
import { getClient } from '../data/client'
import { sendMagicLink } from '../data/auth'

/** Magic-link form, shared by /sign-in and the signed-out view of /invite/:token. */
export function SignInForm({ returnTo }: { returnTo: string }) {
  const [email, setEmail] = useState('')
  const [status, setStatus] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle')

  async function submit(event: FormEvent) {
    event.preventDefault()
    setStatus('sending')
    try {
      await sendMagicLink(getClient(), email.trim(), window.location.origin + returnTo)
      setStatus('sent')
    } catch {
      setStatus('error')
    }
  }

  if (status === 'sent') {
    return (
      <p role="status" className="rounded-lg bg-accent/10 p-4">
        Check your email. We’ve sent a sign-in link to <strong>{email.trim()}</strong>.
      </p>
    )
  }

  return (
    <form onSubmit={submit} className="space-y-3">
      <label className="block">
        <span className="mb-1 block font-medium">Email address</span>
        <input
          type="email"
          required
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="w-full rounded-lg border border-neutral-300 bg-white px-3 py-2 dark:border-neutral-700 dark:bg-neutral-900"
        />
      </label>
      <button
        type="submit"
        disabled={status === 'sending'}
        className="rounded-lg bg-accent px-4 py-2 font-semibold text-white disabled:opacity-60"
      >
        {status === 'sending' ? 'Sending…' : 'Email me a sign-in link'}
      </button>
      {status === 'error' && (
        <p role="alert" className="text-red-700 dark:text-red-400">
          Couldn’t send the link. Check the address and try again.
        </p>
      )}
    </form>
  )
}

export function SignInPage() {
  const { session, loading } = useAuth()
  const from = (useLocation().state as { from?: string } | null)?.from ?? '/plan'
  if (!loading && session) return <Navigate to={from} replace />
  return (
    <main className="mx-auto max-w-md px-4 pt-16">
      <h1 className="mb-2 text-3xl font-bold">Leftovers</h1>
      <p className="mb-6 text-neutral-600 dark:text-neutral-400">
        Sign in with your email. We’ll send you a link, so there’s no password to remember.
      </p>
      <SignInForm returnTo={from} />
    </main>
  )
}
