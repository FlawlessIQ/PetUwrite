/**
 * Clovara Life — Cloud Functions (codebase: "life").
 *
 * Deliberately a separate codebase from the underwriting functions in
 * /functions, so `firebase deploy --only functions:life` never has the
 * underwriting functions in its deploy set. Nothing here imports anything from
 * there and nothing there imports anything from here.
 *
 * Stripe is hosted Checkout and hosted Customer Portal, by design: no
 * client-side Stripe dependency, no publishable key, and dunning, retries,
 * cancellation and payment-method updates are Stripe's flows rather than UI we
 * build and maintain (DECISIONS 2026-09-23).
 */
const { setGlobalOptions } = require('firebase-functions/v2')
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https')
const { defineSecret } = require('firebase-functions/params')
const Stripe = require('stripe')

const {
  db,
  HOUSEHOLDS,
  readPricing,
  ensureHousehold,
  householdByCustomer,
  writeEntitlement,
  entitlementFromSubscription,
  trackServer,
} = require('./shared')
const { autoRenewalDisclosure, membershipSeparationNotice } = require('./legal')
const { sendTemplate } = require('./email')
const { createInvite, redeemInvite } = require('./household')
const {
  createSitterLink,
  revokeSitterLink,
  listSitterLinks,
  readSitterCard,
} = require('./sitter')
const { parseWithGemini } = require('./gemini')
const { composeReply } = require('./compose')

setGlobalOptions({ region: 'us-central1', maxInstances: 10 })

const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY')
const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET')
// Life-scoped, so the underwriting app's GEMINI_API_KEY can rotate
// independently and neither app can break the other.
const LIFE_GEMINI_API_KEY = defineSecret('LIFE_GEMINI_API_KEY')

/**
 * In the emulator, secrets fall through to the shell environment so the whole
 * flow can be exercised locally with the test key. In production they come from
 * Secret Manager and the environment is never consulted.
 */
const isEmulator = () => !!process.env.FUNCTIONS_EMULATOR
const secret = (param, envName) => {
  const v = isEmulator() ? process.env[envName] : param.value()
  if (!v) throw new HttpsError('failed-precondition', `${envName} is not configured.`)
  return v
}

const stripeClient = () =>
  new Stripe(secret(STRIPE_SECRET_KEY, 'STRIPE_SECRET_KEY'), { apiVersion: '2024-06-20' })

/** Where Checkout and the portal send people back to. */
function returnOrigin(req) {
  const origin = req?.rawRequest?.headers?.origin
  const allowed = ['https://clovara-life.web.app', 'http://localhost:4173', 'http://127.0.0.1:4173', 'http://localhost:5173']
  return allowed.includes(origin) ? origin : 'https://clovara-life.web.app'
}

// ───────────────────────────────────────────────────────────────────────────
// Start a trial
// ───────────────────────────────────────────────────────────────────────────

exports.createCheckoutSession = onCall(
  { secrets: [STRIPE_SECRET_KEY], cors: true },
  async (req) => {
    const uid = req.auth?.uid
    if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.')
    const email = req.auth.token?.email || undefined

    const stripe = stripeClient()
    const pricing = await readPricing()
    const household = await ensureHousehold(uid)

    // One Stripe customer per household, reused forever. Creating a second one
    // would split their billing history and break the portal.
    let customerId = household.entitlement?.stripeCustomerId
    if (!customerId) {
      const customer = await stripe.customers.create({
        email,
        metadata: { uid, householdId: household.id, product: 'clovara-life-membership' },
      })
      customerId = customer.id
      await writeEntitlement(household.id, {
        status: household.entitlement?.status ?? 'none',
        stripeCustomerId: customerId,
      })
    }

    const origin = returnOrigin(req)
    const session = await stripe.checkout.sessions.create({
      mode: 'subscription',
      customer: customerId,
      // EXACTLY ONE LINE ITEM, and it is the membership. Insurance is a
      // separate Stripe product on a separate session — invariant 2 requires
      // premium to be a separate line in UI, in Stripe and in receipts, and
      // that is not something to retrofit.
      line_items: [{ price: pricing.priceId, quantity: 1 }],
      subscription_data: {
        trial_period_days: pricing.trialDays,
        metadata: { uid, householdId: household.id },
      },
      client_reference_id: household.id,
      metadata: { uid, householdId: household.id },
      allow_promotion_codes: true,
      // LEGAL-REVIEW placeholder copy — see legal.js.
      custom_text: {
        submit: {
          message: autoRenewalDisclosure({
            amount: pricing.amountDisplay || 'the membership price',
            interval: pricing.interval,
            trialDays: pricing.trialDays,
          }),
        },
        after_submit: { message: membershipSeparationNotice() },
      },
      success_url: `${origin}/?checkout=done#/`,
      cancel_url: `${origin}/?checkout=cancelled#/`,
    })

    await trackServer(uid, 'attach_offer_viewed', { surface: 'membership_checkout' })
    return { url: session.url }
  },
)

