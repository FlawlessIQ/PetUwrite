const functions = require("firebase-functions/v2");
const functionsV1 = require("firebase-functions/v1");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");
const axios = require("axios");
const pdfParse = require("pdf-parse");
const crypto = require("crypto");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

/**
 * Cloud Function to extract text from PDF documents
 * Endpoint: extractPdfText
 * Method: POST
 * Body: { "pdfUrl": "https://storage.googleapis.com/..." }
 */
exports.extractPdfText = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set("Access-Control-Allow-Origin", "*");

  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");
    res.set("Access-Control-Max-Age", "3600");
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({error: "Method not allowed. Use POST."});
    return;
  }

  try {
      const {pdfUrl, gsPath} = req.body;

      if (!pdfUrl && !gsPath) {
        res.status(400).json({error: "Missing pdfUrl or gsPath in request body"});
      return;
    }

      functions.logger.info("Extracting text from PDF:", {pdfUrl, gsPath});

      let pdfBuffer;
      if (gsPath) {
        const match = /^gs:\/\/([^/]+)\/(.+)$/.exec(gsPath);
        if (!match) {
          res.status(400).json({error: "Invalid gsPath format. Expected gs://bucket/path"});
          return;
        }
        const bucketName = match[1];
        const filePath = match[2];
        const [buffer] = await admin.storage().bucket(bucketName).file(filePath).download();
        pdfBuffer = buffer;
      } else {
        // Download PDF from Firebase Storage URL
        const response = await axios.get(pdfUrl, {
          responseType: "arraybuffer",
          timeout: 30000, // 30 second timeout
        });
        pdfBuffer = Buffer.from(response.data);
      }

    // Extract text using pdf-parse
    const data = await pdfParse(pdfBuffer, {
      // Optional: Customize extraction
      max: 0, // No page limit
    });

    functions.logger.info("PDF text extracted successfully", {
      pages: data.numpages,
      textLength: data.text.length,
    });

    // Return extracted text
    res.status(200).json({
      text: data.text,
      metadata: {
        pages: data.numpages,
        info: data.info,
      },
    });
  } catch (error) {
    functions.logger.error("Error extracting PDF text:", error);

    if (error.code === "ECONNABORTED") {
      res.status(408).json({error: "Request timeout. PDF may be too large."});
    } else if (error.response) {
      res.status(error.response.status).json({
        error: "Failed to download PDF",
        details: error.message,
      });
    } else {
      res.status(500).json({
        error: "Failed to extract text from PDF",
        details: error.message,
      });
    }
  }
});

function computeExtractionDocId(bucket, filePath, generation) {
  const key = `${bucket}:${filePath}:${generation || ""}`;
  return crypto.createHash("sha1").update(key).digest("hex");
}

/**
 * Firebase Storage-triggered function (v1)
 * Automatically processes PDFs when uploaded to vet_records folder.
 *
 * NOTE: We intentionally use the v1 trigger here because v2 storage triggers
 * rely on Eventarc and can require additional deploy-time IAM/bucket validation.
 */
