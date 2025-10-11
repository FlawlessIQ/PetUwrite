/**
 * Claims State Reconciliation System
 * 
 * Automatically detects and corrects inconsistent states between claims and payouts.
 * Runs hourly to ensure data integrity and retry failed operations.
 * 
 * Functions:
 * 1. Find payouts marked 'completed' with claims still 'processing'
 * 2. Auto-update claims to 'settled' and log to audit trail
 * 3. Identify failed Stripe/SendGrid operations and retry up to 3 times
 * 4. Notify admin via Slack or email if unresolvable after 3 attempts
 */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const https = require("https");

// Environment variables (set via Firebase config)
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY;
const SENDGRID_API_KEY = process.env.SENDGRID_API_KEY;
const SLACK_WEBHOOK_URL = process.env.SLACK_WEBHOOK_URL;
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || "admin@petuwrite.com";

// Maximum retry attempts before escalation
const MAX_RETRY_ATTEMPTS = 3;

/**
 * Scheduled function that runs hourly to reconcile claims state
 * Triggered at :00 every hour
 */
exports.reconcileClaimsState = onSchedule({
  schedule: "0 * * * *", // Every hour at :00
  timeZone: "America/New_York",
  memory: "512MiB",
  timeoutSeconds: 540, // 9 minutes
}, async (event) => {
  logger.info("Starting claims state reconciliation");

  const reconciliationId = `reconciliation_${Date.now()}`;
  const startTime = Date.now();

  try {
    const results = {
      reconciliationId,
      startedAt: new Date().toISOString(),
      mismatchedStatesFixed: 0,
      failedOperationsRetried: 0,
      successfulRetries: 0,
      escalatedToAdmin: 0,
      errors: [],
    };

    // Step 1: Find and fix mismatched states
    logger.info("Step 1: Finding mismatched claim/payout states");
    const mismatchResults = await findAndFixMismatchedStates();
    results.mismatchedStatesFixed = mismatchResults.fixed;
    results.errors.push(...mismatchResults.errors);

    // Step 2: Retry failed operations
    logger.info("Step 2: Retrying failed operations");
    const retryResults = await retryFailedOperations();
    results.failedOperationsRetried = retryResults.attempted;
    results.successfulRetries = retryResults.succeeded;
    results.escalatedToAdmin = retryResults.escalated;
    results.errors.push(...retryResults.errors);

    // Step 3: Log reconciliation results
    const duration = Date.now() - startTime;
    results.completedAt = new Date().toISOString();
    results.durationMs = duration;

    await logReconciliationRun(results);

    logger.info("Claims state reconciliation completed", {
      duration: `${duration}ms`,
      fixed: results.mismatchedStatesFixed,
      retried: results.failedOperationsRetried,
      succeeded: results.successfulRetries,
      escalated: results.escalatedToAdmin,
    });

    // Send notification if significant issues found
    if (results.mismatchedStatesFixed > 10 || results.escalatedToAdmin > 0) {
      await notifyAdminOfReconciliation(results);
    }

    return results;
  } catch (error) {
    logger.error("Fatal error in claims reconciliation", {
      error: error.message,
      stack: error.stack,
    });

    await logReconciliationRun({
      reconciliationId,
      startedAt: new Date().toISOString(),
      completedAt: new Date().toISOString(),
      status: "failed",
      error: error.message,
    });

    throw error;
  }
});

/**
 * Find claims with completed payouts but stuck in 'processing' or 'settling' status
 * Auto-update these claims to 'settled' status
 */
