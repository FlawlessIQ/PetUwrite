const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");
const Stripe = require("stripe");

function getStripeClient() {
  const secretKey = process.env.STRIPE_SECRET_KEY;
  if (!secretKey) {
    throw new Error("Stripe secret key is not configured. Set STRIPE_SECRET_KEY env var.");
  }
  return Stripe(secretKey);
}

async function isAdminCaller(request) {
  if (!request.auth) return false;
  if (request.auth.token?.admin === true) return true;

  try {
    const uid = request.auth.uid;
    const doc = await admin.firestore().collection("users").doc(uid).get();
    const role = doc.exists ? doc.data()?.userRole : null;
    return role === 2 || role === 3;
  } catch (e) {
    logger.warn("isAdminCaller check failed", {error: e?.message});
    return false;
  }
}

function coerceString(v) {
  return (v ?? "").toString();
}

function dayKeyFromTimestamp(ts) {
  const d = ts instanceof Date ? ts : new Date(ts);
  const y = d.getUTCFullYear().toString().padStart(4, "0");
  const m = (d.getUTCMonth() + 1).toString().padStart(2, "0");
  const dd = d.getUTCDate().toString().padStart(2, "0");
  return `${y}-${m}-${dd}`;
}

async function resolveChannelId({utmSource, utmMedium, utmCampaign, utmContent, referrerHost}) {
  const snap = await admin.firestore().collection("intake_channels").where("status", "==", "active").get();
  const norm = (s) => coerceString(s).trim().toLowerCase();

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const rules = (data.matchRules || {});

    const required = {
      utmSource: norm(rules.utmSource),
      utmMedium: norm(rules.utmMedium),
      utmCampaign: norm(rules.utmCampaign),
      utmContent: norm(rules.utmContent),
      referrerHost: norm(rules.referrerHost),
    };

    let ok = true;
    if (required.utmSource && required.utmSource !== norm(utmSource)) ok = false;
    if (required.utmMedium && required.utmMedium !== norm(utmMedium)) ok = false;
    if (required.utmCampaign && required.utmCampaign !== norm(utmCampaign)) ok = false;
    if (required.utmContent && required.utmContent !== norm(utmContent)) ok = false;
    if (required.referrerHost && required.referrerHost !== norm(referrerHost)) ok = false;

    if (ok) return doc.id;
  }

  return null;
}

async function writeMarketingEvent({
  type,
  ts,
  sessionId,
  channelId,
  userId,
  policyId,
  quoteId,
  underwritingCaseId,
  code,
  premium,
  discountAmount,
  spend,
  metadata,
}) {
  const now = ts || new Date();
  const doc = {
    type: coerceString(type),
    ts: FieldValue.serverTimestamp(),
    tsClient: now instanceof Date ? now.toISOString() : now,
    sessionId: sessionId || null,
    channelId: channelId || null,
    userId: userId || null,
    policyId: policyId || null,
    quoteId: quoteId || null,
    underwritingCaseId: underwritingCaseId || null,
    code: code || null,
    premium: typeof premium === "number" ? premium : null,
    discountAmount: typeof discountAmount === "number" ? discountAmount : null,
    spend: typeof spend === "number" ? spend : null,
    metadata: metadata && typeof metadata === "object" ? metadata : null,
    createdAt: FieldValue.serverTimestamp(),
  };

  await admin.firestore().collection("marketing_events").add(doc);
}

async function bumpDailyRollups(event) {
  const ts = new Date();
  const dayKey = dayKeyFromTimestamp(ts);

  const rootRef = admin.firestore().collection("marketing_rollups_daily").doc(dayKey);
  const inc = (n) => FieldValue.increment(n);

  const updates = {
    updatedAt: FieldValue.serverTimestamp(),
  };

  switch (event.type) {
    case "session_created":
      updates.sessions = inc(1);
      break;
    case "quote_started":
      updates.quoteStarted = inc(1);
      break;
    case "underwriting_submitted":
      updates.underwritingSubmitted = inc(1);
      break;
    case "checkout_started":
      updates.checkoutStarted = inc(1);
      break;
    case "purchase_completed":
      updates.purchases = inc(1);
      if (typeof event.premium === "number") updates.premium = inc(event.premium);
      if (typeof event.discountAmount === "number") updates.discounts = inc(event.discountAmount);
      break;
    case "spend_recorded":
      if (typeof event.spend === "number") updates.spend = inc(event.spend);
      break;
  }

  await rootRef.set({day: dayKey, ...updates}, {merge: true});

  if (event.channelId) {
    const chRef = rootRef.collection("channels").doc(event.channelId);
    await chRef.set({channelId: event.channelId, ...updates}, {merge: true});
  }

  if (event.code) {
    const codeRef = rootRef.collection("discount_codes").doc(event.code);
    await codeRef.set({code: event.code, ...updates}, {merge: true});
  }
}

