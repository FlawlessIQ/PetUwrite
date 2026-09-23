/**
 * Transactional and lifecycle email — the skeleton (SPEC §3).
 *
 * No live sending in P0, by decision: SENDGRID_API_KEY is unset and there is no
 * audience yet. What exists is the shape — a pluggable sender, pure templates,
 * and the triggers wired to real Stripe events — so turning it on later is a
 * provider swap and a key, not a rewrite.
 *
 * Templates are pure functions returning {subject, text}. They are pure so they
 * can be read, diffed and tested without a network, and because email copy is
 * the kind of thing that quietly drifts out of line with the product otherwise.
 *
 * VOCABULARY (docs/VISION.md, binding): never "lifecycle", "platform" or
 * standalone "wellness" in customer copy; never promise longer life; say
 * "more good years", "on track for", "help". A test asserts it.
 */

/** Renders but does not send. The P0 default. */
const consoleSender = {
  name: 'console',
  async send({ to, subject, text }) {
    console.log(`[email:console] to=${to} subject=${JSON.stringify(subject)}\n${text}`)
    return { delivered: false, provider: 'console' }
  },
}

/**
 * Placeholder for the real provider. Deliberately throws rather than silently
 * doing nothing — a half-wired sender that swallows mail is worse than one that
 * says it is not configured.
 */
const sendgridSender = {
  name: 'sendgrid',
  async send() {
    throw new Error(
      'SendGrid sender is not implemented yet. Set EMAIL_PROVIDER=console until it is.',
    )
  },
}

function sender() {
  return process.env.EMAIL_PROVIDER === 'sendgrid' ? sendgridSender : consoleSender
}

// ───────────────────────────────────────────────────────────────────────────
// Templates
// ───────────────────────────────────────────────────────────────────────────

const SIGN_OFF = [
  '',
  '— Clovara',
  '',
  'Clovara Life shares information to support care decisions. It is not veterinary',
  'advice; your veterinarian decides care.',
].join('\n')

function welcome({ petName }) {
  const who = petName || 'your pet'
  return {
    subject: `${who}'s plan is live`,
    text: [
      `${who} has a plan now.`,
      '',
      'It starts from what you have told us and sharpens every time you add',
      'something — a weight, a condition, a vet visit. Nothing is asked for',
      'unless answering it visibly helps.',
      '',
      'Your free trial runs for seven days. Nothing is charged until it ends,',
      'and cancelling takes one tap from your account.',
      SIGN_OFF,
    ].join('\n'),
  }
}

function trialEnding({ petName, daysLeft, amountDisplay }) {
  const who = petName || 'your pet'
  const when = daysLeft === 0 ? 'today' : daysLeft === 1 ? 'tomorrow' : `in ${daysLeft} days`
  // No amount rather than a wrong one. The price is config (SPEC §1) and may be
  // under test at $19.99–$24.99, so a hardcoded fallback here would eventually
  // tell somebody a number they are not going to be charged.
  const price = amountDisplay
    ? `membership is ${amountDisplay} a month`
    : 'your membership begins at the price shown in your account'
  return {
    subject: `Your Clovara trial ends ${when}`,
    text: [
      `Your free trial ends ${when}. After that, ${price}.`,
      '',
      `Nothing about ${who}'s plan goes away if you stop — the plan, the risks and`,
      'the care schedule stay where they are. Membership is what unlocks member',
      'pricing, redeeming points, and the deeper care guidance.',
      '',
      'Cancel or change your card any time from your account. One tap, no email',
      'to write.',
      SIGN_OFF,
    ].join('\n'),
  }
}

const TEMPLATES = { welcome, trialEnding }

/**
 * Renders and hands to the sender. Never throws into the caller: a webhook must
 * not 500 — and be retried by Stripe forever — because an email did not render.
 */
async function sendTemplate(name, to, data) {
  try {
    const template = TEMPLATES[name]
    if (!template) throw new Error(`No email template named ${name}`)
    if (!to) return { delivered: false, provider: 'none', reason: 'no recipient' }
    const { subject, text } = template(data || {})
    return await sender().send({ to, subject, text })
  } catch (err) {
    console.error('sendTemplate failed', name, err?.message)
    return { delivered: false, provider: 'error', reason: err?.message }
  }
}

module.exports = { sendTemplate, TEMPLATES, consoleSender, sendgridSender }
