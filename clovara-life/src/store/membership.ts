/**
 * Membership: reading entitlement, and the two hosted Stripe journeys.
 *
 * Like every other Firebase touchpoint in this app, the SDK is imported
 * dynamically so the signed-out demo never loads it. Nothing here runs unless
 * someone is signed in and looking at their own account.
 *
 * There is no Stripe.js and no publishable key. Both journeys are hosted pages:
 * we ask a Cloud Function for a URL and send the browser there. Cancellation,
 * payment-method updates, dunning and retries are then Stripe's flows rather
 * than screens we build and have to keep correct.
 */
import { FIREBASE_CONFIG } from '../auth/config'

/**
 * What Stripe says about this household, as written by the webhook.
 *
 * Clients cannot write this — the rules deny it. If they could, a member could
 * unlock member-only surfaces by editing their own household document.
 */
export interface Entitlement {
  status: 'none' | 'trialing' | 'active' | 'past_due' | 'canceled' | 'incomplete' | 'unpaid'
  trialEnd: string | null
  currentPeriodEnd: string | null
  cancelAtPeriodEnd: boolean
  priceId: string | null
}

export const NO_ENTITLEMENT: Entitlement = {
  status: 'none',
  trialEnd: null,
  currentPeriodEnd: null,
  cancelAtPeriodEnd: false,
  priceId: null,
}

/**
 * Does this entitlement unlock member-only surfaces?
 *
 * Pure, and deliberately generous at the edges: `trialing` is a member,
 * `past_due` is still a member. Someone whose card failed this morning has not
 * stopped being a customer, and locking them out is how a recoverable payment
 * problem becomes a cancellation. Stripe's dunning gets its chance first; the
 * webhook moves them to `canceled` if it runs out.
 */
export function isMember(e: Entitlement | null | undefined): boolean {
  if (!e) return false
  return e.status === 'trialing' || e.status === 'active' || e.status === 'past_due'
}

/** Days left of trial, or null if not trialing. For the "trial ending" nudge. */
export function trialDaysLeft(e: Entitlement | null | undefined, now: Date): number | null {
  if (!e || e.status !== 'trialing' || !e.trialEnd) return null
  const ms = new Date(e.trialEnd).getTime() - now.getTime()
  if (!Number.isFinite(ms)) return null
  return Math.max(0, Math.ceil(ms / 86_400_000))
}

/** Reads whatever the webhook last wrote, defensively. */
export function entitlementFrom(raw: unknown): Entitlement {
  if (!raw || typeof raw !== 'object') return NO_ENTITLEMENT
  const e = raw as Record<string, unknown>
  const statuses = ['none', 'trialing', 'active', 'past_due', 'canceled', 'incomplete', 'unpaid']
  const str = (v: unknown) => (typeof v === 'string' ? v : null)
  return {
    status: (typeof e.status === 'string' && statuses.includes(e.status)
      ? e.status
      : 'none') as Entitlement['status'],
    trialEnd: str(e.trialEnd),
    currentPeriodEnd: str(e.currentPeriodEnd),
    cancelAtPeriodEnd: e.cancelAtPeriodEnd === true,
    priceId: str(e.priceId),
  }
}

async function callable(name: string): Promise<string> {
  const [{ getApps, getApp, initializeApp }, fns] = await Promise.all([
    import('firebase/app'),
    import('firebase/functions'),
  ])
  const app = getApps().length ? getApp() : initializeApp(FIREBASE_CONFIG)
  const functions = fns.getFunctions(app, 'us-central1')
  if (import.meta.env.VITE_USE_EMULATORS === '1') {
    try {
      fns.connectFunctionsEmulator(functions, '127.0.0.1', 5001)
    } catch {
      /* already connected */
    }
  }
  const fn = fns.httpsCallable<unknown, { url?: string }>(functions, name)
  const res = await fn({})
  const url = res.data?.url
  if (!url) throw new Error(`${name} returned no url`)
  return url
}

/** Hosted Checkout. Starts the 7-day trial. */
export function startTrial(): Promise<string> {
  return callable('createCheckoutSession')
}

/** Hosted Customer Portal — cancel, pause, change card. */
export function manageMembership(): Promise<string> {
  return callable('createPortalSession')
}
