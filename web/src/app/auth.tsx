import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { getClient } from '../data/client'

type AuthState = { session: Session | null; loading: boolean }

const AuthContext = createContext<AuthState>({ session: null, loading: true })

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ session: null, loading: true })

  useEffect(() => {
    const client = getClient()
    const { data } = client.auth.onAuthStateChange((_event, session) => {
      setState({ session, loading: false })
    })
    return () => data.subscription.unsubscribe()
  }, [])

  const value = useMemo(() => state, [state])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthState {
  return useContext(AuthContext)
}

const HouseholdContext = createContext<string | null>(null)
export const HouseholdProvider = HouseholdContext.Provider

/** The signed-in user's household id. Only valid below the signed-in gate. */
export function useHouseholdId(): string {
  const id = useContext(HouseholdContext)
  if (!id) throw new Error('useHouseholdId used outside the signed-in gate')
  return id
}