// ───────────────────────────────────────────────────────────────────────────
// Manage or cancel — Stripe's own portal, so dunning and cancellation are not
// flows we hand-roll.
// ───────────────────────────────────────────────────────────────────────────

exports.createPortalSession = onCall(
  { secrets: [STRIPE_SECRET_KEY], cors: true },
  async (req) => {
    const uid = req.auth?.uid
    if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.')

    const household = await ensureHousehold(uid)
    const customerId = household.entitlement?.stripeCustomerId
    if (!customerId) throw new HttpsError('failed-precondition', 'No membership to manage yet.')

    const stripe = stripeClient()
    const session = await stripe.billingPortal.sessions.create({
      customer: customerId,
      return_url: `${returnOrigin(req)}/#/`,
    })
    return { url: session.url }
  },
)

// ───────────────────────────────────────────────────────────────────────────
// Webhook — the only thing that may grant entitlement
// ───────────────────────────────────────────────────────────────────────────

/**
 * Stripe is the authority on subscription state; this is how it tells us.
 *
 * The signature check is not optional and there is no unsigned path: without
 * it, anyone who found the URL could POST themselves a subscription. Note the
 * raw body — Express's parsed body would fail verification, which is why v2's
 * `req.rawBody` is used rather than `req.body`.
 */
exports.stripeWebhook = onRequest(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET], cors: false },
  async (req, res) => {
    let event
    try {
      const stripe = new Stripe(
        isEmulator() ? process.env.STRIPE_SECRET_KEY : STRIPE_SECRET_KEY.value(),
        { apiVersion: '2024-06-20' },
      )
      const whsec = isEmulator()
        ? process.env.STRIPE_WEBHOOK_SECRET
        : STRIPE_WEBHOOK_SECRET.value()
      event = stripe.webhooks.constructEvent(req.rawBody, req.headers['stripe-signature'], whsec)
    } catch (err) {
      console.error('webhook signature verification failed:', err?.message)
      res.status(400).send(`Webhook Error: ${err?.message}`)
      return
    }

    try {
      await handleEvent(event)
      res.json({ received: true })
    } catch (err) {
      // 500 so Stripe retries. Swallowing this would leave someone paying for
      // a membership the app does not believe they have.
      console.error('webhook handler failed', event?.type, err?.message)
      res.status(500).send('handler failed')
    }
  },
)

