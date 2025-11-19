const functions = require("firebase-functions/v2");
const admin = require("firebase-admin");
const axios = require("axios");
const pdfParse = require("pdf-parse");

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
    const {pdfUrl} = req.body;

    if (!pdfUrl) {
      res.status(400).json({error: "Missing pdfUrl in request body"});
      return;
    }

    functions.logger.info("Extracting text from PDF:", {pdfUrl});

    // Download PDF from Firebase Storage
    const response = await axios.get(pdfUrl, {
      responseType: "arraybuffer",
      timeout: 30000, // 30 second timeout
    });

    const pdfBuffer = Buffer.from(response.data);

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

/**
 * Alternative: Firebase Storage-triggered function
 * Automatically processes PDFs when uploaded to vet_records folder
 */
exports.processPdfOnUpload = functions.storage.onObjectFinalized(async (event) => {
  const filePath = event.data.name;
  const contentType = event.data.contentType;

  // Only process PDFs in vet_records folder
  if (!filePath.startsWith("vet_records/") || contentType !== "application/pdf") {
    functions.logger.info("Skipping non-PDF file:", filePath);
    return null;
  }

  try {
    functions.logger.info("Processing PDF upload:", filePath);

    const bucket = admin.storage().bucket(event.data.bucket);
    const file = bucket.file(filePath);

    // Download file
    const [buffer] = await file.download();

    // Extract text
    const data = await pdfParse(buffer);

    // Extract petId from path (format: vet_records/{petId}/filename.pdf)
    const pathParts = filePath.split("/");
    const petId = pathParts[1];

    // Save extracted text to Firestore for processing
    const docRef = admin.firestore()
        .collection("pets")
        .doc(petId)
        .collection("pdf_extractions")
        .doc();

    await docRef.set({
      filePath,
      extractedText: data.text,
      pages: data.numpages,
      extractedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "extracted",
      metadata: data.info,
    });

    functions.logger.info("PDF text extraction completed", {
      petId,
      docId: docRef.id,
      pages: data.numpages,
    });

    return {success: true, docId: docRef.id};
  } catch (error) {
    functions.logger.error("Error in PDF processing:", error);
    return {success: false, error: error.message};
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
