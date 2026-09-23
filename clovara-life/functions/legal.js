/**
 * ═══════════════════════════════════════════════════════════════════════════
 * LEGAL-REVIEW — PLACEHOLDER COPY. NOT REVIEWED. NOT FINAL.
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * SPEC §3 requires CA/NY automatic-renewal disclosure at checkout, and SPEC §8
 * requires legal-adjacent copy to ship marked `LEGAL-REVIEW` and be listed for
 * Conor's counsel. This file exists so there is exactly one place to replace.
 *
 * What counsel needs to rule on, not what we have decided:
 *
 *  1. California ARL (Bus & Prof Code §17600 et seq.) and New York GBL §527-a
 *     both require clear and conspicuous disclosure of the auto-renewing terms
 *     BEFORE the subscription is agreed, affirmative consent to those terms,
 *     and an acknowledgement the consumer can retain. The text below is a
 *     plain-language sketch of the shape, not filed or reviewed language.
 *  2. Whether disclosure is shown to everyone or only to CA/NY residents. Shown
 *     to everyone here, deliberately — geolocating consumers to decide who gets
 *     told the truth about billing is a bad look and a worse defence.
 *  3. The cancellation mechanism wording. Cancellation is the Stripe customer
 *     portal, which is one tap and self-serve, but counsel should confirm the
 *     "cancel any time, effective at period end" framing.
 *  4. Whether the trial-to-paid transition needs its own separate reminder
 *     under either statute, and the notice period if so.
 *
 * Nothing here is shown as a rate, a quote, or an insurance term. This is the
 * MEMBERSHIP fee only — insurance premium is a separate Stripe product and a
 * separate disclosure surface entirely (invariant 2).
 */

const LEGAL_REVIEW = 'LEGAL-REVIEW'

/**
 * Checkout disclosure. Stripe caps `custom_text.submit.message` at 1200
 * characters, so this must stay short — counsel's full language, if longer,
 * belongs on a linked terms page with a pointer from here.
 */
function autoRenewalDisclosure({ amount, interval, trialDays }) {
  return [
    `After your ${trialDays}-day free trial, this membership renews automatically at ${amount} per ${interval} until you cancel.`,
    'You can cancel any time from your account; cancelling stops the next charge and you keep access to the end of the period you have paid for.',
    'This is the Clovara membership fee only. It is not insurance and it is not a premium.',
  ].join(' ')
}

/** Shown above the pay button. Stripe caps this at 1200 characters too. */
function membershipSeparationNotice() {
  return 'Membership only. Any insurance you choose later is a separate product, billed separately, and shown as its own line.'
}

module.exports = { LEGAL_REVIEW, autoRenewalDisclosure, membershipSeparationNotice }