async function handleEvent(event) {
  const obj = event.data?.object ?? {}

  switch (event.type) {
    case 'customer.subscription.created':
    case 'customer.subscription.updated':
    case 'customer.subscription.deleted': {
      const ent = entitlementFromSubscription(obj)
      const householdId = obj.metadata?.householdId
      const uid = obj.metadata?.uid
      const target = householdId
        ? { id: householdId }
        : await householdByCustomer(ent.stripeCustomerId)
      if (!target) {
        console.warn('no household for customer', ent.stripeCustomerId)
        return
      }
      await writeEntitlement(target.id, ent)

      if (event.type === 'customer.subscription.created' && ent.status === 'trialing') {
        await trackServer(uid, 'trial_started', { price_id: ent.priceId, trial_end: ent.trialEnd })
        await sendTemplate('welcome', await emailFor(ent.stripeCustomerId), {})
      }
      if (event.type === 'customer.subscription.deleted') {
        await trackServer(uid, ent.trialEnd ? 'trial_cancelled' : 'subscription_cancelled', {
          price_id: ent.priceId,
        })
      }
      if (event.type === 'customer.subscription.updated' && ent.cancelAtPeriodEnd) {
        await trackServer(uid, 'subscription_cancelled', {
          price_id: ent.priceId,
          effective: ent.currentPeriodEnd,
          at_period_end: true,
        })
      }
      return
    }

    // Stripe's own three-days-out warning. Using it means the trial-ending email
    // needs no scheduler of ours, and it fires from the same source of truth
    // that decides when the trial actually ends.
    case 'customer.subscription.trial_will_end': {
      const ent = entitlementFromSubscription(obj)
      const days = ent.trialEnd
        ? Math.max(0, Math.ceil((new Date(ent.trialEnd).getTime() - Date.now()) / 86400000))
        : null
      const pricing = await readPricing().catch(() => ({ amountDisplay: null }))
      await sendTemplate('trialEnding', await emailFor(ent.stripeCustomerId), {
        daysLeft: days ?? 3,
        amountDisplay: pricing.amountDisplay,
      })
      return
    }

    case 'invoice.payment_failed': {
      const customerId = typeof obj.customer === 'string' ? obj.customer : obj.customer?.id
      const household = await householdByCustomer(customerId)
      if (!household) return
      // Stripe's own dunning takes it from here — retries and emails are its
      // job, not ours. We record it so churn is measurable.
      await trackServer(household.createdBy, 'payment_failed', {
        attempt: obj.attempt_count ?? null,
        amount_due: obj.amount_due ?? null,
      })
      return
    }

    default:
      // Everything else is deliberately ignored rather than logged as an error.
      return
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Family circle
// ───────────────────────────────────────────────────────────────────────────

exports.createHouseholdInvite = onCall({ cors: true }, async (req) => {
  const uid = req.auth?.uid
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.')
  return createInvite(uid, req.auth.token?.email)
})

exports.redeemHouseholdInvite = onCall({ cors: true }, async (req) => {
  const uid = req.auth?.uid
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.')
  return redeemInvite(uid, req.data?.code)
})

/** The address Stripe holds for a customer. Email is never read from our side. */
async function emailFor(customerId) {
  if (!customerId) return null
  try {
    const stripe = stripeClient()
    const c = await stripe.customers.retrieve(customerId)
    return c?.deleted ? null : (c?.email ?? null)
  } catch {
    return null
  }
}

/** Health probe, so a deploy can be confirmed without touching Stripe. */
/**
 * "Tell me about him" (SPEC §4.3), server-side so the key never reaches a
 * browser.
 *
 * Returns CANDIDATES for confirm-chips, never stored data (invariant 8). The
 * client cannot write any of it to a pet without going through `confirm()`.
 */
exports.parseAboutPet = onCall(
  { secrets: [LIFE_GEMINI_API_KEY], cors: true },
  async (req) => {
    if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.')
    return parseWithGemini(req.data?.text, LIFE_GEMINI_API_KEY.value())
  },
)

/**
 * C3 — model composition (SPEC-COMPANION §3.3). Refuses while the flag is off.
 *
 * The client still runs verification over whatever comes back: the gate is not
 * the prompt and not the schema, it is the pure function on the other side.
 */
exports.composeCompanionReply = onCall(
  { secrets: [LIFE_GEMINI_API_KEY], cors: true },
  async (req) => {
    if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.')
    return composeReply(
      {
        utterance: req.data?.utterance,
        facts: req.data?.facts,
        petName: req.data?.petName,
      },
      LIFE_GEMINI_API_KEY.value(),
    )
  },
)

// ── Sitter Mode (SPEC §6.6) ────────────────────────────────────────────────
exports.createSitterLink = onCall({ cors: true }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.')
  return createSitterLink(req.auth.uid, req.data?.petId, req.data?.days)
})

exports.revokeSitterLink = onCall({ cors: true }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.')
  return revokeSitterLink(req.auth.uid, req.data?.token)
})

exports.listSitterLinks = onCall({ cors: true }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.')
  return { links: await listSitterLinks(req.auth.uid) }
})

/**
 * The only unauthenticated read path in the product.
 *
 * Deliberately an onRequest rather than an onCall: the person opening it is a
 * dog-sitter with a link, not a signed-in user, and the callable protocol
 * expects an SDK. Expired, revoked and never-existed all return the same 404 so
 * this cannot be used as an oracle for guessing tokens.
 */
exports.sitterCard = onRequest({ cors: true }, async (req, res) => {
  res.set('Cache-Control', 'no-store')
  const token = String(req.query.t || '')
  const found = await readSitterCard(token)
  if (!found) {
    res.status(404).json({ error: 'not-found' })
    return
  }
  res.json(found)
})

exports.lifeHealth = onRequest({ cors: true }, async (_req, res) => {
  const pricing = await readPricing().catch((e) => ({ error: e.message }))
  res.json({
    ok: true,
    codebase: 'life',
    pricingConfigured: !pricing.error,
    households: (await db.collection(HOUSEHOLDS).limit(1).get()).size >= 0,
  })
})

// ═══════════════════════════════════════════════════════════════════════════
// Moment emails (ACQUISITION-ONBOARDING-PLAN Phase B, AO5–AO6)
//
// Built and tested behind the console sender: nothing is delivered until a
// sending domain and a provider key exist (EMAIL_PROVIDER stays 'console').
// Opt-in is off by default and lives in `life_prefs/{uid}`, which no client
// rule matches — only these functions read or write it.
// ═══════════════════════════════════════════════════════════════════════════

const { onSchedule } = require('firebase-functions/v2/scheduler')
const { onDocumentCreated } = require('firebase-functions/v2/firestore')
const { getAuth } = require('firebase-admin/auth')
const { randomBytes } = require('node:crypto')
const { runMoments } = require('./moments-job')

