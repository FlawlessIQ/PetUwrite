/**
 * Cloud Functions for Pet Underwriter AI
 * 
 * Webhook triggers for quote creation and policy binding
 * PDF extraction and processing
 */

const {setGlobalOptions} = require("firebase-functions/v2");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

// Initialize Firebase Admin
admin.initializeApp();

// Import PDF extraction functions
const pdfExtraction = require("./pdfExtraction");

// Import policy email functions
const policyEmails = require("./policyEmails");

// Import admin dashboard functions
const adminDashboard = require("./adminDashboard");

// Import declined quote notification functions
const declinedQuoteNotifications = require("./declinedQuoteNotifications");

// For cost control, set maximum number of containers
setGlobalOptions({maxInstances: 10});

/**
 * Triggered when a new quote is created
 * - Sends notification email to user
 * - Logs quote creation for analytics
 * - Triggers risk score calculation if not present
 */
exports.onQuoteCreated = onDocumentCreated(
    "quotes/{quoteId}",
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        logger.warn("No data associated with the event");
        return;
      }

      const quoteData = snapshot.data();
      const quoteId = event.params.quoteId;

      logger.info("New quote created", {
        quoteId: quoteId,
        ownerId: quoteData.ownerId,
        petId: quoteData.petId,
      });

      try {
        // Get owner information
        const ownerDoc = await admin
            .firestore()
            .collection("users")
            .doc(quoteData.ownerId)
            .get();

        if (!ownerDoc.exists) {
          logger.error("Owner not found", {ownerId: quoteData.ownerId});
          return;
        }

        const ownerData = ownerDoc.data();

        // TODO: Send email notification to owner
        // This would integrate with SendGrid, Mailgun, or similar service
        logger.info("Email notification would be sent to:", {
          email: ownerData.email,
          name: `${ownerData.firstName} ${ownerData.lastName}`,
        });

        // Log analytics event
        await admin.firestore().collection("analytics").add({
          event: "quote_created",
          quoteId: quoteId,
          ownerId: quoteData.ownerId,
          petId: quoteData.petId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          metadata: {
            status: quoteData.status,
            numberOfPlans: quoteData.availablePlans?.length || 0,
          },
        });

        // Check if risk score needs calculation
        if (!quoteData.riskScore || !quoteData.riskScore.id) {
          logger.info("Risk score missing, triggering calculation", {
            quoteId: quoteId,
          });
          // TODO: Trigger risk score calculation
          // This could call another function or external API
        }

        return {success: true, quoteId: quoteId};
      } catch (error) {
        logger.error("Error processing quote creation", {
          error: error.message,
          quoteId: quoteId,
        });
        throw error;
      }
    },
);

/**
 * Triggered when a policy status changes to "active" (bound)
 * - Sends policy confirmation email
 * - Generates policy documents
 * - Sets up payment reminders
 * - Logs policy binding for reporting
 */
