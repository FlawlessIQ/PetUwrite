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

exports.createPaymentIntent = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError(
      "unauthenticated",
      "User must be authenticated to create payment intent"
    );
  }

  const data = request.data || {};
  const {amount, currency = "usd", policyId, metadata = {}} = data;

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
    const customerId = await getOrCreateStripeCustomer(stripe, uid);

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
      customerId: customerId,
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
 * @returns {string} Stripe customer ID
 */
async function getOrCreateStripeCustomer(stripe, userId) {
  const userDoc = await admin.firestore().collection("users").doc(userId).get();
  
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "User profile not found");
  }

  const userData = userDoc.data();

  // Check if customer already exists
  if (userData.stripeCustomerId) {
    return userData.stripeCustomerId;
  }

  // Create new Stripe customer
  const customer = await stripe.customers.create({
    email: userData.email || null,
    metadata: {
      userId,
      firebaseUid: userId,
    },
  });

  // Save customer ID to user profile
  await admin.firestore().collection("users").doc(userId).update({
    stripeCustomerId: customer.id,
    updatedAt: FieldValue.serverTimestamp(),
  });

  logger.info("Created Stripe customer", {customerId: customer.id, uid: userId});

  return customer.id;
}

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