const PREFS = 'life_prefs'
const PREFERENCES_URL = `https://us-central1-${process.env.GCLOUD_PROJECT || 'pet-underwriter-ai'}.cloudfunctions.net/emailPreferences`
const newToken = () => randomBytes(24).toString('base64url')

exports.getEmailPrefs = onCall({ cors: true }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.')
  const snap = await db.collection(PREFS).doc(req.auth.uid).get()
  return { moments: snap.exists && snap.get('moments') === true }
})

exports.setEmailPrefs = onCall({ cors: true }, async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Sign in first.')
  if (typeof req.data?.moments !== 'boolean') throw new HttpsError('invalid-argument', 'moments must be true or false.')
  const ref = db.collection(PREFS).doc(req.auth.uid)
  const snap = await ref.get()
  await ref.set(
    {
      moments: req.data.moments,
      updatedAt: new Date().toISOString(),
      // One per person, kept for good: the unsubscribe link in an old email
      // must still work.
      unsubscribeToken: (snap.exists && snap.get('unsubscribeToken')) || newToken(),
    },
    { merge: true },
  )
  await trackServer(req.auth.uid, 'email_prefs_changed', { moments: req.data.moments })
  return { moments: req.data.moments }
})

const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c])
const page = (title, body) =>
  `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(title)}</title>` +
  `<style>body{font-family:system-ui,sans-serif;background:#F6F3EA;color:#1B1E1B;margin:0;padding:48px 20px}main{max-width:520px;margin:auto}h1{font-family:Georgia,serif;font-weight:600}button{background:#1A5C38;color:#fff;border:0;border-radius:999px;padding:12px 22px;font-size:16px}p{line-height:1.6;color:#5C635C}</style></head><body><main>${body}</main></body></html>`

/**
 * The link at the foot of every moment email. GET shows a page with a button;
 * the change happens on POST, because mail scanners follow links on their own
 * and would otherwise unsubscribe people who never asked. Mail apps that
 * support RFC 8058 POST here directly ("List-Unsubscribe=One-Click").
 */
exports.emailPreferences = onRequest(async (req, res) => {
  res.set('Cache-Control', 'no-store')
  const token = String(req.query.t || req.body?.t || '')
  const found = token ? await db.collection(PREFS).where('unsubscribeToken', '==', token).limit(1).get() : null
  if (!found || found.empty) {
    res.status(404).send(page('Link not recognised', '<h1>We do not recognise that link</h1><p>It may be from an old email. You can change reminders from your account in Clovara Life.</p>'))
    return
  }
  if (req.method === 'POST') {
    await found.docs[0].ref.set({ moments: false, updatedAt: new Date().toISOString() }, { merge: true })
    await trackServer(found.docs[0].id, 'email_prefs_changed', { moments: false, via: 'unsubscribe_link' })
    res.send(page('Reminders off', '<h1>Reminders are off</h1><p>You will not get these emails any more. Everything in your pets’ plans is still there, and you can turn reminders back on from your account.</p>'))
    return
  }
  res.send(
    page(
      'Turn off reminders',
      `<h1>Turn off reminders?</h1><p>You will stop getting emails about vaccinations, the socialisation window, the yearly check and Gotcha Day. Nothing else changes.</p>` +
        `<form method="post"><input type="hidden" name="t" value="${esc(token)}"><button type="submit">Turn off reminders</button></form>`,
    ),
  )
})

exports.sendMoments = onSchedule({ schedule: 'every day 08:00', timeZone: 'America/New_York' }, async () => {
  const r = await runMoments({
    db,
    now: new Date(),
    preferencesUrl: PREFERENCES_URL,
    emailOf: (uid) => getAuth().getUser(uid).then((u) => u.email || null).catch(() => null),
    send: sendTemplate,
    track: trackServer,
  })
  console.log(`[moments] ${r.sent} to ${r.recipients} opted-in owners`)
})

/**
 * "Bruno's plan is saved" — transactional, once per person ever, naming the
 * first pet they saved (AO5). Not gated on the moments opt-in: it is the
 * receipt for something they just did.
 */
exports.lifePlanSaved = onDocumentCreated(`${HOUSEHOLDS}/{householdId}/pets/{petId}`, async (event) => {
  const pet = event.data?.data()
  const uid = pet?.createdBy
  if (!uid) return
  const ref = db.collection(PREFS).doc(uid)
  const already = await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref)
    if (snap.exists && snap.get('planSavedAt')) return true
    tx.set(ref, { planSavedAt: new Date().toISOString() }, { merge: true })
    return false
  })
  if (already) return
  const email = await getAuth().getUser(uid).then((u) => u.email || null).catch(() => null)
  await sendTemplate('planSaved', email, { petName: pet?.name?.value || null })
})