async function findAndFixMismatchedStates() {
  const results = {fixed: 0, errors: []};

  try {
    const db = admin.firestore();
    
    // Query claims that are not in final states
    const claimsSnapshot = await db
        .collection("claims")
        .where("status", "in", ["processing", "settling"])
        .limit(500) // Process in batches
        .get();

    logger.info(`Found ${claimsSnapshot.size} claims in processing/settling state`);

    for (const claimDoc of claimsSnapshot.docs) {
      const claimId = claimDoc.id;
      const claimData = claimDoc.data();

      try {
        // Check if there's a completed payout for this claim
        const payoutsSnapshot = await db
            .collection("payouts")
            .where("claimId", "==", claimId)
            .where("status", "==", "completed")
            .limit(1)
            .get();

        if (!payoutsSnapshot.empty) {
          const payoutData = payoutsSnapshot.docs[0].data();
          const payoutId = payoutsSnapshot.docs[0].id;

          logger.info("Mismatched state detected", {
            claimId,
            claimStatus: claimData.status,
            payoutStatus: "completed",
            payoutId,
          });

          // Update claim to 'settled'
          await db.collection("claims").doc(claimId).update({
            status: "settled",
            settledAt: admin.firestore.FieldValue.serverTimestamp(),
            reconciledAt: admin.firestore.FieldValue.serverTimestamp(),
            reconciledBy: "system_reconciliation",
          });

          // Log to audit trail
          await db.collection("payout_audit_trail").add({
            type: "state_reconciliation",
            claimId,
            payoutId,
            previousStatus: claimData.status,
            newStatus: "settled",
            reason: "Auto-reconciled: Found completed payout for non-settled claim",
            performedBy: "system",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            metadata: {
              claimAmount: claimData.claimAmount,
              payoutAmount: payoutData.amount,
              originalSettlingBy: claimData.settlingBy,
              originalSettlingAt: claimData.settlingAt,
            },
          });

          results.fixed++;
        }
      } catch (error) {
        logger.error("Error fixing mismatched state", {
          claimId,
          error: error.message,
        });
        results.errors.push({
          claimId,
          operation: "fix_mismatched_state",
          error: error.message,
        });
      }
    }

    logger.info(`Fixed ${results.fixed} mismatched states`);
    return results;
  } catch (error) {
    logger.error("Error in findAndFixMismatchedStates", {
      error: error.message,
    });
    results.errors.push({
      operation: "find_mismatched_states",
      error: error.message,
    });
    return results;
  }
}

/**
 * Find and retry failed Stripe/SendGrid operations
 * Escalate to admin after MAX_RETRY_ATTEMPTS
 */
