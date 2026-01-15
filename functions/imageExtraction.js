const functions = require("firebase-functions/v2");
const axios = require("axios");
const vision = require("@google-cloud/vision");
const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

// Lazily initialized client (ADC via Cloud Functions service account)
let _client;
function getClient() {
  if (!_client) {
    _client = new vision.ImageAnnotatorClient();
  }
  return _client;
}

/**
 * Cloud Function to extract text from image documents (JPG/PNG)
 * Endpoint: extractImageText
 * Method: POST
 * Body: { "imageUrl": "https://storage.googleapis.com/..." }
 */
exports.extractImageText = functions.https.onRequest(async (req, res) => {
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
      const {imageUrl, gsPath} = req.body || {};

      if (!imageUrl && !gsPath) {
        res.status(400).json({error: "Missing imageUrl or gsPath in request body"});
      return;
    }

      functions.logger.info("Extracting text from image", {imageUrl, gsPath});

      let imageBuffer;
      if (gsPath) {
        const match = /^gs:\/\/([^/]+)\/(.+)$/.exec(gsPath);
        if (!match) {
          res.status(400).json({error: "Invalid gsPath format. Expected gs://bucket/path"});
          return;
        }
        const bucketName = match[1];
        const filePath = match[2];
        const [buffer] = await admin.storage().bucket(bucketName).file(filePath).download();
        imageBuffer = buffer;
      } else {
        const response = await axios.get(imageUrl, {
          responseType: "arraybuffer",
          timeout: 30000,
        });
        imageBuffer = Buffer.from(response.data);
      }

    const client = getClient();
    const [result] = await client.documentTextDetection({
      image: {content: imageBuffer},
    });

    const fullText = result?.fullTextAnnotation?.text || "";

    functions.logger.info("Image OCR completed", {
      textLength: fullText.length,
    });

    res.status(200).json({
      text: fullText,
      metadata: {
        provider: "google-cloud-vision",
      },
    });
  } catch (error) {
    functions.logger.error("Error extracting image text", error);

    if (error.code === "ECONNABORTED") {
      res.status(408).json({error: "Request timeout. Image may be too large."});
      return;
    }

    res.status(500).json({
      error: "Failed to extract text from image",
      details: error?.message || String(error),
    });
  }
});
