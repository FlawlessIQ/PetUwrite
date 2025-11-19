/**
 * AI Training Data Export Cloud Functions
 *
 * Handles exporting training data batches from Firestore to Google Cloud Storage
 * in JSONL format for fine-tuning with OpenAI or Vertex AI.
 *
 * Functions:
 * - exportAITrainingBatch: Callable function to export a completed batch to GCS
 * - scheduleExport: Triggered when a batch is marked complete
 */

const functions = require("firebase-functions/v2");
const admin = require("firebase-admin");
const {Storage} = require("@google-cloud/storage");
const https = require("https");

// Initialize Firestore and Storage
const db = admin.firestore();
const storage = new Storage();

// Configuration
const BUCKET_NAME = "petuwrite-ai-training"; // TODO: Update with actual bucket name
const TRAINING_DATA_COLLECTION = "ai_training_data";
const BATCHES_COLLECTION = "ai_training_batches";
const EXPORTS_COLLECTION = "ai_training_exports";
const SLACK_WEBHOOK_URL = process.env.SLACK_WEBHOOK_URL || "";

/**
 * Export a completed training batch to Google Cloud Storage
 *
 * @param {string} batchId - The ID of the batch to export
 * @returns {Promise<Object>} Export result with GCS path and statistics
 */
exports.exportAITrainingBatch = functions.https.onCall(async (data, context) => {
  try {
    // Verify admin authentication
    if (!context.auth || !context.auth.token.admin) {
      throw new functions.https.HttpsError(
          "permission-denied",
          "Only administrators can trigger batch exports",
      );
    }

    const {batchId} = data;
    if (!batchId) {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Batch ID is required",
      );
    }

    console.log(`Starting export for batch: ${batchId}`);

    // Get batch metadata
    const batchRef = db.collection(BATCHES_COLLECTION).doc(batchId);
    const batchDoc = await batchRef.get();

    if (!batchDoc.exists) {
      throw new functions.https.HttpsError(
          "not-found",
          `Batch ${batchId} not found`,
      );
    }

    const batchData = batchDoc.data();

    // Verify batch is completed
    if (batchData.status !== "completed") {
      throw new functions.https.HttpsError(
          "failed-precondition",
          `Batch must be completed before export. Current status: ${batchData.status}`,
      );
    }

    // Check if already exported
    if (batchData.exportPath) {
      console.log(`Batch ${batchId} already exported to ${batchData.exportPath}`);
      return {
        success: true,
        alreadyExported: true,
        exportPath: batchData.exportPath,
        message: "Batch already exported",
      };
    }

    // Fetch all training records from the batch
    const recordsSnapshot = await db
        .collection(TRAINING_DATA_COLLECTION)
        .doc(batchId)
        .collection("records")
        .orderBy("timestamp", "asc")
        .get();

    if (recordsSnapshot.empty) {
      throw new functions.https.HttpsError(
          "failed-precondition",
          `No training records found in batch ${batchId}`,
      );
    }

    console.log(`Found ${recordsSnapshot.size} records in batch ${batchId}`);

    // Convert to JSONL format for fine-tuning
    const trainingData = [];
    const statistics = {
      totalRecords: 0,
      labelDistribution: {},
      avgConfidence: 0,
    };

    let totalConfidence = 0;

    for (const doc of recordsSnapshot.docs) {
      const record = doc.data();

      // Format for fine-tuning (OpenAI format)
      const formattedRecord = formatForFineTuning(record);
      trainingData.push(JSON.stringify(formattedRecord));

      // Collect statistics
      statistics.totalRecords++;
      const label = record.label || "unknown";
      statistics.labelDistribution[label] = (statistics.labelDistribution[label] || 0) + 1;
      totalConfidence += record.aiConfidenceScore || 0;
    }

    statistics.avgConfidence = totalConfidence / statistics.totalRecords;

    // Create JSONL content (one JSON object per line)
    const jsonlContent = trainingData.join("\n");

    // Generate GCS path
    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const gcsPath = `training-batches/batch-${batchId}-${timestamp}.jsonl`;

    // Upload to Google Cloud Storage
    const bucket = storage.bucket(BUCKET_NAME);
    const file = bucket.file(gcsPath);

    await file.save(jsonlContent, {
      contentType: "application/jsonl",
      metadata: {
        batchId,
        recordCount: statistics.totalRecords,
        exportedAt: new Date().toISOString(),
        exportedBy: context.auth.uid,
      },
    });

    console.log(`Uploaded batch to GCS: gs://${BUCKET_NAME}/${gcsPath}`);

    // Update batch with export info
    await batchRef.update({
      status: "exported",
      exportPath: `gs://${BUCKET_NAME}/${gcsPath}`,
      exportedAt: admin.firestore.FieldValue.serverTimestamp(),
      exportedBy: context.auth.uid,
    });

    // Log to exports collection
    const exportId = `export_${Date.now()}`;
    await db.collection(EXPORTS_COLLECTION).doc(exportId).set({
      exportId,
      batchId,
      format: "jsonl",
      gcsPath: `gs://${BUCKET_NAME}/${gcsPath}`,
      recordCount: statistics.totalRecords,
      labelDistribution: statistics.labelDistribution,
      avgConfidence: statistics.avgConfidence,
      exportedAt: admin.firestore.FieldValue.serverTimestamp(),
      exportedBy: context.auth.uid,
    });

    // Send Slack notification
    await sendSlackNotification({
      batchId,
      recordCount: statistics.totalRecords,
      gcsPath: `gs://${BUCKET_NAME}/${gcsPath}`,
      labelDistribution: statistics.labelDistribution,
      avgConfidence: statistics.avgConfidence,
    });

    console.log(`Successfully exported batch ${batchId}`);

    return {
      success: true,
      exportPath: `gs://${BUCKET_NAME}/${gcsPath}`,
      statistics,
    };
  } catch (error) {
    console.error("Error exporting training batch:", error);

    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    throw new functions.https.HttpsError(
        "internal",
        `Failed to export batch: ${error.message}`,
    );
  }
});