exports.onMarketingEventCreated = onDocumentCreated("marketing_events/{eventId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data() || {};
  try {
    await bumpDailyRollups(data);
  } catch (e) {
    logger.error("Failed to bump daily rollups", {error: e?.message});
  }
});

exports.startAttributionSession = onCall({ cors: true }, async (request) => {
  const data = request.data || {};

  const utmSource = coerceString(data.utmSource).trim();
  const utmMedium = coerceString(data.utmMedium).trim();
  const utmCampaign = coerceString(data.utmCampaign).trim();
  const utmContent = coerceString(data.utmContent).trim();
  const utmTerm = coerceString(data.utmTerm).trim();
  const referrerHost = coerceString(data.referrerHost).trim();
  const landingPath = coerceString(data.landingPath).trim();

  const channelId = await resolveChannelId({utmSource, utmMedium, utmCampaign, utmContent, referrerHost});

  const sessionRef = admin.firestore().collection("attribution_sessions").doc();
  const sessionId = sessionRef.id;

  await sessionRef.set({
    sessionId,
    userId: request.auth?.uid || null,
    firstTouch: {
      utmSource: utmSource || null,
      utmMedium: utmMedium || null,
      utmCampaign: utmCampaign || null,
      utmContent: utmContent || null,
      utmTerm: utmTerm || null,
      referrerHost: referrerHost || null,
      landingPath: landingPath || null,
      ts: FieldValue.serverTimestamp(),
    },
    lastTouch: {
      utmSource: utmSource || null,
      utmMedium: utmMedium || null,
      utmCampaign: utmCampaign || null,
      utmContent: utmContent || null,
      utmTerm: utmTerm || null,
      referrerHost: referrerHost || null,
      landingPath: landingPath || null,
      ts: FieldValue.serverTimestamp(),
    },
    resolvedChannelId: channelId,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  await writeMarketingEvent({
    type: "session_created",
    sessionId,
    channelId,
    userId: request.auth?.uid || null,
    metadata: {
      utmSource,
      utmMedium,
      utmCampaign,
      utmContent,
      utmTerm,
      referrerHost,
      landingPath,
    },
  });

  return {sessionId, channelId};
});

exports.trackMarketingEvent = onCall({ cors: true }, async (request) => {
  const data = request.data || {};
  const type = coerceString(data.type).trim();
  if (!type) throw new HttpsError("invalid-argument", "Missing type");

  const sessionId = coerceString(data.sessionId).trim() || null;
  let channelId = coerceString(data.channelId).trim() || null;

  if (!channelId && sessionId) {
    const sess = await admin.firestore().collection("attribution_sessions").doc(sessionId).get();
    channelId = sess.exists ? (sess.data()?.resolvedChannelId || null) : null;
  }

  await writeMarketingEvent({
    type,
    sessionId,
    channelId,
    userId: request.auth?.uid || null,
    policyId: coerceString(data.policyId).trim() || null,
    quoteId: coerceString(data.quoteId).trim() || null,
    underwritingCaseId: coerceString(data.underwritingCaseId).trim() || null,
    code: coerceString(data.code).trim() || null,
    premium: typeof data.premium === "number" ? data.premium : null,
    discountAmount: typeof data.discountAmount === "number" ? data.discountAmount : null,
    spend: typeof data.spend === "number" ? data.spend : null,
    metadata: data.metadata,
  });

  return {ok: true};
});

exports.createPromotionCode = onCall({ cors: true }, async (request) => {
  if (!(await isAdminCaller(request))) {
    throw new HttpsError("permission-denied", "Admin privileges required");
  }

  const data = request.data || {};
  const code = coerceString(data.code).trim().toUpperCase();
  if (!code) throw new HttpsError("invalid-argument", "Missing code");

  const percentOff = data.percentOff;
  const amountOff = data.amountOff;
  const currency = coerceString(data.currency || "usd").trim().toLowerCase();

  if (!(typeof percentOff === "number") && !(typeof amountOff === "number")) {
    throw new HttpsError("invalid-argument", "Provide percentOff or amountOff");
  }

  const stripe = getStripeClient();

  const couponParams = {};
  if (typeof percentOff === "number") couponParams.percent_off = percentOff;
  if (typeof amountOff === "number") {
    couponParams.amount_off = Math.round(amountOff * 100);
    couponParams.currency = currency;
  }

  const coupon = await stripe.coupons.create({
    ...couponParams,
    duration: "once",
    metadata: {source: "clovara_admin"},
  });

  const promo = await stripe.promotionCodes.create({
    coupon: coupon.id,
    code,
    max_redemptions: typeof data.maxRedemptions === "number" ? data.maxRedemptions : undefined,
    expires_at: typeof data.expiresAt === "number" ? data.expiresAt : undefined,
    active: true,
    metadata: {source: "clovara_admin"},
  });

  const docRef = admin.firestore().collection("discount_codes").doc(code);
  await docRef.set(
    {
      code,
      active: true,
      stripePromotionCodeId: promo.id,
      stripeCouponId: coupon.id,
      discount: {
        type: typeof percentOff === "number" ? "percent" : "amount",
        percentOff: typeof percentOff === "number" ? percentOff : null,
        amountOff: typeof amountOff === "number" ? amountOff : null,
        currency,
      },
      restrictions: data.restrictions && typeof data.restrictions === "object" ? data.restrictions : {},
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      createdBy: request.auth.uid,
    },
    {merge: true},
  );

  await admin.firestore().collection("audit_logs").add({
    type: "marketing_create_promo_code",
    performedBy: request.auth.uid,
    performedAt: FieldValue.serverTimestamp(),
    code,
    stripePromotionCodeId: promo.id,
    stripeCouponId: coupon.id,
  });

  return {code, stripePromotionCodeId: promo.id, stripeCouponId: coupon.id};
});

exports.setPromotionCodeActive = onCall({ cors: true }, async (request) => {
  if (!(await isAdminCaller(request))) {
    throw new HttpsError("permission-denied", "Admin privileges required");
  }

  const data = request.data || {};
  const code = coerceString(data.code).trim().toUpperCase();
  const active = data.active === true;
  if (!code) throw new HttpsError("invalid-argument", "Missing code");

  const doc = await admin.firestore().collection("discount_codes").doc(code).get();
  if (!doc.exists) throw new HttpsError("not-found", "Code not found");

  const stripePromotionCodeId = doc.data()?.stripePromotionCodeId;
  if (!stripePromotionCodeId) throw new HttpsError("failed-precondition", "Missing stripePromotionCodeId");

  const stripe = getStripeClient();
  await stripe.promotionCodes.update(stripePromotionCodeId, {active});

  await admin.firestore().collection("discount_codes").doc(code).set(
    {
      active,
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await admin.firestore().collection("audit_logs").add({
    type: "marketing_set_promo_code_active",
    performedBy: request.auth.uid,
    performedAt: FieldValue.serverTimestamp(),
    code,
    active,
  });

  return {ok: true};
});

function passesRestrictions({restrictions, channelId, state, productId, isNewCustomer}) {
  if (!restrictions || typeof restrictions !== "object") return true;

  const allowList = (arr) => Array.isArray(arr) ? arr.map((x) => coerceString(x).trim()).filter(Boolean) : null;

  const channelAllow = allowList(restrictions.channelAllowList);
  const channelDeny = allowList(restrictions.channelDenyList);
  const stateAllow = allowList(restrictions.stateAllowList);
  const productAllow = allowList(restrictions.productAllowList);

  if (channelAllow && channelAllow.length && (!channelId || !channelAllow.includes(channelId))) return false;
  if (channelDeny && channelDeny.length && channelId && channelDeny.includes(channelId)) return false;
  if (stateAllow && stateAllow.length && (!state || !stateAllow.includes(state))) return false;
  if (productAllow && productAllow.length && (!productId || !productAllow.includes(productId))) return false;

  if (restrictions.newCustomerOnly === true && isNewCustomer === false) return false;

  const now = Date.now();
  if (typeof restrictions.startsAt === "number" && now < restrictions.startsAt * 1000) return false;
  if (typeof restrictions.expiresAt === "number" && now > restrictions.expiresAt * 1000) return false;

  return true;
}

exports.validatePromotionCode = onCall({ cors: true }, async (request) => {
  const data = request.data || {};
  const code = coerceString(data.code).trim().toUpperCase();
  if (!code) throw new HttpsError("invalid-argument", "Missing code");

  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }

  // Optional TEST100 gate
  if (code === "TEST100") {
    const allow = process.env.ALLOW_TEST_COUPONS === "true" || (await isAdminCaller(request));
    if (!allow) {
      return {valid: false, code, message: "Test code is not allowed"};
    }
    return {valid: true, code, bypassPayment: true, message: "Test coupon applied"};
  }

  const sessionId = coerceString(data.sessionId).trim() || null;
  let channelId = coerceString(data.channelId).trim() || null;

  if (!channelId && sessionId) {
    const sess = await admin.firestore().collection("attribution_sessions").doc(sessionId).get();
    channelId = sess.exists ? (sess.data()?.resolvedChannelId || null) : null;
  }

  const state = coerceString(data.state).trim().toUpperCase() || null;
  const productId = coerceString(data.productId).trim() || null;
  const amount = typeof data.amount === "number" ? data.amount : null;
  const currency = coerceString(data.currency || "usd").trim().toLowerCase();

  // Load Firestore mirror if present
  const mirror = await admin.firestore().collection("discount_codes").doc(code).get();
  const mirrorData = mirror.exists ? mirror.data() : null;

  if (mirrorData && mirrorData.active === false) {
    return {valid: false, code, message: "Code disabled"};
  }

  // Compute isNewCustomer
  let isNewCustomer = true;
  try {
    const policies = await admin
      .firestore()
      .collection("policies")
      .where("ownerId", "==", request.auth.uid)
      .limit(1)
      .get();
    isNewCustomer = policies.empty;
  } catch (_) {
    // leave as true
  }

  if (mirrorData && !passesRestrictions({
    restrictions: mirrorData.restrictions,
    channelId,
    state,
    productId,
    isNewCustomer,
  })) {
    return {valid: false, code, message: "Code not eligible"};
  }

  // Validate via Stripe promotion codes
  try {
    const stripe = getStripeClient();
    const list = await stripe.promotionCodes.list({code, active: true, limit: 1});
    const promo = (list.data && list.data.length) ? list.data[0] : null;
    if (!promo) {
      return {valid: false, code, message: "Invalid or expired code"};
    }

    const coupon = promo.coupon;
    const percentOff = coupon?.percent_off ?? null;
    const amountOff = coupon?.amount_off ? (coupon.amount_off / 100) : null;

    let discountAmount = null;
    if (typeof amount === "number") {
      if (typeof percentOff === "number") discountAmount = Math.max(0, amount * (percentOff / 100));
      if (typeof amountOff === "number") discountAmount = Math.min(amount, Math.max(0, amountOff));
    }

    return {
      valid: true,
      code,
      promotionCodeId: promo.id,
      couponId: coupon?.id || null,
      percentOff,
      amountOff,
      currency,
      discountAmount,
      message: "Code applied",
    };
  } catch (e) {
    logger.warn("Stripe promo code validate failed", {error: e?.message});
    return {valid: false, code, message: "Invalid or expired code"};
  }
});

exports.recordSpend = onCall({ cors: true }, async (request) => {
  if (!(await isAdminCaller(request))) {
    throw new HttpsError("permission-denied", "Admin privileges required");
  }

  const data = request.data || {};
  const channelId = coerceString(data.channelId).trim();
  const date = coerceString(data.date).trim(); // YYYY-MM-DD
  const spend = typeof data.spend === "number" ? data.spend : null;
  if (!channelId || !date || typeof spend !== "number") {
    throw new HttpsError("invalid-argument", "Missing channelId/date/spend");
  }

  const docId = `${channelId}_${date}`;
  await admin.firestore().collection("channel_spend_daily").doc(docId).set(
    {
      channelId,
      date,
      spend,
      source: coerceString(data.source || "manual"),
      notes: coerceString(data.notes || "") || null,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  await writeMarketingEvent({
    type: "spend_recorded",
    channelId,
    spend,
    metadata: {date, source: data.source || "manual"},
    userId: request.auth.uid,
  });

  return {ok: true};
});

exports.importChannelSpendCsv = onCall({ cors: true }, async (request) => {
  if (!(await isAdminCaller(request))) {
    throw new HttpsError("permission-denied", "Admin privileges required");
  }

  const data = request.data || {};
  const csvText = coerceString(data.csv).trim();
  if (!csvText) throw new HttpsError("invalid-argument", "Missing csv");

  const lines = csvText.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  if (!lines.length) return {ok: true, imported: 0};

  // Accept optional header
  const hasHeader = /date/i.test(lines[0]) && /channel/i.test(lines[0]);
  const startIdx = hasHeader ? 1 : 0;

  const batch = admin.firestore().batch();
  let imported = 0;

  for (let i = startIdx; i < lines.length; i++) {
    const parts = lines[i].split(",").map((p) => p.trim());
    if (parts.length < 3) continue;
    const date = parts[0];
    const channelId = parts[1];
    const spend = Number(parts[2]);
    if (!date || !channelId || !Number.isFinite(spend)) continue;

    const docId = `${channelId}_${date}`;
    const ref = admin.firestore().collection("channel_spend_daily").doc(docId);
    batch.set(ref, {
      channelId,
      date,
      spend,
      source: "csv",
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(),
    }, {merge: true});

    imported++;
  }

  await batch.commit();

  await admin.firestore().collection("audit_logs").add({
    type: "marketing_import_spend_csv",
    performedBy: request.auth.uid,
    performedAt: FieldValue.serverTimestamp(),
    imported,
  });

  return {ok: true, imported};
});