async function retryFailedOperations() {
  const results = {attempted: 0, succeeded: 0, escalated: 0, errors: []};

  try {
    const db = admin.firestore();

    // Find payouts with status 'failed' or 'pending_retry'
    const failedPayoutsSnapshot = await db
        .collection("payouts")
        .where("status", "in", ["failed", "pending_retry"])
        .limit(100)
        .get();

    logger.info(`Found ${failedPayoutsSnapshot.size} failed payouts to retry`);

    for (const payoutDoc of failedPayoutsSnapshot.docs) {
      const payoutId = payoutDoc.id;
      const payoutData = payoutDoc.data();
      const retryCount = payoutData.retryCount || 0;

      results.attempted++;

      try {
        // Check if max retries exceeded
        if (retryCount >= MAX_RETRY_ATTEMPTS) {
          logger.warn("Max retries exceeded, escalating to admin", {
            payoutId,
            retryCount,
          });

          await escalateFailedOperation(payoutId, payoutData);
          results.escalated++;
          continue;
        }

        // Attempt retry based on failure type
        const failureType = payoutData.failureType || "stripe_payout";
        let retrySuccessful = false;

        if (failureType === "stripe_payout") {
          retrySuccessful = await retryStripePayout(payoutId, payoutData);
        } else if (failureType === "sendgrid_notification") {
          retrySuccessful = await retrySendGridNotification(payoutId, payoutData);
        }

        if (retrySuccessful) {
          results.succeeded++;
          logger.info("Retry successful", {payoutId, retryCount: retryCount + 1});
        } else {
          // Update retry count and schedule next attempt
          await db.collection("payouts").doc(payoutId).update({
            retryCount: retryCount + 1,
            lastRetryAt: admin.firestore.FieldValue.serverTimestamp(),
            status: "pending_retry",
          });

          await db.collection("payout_audit_trail").add({
            type: "retry_attempt",
            payoutId,
            claimId: payoutData.claimId,
            retryCount: retryCount + 1,
            failureType,
            result: "failed",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      } catch (error) {
        logger.error("Error retrying failed operation", {
          payoutId,
          error: error.message,
        });
        results.errors.push({
          payoutId,
          operation: "retry_failed_operation",
          error: error.message,
        });
      }
    }

    return results;
  } catch (error) {
    logger.error("Error in retryFailedOperations", {
      error: error.message,
    });
    results.errors.push({
      operation: "retry_failed_operations",
      error: error.message,
    });
    return results;
  }
}

/**
 * Retry a failed Stripe payout
 */
async function retryStripePayout(payoutId, payoutData) {
  try {
    logger.info("Retrying Stripe payout", {payoutId});

    // Verify claim is still in appropriate state
    const db = admin.firestore();
    const claimDoc = await db.collection("claims").doc(payoutData.claimId).get();

    if (!claimDoc.exists) {
      throw new Error("Claim not found");
    }

    const claimData = claimDoc.data();
    if (!["settling", "processing"].includes(claimData.status)) {
      logger.warn("Claim not in appropriate state for payout retry", {
        claimId: payoutData.claimId,
        status: claimData.status,
      });
      return false;
    }

    // Execute Stripe payout with stored idempotency key
    const stripeResult = await executeStripePayout({
      amount: payoutData.amount,
      currency: payoutData.currency || "usd",
      customerId: payoutData.stripeCustomerId,
      idempotencyKey: payoutData.idempotencyKey,
      description: `Claim payout retry for claim ${payoutData.claimId}`,
    });

    if (stripeResult.success) {
      // Update payout status
      await db.collection("payouts").doc(payoutId).update({
        status: "completed",
        stripeTransactionId: stripeResult.transactionId,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        retrySuccessful: true,
      });

      // Update claim status
      await db.collection("claims").doc(payoutData.claimId).update({
        status: "settled",
        settledAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Log success to audit trail
      await db.collection("payout_audit_trail").add({
        type: "retry_success",
        payoutId,
        claimId: payoutData.claimId,
        operation: "stripe_payout",
        retryCount: (payoutData.retryCount || 0) + 1,
        stripeTransactionId: stripeResult.transactionId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return true;
    }

    return false;
  } catch (error) {
    logger.error("Error retrying Stripe payout", {
      payoutId,
      error: error.message,
    });
    return false;
  }
}

/**
 * Retry a failed SendGrid notification
 */
async function retrySendGridNotification(payoutId, payoutData) {
  try {
    logger.info("Retrying SendGrid notification", {payoutId});

    const db = admin.firestore();

    // Get owner email
    const claimDoc = await db.collection("claims").doc(payoutData.claimId).get();
    if (!claimDoc.exists) {
      throw new Error("Claim not found");
    }

    const claimData = claimDoc.data();
    const ownerDoc = await db.collection("users").doc(claimData.ownerId).get();

    if (!ownerDoc.exists) {
      throw new Error("Owner not found");
    }

    const ownerData = ownerDoc.data();

    // Send notification via SendGrid
    const sendGridResult = await sendPayoutNotification({
      to: ownerData.email,
      ownerName: `${ownerData.firstName} ${ownerData.lastName}`,
      claimId: payoutData.claimId,
      amount: payoutData.amount,
      currency: payoutData.currency || "USD",
    });

    if (sendGridResult.success) {
      // Update payout
      await db.collection("payouts").doc(payoutId).update({
        notificationSent: true,
        notificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Log success
      await db.collection("payout_audit_trail").add({
        type: "retry_success",
        payoutId,
        claimId: payoutData.claimId,
        operation: "sendgrid_notification",
        retryCount: (payoutData.retryCount || 0) + 1,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      return true;
    }

    return false;
  } catch (error) {
    logger.error("Error retrying SendGrid notification", {
      payoutId,
      error: error.message,
    });
    return false;
  }
}

/**
 * Escalate failed operation to admin after max retries
 */
async function escalateFailedOperation(payoutId, payoutData) {
  try {
    const db = admin.firestore();

    // Mark as escalated
    await db.collection("payouts").doc(payoutId).update({
      status: "escalated",
      escalatedAt: admin.firestore.FieldValue.serverTimestamp(),
      escalatedReason: `Failed after ${payoutData.retryCount} retry attempts`,
    });

    // Log escalation
    await db.collection("payout_audit_trail").add({
      type: "escalation",
      payoutId,
      claimId: payoutData.claimId,
      reason: "max_retries_exceeded",
      retryCount: payoutData.retryCount,
      failureType: payoutData.failureType,
      lastError: payoutData.lastError,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      requiresManualIntervention: true,
    });

    // Send admin notification
    await sendAdminNotification({
      type: "payout_escalation",
      payoutId,
      claimId: payoutData.claimId,
      amount: payoutData.amount,
      retryCount: payoutData.retryCount,
      failureType: payoutData.failureType,
      lastError: payoutData.lastError,
    });

    logger.warn("Operation escalated to admin", {payoutId});
  } catch (error) {
    logger.error("Error escalating failed operation", {
      payoutId,
      error: error.message,
    });
    throw error;
  }
}

/**
 * Execute Stripe payout with timeout
 */
async function executeStripePayout(options) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      amount: Math.round(options.amount * 100), // Convert to cents
      currency: options.currency,
      customer: options.customerId,
      description: options.description,
    });

    const requestOptions = {
      hostname: "api.stripe.com",
      port: 443,
      path: "/v1/refunds", // Or appropriate Stripe endpoint
      method: "POST",
      headers: {
        "Authorization": `Bearer ${STRIPE_SECRET_KEY}`,
        "Content-Type": "application/x-www-form-urlencoded",
        "Content-Length": postData.length,
        "Idempotency-Key": options.idempotencyKey,
      },
      timeout: 30000, // 30 second timeout
    };

    const req = https.request(requestOptions, (res) => {
      let data = "";

      res.on("data", (chunk) => {
        data += chunk;
      });

      res.on("end", () => {
        try {
          const response = JSON.parse(data);

          if (res.statusCode === 200) {
            resolve({
              success: true,
              transactionId: response.id,
            });
          } else {
            logger.error("Stripe API error", {
              statusCode: res.statusCode,
              response,
            });
            resolve({success: false, error: response.error});
          }
        } catch (error) {
          reject(error);
        }
      });
    });

    req.on("error", (error) => {
      logger.error("Stripe request error", {error: error.message});
      resolve({success: false, error: error.message});
    });

    req.on("timeout", () => {
      req.destroy();
      logger.error("Stripe request timeout");
      resolve({success: false, error: "Request timeout"});
    });

    req.write(postData);
    req.end();
  });
}

/**
 * Send payout notification via SendGrid
 */
async function sendPayoutNotification(options) {
  return new Promise((resolve) => {
    const emailData = JSON.stringify({
      personalizations: [{
        to: [{email: options.to}],
        subject: `Payment Processed - Claim ${options.claimId}`,
      }],
      from: {email: "noreply@petuwrite.com", name: "PetUwrite"},
      content: [{
        type: "text/html",
        value: `
          <p>Hello ${options.ownerName},</p>
          <p>Your claim payout has been processed successfully.</p>
          <p><strong>Claim ID:</strong> ${options.claimId}</p>
          <p><strong>Amount:</strong> ${options.currency} ${options.amount.toFixed(2)}</p>
          <p>The payment should appear in your account within 5-7 business days.</p>
          <p>Thank you for choosing PetUwrite!</p>
        `,
      }],
    });

    const requestOptions = {
      hostname: "api.sendgrid.com",
      port: 443,
      path: "/v3/mail/send",
      method: "POST",
      headers: {
        "Authorization": `Bearer ${SENDGRID_API_KEY}`,
        "Content-Type": "application/json",
        "Content-Length": emailData.length,
      },
      timeout: 15000, // 15 second timeout
    };

    const req = https.request(requestOptions, (res) => {
      if (res.statusCode === 202) {
        resolve({success: true});
      } else {
        logger.error("SendGrid API error", {statusCode: res.statusCode});
        resolve({success: false});
      }
    });

    req.on("error", (error) => {
      logger.error("SendGrid request error", {error: error.message});
      resolve({success: false});
    });

    req.on("timeout", () => {
      req.destroy();
      resolve({success: false});
    });

    req.write(emailData);
    req.end();
  });
}

/**
 * Send admin notification via Slack and email
 */
async function sendAdminNotification(notification) {
  try {
    // Send to Slack
    if (SLACK_WEBHOOK_URL) {
      await sendSlackNotification({
        text: `🚨 *Payout Escalation Required*`,
        blocks: [
          {
            type: "header",
            text: {
              type: "plain_text",
              text: "🚨 Payout Escalation",
            },
          },
          {
            type: "section",
            fields: [
              {
                type: "mrkdwn",
                text: `*Payout ID:*\n${notification.payoutId}`,
              },
              {
                type: "mrkdwn",
                text: `*Claim ID:*\n${notification.claimId}`,
              },
              {
                type: "mrkdwn",
                text: `*Amount:*\n$${notification.amount.toFixed(2)}`,
              },
              {
                type: "mrkdwn",
                text: `*Retry Count:*\n${notification.retryCount}`,
              },
              {
                type: "mrkdwn",
                text: `*Failure Type:*\n${notification.failureType}`,
              },
              {
                type: "mrkdwn",
                text: `*Last Error:*\n${notification.lastError || "Unknown"}`,
              },
            ],
          },
          {
            type: "context",
            elements: [
              {
                type: "mrkdwn",
                text: "⚠️ Manual intervention required. Check admin dashboard.",
              },
            ],
          },
        ],
      });
    }

    // Send email to admin
    if (SENDGRID_API_KEY && ADMIN_EMAIL) {
      await sendAdminEmail({
        to: ADMIN_EMAIL,
        subject: `🚨 Payout Escalation - ${notification.claimId}`,
        content: `
          <h2>Payout Escalation Required</h2>
          <p>A payout has failed after ${notification.retryCount} retry attempts and requires manual intervention.</p>
          <h3>Details:</h3>
          <ul>
            <li><strong>Payout ID:</strong> ${notification.payoutId}</li>
            <li><strong>Claim ID:</strong> ${notification.claimId}</li>
            <li><strong>Amount:</strong> $${notification.amount.toFixed(2)}</li>
            <li><strong>Failure Type:</strong> ${notification.failureType}</li>
            <li><strong>Last Error:</strong> ${notification.lastError || "Unknown"}</li>
          </ul>
          <p><a href="https://console.firebase.google.com/project/pet-underwriter-ai/firestore/data/payouts/${notification.payoutId}">View in Firestore</a></p>
        `,
      });
    }

    logger.info("Admin notification sent", {
      type: notification.type,
      payoutId: notification.payoutId,
    });
  } catch (error) {
    logger.error("Error sending admin notification", {
      error: error.message,
    });
    // Don't throw - notification failure shouldn't block reconciliation
  }
}

/**
 * Send Slack webhook notification
 */
async function sendSlackNotification(message) {
  return new Promise((resolve) => {
    const url = new URL(SLACK_WEBHOOK_URL);
    const postData = JSON.stringify(message);

    const requestOptions = {
      hostname: url.hostname,
      port: 443,
      path: url.pathname,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": postData.length,
      },
      timeout: 10000,
    };

    const req = https.request(requestOptions, (res) => {
      resolve(res.statusCode === 200);
    });

    req.on("error", () => resolve(false));
    req.on("timeout", () => {
      req.destroy();
      resolve(false);
    });

    req.write(postData);
    req.end();
  });
}

/**
 * Send email to admin
 */
async function sendAdminEmail(options) {
  const emailData = JSON.stringify({
    personalizations: [{
      to: [{email: options.to}],
      subject: options.subject,
    }],
    from: {email: "alerts@petuwrite.com", name: "PetUwrite Alerts"},
    content: [{
      type: "text/html",
      value: options.content,
    }],
  });

  return new Promise((resolve) => {
    const requestOptions = {
      hostname: "api.sendgrid.com",
      port: 443,
      path: "/v3/mail/send",
      method: "POST",
      headers: {
        "Authorization": `Bearer ${SENDGRID_API_KEY}`,
        "Content-Type": "application/json",
        "Content-Length": emailData.length,
      },
      timeout: 15000,
    };

    const req = https.request(requestOptions, (res) => {
      resolve(res.statusCode === 202);
    });

    req.on("error", () => resolve(false));
    req.on("timeout", () => {
      req.destroy();
      resolve(false);
    });

    req.write(emailData);
    req.end();
  });
}

/**
 * Notify admin of reconciliation results (summary)
 */
async function notifyAdminOfReconciliation(results) {
  try {
    if (SLACK_WEBHOOK_URL) {
      await sendSlackNotification({
        text: `📊 Claims Reconciliation Report`,
        blocks: [
          {
            type: "header",
            text: {
              type: "plain_text",
              text: "📊 Hourly Claims Reconciliation",
            },
          },
          {
            type: "section",
            fields: [
              {
                type: "mrkdwn",
                text: `*Mismatched States Fixed:*\n${results.mismatchedStatesFixed}`,
              },
              {
                type: "mrkdwn",
                text: `*Failed Operations Retried:*\n${results.failedOperationsRetried}`,
              },
              {
                type: "mrkdwn",
                text: `*Successful Retries:*\n${results.successfulRetries}`,
              },
              {
                type: "mrkdwn",
                text: `*Escalated to Admin:*\n${results.escalatedToAdmin}`,
              },
            ],
          },
          {
            type: "context",
            elements: [
              {
                type: "mrkdwn",
                text: `Completed in ${results.durationMs}ms`,
              },
            ],
          },
        ],
      });
    }
  } catch (error) {
    logger.error("Error sending reconciliation notification", {
      error: error.message,
    });
  }
}

/**
 * Log reconciliation run to Firestore
 */
async function logReconciliationRun(results) {
  try {
    const db = admin.firestore();
    await db.collection("reconciliation_runs").add({
      ...results,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    logger.error("Error logging reconciliation run", {
      error: error.message,
    });
  }
}

/**
 * Callable function to manually trigger retry for a specific payout
 * Accessible from admin dashboard
 */
exports.retryFailedOperation = onCall({
  enforceAppCheck: false,
}, async (request) => {
  const {payoutId} = request.data;

  if (!payoutId) {
    throw new Error("Missing required parameter: payoutId");
  }

  // Verify admin access
  if (!request.auth || !request.auth.token.admin) {
    throw new Error("Unauthorized: Admin access required");
  }

  logger.info("Manual retry triggered", {
    payoutId,
    adminUid: request.auth.uid,
  });

  try {
    const db = admin.firestore();
    const payoutDoc = await db.collection("payouts").doc(payoutId).get();

    if (!payoutDoc.exists) {
      throw new Error("Payout not found");
    }

    const payoutData = payoutDoc.data();

    // Attempt retry
    let success = false;
    const failureType = payoutData.failureType || "stripe_payout";

    if (failureType === "stripe_payout") {
      success = await retryStripePayout(payoutId, payoutData);
    } else if (failureType === "sendgrid_notification") {
      success = await retrySendGridNotification(payoutId, payoutData);
    }

    // Log manual retry attempt
    await db.collection("payout_audit_trail").add({
      type: "manual_retry",
      payoutId,
      claimId: payoutData.claimId,
      performedBy: request.auth.uid,
      result: success ? "success" : "failed",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success,
      payoutId,
      message: success ?
        "Retry successful - payout completed" :
        "Retry failed - check logs for details",
    };
  } catch (error) {
    logger.error("Error in manual retry", {
      payoutId,
      error: error.message,
    });
    throw error;
  }
});