/**
 * Format training record for fine-tuning
 *
 * Converts internal training data format to OpenAI/Vertex AI JSONL format
 *
 * @param {Object} record - Training record from Firestore
 * @return {Object} Formatted record for fine-tuning
 */
function formatForFineTuning(record) {
  // OpenAI fine-tuning format (chat completion)
  // Reference: https://platform.openai.com/docs/guides/fine-tuning

  const systemPrompt = `You are an expert pet insurance underwriter. Analyze claims and determine approval/denial based on policy coverage, pet health history, and claim details.`;

  // Build user prompt with claim context
  const userPrompt = `
Pet Information:
- Species: ${record.petSpecies || "Unknown"}
- Breed: ${record.petBreed || "Unknown"}
- Age: ${record.petAge || "Unknown"} years
${record.preExistingConditions ? `- Pre-existing Conditions: ${record.preExistingConditions.join(", ")}` : ""}

Policy Information:
- Tier: ${record.policyTier || "Unknown"}
- Annual Limit: $${record.annualLimit || 0}
- Deductible: $${record.deductible || 0}

Claim Details:
- Type: ${record.claimType || "Unknown"}
- Amount: $${record.claimAmount || 0}
- Description: ${record.description || "No description"}
- Documents: ${record.documentsAnalyzed || 0} attachments

Should this claim be approved or denied?
  `.trim();

  // The correct decision (what the human decided after AI analysis)
  const assistantResponse = record.humanDecision === "approve" ?
    `APPROVED - ${record.humanReason || "Claim meets coverage criteria"}` :
    `DENIED - ${record.humanReason || "Claim does not meet coverage criteria"}`;

  return {
    messages: [
      {role: "system", content: systemPrompt},
      {role: "user", content: userPrompt},
      {role: "assistant", content: assistantResponse},
    ],
    // Include metadata for analysis (not used in training)
    metadata: {
      claimId: record.claimId,
      label: record.label,
      labelCategory: record.labelCategory,
      aiWasCorrect: record.aiWasCorrect,
      aiConfidenceScore: record.aiConfidenceScore,
    },
  };
}

