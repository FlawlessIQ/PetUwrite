const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { FieldValue } = require("firebase-admin/firestore");

if (!admin.apps.length) admin.initializeApp();

function isEmulator() {
  return process.env.FUNCTIONS_EMULATOR === "true" || !!process.env.FIREBASE_EMULATOR_HUB;
}

function getStripeClient() {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key || typeof key !== "string") {
    throw new HttpsError(
      "failed-precondition",
      "Stripe is not configured (missing STRIPE_SECRET_KEY)"
    );
  }
  return require("stripe")(key);
}

function getAllowedReturnUrlPrefixes() {
  const prefixes = [];

  const appUrl = process.env.APP_URL;
  if (appUrl && typeof appUrl === "string") prefixes.push(appUrl);

  const publicAppUrl = process.env.PUBLIC_APP_URL;
  if (publicAppUrl && typeof publicAppUrl === "string") prefixes.push(publicAppUrl);

  // Local dev (web + emulator)
  if (isEmulator()) {
    prefixes.push("http://localhost");
    prefixes.push("http://127.0.0.1");
  }

  // Sensible default (keeps prod working if env vars aren’t set yet)
  if (prefixes.length === 0) prefixes.push("https://clovara.com");

  return prefixes;
}

function validateReturnUrl(url) {
  if (!url || typeof url !== "string") return null;

  // Require absolute URLs only.
  if (!url.startsWith("http://") && !url.startsWith("https://")) return null;

  const allowed = getAllowedReturnUrlPrefixes();
  const ok = allowed.some((p) => url.startsWith(p));
  return ok ? url : null;
}

/**
 * Callable: createReimbursementOnboardingLink
 *
 * Captures customer payout details safely by using Stripe Connect onboarding.
 * We DO NOT store bank/card details in Firestore; Stripe handles that.
 *
 * Returns an onboarding URL the client should open.
 */
exports.createReimbursementOnboardingLink = onCall({ enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  if (!process.env.STRIPE_SECRET_KEY && !isEmulator()) {
    throw new HttpsError("failed-precondition", "Stripe is not configured");
  }

  const data = request.data || {};
  const returnUrl = validateReturnUrl(data.returnUrl) || null;
  const refreshUrl = validateReturnUrl(data.refreshUrl) || returnUrl;

  const fallbackUrl = getAllowedReturnUrlPrefixes()[0];
  const effectiveReturnUrl = returnUrl || fallbackUrl;
  const effectiveRefreshUrl = refreshUrl || fallbackUrl;

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    throw new HttpsError("not-found", "User profile not found");
  }

  const user = userSnap.data() || {};
  const stripe = getStripeClient();

  let accountId = user.stripeConnectAccountId;

  // Create (or reuse) a Connect Express account for this user.
  if (!accountId) {
    const account = await stripe.accounts.create({
      type: "express",
      country: "US",
      email: user.email || undefined,
      capabilities: {
        transfers: { requested: true },
      },
      metadata: {
        firebaseUid: uid,
        userId: uid,
      },
    });

    accountId = account.id;
    await userRef.update({
      stripeConnectAccountId: accountId,
      stripeConnectOnboarded: false,
      updatedAt: FieldValue.serverTimestamp(),
    });

    logger.info("Created Stripe Connect account", { uid, accountId });
  }

  const accountLink = await stripe.accountLinks.create({
    account: accountId,
    refresh_url: effectiveRefreshUrl,
    return_url: effectiveReturnUrl,
    type: "account_onboarding",
  });

  return {
    url: accountLink.url,
    accountId,
  };
});

/**
 * Callable: refreshReimbursementSetupStatus
 *
 * Queries Stripe for the current Connect account state and mirrors it into
 * Firestore on the user document.
 */
exports.refreshReimbursementSetupStatus = onCall({ enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  if (!process.env.STRIPE_SECRET_KEY && !isEmulator()) {
    throw new HttpsError("failed-precondition", "Stripe is not configured");
  }

  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    throw new HttpsError("not-found", "User profile not found");
  }

  const user = userSnap.data() || {};
  const accountId = user.stripeConnectAccountId;
  if (!accountId || typeof accountId !== "string") {
    return { onboarded: false, reason: "missing_connect_account" };
  }

  const stripe = getStripeClient();
  const account = await stripe.accounts.retrieve(accountId);

  const onboarded = account?.details_submitted === true;
  const transfers = account?.capabilities?.transfers;

  await userRef.update({
    stripeConnectOnboarded: onboarded,
    stripeConnectDetailsSubmitted: account?.details_submitted === true,
    stripeConnectTransfersCapability: transfers || null,
    stripeConnectUpdatedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  logger.info("Refreshed Stripe Connect status", {
    uid,
    accountId,
    onboarded,
    transfers,
  });

  return {
    accountId,
    onboarded,
    transfersCapability: transfers || null,
  };
});
