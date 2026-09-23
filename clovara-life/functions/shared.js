/**
 * Shared plumbing for the Clovara Life functions: Firebase admin, Stripe, the
 * pricing config, households, entitlement, and server-side analytics.
 */
const { initializeApp, getApps } = require('firebase-admin/app')
const { getFirestore, FieldValue } = require('firebase-admin/firestore')

if (!getApps().length) initializeApp()

const db = getFirestore()

const HOUSEHOLDS = 'households'
const CONFIG = 'life_config'
const EVENTS = 'life_events'

/**
 * Pricing, read from Firestore rather than hardcoded.
 *
 * SPEC §1: "A price test ($19.99–$24.99) comes later via config, so price must
 * be a config value, never a literal." The document is written by tooling, not
 * by clients — the rules deny all client writes to life_config.
 *
 * The fallback is NOT a second source of truth. It exists so a missing config
 * document fails loudly with a clear message rather than creating a Checkout
 * session at some accidental amount.
 */
async function readPricing() {
  const snap = await db.collection(CONFIG).doc('pricing').get()
  if (!snap.exists) {
    throw new Error(
      'life_config/pricing is missing. Seed it with scripts/seed-config.mjs before taking payments.',
    )
  }
  const d = snap.data() || {}
  if (!d.priceId || typeof d.priceId !== 'string') {
    throw new Error('life_config/pricing has no priceId.')
  }
  return {
    priceId: d.priceId,
    /** Display only — Stripe is the authority on what is actually charged. */
    amountDisplay: d.amountDisplay || null,
    interval: d.interval || 'month',
    trialDays: Number.isFinite(d.trialDays) ? d.trialDays : 7,
  }
}

/** Finds the caller's household, or makes them one. Mirrors the client's ensureHousehold. */
async function ensureHousehold(uid) {
  const existing = await db
    .collection(HOUSEHOLDS)
    .where('memberIds', 'array-contains', uid)
    .limit(1)
    .get()
  if (!existing.empty) return { id: existing.docs[0].id, ...existing.docs[0].data() }

  const ref = db.collection(HOUSEHOLDS).doc()
  const now = new Date().toISOString()
  const household = {
    id: ref.id,
    createdAt: now,
    createdBy: uid,
    members: { [uid]: { role: 'owner', joinedAt: now } },
    memberIds: [uid],
  }
  await ref.set(household)
  return household
}

async function householdByCustomer(customerId) {
  const snap = await db
    .collection(HOUSEHOLDS)
    .where('entitlement.stripeCustomerId', '==', customerId)
    .limit(1)
    .get()
  return snap.empty ? null : { id: snap.docs[0].id, ...snap.docs[0].data() }
}

/**
 * The entitlement flag that drives member-only UI.
 *
 * Written ONLY here, by the Admin SDK, from what Stripe says. Clients are
 * denied writes to this field in the rules — otherwise a member could grant
 * themselves a subscription by editing their own household document.
 */
async function writeEntitlement(householdId, entitlement) {
  await db
    .collection(HOUSEHOLDS)
    .doc(householdId)
    .set(
      { entitlement: { ...entitlement, updatedAt: FieldValue.serverTimestamp() } },
      { merge: true },
    )
}

/** Maps a Stripe subscription onto our entitlement shape. */
function entitlementFromSubscription(sub) {
  const iso = (s) => (typeof s === 'number' ? new Date(s * 1000).toISOString() : null)
  return {
    status: sub.status, // trialing | active | past_due | canceled | incomplete | unpaid
    stripeCustomerId: typeof sub.customer === 'string' ? sub.customer : sub.customer?.id ?? null,
    stripeSubscriptionId: sub.id,
    priceId: sub.items?.data?.[0]?.price?.id ?? null,
    trialEnd: iso(sub.trial_end),
    currentPeriodEnd: iso(sub.current_period_end),
    cancelAtPeriodEnd: !!sub.cancel_at_period_end,
  }
}

/**
 * Server-side analytics, in the same collection and shape the client writes.
 *
 * Billing events have to come from here: the client is not told about a failed
 * payment or a renewal, and a churn number built from what the browser happened
 * to observe would be wrong in a flattering direction.
 */
async function trackServer(uid, name, props = {}) {
  if (!uid) return
  try {
    await db.collection(EVENTS).add({
      name,
      props,
      uid,
      at: new Date().toISOString(),
      visitorId: `server:${uid}`,
      sessionId: 'server',
      build: 'functions',
    })
  } catch (err) {
    // Instrumentation must never fail the operation it is instrumenting.
    console.error('trackServer failed', name, err?.message)
  }
}

module.exports = {
  db,
  HOUSEHOLDS,
  CONFIG,
  EVENTS,
  readPricing,
  ensureHousehold,
  householdByCustomer,
  writeEntitlement,
  entitlementFromSubscription,
  trackServer,
}