exports.processPdfOnUpload = functionsV1.storage.object().onFinalize(async (object) => {
  const filePath = object.name;
  const contentType = object.contentType;
  const bucketName = object.bucket;
  const generation = object.generation;

  // Only process PDFs in vet_records folder
  if (!filePath || !filePath.startsWith("vet_records/") || contentType !== "application/pdf") {
    functions.logger.info("Skipping non-PDF file:", {filePath, contentType});
    return;
  }

  try {
    functions.logger.info("Processing PDF upload:", {filePath, bucketName});

    const bucket = admin.storage().bucket(bucketName);
    const file = bucket.file(filePath);

    const [buffer] = await file.download();

    // Extract text
    const data = await pdfParse(buffer);

    // Path formats supported:
    // - vet_records/{petId}/filename.pdf
    // - vet_records/cases/{caseId}/filename.pdf
    const pathParts = filePath.split("/");

    const isCaseUpload = pathParts.length >= 4 && pathParts[1] === "cases";
    const caseId = isCaseUpload ? pathParts[2] : null;
    const petId = !isCaseUpload ? pathParts[1] : null;

    const docId = computeExtractionDocId(bucketName, filePath, generation);

    // Store extracted text as a .txt file in Storage to avoid Firestore document size limits.
    const originalFileName = pathParts[pathParts.length - 1];
    const baseName = originalFileName.replace(/\.pdf$/i, "");
    const textObjectPath = isCaseUpload
        ? `vet_records/cases/${caseId}/extracted/${baseName}_${Date.now()}.txt`
        : `vet_records/${petId}/extracted/${baseName}_${Date.now()}.txt`;

    const textFile = bucket.file(textObjectPath);
    await textFile.save(data.text, {
      contentType: "text/plain",
      metadata: {
        metadata: {
          sourcePdfPath: filePath,
          ...(isCaseUpload ? {caseId} : {petId}),
        },
      },
    });

    // Save extraction metadata to Firestore (idempotent doc id)
    const docRef = isCaseUpload
        ? admin.firestore().collection("underwriting_cases").doc(caseId).collection("pdf_extractions").doc(docId)
        : admin.firestore().collection("pets").doc(petId).collection("pdf_extractions").doc(docId);

    const existing = await docRef.get();
    if (existing.exists && existing.data()?.status === "extracted") {
      functions.logger.info("Extraction already completed; skipping", {
        ...(isCaseUpload ? {caseId} : {petId}),
        docId,
        filePath,
      });
      return;
    }

    await docRef.set({
      filePath,
      extractedTextPath: textObjectPath,
      pages: data.numpages,
      extractedAt: FieldValue.serverTimestamp(),
      status: "extracted",
      metadata: data.info,
      ...(isCaseUpload ? {caseId} : {petId}),
    });

    functions.logger.info("PDF text extraction completed", {
      ...(isCaseUpload ? {caseId} : {petId}),
      docId: docRef.id,
      pages: data.numpages,
    });

    return;
  } catch (error) {
    functions.logger.error("Error in PDF processing:", error);

    // Best-effort status write for ops visibility.
    try {
      const pathParts = filePath.split("/");
      const isCaseUpload = pathParts.length >= 4 && pathParts[1] === "cases";
      const caseId = isCaseUpload ? pathParts[2] : null;
      const petId = !isCaseUpload ? pathParts[1] : null;
      const docId = computeExtractionDocId(bucketName, filePath, generation);

      const docRef = isCaseUpload
          ? admin.firestore().collection("underwriting_cases").doc(caseId).collection("pdf_extractions").doc(docId)
          : admin.firestore().collection("pets").doc(petId).collection("pdf_extractions").doc(docId);

      await docRef.set({
        filePath,
        status: "failed",
        errorMessage: error?.message || String(error),
        failedAt: FieldValue.serverTimestamp(),
        ...(isCaseUpload ? {caseId} : {petId}),
      }, {merge: true});
    } catch (e) {
      functions.logger.error("Failed to record PDF extraction failure", e);
    }

    return;
  }
});

/**
 * Helper function to validate PDF files
 */
function isPdfValid(buffer) {
  // Check PDF magic number (starts with %PDF-)
  const header = buffer.slice(0, 5).toString("ascii");
  return header === "%PDF-";
}

/**
 * Cloud Function to get processing status
 */
exports.getPdfProcessingStatus = functions.https.onCall(async (data, context) => {
  // Check authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated",
    );
  }

  const {petId} = data;

  if (!petId) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "petId is required",
    );
  }

  try {
    const snapshot = await admin.firestore()
        .collection("pets")
        .doc(petId)
        .collection("pdf_extractions")
        .orderBy("extractedAt", "desc")
        .limit(10)
        .get();

    const extractions = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {extractions};
  } catch (error) {
    functions.logger.error("Error getting processing status:", error);
    throw new functions.https.HttpsError(
        "internal",
        "Failed to retrieve processing status",
    );
  }
});
