import { Navigate, Outlet, useLocation } from 'react-router'
import { useQuery } from '@tanstack/react-query'
import { HouseholdProvider, useAuth } from './auth'
import { getClient } from '../data/client'
import { ensureHousehold } from '../data/households'

function Message({ children }: { children: string }) {
  return <p role="status" className="p-6 text-neutral-600 dark:text-neutral-400">{children}</p>
}

/** Everything below this needs a signed-in user; the first sign-in creates their household. */
export function AuthGate() {
  const { session, loading } = useAuth()
  const location = useLocation()
  const userId = session?.user.id

  const household = useQuery({
    queryKey: ['household', userId],
    queryFn: () => ensureHousehold(getClient()),
    enabled: Boolean(userId),
    staleTime: Infinity,
  })

  if (loading) return <Message>Loading…</Message>
  if (!session) {
    return <Navigate to="/sign-in" replace state={{ from: location.pathname + location.search }} />
  }
  if (household.isError) return <Message>Couldn’t set up your household. Please reload.</Message>
  if (!household.data) return <Message>Loading…</Message>
  return (
    <HouseholdProvider value={household.data}>
      <Outlet />
    </HouseholdProvider>
  )
}
