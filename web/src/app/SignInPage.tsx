import { useState, type FormEvent } from 'react'
import { Navigate, useLocation } from 'react-router'
import { useAuth } from './auth'
import { getClient } from '../data/client'
import { sendSignInEmail, verifySignInCode } from '../data/auth'

const inputClass =
  'w-full rounded-lg border border-neutral-300 bg-white px-3 py-2 dark:border-neutral-700 dark:bg-neutral-900'
const buttonClass = 'rounded-lg bg-accent px-4 py-2 font-semibold text-white disabled:opacity-60'

/**
 * Email form, then a code form. Shared by /sign-in and the signed-out view of /invite/:token.
 * Signing in with the code keeps the session in this app, which matters for iPhone home-screen apps (W4).
 */
export function SignInForm({ returnTo }: { returnTo: string }) {
  const [email, setEmail] = useState('')
  const [code, setCode] = useState('')
  const [step, setStep] = useState<'email' | 'code'>('email')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function run(action: () => Promise<void>) {
    setBusy(true)
    setError(null)
    try {
      await action()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Something went wrong. Please try again.')
    } finally {
      setBusy(false)
    }
  }

  function send(event: FormEvent) {
    event.preventDefault()
    void run(async () => {
      await sendSignInEmail(getClient(), email.trim(), window.location.origin + returnTo)
      setCode('')
      setStep('code')
    })
  }

  // On success the auth listener picks up the session, and the page moves on by itself.
  function verify(event: FormEvent) {
    event.preventDefault()
    void run(() => verifySignInCode(getClient(), email.trim(), code.trim()))
  }

  const errorText = error && (
    <p role="alert" className="text-red-700 dark:text-red-400">
      {error}
    </p>
  )

  if (step === 'code') {
    return (
      <form onSubmit={verify} className="space-y-3">
        <p role="status" className="rounded-lg bg-accent/10 p-4">
          We’ve emailed a 6-digit code and a sign-in link to <strong>{email.trim()}</strong>. Enter the code here,
          or open the link in this browser.
        </p>
        <label className="block">
          <span className="mb-1 block font-medium">Code from the email</span>
          <input
            required
            inputMode="numeric"
            autoComplete="one-time-code"
            pattern="[0-9]{6}"
            maxLength={6}
            value={code}
            onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
            className={`${inputClass} text-lg tracking-widest`}
          />
        </label>
        <div className="flex flex-wrap items-center gap-3">
          <button type="submit" disabled={busy} className={buttonClass}>
            {busy ? 'Signing in…' : 'Sign in'}
          </button>
          <button
            type="button"
            onClick={() => {
              setStep('email')
              setError(null)
            }}
            className="rounded-lg px-2 py-2 font-medium text-accent underline dark:text-accent-dark"
          >
            Use a different email
          </button>
        </div>
        {errorText}
      </form>
    )
  }

  return (
    <form onSubmit={send} className="space-y-3">
      <label className="block">
        <span className="mb-1 block font-medium">Email address</span>
        <input
          type="email"
          required
          autoComplete="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className={inputClass}
        />
      </label>
      <button type="submit" disabled={busy} className={buttonClass}>
        {busy ? 'Sending…' : 'Email me a sign-in code'}
      </button>
      {errorText}
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
        Sign in with your email. We’ll send you a code, so there’s no password to remember.
      </p>
      <SignInForm returnTo={from} />
    </main>
  )
}