exports.onPolicyBound = onDocumentUpdated(
    "policies/{policyId}",
    async (event) => {
      const before = event.data.before;
      const after = event.data.after;

      if (!before || !after) {
        logger.warn("Missing before or after data");
        return;
      }

      const beforeStatus = before.data().status;
      const afterStatus = after.data().status;
      const policyId = event.params.policyId;

      // Check if policy status changed to active
      if (beforeStatus !== "PolicyStatus.active" &&
          afterStatus === "PolicyStatus.active") {
        logger.info("Policy bound (activated)", {
          policyId: policyId,
          previousStatus: beforeStatus,
        });

        const policyData = after.data();

        try {
          // Get owner information
          const ownerDoc = await admin
              .firestore()
              .collection("users")
              .doc(policyData.ownerId)
              .get();

          if (!ownerDoc.exists) {
            logger.error("Owner not found", {ownerId: policyData.ownerId});
            return;
          }

          const ownerData = ownerDoc.data();

          // Get pet information
          const petDoc = await admin
              .firestore()
              .collection("pets")
              .doc(policyData.petId)
              .get();

          const petData = petDoc.exists ? petDoc.data() : null;

          // TODO: Send policy confirmation email
          logger.info("Policy confirmation email would be sent to:", {
            email: ownerData.email,
            policyNumber: policyData.policyNumber,
            petName: petData?.name || "Unknown",
          });

          // TODO: Generate policy documents (PDF)
          // This would use a library like PDFKit or call a document
          // generation service
          logger.info("Policy documents would be generated", {
            policyId: policyId,
          });

          // Set up payment reminders based on payment schedule
          const paymentSchedule = policyData.paymentSchedule;
          const nextPaymentDate = calculateNextPaymentDate(
              policyData.effectiveDate,
              paymentSchedule,
          );

          await admin.firestore().collection("paymentReminders").add({
            policyId: policyId,
            ownerId: policyData.ownerId,
            nextPaymentDate: nextPaymentDate,
            paymentSchedule: paymentSchedule,
            amount: policyData.plan.monthlyPremium,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            status: "pending",
          });

          // Log analytics event
          await admin.firestore().collection("analytics").add({
            event: "policy_bound",
            policyId: policyId,
            policyNumber: policyData.policyNumber,
            ownerId: policyData.ownerId,
            petId: policyData.petId,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            metadata: {
              planTier: policyData.plan.tier,
              monthlyPremium: policyData.plan.monthlyPremium,
              paymentSchedule: paymentSchedule,
            },
          });

          logger.info("Policy binding processed successfully", {
            policyId: policyId,
          });

          return {success: true, policyId: policyId};
        } catch (error) {
          logger.error("Error processing policy binding", {
            error: error.message,
            policyId: policyId,
          });
          throw error;
        }
      }

      return null;
    },
);

/**
 * Helper function to calculate next payment date
 */
function calculateNextPaymentDate(effectiveDate, schedule) {
  const date = new Date(effectiveDate);

  switch (schedule) {
    case "PaymentSchedule.monthly":
      date.setMonth(date.getMonth() + 1);
      break;
    case "PaymentSchedule.quarterly":
      date.setMonth(date.getMonth() + 3);
      break;
    case "PaymentSchedule.annually":
      date.setFullYear(date.getFullYear() + 1);
      break;
    default:
      date.setMonth(date.getMonth() + 1);
  }

  return admin.firestore.Timestamp.fromDate(date);
}

/**
 * HTTP endpoint for manual risk score calculation
 * Can be called from the app or other services
 */
