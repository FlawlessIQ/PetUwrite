import { useCallback, useEffect, useRef, useState } from 'react'
import type { User } from '../auth/firebase'
import { entitlementFrom, isMember, NO_ENTITLEMENT, type Entitlement } from './membership'
import { track } from '../analytics/track'

/**
 * The household's membership, watched live.
 *
 * A listener rather than a one-shot read, because of the return from Checkout:
 * someone comes back from Stripe's page seconds before the webhook writes their
 * entitlement. With a read they would land on a page that still says "start
 * your trial" after they just started one, and the fix would be "reload". With
 * a listener the screen corrects itself when the webhook lands.
 */
export interface MembershipState {
  entitlement: Entitlement
  member: boolean
  /** True until the first snapshot arrives, so the UI can avoid flashing a gate. */
  loading: boolean
  /** Sends the browser to hosted Checkout. */
  beginTrial: () => Promise<void>
  /** Sends the browser to the hosted Customer Portal. */
  manage: () => Promise<void>
  busy: boolean
  error: string | null
}

export function useMembership(user: User | null, householdId: string | null): MembershipState {
  const [entitlement, setEntitlement] = useState<Entitlement>(NO_ENTITLEMENT)
  const [loading, setLoading] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const unsub = useRef<(() => void) | null>(null)

  useEffect(() => {
    unsub.current?.()
    unsub.current = null
    if (!user || !householdId) {
      setEntitlement(NO_ENTITLEMENT)
      setLoading(false)
      return
    }
    let cancelled = false
    setLoading(true)
    ;(async () => {
      try {
        const [{ getApps, getApp, initializeApp }, fs] = await Promise.all([
          import('firebase/app'),
          import('firebase/firestore'),
        ])
        const { FIREBASE_CONFIG } = await import('../auth/config')
        const app = getApps().length ? getApp() : initializeApp(FIREBASE_CONFIG)
        const db = fs.getFirestore(app)
        if (import.meta.env.VITE_USE_EMULATORS === '1') {
          try {
            fs.connectFirestoreEmulator(db, '127.0.0.1', 8080)
          } catch {
            /* already connected */
          }
        }
        if (cancelled) return
        unsub.current = fs.onSnapshot(
          fs.doc(db, 'households', householdId),
          (snap) => {
            setEntitlement(entitlementFrom(snap.data()?.entitlement))
            setLoading(false)
          },
          () => setLoading(false),
        )
      } catch {
        if (!cancelled) setLoading(false)
      }
    })()
    return () => {
      cancelled = true
      unsub.current?.()
      unsub.current = null
    }
  }, [user, householdId])

  /** Both journeys are the same shape: ask a function for a URL, then go there. */
  const go = useCallback(async (which: 'trial' | 'manage') => {
    setBusy(true)
    setError(null)
    try {
      const m = await import('./membership')
      const url = which === 'trial' ? await m.startTrial() : await m.manageMembership()
      if (which === 'trial') track('attach_offer_viewed', { surface: 'membership_checkout' })
      window.location.assign(url)
    } catch (err) {
      setError(
        which === 'trial'
          ? "We couldn't open checkout just now. Try again in a moment."
          : "We couldn't open your billing settings just now. Try again in a moment.",
      )
      setBusy(false)
      void err
    }
  }, [])

  return {
    entitlement,
    member: isMember(entitlement),
    loading,
    beginTrial: () => go('trial'),
    manage: () => go('manage'),
    busy,
    error,
  }
}