/**
 * Alternative format for Vertex AI
 *
 * Uncomment and use if targeting Google's Vertex AI instead of OpenAI
 */
/*
function formatForVertexAI(record) {
  const inputText = `Pet: ${record.petSpecies} ${record.petBreed}, Age: ${record.petAge}
Policy: ${record.policyTier}, Limit: $${record.annualLimit}, Deductible: $${record.deductible}
Claim: ${record.claimType}, Amount: $${record.claimAmount}
Description: ${record.description}`;

  const outputText = record.humanDecision === 'approve'
    ? `Approve: ${record.humanReason}`
    : `Deny: ${record.humanReason}`;

  return {
    input_text: inputText,
    output_text: outputText
  };
}
*/

/**
 * Send Slack notification about batch export
 *
 * @param {Object} exportInfo - Information about the export
 */
async function sendSlackNotification(exportInfo) {
  if (!SLACK_WEBHOOK_URL) {
    console.log("Slack webhook not configured, skipping notification");
    return;
  }

  try {
    const labelDistributionText = Object.entries(exportInfo.labelDistribution)
        .map(([label, count]) => `• ${label}: ${count}`)
        .join("\n");

    const message = {
      text: "🤖 AI Training Batch Exported",
      blocks: [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "🤖 AI Training Batch Exported",
          },
        },
        {
          type: "section",
          fields: [
            {
              type: "mrkdwn",
              text: `*Batch ID:*\n${exportInfo.batchId}`,
            },
            {
              type: "mrkdwn",
              text: `*Record Count:*\n${exportInfo.recordCount}`,
            },
            {
              type: "mrkdwn",
              text: `*Average Confidence:*\n${(exportInfo.avgConfidence * 100).toFixed(1)}%`,
            },
            {
              type: "mrkdwn",
              text: `*GCS Path:*\n\`${exportInfo.gcsPath}\``,
            },
          ],
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: `*Label Distribution:*\n${labelDistributionText}`,
          },
        },
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: `Exported at ${new Date().toLocaleString()}`,
            },
          ],
        },
      ],
    };

    await sendSlackMessage(message);
    console.log("Slack notification sent successfully");
  } catch (error) {
    console.error("Error sending Slack notification:", error);
    // Don't fail the export if Slack notification fails
  }
}

/**
 * Send message to Slack webhook
 *
 * @param {Object} message - Slack message payload
 */
function sendSlackMessage(message) {
  return new Promise((resolve, reject) => {
    const url = new URL(SLACK_WEBHOOK_URL);
    const postData = JSON.stringify(message);

    const options = {
      hostname: url.hostname,
      path: url.pathname + url.search,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData),
      },
      timeout: 10000,
    };

    const req = https.request(options, (res) => {
      let responseData = "";

      res.on("data", (chunk) => {
        responseData += chunk;
      });

      res.on("end", () => {
        if (res.statusCode === 200) {
          resolve({success: true});
        } else {
          reject(new Error(`Slack API returned ${res.statusCode}: ${responseData}`));
        }
      });
    });

    req.on("error", (error) => {
      reject(error);
    });

    req.on("timeout", () => {
      req.destroy();
      reject(new Error("Slack webhook request timed out"));
    });

    req.write(postData);
    req.end();
  });
}

/**
 * Firestore trigger to auto-export when batch is marked complete
 *
 * Automatically exports a batch when its status changes to 'completed'
 */
