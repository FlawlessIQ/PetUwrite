import { callable } from './callable'

/**
 * The family circle (SPEC §4.3), client side.
 *
 * Both calls are Cloud Functions, not Firestore writes: a client that could add
 * a uid to a household document could add itself to any household it could name.
 * The rules deny clients all access to `life_invites` for the same reason.
 */
export interface InviteResult {
  code: string
  expiresInDays: number
}

export function createInvite(): Promise<InviteResult> {
  return callable<InviteResult>('createHouseholdInvite', {})
}

export function redeemInvite(code: string): Promise<{ householdId: string }> {
  return callable<{ householdId: string }>('redeemHouseholdInvite', { code })
}

/**
 * Turns a callable rejection into something worth reading.
 *
 * The functions throw HttpsError with messages written for people — "That
 * invite has already been used", not a code — so the message is preserved where
 * there is one, and only the unhandled case gets a generic sentence.
 */
export function inviteError(err: unknown): string {
  const e = err as { code?: string; message?: string }
  if (e?.message && !/internal|unknown/i.test(e.message)) {
    return e.message.replace(/^[a-z-]+\/[a-z-]+:?\s*/i, '')
  }
  return 'Something went wrong. Try again in a moment.'
}
