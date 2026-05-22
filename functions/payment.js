/**
 * Create Stripe PaymentIntent for one-time payment
 * 
 * This function creates a PaymentIntent with the Stripe API for processing
 * one-time payments during policy purchase.
 * 
 * @param {number} amount - Amount in cents (e.g., 4999 for $49.99)
 * @param {string} currency - Currency code (e.g., 'usd')
 * @param {string} userId - Firebase user ID
 * @param {string} policyId - Policy identifier
 * @param {object} metadata - Additional metadata
 * @returns {object} PaymentIntent details including clientSecret
 */

const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");

if (!admin.apps.length) admin.initializeApp();

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

function getStripeApiVersion() {
  return process.env.STRIPE_API_VERSION || "2024-06-20";
}

exports.createPaymentIntent = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "User must be authenticated to create payment intent"
    );
  }

  const data = request.data || {};
  const {
    amount,
    currency = "usd",
    policyId,
    metadata = {},
    email,
  } = data;

  // Validate inputs
  if (!amount || typeof amount !== "number" || amount <= 0) {
    throw new HttpsError("invalid-argument", "Amount must be a positive number in cents");
  }

  if (!policyId || typeof policyId !== "string") {
    throw new HttpsError("invalid-argument", "Policy ID is required");
  }

  try {
    // Get or create Stripe customer
    const stripe = getStripeClient();
    const customerId = await getOrCreateStripeCustomer(stripe, uid, {
      emailHint: typeof email === "string" ? email.trim() : null,
    });
    const ephemeralKey = await stripe.ephemeralKeys.create(
      {customer: customerId},
      {apiVersion: getStripeApiVersion()},
    );

    // Create PaymentIntent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount), // Ensure integer
      currency: currency.toLowerCase(),
      customer: customerId,
      automatic_payment_methods: {
        enabled: true,
      },
      metadata: {
        userId: uid,
        policyId,
        ...(metadata && typeof metadata === "object" ? metadata : {}),
      },
      description: `Pet Insurance Policy - ${policyId}`,
    });

    // Log payment intent creation
    await admin.firestore().collection("payment_intents").doc(paymentIntent.id).set({
      userId: uid,
      policyId,
      amount,
      currency,
      status: paymentIntent.status,
      clientSecret: paymentIntent.client_secret,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    logger.info("PaymentIntent created", {paymentIntentId: paymentIntent.id, uid});

    // Return clientSecret and other necessary info
    return {
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      paymentIntent: paymentIntent.id,
      customerId: customerId,
      ephemeralKey: ephemeralKey.secret,
      amount: paymentIntent.amount,
      currency: paymentIntent.currency,
    };
  } catch (error) {
    logger.error("Error creating payment intent", {error: error?.message ?? String(error)});
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", `Failed to create payment intent: ${error?.message ?? String(error)}`);
  }
});

/**
 * Get or create Stripe customer for a user
 * @param {string} userId - Firebase user ID
 * @param {object} options - optional hints for bootstrap
 * @returns {string} Stripe customer ID
 */
async function getOrCreateStripeCustomer(stripe, userId, options = {}) {
  const userDoc = await admin.firestore().collection("users").doc(userId).get();
  const userData = userDoc.exists ? (userDoc.data() || {}) : {};

  // Check if customer already exists
  if (userData.stripeCustomerId) {
    return userData.stripeCustomerId;
  }

  // Create new Stripe customer
  const customer = await stripe.customers.create({
    email: userData.email || options.emailHint || null,
    metadata: {
      userId,
      firebaseUid: userId,
    },
  });

  // Save customer ID to user profile
  await admin.firestore().collection("users").doc(userId).set({
    stripeCustomerId: customer.id,
    ...(userData.email || !options.emailHint ? {} : {email: options.emailHint}),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  logger.info("Created Stripe customer", {customerId: customer.id, uid: userId});

  return customer.id;
}

exports.createCustomer = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  try {
    const stripe = getStripeClient();
    const customerId = await getOrCreateStripeCustomer(stripe, uid, {
      emailHint: typeof request.data?.email === "string" ?
        request.data.email.trim() :
        null,
    });
    return {customerId};
  } catch (error) {
    logger.error("Error creating customer", {error: error?.message ?? String(error)});
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", `Failed to create customer: ${error?.message ?? String(error)}`);
  }
});

