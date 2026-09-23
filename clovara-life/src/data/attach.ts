/**
 * Attach-flow content (SPEC §5): waiting periods, the pre-existing picture, and
 * the disclosures.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * LEGAL-REVIEW. Everything in DISCLOSURES and FRAUD_NOTICE below is placeholder
 * copy standing in for documents counsel has to write and a carrier has to
 * file. It is written to be honest rather than to be final, and it must not
 * ship to a real customer as it stands.
 *
 * Questions for counsel:
 *  1. The fraud notice differs by state and several states mandate specific
 *     wording. Which set applies, and does it vary by the filing?
 *  2. Is a scroll-to-enable attestation sufficient evidence of disclosure, or
 *     is a separate signed acknowledgement required?
 *  3. Waiting periods below are typical of the US market. The filed ones govern
 *     and will replace them.
 *  4. The orthopaedic waiting period is commonly waivable after an examination.
 *     Do we offer that, and who pays for the exam?
 * ═══════════════════════════════════════════════════════════════════════════
 */

export interface WaitingPeriod {
  id: string
  label: string
  days: number
  because: string
}

/** LEGAL-REVIEW: typical of the market; the filed periods govern. */
export const WAITING_PERIODS: WaitingPeriod[] = [
  {
    id: 'accident',
    label: 'Accidents',
    days: 3,
    because: 'Short, because an accident is not something anyone saw coming.',
  },
  {
    id: 'illness',
    label: 'Illness',
    days: 14,
    because:
      'Long enough that a policy cannot be bought for something already brewing, which is what keeps it affordable for everyone else.',
  },
  {
    id: 'orthopaedic',
    label: 'Cruciate and other orthopaedic conditions',
    days: 180,
    because:
      'The longest one, and the one worth knowing about before you need it. Joint problems develop slowly and are the most commonly claimed-for thing in large dogs.',
  },
]

/** LEGAL-REVIEW: placeholder. Counsel writes these. */
export const DISCLOSURES = [
  {
    id: 'pre-existing',
    heading: 'Anything already there is not covered',
    body: 'A condition that showed signs before your policy started, or during a waiting period, is not covered — whether or not it had been diagnosed. This is the single most common reason a claim is declined, and it is why the page before this one lists what we already know about.',
  },
  {
    id: 'illustrative',
    heading: 'This price is illustrative',
    body: 'Rates have not been filed with your state regulator yet. The figure shown is our best current estimate of what the filed rate will be, and the price you are actually offered may differ.',
  },
  {
    id: 'separate',
    heading: 'Insurance is separate from membership',
    body: 'Your Clovara membership and your insurance premium are two different things, billed as two different lines. Cancelling one does not cancel the other, and membership points never reduce a premium.',
  },
  {
    id: 'renewal',
    heading: 'It renews, and the price can change',
    body: 'The policy renews annually. The premium at renewal reflects your pet getting older, claims experience, and any change to our filed rates — never anything measured by a tracker or said to the companion.',
  },
  {
    id: 'cancel',
    heading: 'You can cancel',
    body: 'Cancel at any time. Depending on your state you may be entitled to a refund of unearned premium; the policy documents set out how that is calculated.',
  },
]

/** LEGAL-REVIEW: several states mandate specific wording. Placeholder. */
export const FRAUD_NOTICE =
  'Any person who knowingly and with intent to defraud an insurer files a claim or application containing materially false information, or conceals information concerning any material fact, commits a fraudulent insurance act, which is a crime and may subject that person to criminal and civil penalties. State-specific wording will replace this notice once filings are complete.'

export const ATTESTATION =
  'Everything I have told Clovara about my pet is accurate as far as I know, and I have read what is and is not covered.'

export const ILLUSTRATIVE_LABEL =
  'Illustrative — rates are not yet filed. This is an estimate, not an offer.'

/**
 * The reverse bridge (SPEC §5, Path B): the post-bind offer of a membership
 * trial to somebody who came through the web quote flow.
 *
 * The VAS free-months variant is gated OFF until counsel confirms the state
 * list — offering free months as an inducement to buy insurance is a
 * rebating question in several states, not a marketing decision.
 */
export const REVERSE_BRIDGE_ENABLED = false
export const REVERSE_BRIDGE_VAS_FREE_MONTHS_ENABLED = false
