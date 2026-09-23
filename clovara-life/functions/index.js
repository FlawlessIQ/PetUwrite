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

setGlobalOptions({ region: 'us-central1', maxInstances: 10 })

const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY')
const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET')

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

/** Health probe, so a deploy can be confirmed without touching Stripe. */
exports.lifeHealth = onRequest({ cors: true }, async (_req, res) => {
  const pricing = await readPricing().catch((e) => ({ error: e.message }))
  res.json({
    ok: true,
    codebase: 'life',
    pricingConfigured: !pricing.error,
    households: (await db.collection(HOUSEHOLDS).limit(1).get()).size >= 0,
  })
})