exports.calculateRiskScore = onRequest(
    {cors: true},
    async (request, response) => {
      if (request.method !== "POST") {
        response.status(405).send("Method Not Allowed");
        return;
      }

      const {petId, ownerId} = request.body;

      if (!petId || !ownerId) {
        response.status(400).send("Missing required fields: petId, ownerId");
        return;
      }

      try {
        logger.info("Calculating risk score", {petId, ownerId});

        // Get pet data
        const petDoc = await admin
            .firestore()
            .collection("pets")
            .doc(petId)
            .get();

        if (!petDoc.exists) {
          response.status(404).send("Pet not found");
          return;
        }

        const petData = petDoc.data();

        // TODO: Implement actual risk scoring logic
        // This would integrate with your AI services (GPT/Vertex AI)
        const mockRiskScore = {
          id: `risk_${Date.now()}`,
          petId: petId,
          calculatedAt: new Date().toISOString(),
          overallScore: 45.5,
          riskLevel: "RiskLevel.medium",
          categoryScores: {
            age: 30,
            breed: 40,
            preExisting: 50,
            medicalHistory: 45,
            lifestyle: 35,
          },
          riskFactors: [],
        };

        // Save risk score
        await admin.firestore().collection("riskScores").add({
          ...mockRiskScore,
          ownerId: ownerId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        logger.info("Risk score calculated", {
          petId,
          score: mockRiskScore.overallScore,
        });

        response.json({
          success: true,
          riskScore: mockRiskScore,
        });
      } catch (error) {
        logger.error("Error calculating risk score", {error: error.message});
        response.status(500).json({
          success: false,
          error: error.message,
        });
      }
    },
);

/**
 * Webhook endpoint for Stripe payment events
 * Handles payment success, failure, and subscription events
 */
exports.stripeWebhook = onRequest(
    {cors: false},
    async (request, response) => {
      if (request.method !== "POST") {
        response.status(405).send("Method Not Allowed");
        return;
      }

      const event = request.body;

      logger.info("Stripe webhook received", {type: event.type});

      try {
        switch (event.type) {
          case "payment_intent.succeeded":
            await handlePaymentSuccess(event.data.object);
            break;
          case "payment_intent.failed":
            await handlePaymentFailure(event.data.object);
            break;
          case "customer.subscription.created":
            await handleSubscriptionCreated(event.data.object);
            break;
          case "customer.subscription.updated":
            await handleSubscriptionUpdated(event.data.object);
            break;
          case "customer.subscription.deleted":
            await handleSubscriptionDeleted(event.data.object);
            break;
          default:
            logger.info("Unhandled event type", {type: event.type});
        }

        response.json({received: true});
      } catch (error) {
        logger.error("Error processing Stripe webhook", {
          error: error.message,
        });
        response.status(500).json({error: error.message});
      }
    },
);

/**
 * Handle successful payment
 */
async function handlePaymentSuccess(paymentIntent) {
  logger.info("Payment succeeded", {paymentIntentId: paymentIntent.id});

  const policyId = paymentIntent.metadata?.policyId;

  if (policyId) {
    // Update policy status
    await admin.firestore().collection("policies").doc(policyId).update({
      status: "PolicyStatus.active",
      lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log payment
    await admin.firestore().collection("payments").add({
      policyId: policyId,
      paymentIntentId: paymentIntent.id,
      amount: paymentIntent.amount / 100,
      currency: paymentIntent.currency,
      status: "succeeded",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

/**
 * Handle failed payment
 */
async function handlePaymentFailure(paymentIntent) {
  logger.error("Payment failed", {paymentIntentId: paymentIntent.id});

  const policyId = paymentIntent.metadata?.policyId;

  if (policyId) {
    // Update policy status
    await admin.firestore().collection("policies").doc(policyId).update({
      status: "PolicyStatus.suspended",
      paymentFailureDate: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log failed payment
    await admin.firestore().collection("payments").add({
      policyId: policyId,
      paymentIntentId: paymentIntent.id,
      amount: paymentIntent.amount / 100,
      currency: paymentIntent.currency,
      status: "failed",
      failureReason: paymentIntent.last_payment_error?.message,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // TODO: Send payment failure notification
  }
}

/**
 * Handle subscription creation
 */
async function handleSubscriptionCreated(subscription) {
  logger.info("Subscription created", {subscriptionId: subscription.id});

  const policyId = subscription.metadata?.policyId;

  if (policyId) {
    await admin.firestore().collection("policies").doc(policyId).update({
      subscriptionId: subscription.id,
      subscriptionStatus: subscription.status,
    });
  }
}

/**
 * Handle subscription update
 */
async function handleSubscriptionUpdated(subscription) {
  logger.info("Subscription updated", {subscriptionId: subscription.id});

  const policyId = subscription.metadata?.policyId;

  if (policyId) {
    await admin.firestore().collection("policies").doc(policyId).update({
      subscriptionStatus: subscription.status,
    });
  }
}

/**
 * Handle subscription deletion
 */
async function handleSubscriptionDeleted(subscription) {
  logger.info("Subscription deleted", {subscriptionId: subscription.id});

  const policyId = subscription.metadata?.policyId;

  if (policyId) {
    await admin.firestore().collection("policies").doc(policyId).update({
      status: "PolicyStatus.cancelled",
      subscriptionStatus: "canceled",
      cancellationDate: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

// Export PDF extraction functions
exports.extractPdfText = pdfExtraction.extractPdfText;

// Export policy email functions
exports.sendPolicyEmail = policyEmails.sendPolicyEmail;
exports.generatePolicyPDF = policyEmails.generatePolicyPDF;
exports.checkExpiringPolicies = policyEmails.checkExpiringPolicies;

// Export admin dashboard functions
exports.flagHighRiskQuote = adminDashboard.flagHighRiskQuote;
exports.onQuoteOverride = adminDashboard.onQuoteOverride;
exports.generateDailyOverrideReport = adminDashboard.generateDailyOverrideReport;
exports.alertPendingQuotes = adminDashboard.alertPendingQuotes;
exports.getOverrideAnalytics = adminDashboard.getOverrideAnalytics;
exports.processPdfOnUpload = pdfExtraction.processPdfOnUpload;
exports.getPdfProcessingStatus = pdfExtraction.getPdfProcessingStatus;

/**
 * Triggered when a quote's eligibility status changes to declined
 * - Sends notification to Slack webhook
 * - Sends email via SendGrid (if configured)
 * - Logs the decline for analytics
 */
exports.onQuoteDeclined = onDocumentUpdated(
    "quotes/{quoteId}",
    async (event) => {
      const before = event.data.before;
      const after = event.data.after;

      if (!before || !after) {
        logger.warn("Missing before or after data in onQuoteDeclined");
        return;
      }

      const beforeEligibility = before.data().eligibility;
      const afterEligibility = after.data().eligibility;
      const quoteId = event.params.quoteId;

      // Check if eligibility just changed to declined
      const wasDeclined = beforeEligibility?.status === "declined";
      const isNowDeclined = afterEligibility?.status === "declined" &&
                            afterEligibility?.eligible === false;

      if (!wasDeclined && isNowDeclined) {
        logger.info("Quote declined - triggering notification", {
          quoteId,
          ruleViolated: afterEligibility.ruleViolated,
        });

        try {
          const quoteData = after.data();

          // Send notifications
          const result = await declinedQuoteNotifications.handleDeclinedQuoteNotification(
              quoteData,
              quoteId,
          );

          // Log analytics event
          await admin.firestore().collection("analytics").add({
            event: "quote_declined",
            quoteId: quoteId,
            ruleViolated: afterEligibility.ruleViolated,
            violatedValue: afterEligibility.violatedValue,
            reason: afterEligibility.reason,
            petBreed: quoteData.pet?.breed,
            petAge: quoteData.pet?.age,
            riskScore: quoteData.riskScore?.totalScore,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            notificationsSent: {
              slack: result.slack,
              email: result.email,
            },
          });

          logger.info("Quote decline processed successfully", {
            quoteId,
            notificationsSent: result,
          });

          return result;
        } catch (error) {
          logger.error("Error processing declined quote", {
            error: error.message,
            quoteId,
          });
          throw error;
        }
      } else {
        logger.debug("Quote eligibility changed but not to declined state", {
          quoteId,
          beforeStatus: beforeEligibility?.status,
          afterStatus: afterEligibility?.status,
        });
        return null;
      }
    },
);

// Export claims analytics functions
const claimsAnalytics = require("./claimsAnalytics");
exports.getClaimsAnalytics = claimsAnalytics.getClaimsAnalytics;
exports.updateClaimsAnalyticsCache = claimsAnalytics.updateClaimsAnalyticsCache;

// Export claims reconciliation functions
const claimsReconciliation = require("./claimsReconciliation");
exports.reconcileClaimsState = claimsReconciliation.reconcileClaimsState;
exports.retryFailedOperation = claimsReconciliation.retryFailedOperation;

// Export AI training export functions
const aiTrainingExport = require("./aiTrainingExport");
exports.exportAITrainingBatch = aiTrainingExport.exportAITrainingBatch;
exports.onBatchCompleted = aiTrainingExport.onBatchCompleted;

// Export analytics email functions
const analyticsEmail = require("./analyticsEmail");
exports.sendAnalyticsEmail = analyticsEmail.sendAnalyticsEmail;