exports.onBatchCompleted = functions.firestore.onDocumentUpdated(
    `${BATCHES_COLLECTION}/{batchId}`,
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      const batchId = event.params.batchId;

      // Check if status changed to 'completed' and not already exported
      if (
        before.status !== "completed" &&
      after.status === "completed" &&
      !after.exportPath
      ) {
        console.log(`Batch ${batchId} completed, triggering auto-export`);

        try {
        // Trigger export (simulate admin context for internal call)
          const exportResult = await exportBatchInternal(batchId, "system");
          console.log(`Auto-export completed for batch ${batchId}:`, exportResult);
        } catch (error) {
          console.error(`Auto-export failed for batch ${batchId}:`, error);

          // Update batch with error status
          await db.collection(BATCHES_COLLECTION).doc(batchId).update({
            status: "export_failed",
            exportError: error.message,
            exportErrorAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
    },
);

/**
 * Internal export function (for Firestore triggers)
 *
 * Same logic as callable function but without auth checks
 *
 * @param {string} batchId - Batch ID to export
 * @param {string} triggeredBy - Who/what triggered the export
 */
async function exportBatchInternal(batchId, triggeredBy = "system") {
  // Get batch metadata
  const batchRef = db.collection(BATCHES_COLLECTION).doc(batchId);
  const batchDoc = await batchRef.get();

  if (!batchDoc.exists) {
    throw new Error(`Batch ${batchId} not found`);
  }

  const batchData = batchDoc.data();

  // Check if already exported
  if (batchData.exportPath) {
    console.log(`Batch ${batchId} already exported`);
    return {alreadyExported: true, exportPath: batchData.exportPath};
  }

  // Fetch training records
  const recordsSnapshot = await db
      .collection(TRAINING_DATA_COLLECTION)
      .doc(batchId)
      .collection("records")
      .orderBy("timestamp", "asc")
      .get();

  if (recordsSnapshot.empty) {
    throw new Error(`No records found in batch ${batchId}`);
  }

  // Convert to JSONL
  const trainingData = [];
  const statistics = {
    totalRecords: 0,
    labelDistribution: {},
    avgConfidence: 0,
  };

  let totalConfidence = 0;

  for (const doc of recordsSnapshot.docs) {
    const record = doc.data();
    const formattedRecord = formatForFineTuning(record);
    trainingData.push(JSON.stringify(formattedRecord));

    statistics.totalRecords++;
    const label = record.label || "unknown";
    statistics.labelDistribution[label] = (statistics.labelDistribution[label] || 0) + 1;
    totalConfidence += record.aiConfidenceScore || 0;
  }

  statistics.avgConfidence = totalConfidence / statistics.totalRecords;

  const jsonlContent = trainingData.join("\n");

  // Upload to GCS
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const gcsPath = `training-batches/batch-${batchId}-${timestamp}.jsonl`;
  const bucket = storage.bucket(BUCKET_NAME);
  const file = bucket.file(gcsPath);

  await file.save(jsonlContent, {
    contentType: "application/jsonl",
    metadata: {
      batchId,
      recordCount: statistics.totalRecords,
      exportedAt: new Date().toISOString(),
      exportedBy: triggeredBy,
    },
  });

  // Update batch
  await batchRef.update({
    status: "exported",
    exportPath: `gs://${BUCKET_NAME}/${gcsPath}`,
    exportedAt: admin.firestore.FieldValue.serverTimestamp(),
    exportedBy: triggeredBy,
  });

  // Log export
  const exportId = `export_${Date.now()}`;
  await db.collection(EXPORTS_COLLECTION).doc(exportId).set({
    exportId,
    batchId,
    format: "jsonl",
    gcsPath: `gs://${BUCKET_NAME}/${gcsPath}`,
    recordCount: statistics.totalRecords,
    labelDistribution: statistics.labelDistribution,
    avgConfidence: statistics.avgConfidence,
    exportedAt: admin.firestore.FieldValue.serverTimestamp(),
    exportedBy: triggeredBy,
  });

  // Send Slack notification
  await sendSlackNotification({
    batchId,
    recordCount: statistics.totalRecords,
    gcsPath: `gs://${BUCKET_NAME}/${gcsPath}`,
    labelDistribution: statistics.labelDistribution,
    avgConfidence: statistics.avgConfidence,
  });

  return {
    success: true,
    exportPath: `gs://${BUCKET_NAME}/${gcsPath}`,
    statistics,
  };
}