exports.createSubscription = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  const data = request.data || {};
  const {priceId, policyId, email} = data;

  if (!priceId || typeof priceId !== "string") {
    throw new HttpsError("invalid-argument", "priceId is required");
  }

  if (!policyId || typeof policyId !== "string") {
    throw new HttpsError("invalid-argument", "policyId is required");
  }

  try {
    const stripe = getStripeClient();
    const customerId = await getOrCreateStripeCustomer(stripe, uid, {
      emailHint: typeof email === "string" ? email.trim() : null,
    });
    const ephemeralKey = await stripe.ephemeralKeys.create(
      {customer: customerId},
      {apiVersion: getStripeApiVersion()},
    );

    const subscription = await stripe.subscriptions.create({
      customer: customerId,
      items: [{price: priceId}],
      payment_behavior: "default_incomplete",
      payment_settings: {save_default_payment_method: "on_subscription"},
      expand: ["latest_invoice.payment_intent"],
      metadata: {
        userId: uid,
        policyId,
      },
    });

    const paymentIntent = subscription.latest_invoice &&
      subscription.latest_invoice.payment_intent;
    const clientSecret = paymentIntent && paymentIntent.client_secret;

    if (!clientSecret) {
      throw new HttpsError(
        "internal",
        "Stripe subscription did not return a client secret",
      );
    }

    return {
      subscriptionId: subscription.id,
      customerId,
      ephemeralKey: ephemeralKey.secret,
      clientSecret,
    };
  } catch (error) {
    logger.error("Error creating subscription", {error: error?.message ?? String(error)});
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", `Failed to create subscription: ${error?.message ?? String(error)}`);
  }
});

exports.cancelSubscription = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  const subscriptionId = request.data?.subscriptionId;
  if (!subscriptionId || typeof subscriptionId !== "string") {
    throw new HttpsError("invalid-argument", "subscriptionId is required");
  }

  try {
    const stripe = getStripeClient();
    const customerId = await getOrCreateStripeCustomer(stripe, uid);
    const subscription = await stripe.subscriptions.retrieve(subscriptionId);
    if (subscription.customer !== customerId) {
      throw new HttpsError(
        "permission-denied",
        "Subscription does not belong to the authenticated user",
      );
    }

    const canceled = await stripe.subscriptions.cancel(subscriptionId);
    return {
      subscriptionId: canceled.id,
      status: canceled.status,
    };
  } catch (error) {
    logger.error("Error canceling subscription", {error: error?.message ?? String(error)});
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", `Failed to cancel subscription: ${error?.message ?? String(error)}`);
  }
});

/**
 * Confirm Payment Intent status (webhook or manual check)
 * This is called by Stripe webhooks to update payment status
 */
exports.handlePaymentIntentSucceeded = onRequest(async (req, res) => {
  const sig = req.headers["stripe-signature"];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
  const stripe = getStripeClient();

  let event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err) {
    logger.error("Webhook signature verification failed", {error: err?.message ?? String(err)});
    res.status(400).send(`Webhook Error: ${err?.message ?? String(err)}`);
    return;
  }

  // Handle the event
  switch (event.type) {
    case 'payment_intent.succeeded':
      const paymentIntent = event.data.object;
      await handlePaymentSuccess(paymentIntent);
      break;
    case 'payment_intent.payment_failed':
      const failedPayment = event.data.object;
      await handlePaymentFailure(failedPayment);
      break;
    case 'checkout.session.completed':
      const checkoutSession = event.data.object;
      await handleCheckoutSessionCompleted(checkoutSession);
      break;
    default:
        logger.info("Unhandled Stripe event", {type: event.type});
  }

  res.json({ received: true });
});

