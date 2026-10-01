import { createClient, type SupabaseClient } from '@supabase/supabase-js'

export type Client = SupabaseClient

/** Builds a client for the given project. Tests use this with the local stack's keys. */
export function createSupabaseClient(url: string, anonKey: string): Client {
  return createClient(url, anonKey)
}

let shared: Client | undefined

/** The app's single browser client, built from the VITE_ variables (anon key only, SPEC W3.1). */
export function getClient(): Client {
  if (!shared) {
    const url = import.meta.env.VITE_SUPABASE_URL
    const key = import.meta.env.VITE_SUPABASE_ANON_KEY
    if (!url || !key) {
      throw new Error('Missing VITE_SUPABASE_URL or VITE_SUPABASE_ANON_KEY. See .env.example.')
    }
    shared = createSupabaseClient(url, key)
  }
  return shared
}
