/**
 * PDF Extraction Failure Alerts
 *
 * Scheduled function to detect repeated failures in pdf_extractions and
 * notify ops.
 */

const {onSchedule} = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");

if (!admin.apps.length) admin.initializeApp();

exports.alertPdfExtractionFailures = onSchedule(
    {
      schedule: "*/15 * * * *", // every 15 minutes
      timeZone: "UTC",
      memory: "256MiB",
      timeoutSeconds: 120,
    },
    async () => {
      const db = admin.firestore();

      const now = Date.now();
      const lookbackMs = 60 * 60 * 1000; // 1 hour
      const cutoff = new Date(now - lookbackMs);

      // Query all pdf_extractions failures (pets/*/pdf_extractions and
      // underwriting_cases/*/pdf_extractions)
      const failuresSnap = await db
          .collectionGroup("pdf_extractions")
          .where("status", "==", "failed")
          .where("failedAt", ">=", admin.firestore.Timestamp.fromDate(cutoff))
          .get();

      const failures = failuresSnap.docs.map((d) => ({id: d.id, ...d.data()}));
      const failureCount = failures.length;

      // Nothing to do
      if (failureCount === 0) {
        logger.info(
            "pdf_extractions failure check: none in lookback",
            {lookbackMs},
        );
        return;
      }

      // Only alert if we see repeated failures (basic noise control)
      const threshold = Number(
          process.env.PDF_EXTRACTION_FAILURE_ALERT_THRESHOLD || 3,
      );
      if (failureCount < threshold) {
        logger.warn(
            "pdf_extractions failures below threshold",
            {failureCount, threshold},
        );
        return;
      }

      // Throttle alerts (avoid spamming)
      const throttleMinutes = Number(
          process.env.PDF_EXTRACTION_FAILURE_ALERT_THROTTLE_MINUTES || 30,
      );
      const throttleMs = throttleMinutes * 60 * 1000;
      const alertDocRef = db.collection("admin_settings").doc("ops_alerts");

      const shouldSend = await db.runTransaction(async (tx) => {
        const doc = await tx.get(alertDocRef);
        const lastSentAt = doc.exists ?
          doc.data()?.pdfExtractionFailuresLastSentAt :
          null;
        const lastSentDate = lastSentAt?.toDate ? lastSentAt.toDate() : null;

        if (lastSentDate && now - lastSentDate.getTime() < throttleMs) {
          return false;
        }

        tx.set(
            alertDocRef,
            {
              pdfExtractionFailuresLastSentAt:
                FieldValue.serverTimestamp(),
              pdfExtractionFailuresLastCount: failureCount,
              pdfExtractionFailuresLastLookbackMs: lookbackMs,
              updatedAt: FieldValue.serverTimestamp(),
            },
            {merge: true},
        );

        return true;
      });

      if (!shouldSend) {
        logger.warn(
            "pdf_extractions failures alert throttled",
            {failureCount, throttleMinutes},
        );
        return;
      }

      const sample = failures.slice(0, 5).map((f) => ({
        filePath: f.filePath,
        caseId: f.caseId,
        petId: f.petId,
        errorMessage: f.errorMessage,
      }));

      logger.error("Repeated PDF extraction failures detected", {
        failureCount,
        lookbackMs,
        sample,
      });
    },
);