async function handlePaymentSuccess(paymentIntent) {
  const { id, amount, currency, metadata } = paymentIntent;
  const { userId, policyId } = metadata;

  try {
    // Update payment intent record
    await admin.firestore().collection("payment_intents").doc(id).update({
      status: "succeeded",
      succeededAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Create payment record
    await admin.firestore().collection("payments").add({
      userId,
      policyId,
      paymentIntentId: id,
      amount: amount / 100, // Convert cents to dollars
      currency,
      status: "succeeded",
      paidAt: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info("Payment succeeded", {paymentIntentId: id});
  } catch (error) {
    logger.error("Error handling payment success", {paymentIntentId: id, error: error?.message ?? String(error)});
  }
}

async function handlePaymentFailure(paymentIntent) {
  const { id, last_payment_error } = paymentIntent;

  try {
    await admin.firestore().collection("payment_intents").doc(id).update({
      status: "failed",
      error: last_payment_error?.message || "Payment failed",
      failedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    logger.warn("Payment failed", {paymentIntentId: id});
  } catch (error) {
    logger.error("Error handling payment failure", {paymentIntentId: id, error: error?.message ?? String(error)});
  }
}

async function handleCheckoutSessionCompleted(session) {
  const policyId = session.metadata?.policyId;
  const caseId = session.metadata?.caseId || session.client_reference_id;

  if (!policyId || !caseId) {
    logger.warn("Checkout session missing policy binding metadata", {
      checkoutSessionId: session.id,
      policyId,
      caseId,
    });
    return;
  }

  if (session.payment_status && session.payment_status !== "paid") {
    await admin.firestore().collection("policy_bindings").doc(policyId).set({
      status: "checkout_completed_payment_pending",
      checkoutSessionId: session.id,
      checkoutPaymentStatus: session.payment_status,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    logger.info("Checkout completed but payment is not paid yet", {
      checkoutSessionId: session.id,
      policyId,
      paymentStatus: session.payment_status,
    });
    return;
  }

  const bindingRef = admin.firestore().collection("policy_bindings").doc(policyId);
  const caseRef = admin.firestore().collection("underwriting_cases").doc(caseId);
  const [bindingSnap, caseSnap] = await Promise.all([bindingRef.get(), caseRef.get()]);

  if (!bindingSnap.exists || !caseSnap.exists) {
    logger.error("Policy binding activation missing records", {
      checkoutSessionId: session.id,
      policyId,
      caseId,
      bindingExists: bindingSnap.exists,
      caseExists: caseSnap.exists,
    });
    return;
  }

  const binding = bindingSnap.data() || {};
  const underwriting = binding.underwritingSnapshot || {};
  const approved =
    (underwriting.status === "approved" ||
      underwriting.status === "approved_with_exclusions") &&
    underwriting.pricingEnabled === true &&
    underwriting.integrityPassed === true;

  if (!approved) {
    await bindingRef.set({
      status: "activation_blocked",
      activationBlockedReason: "UNDERWRITING_NOT_APPROVED",
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
    logger.error("Checkout paid but underwriting gates are not approved", {
      checkoutSessionId: session.id,
      policyId,
      caseId,
      underwritingStatus: underwriting.status,
    });
    return;
  }

  const caseData = caseSnap.data() || {};
  const quote = caseData.quote || {};
  const contact = caseData.contact || {};
  const now = new Date();
  const expirationDate = new Date(
    now.getFullYear() + 1,
    now.getMonth(),
    now.getDate(),
  );
  const policyNumber = `CLV-${now.getFullYear()}-${policyId.slice(0, 8).toUpperCase()}`;

  const policy = {
    policyId,
    policyNumber,
    status: "active",
    source: "no_touch_checkout",
    noHumanTouch: true,
    underwritingCaseId: caseId,
    ownerId: contact.emailHash || null,
    owner: {
      firstName: contact.firstName || "",
      lastName: contact.lastName || "",
      email: contact.email || "",
      zipCode: contact.zipCode || quote.zipCode || "",
    },
    pet: {
      name: quote.petName || "",
      species: quote.petType || "",
      breed: quote.breed || "",
      ageYears: quote.ageYears || "",
      ageMonths: quote.ageMonths || "",
      weightLbs: quote.weightLbs || "",
      sex: quote.sex || "",
      altered: quote.altered || "",
    },
    plan: {
      ...(binding.selectedPlan || {}),
      ...(binding.selectedOptions || {}),
      monthlyPremium: binding.monthlyPremium ?? (
        session.amount_total ? Number(session.amount_total) / 100 : null
      ),
    },
    payment: {
      provider: "stripe",
      checkoutSessionId: session.id,
      subscriptionId: typeof session.subscription === "string" ? session.subscription : null,
      customerId: typeof session.customer === "string" ? session.customer : null,
      paymentStatus: session.payment_status || "paid",
    },
    exclusions: Array.isArray(underwriting.exclusions) ? underwriting.exclusions : [],
    underwritingSnapshot: underwriting,
    effectiveDate: now.toISOString(),
    expirationDate: expirationDate.toISOString(),
    createdAt: now.toISOString(),
    activatedAt: FieldValue.serverTimestamp(),
    lastUpdated: FieldValue.serverTimestamp(),
  };

  await admin.firestore().collection("policies").doc(policyId).set(policy, {merge: true});
  await bindingRef.set({
    status: "active",
    activatedAt: FieldValue.serverTimestamp(),
    checkoutSessionId: session.id,
    subscriptionId: typeof session.subscription === "string" ? session.subscription : null,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await caseRef.set({
    status: "policy_active",
    policyId,
    policyNumber,
    activatedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});

  logger.info("No-touch policy activated from Checkout", {
    checkoutSessionId: session.id,
    policyId,
    caseId,
  });
}
