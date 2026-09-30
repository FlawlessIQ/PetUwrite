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
  async send({ to, subject, text, headers }) {
    const h = headers ? `\n${Object.entries(headers).map(([k, v]) => `${k}: ${v}`).join('\n')}` : ''
    console.log(`[email:console] to=${to} subject=${JSON.stringify(subject)}${h}\n${text}`)
    return { delivered: false, provider: 'console' }
  },
}

/**
 * The real provider: SendGrid's v3 HTTP API, over Node's built-in fetch — no
 * SDK, so no new dependency.
 *
 * Turned on only by configuration (see docs/DEPLOYMENT.md → "Switching email
 * on"): EMAIL_PROVIDER=sendgrid, a SENDGRID_API_KEY secret, and EMAIL_FROM on
 * the verified sending domain. Missing any of them it THROWS rather than
 * falling back to the console — a half-configured sender that quietly drops
 * mail is worse than one that says it is not configured.
 *
 * Open and click tracking are switched off per message. Click tracking rewrites
 * every link through SendGrid's servers, which would break the unsubscribe
 * link's one-click POST and tell a third party which reminder somebody opened —
 * not something the Data Covenant lets us hand over.
 */
const SENDGRID_URL = 'https://api.sendgrid.com/v3/mail/send'

function makeSendgridSender({ apiKey, from, fetchImpl = globalThis.fetch, timeoutMs = 10_000 } = {}) {
  return {
    name: 'sendgrid',
    async send({ to, subject, text, headers }) {
      if (!apiKey) throw new Error('SENDGRID_API_KEY is not set')
      if (!from) throw new Error('EMAIL_FROM is not set')
      const controller = new AbortController()
      const timer = setTimeout(() => controller.abort(), timeoutMs)
      try {
        const res = await fetchImpl(SENDGRID_URL, {
          method: 'POST',
          signal: controller.signal,
          headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
          body: JSON.stringify({
            personalizations: [{ to: [{ email: to }] }],
            from: parseFrom(from),
            subject,
            content: [{ type: 'text/plain', value: text }],
            ...(headers && Object.keys(headers).length ? { headers } : {}),
            tracking_settings: {
              click_tracking: { enable: false, enable_text: false },
              open_tracking: { enable: false },
              subscription_tracking: { enable: false },
            },
          }),
        })
        if (!res.ok) {
          // SendGrid's error body names the problem (bad key, unverified sender)
          // and does not echo the recipient, so it is safe to log.
          const detail = await res.text().catch(() => '')
          throw new Error(`SendGrid ${res.status}: ${detail.slice(0, 300)}`)
        }
        return { delivered: true, provider: 'sendgrid', id: res.headers.get('x-message-id') || null }
      } finally {
        clearTimeout(timer)
      }
    },
  }
}

/** "Clovara <hello@example.com>" or a bare address → SendGrid's {email, name}. */
function parseFrom(from) {
  const m = /^\s*(.*?)\s*<([^>]+)>\s*$/.exec(from)
  return m ? { email: m[2], ...(m[1] ? { name: m[1].replace(/^"|"$/g, '') } : {}) } : { email: from.trim() }
}

function sender() {
  if (process.env.EMAIL_PROVIDER !== 'sendgrid') return consoleSender
  return makeSendgridSender({ apiKey: process.env.SENDGRID_API_KEY, from: process.env.EMAIL_FROM })
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

/**
 * Transactional: a pet's plan has just been saved to an account for the first
 * time (Phase B, AO5). Once per person, not per pet — see the trigger.
 */
function planSaved({ petName }) {
  const who = petName || 'your pet'
  return {
    subject: `${who}'s plan is saved`,
    text: [
      `${who}'s plan is in your account now, not just in one browser.`,
      '',
      'Sign in with this email address on your phone or anywhere else and it will',
      'be there — and anyone you invite to your household sees the same plan.',
      SIGN_OFF,
    ].join('\n'),
  }
}

/**
 * A moment that is due (Phase B, AO6) — only ever to somebody who opted in.
 * The subject and paragraphs come from the app's own moment engine
 * (functions/generated/moments.js), so the email says what the app says.
 *
 * Every one carries the way out, and the postal address US law requires in
 * commercial email. The address is counsel's to supply (A2), so it is a marked
 * placeholder rather than a line anyone here drafts.
 */
function moment({ petName, subject, lines, preferencesUrl }) {
  const who = petName || 'your pet'
  return {
    subject: subject || `Something is due for ${who}`,
    text: [
      ...(lines || []).flatMap((l, i) => (i === 0 ? [l] : ['', l])),
      SIGN_OFF,
      '',
      `You get these because you asked for reminders about ${who}.`,
      `Turn them off: ${preferencesUrl || '[preferences link]'}`,
      '[LEGAL-REVIEW: postal address, required in every commercial email — counsel to supply]',
    ].join('\n'),
  }
}

const TEMPLATES = { welcome, trialEnding, planSaved, moment }

/**
 * Renders and hands to the sender. Never throws into the caller: a webhook must
 * not 500 — and be retried by Stripe forever — because an email did not render.
 */
async function sendTemplate(name, to, data, headers) {
  try {
    const template = TEMPLATES[name]
    if (!template) throw new Error(`No email template named ${name}`)
    if (!to) return { delivered: false, provider: 'none', reason: 'no recipient' }
    const { subject, text } = template(data || {})
    return await sender().send({ to, subject, text, headers })
  } catch (err) {
    console.error('sendTemplate failed', name, err?.message)
    return { delivered: false, provider: 'error', reason: err?.message }
  }
}

module.exports = { sendTemplate, TEMPLATES, consoleSender, makeSendgridSender, parseFrom }
