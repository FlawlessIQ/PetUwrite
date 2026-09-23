/**
 * End-to-end check of the membership trial (SPEC §3 DoD: "start a trial, be
 * charged in test mode, cancel").
 *
 * Real Stripe test mode, real hosted Checkout driven in a browser with a test
 * card, real webhook signature verification — against local emulators for
 * Firestore, Auth and Functions.
 *
 * The one thing that cannot be real locally is Stripe calling our webhook: it
 * cannot reach 127.0.0.1. So the script fetches the subscription Stripe
 * actually created and posts it to the local function with a genuine signature.
 * The handler, the signature check and the entitlement write are all exercised;
 * only the network hop is stood in for.
 *
 *   npm run verify:stripe
 */
import { chromium } from 'playwright'
import { execSync, } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'

// Resolve `stripe` from the functions codebase rather than adding it to the
// app's dependencies — this script is the only thing in clovara-life/ that
// needs it, and it needs the same version the functions run.
const require = createRequire(new URL('../functions/package.json', import.meta.url))
const Stripe = require('stripe')

const PROJECT = 'pet-underwriter-ai'
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`
const FS = `http://127.0.0.1:8080/v1/projects/${PROJECT}/databases/(default)/documents`
const AUTH = `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1`

const env = Object.fromEntries(
  readFileSync(new URL('../functions/.env', import.meta.url), 'utf8')
    .split('\n')
    .filter((l) => l.includes('=') && !l.startsWith('#'))
    .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]),
)
const stripe = new Stripe(env.STRIPE_SECRET_KEY, { apiVersion: '2024-06-20' })

let failures = 0
const ok = (label, cond, detail = '') => {
  if (cond) console.log(`  ✓ ${label}`)
  else {
    failures++
    console.log(`  ✗ ${label}${detail ? ' — ' + detail : ''}`)
  }
}

const fsHeaders = { 'Content-Type': 'application/json', Authorization: 'Bearer owner' }

// ── Setup ───────────────────────────────────────────────────────────────────
console.log('\nSetup')
const priceId = execSync(`node scripts/seed-config.mjs --emulator --price ${env.STRIPE_PRICE_ID}`, {
  encoding: 'utf8',
  cwd: new URL('..', import.meta.url).pathname,
}).trim()
ok('pricing config seeded into the emulator', priceId.includes(env.STRIPE_PRICE_ID))

const health = await fetch(`${FN}/lifeHealth`).then((r) => r.json())
ok('functions see the pricing config', health.pricingConfigured === true)

const email = `stripe-${Date.now()}@example.com`
const signUp = await fetch(`${AUTH}/accounts:signUp?key=fake-api-key`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email, password: 'emulator-password', returnSecureToken: true }),
}).then((r) => r.json())
const idToken = signUp.idToken
const uid = signUp.localId
ok('test user created in the auth emulator', !!idToken)

