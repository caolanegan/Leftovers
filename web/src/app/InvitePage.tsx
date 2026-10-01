import { useState } from 'react'
import { Link, useParams } from 'react-router'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuth } from './auth'
import { SignInForm } from './SignInPage'
import { getClient } from '../data/client'
import { acceptInvite } from '../data/households'
import { HouseholdError } from '../data/errors'

export function InvitePage() {
  const { token = '' } = useParams()
  const { session, loading } = useAuth()
  const queryClient = useQueryClient()
  const [joined, setJoined] = useState(false)

  // Read-only: has this user got a household already? Signing in from an invite must not create one.
  const membership = useQuery({
    queryKey: ['membership', session?.user.id],
    enabled: Boolean(session),
    queryFn: async () => {
      const { data, error } = await getClient().from('household_member').select('household_id').maybeSingle()
      if (error) throw error
      return data?.household_id as string | undefined
    },
  })

  const join = useMutation({
    mutationFn: () => acceptInvite(getClient(), token),
    onSuccess: async () => {
      setJoined(true)
      await queryClient.invalidateQueries()
    },
  })

  let body
  if (loading || (session && membership.isLoading)) {
    body = <p role="status">Loading…</p>
  } else if (!session) {
    body = (
      <>
        <p className="mb-4">You’ve been invited to share a household. Sign in to join it.</p>
        <SignInForm returnTo={`/invite/${token}`} />
      </>
    )
  } else if (joined) {
    body = (
      <p role="status">
        You’ve joined the household. <Link to="/plan" className="font-medium text-accent underline dark:text-accent-dark">Go to the plan</Link>
      </p>
    )
  } else if (membership.data) {
    body = (
      <p role="status">
        You’re already in a household, so this invite can’t be used. <Link to="/plan" className="font-medium text-accent underline dark:text-accent-dark">Go to the plan</Link>
      </p>
    )
  } else {
    body = (
      <>
        <p className="mb-4">You’ve been invited to share a household.</p>
        <button
          type="button"
          onClick={() => join.mutate()}
          disabled={join.isPending}
          className="rounded-lg bg-accent px-4 py-2 font-semibold text-white disabled:opacity-60"
        >
          Join household
        </button>
        {join.isError && (
          <p role="alert" className="mt-3 text-red-700 dark:text-red-400">
            {join.error instanceof HouseholdError ? join.error.message : 'Something went wrong. Please try again.'}
          </p>
        )}
      </>
    )
  }

  return (
    <main className="mx-auto max-w-md px-4 pt-16">
      <h1 className="mb-4 text-3xl font-bold">Invitation</h1>
      {body}
    </main>
  )
}
