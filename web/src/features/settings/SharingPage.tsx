import { useState } from 'react'
import { Screen } from '../../components/Screen'
import { useAuth, useHouseholdId } from '../../app/auth'
import { getClient } from '../../data/client'
import { createInvite, inviteLink } from '../../data/households'

export function SharingPage() {
  const householdId = useHouseholdId()
  const userId = useAuth().session?.user.id ?? ''
  const [link, setLink] = useState<string | null>(null)
  const [notice, setNotice] = useState('')
  const [busy, setBusy] = useState(false)

  async function invite() {
    setBusy(true)
    setNotice('')
    try {
      const token = await createInvite(getClient(), householdId, userId)
      const url = inviteLink(window.location.origin, token)
      setLink(url)
      if (typeof navigator.share === 'function') {
        try {
          await navigator.share({ title: 'Join my household on Leftovers', url })
        } catch {
          // The share sheet was dismissed; the link stays on screen.
        }
      } else {
        try {
          await navigator.clipboard.writeText(url)
          setNotice('Link copied.')
        } catch {
          setNotice('Copy the link below to share it.')
        }
      }
    } catch {
      setNotice('Couldn’t create an invite. Please try again.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Screen title="Sharing">
      <h2 className="mb-2 font-semibold">Invite someone</h2>
      <p className="mb-3 text-neutral-600 dark:text-neutral-400">
        Share the link with one person. It works once, and they’ll see the same meals, plans and lists as you.
      </p>
      <button
        type="button"
        onClick={() => void invite()}
        disabled={busy}
        className="rounded-lg bg-accent px-4 py-2 font-semibold text-white disabled:opacity-60"
      >
        Invite someone
      </button>
      {link && <p className="mt-3 break-all rounded-lg bg-accent/10 p-3 text-sm">{link}</p>}
      {notice && <p role="status" className="mt-2">{notice}</p>}
    </Screen>
  )
}