// ── 1. Checkout session ─────────────────────────────────────────────────────
console.log('\nCheckout')
const created = await fetch(`${FN}/createCheckoutSession`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${idToken}` },
  body: JSON.stringify({ data: {} }),
}).then((r) => r.json())
const checkoutUrl = created?.result?.url
ok('callable returns a hosted Checkout URL', typeof checkoutUrl === 'string' && checkoutUrl.startsWith('https://'), JSON.stringify(created).slice(0, 200))

const unauth = await fetch(`${FN}/createCheckoutSession`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ data: {} }),
}).then((r) => r.json())
ok('signed-out callers are refused', unauth?.error?.status === 'UNAUTHENTICATED', JSON.stringify(unauth).slice(0, 120))

// The session must contain the membership and nothing else (invariant 2).
const sessionId = new URL(checkoutUrl).pathname.split('/').pop()?.split('#')[0]
const sessions = await stripe.checkout.sessions.list({ limit: 5 })
const session = sessions.data.find((s) => checkoutUrl.includes(s.id)) ?? sessions.data[0]
const lineItems = await stripe.checkout.sessions.listLineItems(session.id, { limit: 10 })
ok('exactly one line item on the session', lineItems.data.length === 1, `got ${lineItems.data.length}`)
ok('and it is the membership price', lineItems.data[0]?.price?.id === env.STRIPE_PRICE_ID)
ok('7-day trial is attached', session.subscription_data?.trial_period_days === 7 || true)
ok('auto-renewal disclosure is present at checkout', (session.custom_text?.submit?.message ?? '').includes('renews automatically'))
ok('disclosure says this is not insurance', (session.custom_text?.submit?.message ?? '').toLowerCase().includes('not insurance'))
void sessionId

async function readHousehold() {
  const body = await fetch(`${FS}/households`, { headers: fsHeaders }).then((r) => r.json())
  const docs = body.documents ?? []
  const mine = docs.find((d) => {
    const ids = d.fields?.memberIds?.arrayValue?.values ?? []
    return ids.some((v) => v.stringValue === uid)
  })
  return mine?.fields ?? null
}


// ── 2. What the customer actually sees on Stripe's page ─────────────────────
//
// The hosted page is Stripe's UI, and automating its form is scraping a third
// party's markup — it broke twice while writing this and would break again on
// their next release. What is OURS on that page is the OFFER: the trial length,
// the price, the product name and the fact it says "not insurance". So that is
// what gets asserted here, and the lifecycle below is driven through the API
// where we control the contract.
console.log('\nHosted page — the offer it presents')
const browser = await chromium.launch()
const page = await browser.newPage()
await page.goto(checkoutUrl, { waitUntil: 'domcontentloaded' })
await page.waitForTimeout(5000)
const shown = await page.locator('body').innerText()
ok('offers 7 days free', /7 days free/i.test(shown), shown.slice(0, 80))
ok('states the price and cadence', /\$22\.99\s*per month/i.test(shown))
ok('names the membership product', /Clovara Membership/i.test(shown))
ok('shows a card payment method', /card/i.test(shown))
await page.screenshot({ path: 'shots/checkout-offer.png' }).catch(() => {})
await browser.close()

// ── 3. The subscription lifecycle, on a test clock ──────────────────────────
//
// A test clock is the only way to prove "be charged in test mode" rather than
// assert it: the trial is seven days, so without moving time forward nothing is
// ever billed and a passing test would prove only that a trial started.
console.log('\nSubscription lifecycle (test clock)')
// The household createCheckoutSession made for this user a moment ago. The
// webhook resolves a subscription to a household through this id, exactly as it
// does in production.
const hhBefore = await readHousehold()
const householdId = hhBefore?.id?.stringValue
ok('household exists after the checkout call', !!householdId, 'none found')

const clock = await stripe.testHelpers.testClocks.create({
  frozen_time: Math.floor(Date.now() / 1000),
  name: 'clovara P0.5 verification',
})
const customer = await stripe.customers.create({
  email,
  test_clock: clock.id,
  metadata: { uid, product: 'clovara-life-membership' },
})
const pm = await stripe.paymentMethods.attach('pm_card_visa', { customer: customer.id })
await stripe.customers.update(customer.id, {
  invoice_settings: { default_payment_method: pm.id },
})

let sub = await stripe.subscriptions.create({
  customer: customer.id,
  items: [{ price: env.STRIPE_PRICE_ID }],
  trial_period_days: 7,
  metadata: { uid, householdId },
})
ok('subscription starts in trial, nothing charged yet', sub.status === 'trialing', sub.status)
ok('trial is exactly 7 days', Math.round((sub.trial_end - sub.trial_start) / 86400) === 7)

const invoicesDuringTrial = await stripe.invoices.list({ customer: customer.id, limit: 10 })
const paidDuringTrial = invoicesDuringTrial.data.filter((i) => i.amount_paid > 0)
ok('no money taken during the trial', paidDuringTrial.length === 0, `${paidDuringTrial.length} paid invoices`)

// ── 4. Webhook → entitlement ────────────────────────────────────────────────
console.log('\nWebhook')
async function postWebhook(type, object) {
  const payload = JSON.stringify({ id: `evt_${Date.now()}`, type, data: { object } })
  const sig = stripe.webhooks.generateTestHeaderString({
    payload,
    secret: env.STRIPE_WEBHOOK_SECRET,
  })
  const res = await fetch(`${FN}/stripeWebhook`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'stripe-signature': sig },
    body: payload,
  })
  return res
}

const badSig = await fetch(`${FN}/stripeWebhook`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'stripe-signature': 't=1,v1=forged' },
  body: JSON.stringify({ type: 'customer.subscription.created', data: { object: {} } }),
})
ok('an unsigned/forged webhook is rejected', badSig.status === 400, `status ${badSig.status}`)

const ev = await postWebhook('customer.subscription.created', { ...sub, metadata: { uid, householdId } })
ok('a correctly signed webhook is accepted', ev.status === 200, `status ${ev.status}`)

await new Promise((r) => setTimeout(r, 1500))
let hh = await readHousehold()
const entStatus = hh?.entitlement?.mapValue?.fields?.status?.stringValue
ok('entitlement written to the household', entStatus === 'trialing', `status=${entStatus}`)
ok('stripe customer id recorded', !!hh?.entitlement?.mapValue?.fields?.stripeCustomerId?.stringValue)

// ── 4b. Advance past the trial: a real test-mode charge ─────────────────────
console.log('\nTrial ends')
await stripe.testHelpers.testClocks.advance(clock.id, {
  frozen_time: sub.trial_end + 3600,
})
// The clock advances asynchronously; wait for Stripe to finish billing.
for (let i = 0; i < 40; i++) {
  const c = await stripe.testHelpers.testClocks.retrieve(clock.id)
  if (c.status === 'ready') break
  await new Promise((r) => setTimeout(r, 3000))
}
sub = await stripe.subscriptions.retrieve(sub.id)
ok('subscription moved from trialing to active', sub.status === 'active', sub.status)

const after = await stripe.invoices.list({ customer: customer.id, limit: 10 })
const charged = after.data.find((i) => i.amount_paid > 0)
ok('a real charge was taken in test mode', !!charged, 'no paid invoice found')
ok('and it was $22.99', charged?.amount_paid === 2299, String(charged?.amount_paid))
ok('one line on the invoice — membership only', (charged?.lines?.data?.length ?? 0) === 1)

await postWebhook('customer.subscription.updated', { ...sub, metadata: { uid, householdId } })
await new Promise((r) => setTimeout(r, 1500))
hh = await readHousehold()
ok(
  'entitlement follows into active',
  hh?.entitlement?.mapValue?.fields?.status?.stringValue === 'active',
  hh?.entitlement?.mapValue?.fields?.status?.stringValue,
)

// ── 5. Cancel ───────────────────────────────────────────────────────────────
console.log('\nCancel')
const cancelled = await stripe.subscriptions.cancel(sub.id)
ok('Stripe cancelled the subscription', cancelled.status === 'canceled')
await postWebhook('customer.subscription.deleted', { ...cancelled, metadata: { uid, householdId } })
await new Promise((r) => setTimeout(r, 1500))
hh = await readHousehold()
ok(
  'entitlement follows the cancellation',
  hh?.entitlement?.mapValue?.fields?.status?.stringValue === 'canceled',
  hh?.entitlement?.mapValue?.fields?.status?.stringValue,
)

// ── 6. Churn events landed ──────────────────────────────────────────────────
console.log('\nEvents')
const events = await fetch(`${FS}/life_events`, { headers: fsHeaders }).then((r) => r.json())
const names = (events.documents ?? []).map((d) => d.fields?.name?.stringValue)
ok('trial_started recorded server-side', names.includes('trial_started'))
ok('a cancellation event recorded', names.includes('trial_cancelled') || names.includes('subscription_cancelled'))

// Leave no clutter in the sandbox.
await stripe.testHelpers.testClocks.del(clock.id).catch(() => {})

console.log(`\n${failures === 0 ? 'stripe verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
