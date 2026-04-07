/**
 * OpenAI API Proxy Cloud Functions
 * Securely handles OpenAI API calls server-side to protect API keys
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onRequest} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const axios = require("axios");
const crypto = require("crypto");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const pdfParse = require("pdf-parse");
const vision = require("@google-cloud/vision");

function isEmulator() {
  // The Functions emulator sets different env vars depending on how it is started
  // (emulators:exec, emulators:start, unit tests, etc). Be generous here so we
  // never accidentally attempt to access Secret Manager or other production-only
  // resources while running locally.
  return (
    process.env.FUNCTIONS_EMULATOR === "true" ||
    process.env.FUNCTIONS_EMULATOR === "1" ||
    !!process.env.FIREBASE_EMULATOR_HUB ||
    !!process.env.FUNCTIONS_EMULATOR_HOST ||
    !!process.env.FIRESTORE_EMULATOR_HOST ||
    !!process.env.FIREBASE_AUTH_EMULATOR_HOST ||
    !!process.env.FIREBASE_STORAGE_EMULATOR_HOST
  );
}

function isEmulatorOrNoOpenAISecret() {
  return isEmulator() || !openaiApiKey;
}

function isEmulatorOrNoGeminiSecret() {
  return isEmulator() || !geminiApiKey;
}

// Define the OpenAI API key as a secret (production only)
const openaiApiKey = isEmulator() ? null : defineSecret("OPENAI_API_KEY");
// Define the Gemini API key as a secret (production only)
const geminiApiKey = isEmulator() ? null : defineSecret("GEMINI_API_KEY");

const OPENAI_CHAT_COMPLETIONS_URL = "https://api.openai.com/v1/chat/completions";
// If the requested model isn't available for the current API key/account,
// fall back to the strongest generally-available model first.
const FALLBACK_MODEL = "gpt-4o";
const SECONDARY_FALLBACK_MODEL = "gpt-4o-mini";

// Gemini default model. Prefer a stable, generally-available model for
// production reliability.
// Keep this aligned with the models returned by:
// GET https://generativelanguage.googleapis.com/v1beta/models?key=...
const GEMINI_DEFAULT_MODEL = "gemini-pro-latest";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

let visionClient;
function getVisionClient() {
  if (!visionClient) {
    visionClient = new vision.ImageAnnotatorClient();
  }
  return visionClient;
}

function normalizeStringArray(value) {
  if (!Array.isArray(value)) return [];
  return value.filter((v) => typeof v === "string" && v.trim().length > 0);
}

function toIsoDateMaybe(value) {
  try {
    if (!value) return null;
    if (value.toDate && typeof value.toDate === "function") {
      return value.toDate().toISOString();
    }
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return null;
    return d.toISOString();
  } catch {
    return null;
  }
}

function computeAutomationInputHash(claim) {
  const payload = {
    claimType: String(claim?.claimType || "").toLowerCase(),
    claimAmount: Number(claim?.claimAmount || 0),
    incidentDate: toIsoDateMaybe(claim?.incidentDate),
    description: String(claim?.description || ""),
    attachments: normalizeStringArray(claim?.attachments),
  };

  return crypto.createHash("sha256").update(JSON.stringify(payload)).digest("hex");
}

function requiredDocumentsForClaimType(claimType) {
  const ct = String(claimType || "").toLowerCase();

  if (ct === "accident") {
    return [
      "Itemized invoice/receipt",
      "Vet record or ER visit notes",
      "Diagnosis and treatment details",
      "Any relevant photos (if applicable)",
    ];
  }

  if (ct === "wellness") {
    return [
      "Itemized invoice/receipt",
      "Wellness service details (vaccines, exam, labs)",
    ];
  }

  // Default: illness
  return [
    "Itemized invoice/receipt",
    "Vet record for diagnosis",
    "Treatment plan and/or discharge notes",
    "Any lab results (if applicable)",
  ];
}

function coerceDecisionString(value) {
  const d = String(value || "").toLowerCase();
  if (d === "approve") return "approve";
  if (d === "deny") return "deny";
  if (d === "needs_more_info" || d === "needs-more-info" || d === "needs_info" || d === "needs-info") {
    return "needs_more_info";
  }
  if (d === "review") return "needs_more_info";
  return "needs_more_info";
}

async function extractTextFromAttachmentUrl(url) {
  if (!url || typeof url !== "string") return "";

  // Download via the (tokenized) URL stored on the claim.
  const response = await axios.get(url, {
    responseType: "arraybuffer",
    timeout: 30000,
    maxContentLength: 20 * 1024 * 1024,
    maxBodyLength: 20 * 1024 * 1024,
    validateStatus: (s) => s >= 200 && s < 300,
  });

  const contentType = String(response.headers?.["content-type"] || "").toLowerCase();
  const buffer = Buffer.from(response.data);
  const lowerUrl = url.toLowerCase();

  const looksPdf = contentType.includes("pdf") || lowerUrl.includes(".pdf");
  const looksImage =
    contentType.startsWith("image/") ||
    lowerUrl.match(/\.(png|jpe?g|webp|gif)(\?|$)/);

  if (looksPdf) {
    const parsed = await pdfParse(buffer);
    return String(parsed?.text || "");
  }

  if (looksImage && !isEmulator()) {
    try {
      const client = getVisionClient();
      const [result] = await client.textDetection({
        image: {content: buffer},
      });
      const fullText = result?.fullTextAnnotation?.text;
      if (fullText) return String(fullText);
      const first = result?.textAnnotations?.[0]?.description;
      return first ? String(first) : "";
    } catch (e) {
      console.warn("Vision OCR failed; continuing without OCR text", e?.message || e);
      return "";
    }
  }

  return "";
}

async function downloadFromStoragePath(storagePath) {
  if (!storagePath || typeof storagePath !== "string") return null;
  try {
    const bucket = admin.storage().bucket();
    const file = bucket.file(storagePath);
    const [buffer] = await file.download();
    return Buffer.from(buffer);
  } catch (e) {
    console.warn("Storage download failed; falling back to URL download", e?.message || e);
    return null;
  }
}

async function extractTextFromAttachmentRecord(record) {
  const downloadUrl = record?.downloadUrl;
  const storagePath = record?.storagePath;
  const fileName = String(record?.fileName || "");
  const contentType = String(record?.contentType || "").toLowerCase();

  let buffer = await downloadFromStoragePath(storagePath);
  let inferredType = contentType;
  if (!buffer && downloadUrl) {
    // URL path sets contentType from headers in extractTextFromAttachmentUrl.
    return await extractTextFromAttachmentUrl(downloadUrl);
  }

  if (!buffer) return "";

  const lowerName = fileName.toLowerCase();
  const looksPdf = inferredType.includes("pdf") || lowerName.endsWith(".pdf");
  const looksImage =
    inferredType.startsWith("image/") ||
    lowerName.match(/\.(png|jpe?g|webp|gif)$/);

  if (looksPdf) {
    const parsed = await pdfParse(buffer);
    return String(parsed?.text || "");
  }

  if (looksImage && !isEmulator()) {
    try {
      const client = getVisionClient();
      const [result] = await client.textDetection({
        image: {content: buffer},
      });
      const fullText = result?.fullTextAnnotation?.text;
      if (fullText) return String(fullText);
      const first = result?.textAnnotations?.[0]?.description;
      return first ? String(first) : "";
    } catch (e) {
      console.warn("Vision OCR failed; continuing without OCR text", e?.message || e);
      return "";
    }
  }

  return "";
}

const MAX_ATTACHMENT_EXTRACTION_ATTEMPTS = 3;
function getExtractionBackoffSeconds(attemptNumber) {
  // attemptNumber is 1-based (first failure uses 1)
  if (attemptNumber <= 1) return 60;
  if (attemptNumber === 2) return 5 * 60;
  return 30 * 60;
}

async function claimAttachmentExtractionLock(ref) {
  const now = Date.now();
  return await db.runTransaction(async (tx) => {
    const current = await tx.get(ref);
    if (!current.exists) return {claimed: false};
    const cur = current.data() || {};

    const status = String(cur.extractionStatus || "queued").toLowerCase();
    if (status === "done") return {claimed: false};
    if (status === "processing") return {claimed: false};

    const attemptCount = Number(cur.extractionAttemptCount || 0);
    if (attemptCount >= MAX_ATTACHMENT_EXTRACTION_ATTEMPTS) {
      return {claimed: false};
    }

    const nextAttemptAt = cur.nextAttemptAt;
    if (status === "error" && nextAttemptAt?.toDate) {
      const nextMs = nextAttemptAt.toDate().getTime();
      if (nextMs > now) return {claimed: false};
    }

    const nextAttemptCount = attemptCount + 1;
    tx.update(ref, {
      extractionStatus: "processing",
      extractionStartedAt: FieldValue.serverTimestamp(),
      extractionLastAttemptAt: FieldValue.serverTimestamp(),
      extractionAttemptCount: nextAttemptCount,
      extractionError: FieldValue.delete(),
      nextAttemptAt: FieldValue.delete(),
    });

    return {claimed: true, attemptCount: nextAttemptCount};
  });
}

async function extractCombinedDocumentText(attachmentUrls, options = {}) {
  const urls = normalizeStringArray(attachmentUrls);
  const maxDocs = Number(options.maxDocs ?? 2);
  const maxChars = Number(options.maxChars ?? 12000);

  if (urls.length === 0) return "";

  const selected = urls.slice(0, Math.max(0, maxDocs));
  const chunks = [];

  for (const url of selected) {
    try {
      const text = await extractTextFromAttachmentUrl(url);
      if (text && text.trim()) {
        chunks.push(text.trim());
      }
    } catch (e) {
      console.warn("Attachment text extraction failed; continuing", e?.message || e);
    }
  }

  const combined = chunks.join("\n\n---\n\n");
  if (combined.length <= maxChars) return combined;
  return combined.slice(0, maxChars);
}

async function processClaimDecisionCore({
  claimId,
  requestedByUid,
  isAdmin,
  system = false,
}) {
  const claimRef = db.collection("claims").doc(claimId);
  const claimSnap = await claimRef.get();
  if (!claimSnap.exists) {
    throw new HttpsError("not-found", `Claim ${claimId} not found`);
  }

  const claim = claimSnap.data() || {};

  if (!system) {
    if (!requestedByUid) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    if (!isAdmin && claim.ownerId !== requestedByUid) {
      throw new HttpsError("permission-denied", "Not authorized for this claim");
    }
  }

  const status = String(claim.status || "").toLowerCase();
  if (["draft", "cancelled", "canceled", "settled", "settling", "denied"].includes(status)) {
    return {success: true, claimId, skipped: true, status};
  }

  const policyId = claim.policyId;
  if (!policyId) {
    throw new HttpsError("failed-precondition", "Claim is missing policyId");
  }

  const policyRef = db.collection("policies").doc(policyId);
  const policySnap = await policyRef.get();
  if (!policySnap.exists) {
    throw new HttpsError("failed-precondition", `Policy ${policyId} not found`);
  }

  const policy = policySnap.data() || {};
  const plan = policy.plan || {};

  // Compute waiting period satisfaction (best-effort).
  const claimType = String(claim.claimType || "illness").toLowerCase();
  const waitingPeriodsDays = plan.waitingPeriodsDays || {};
  const waitingDays = Number(waitingPeriodsDays[claimType] ?? 0) || 0;
  const effectiveDate = policy.effectiveDate ? new Date(policy.effectiveDate) : null;
  const incidentDate = claim.incidentDate?.toDate
    ? claim.incidentDate.toDate()
    : (claim.incidentDate ? new Date(claim.incidentDate) : null);

  let waitingPeriodSatisfied = true;
  if (effectiveDate && incidentDate) {
    const msDiff = incidentDate.getTime() - effectiveDate.getTime();
    const daysDiff = msDiff / (1000 * 60 * 60 * 24);
    waitingPeriodSatisfied = daysDiff >= waitingDays;
  }

  const attachments = normalizeStringArray(claim.attachments);
  const inputHash = computeAutomationInputHash(claim);

  // ── Deduplication guard ──────────────────────────────────────────────
  // If another invocation (callable or Firestore trigger) already
  // processed this exact input hash recently, return the cached result
  // instead of making a duplicate AI call.
  const existingAutomation = claim.automation || {};
  if (
    existingAutomation.inputHash === inputHash &&
    existingAutomation.lastDecision &&
    existingAutomation.lastDecision !== "pending_extraction"
  ) {
    const lastProcessed = existingAutomation.lastProcessedAt;
    const lastProcessedMs = lastProcessed?.toMillis
      ? lastProcessed.toMillis()
      : (lastProcessed?._seconds ? lastProcessed._seconds * 1000 : 0);
    const ageMs = Date.now() - lastProcessedMs;
    // If processed within the last 60 seconds, skip (race-condition window).
    if (ageMs < 60_000) {
      console.log(
        `processClaimDecisionCore: skipping duplicate for ${claimId} ` +
        `(inputHash=${inputHash.slice(0, 8)}… age=${ageMs}ms)`
      );
      return {
        success: true,
        claimId,
        skipped: true,
        reason: "duplicate_input_hash",
        decision: {
          decision: existingAutomation.lastDecision,
          confidence: claim.aiConfidenceScore ?? 0,
          reasoning: claim.aiReasoningExplanation?.explanation || "",
          denialReason: claim.aiReasoningExplanation?.denialReason || null,
          requiredDocuments: claim.aiReasoningExplanation?.requiredDocuments || [],
          questionsForCustomer: claim.aiReasoningExplanation?.questionsForCustomer || [],
          discrepancies: claim.aiReasoningExplanation?.discrepancies || [],
          flagsForReview: claim.aiReasoningExplanation?.flagsForReview || [],
        },
        status: status,
        modelUsed: existingAutomation.modelUsed || null,
        provider: existingAutomation.provider || null,
      };
    }
  }

  async function hydrateStructuredAttachmentsFromUrls() {
    if (!attachments.length) return 0;

    // Only hydrate a small batch; decisioning only needs a couple docs.
    const urls = attachments.slice(0, 5);
    let created = 0;

    for (const url of urls) {
      const raw = String(url || "").trim();
      if (!raw) continue;

      let storagePath = null;
      try {
        const u = new URL(raw);
        const pathname = String(u.pathname || "");

        // Firebase download URL:
        // /v0/b/<bucket>/o/<encodedPath>
        const idx = pathname.indexOf("/o/");
        if (idx >= 0) {
          storagePath = decodeURIComponent(pathname.substring(idx + 3));
        } else {
          // GCS style:
          // /<bucket>/<path>
          const parts = pathname.split("/").filter(Boolean);
          if (parts.length >= 2) {
            storagePath = parts.slice(1).join("/");
          }
        }
      } catch (_) {
        storagePath = null;
      }

      if (!storagePath || !storagePath.includes("/")) continue;

      const fileName = storagePath.split("/").pop() || "document";
      const ext = fileName.toLowerCase().split(".").pop();
      const contentType = ext === "pdf"
        ? "application/pdf"
        : (ext === "png" ? "image/png" : (ext === "jpg" || ext === "jpeg" ? "image/jpeg" : null));

      const attachmentId = crypto.createHash("sha256").update(storagePath).digest("hex").slice(0, 32);
      const ref = claimRef.collection("attachments").doc(attachmentId);

      try {
        await ref.create({
          downloadUrl: raw,
          storagePath,
          fileName,
          contentType,
          uploadedAt: FieldValue.serverTimestamp(),
          uploadedBy: claim.ownerId || null,
          extractionStatus: "queued",
        });
        created++;
      } catch (e) {
        // Already exists or cannot be created; ignore.
      }
    }

    return created;
  }

  // Prefer structured attachment records when available.
  // If there are queued/processing attachments, wait for extraction to complete.
  let attachmentDocs = [];
  try {
    const snap = await claimRef
      .collection("attachments")
      .orderBy("uploadedAt", "desc")
      .limit(10)
      .get();
    attachmentDocs = snap.docs.map((d) => ({id: d.id, ...d.data()}));
  } catch (e) {
    // It's OK if the subcollection isn't accessible yet.
    attachmentDocs = [];
  }

  // If the claim has attachment URLs but no structured attachment records,
  // create deterministic attachment docs server-side so extraction/retries can run.
  if (attachments.length > 0 && attachmentDocs.length === 0) {
    try {
      const created = await hydrateStructuredAttachmentsFromUrls();
      if (created > 0) {
        const snap = await claimRef
          .collection("attachments")
          .orderBy("uploadedAt", "desc")
          .limit(10)
          .get();
        attachmentDocs = snap.docs.map((d) => ({id: d.id, ...d.data()}));
      }
    } catch (e) {
      // Best-effort only.
    }
  }

  const hasStructuredAttachments = attachmentDocs.length > 0;
  const hasPendingExtraction = hasStructuredAttachments && attachmentDocs.some((a) => {
    const s = String(a.extractionStatus || "").toLowerCase();
    return s === "queued" || s === "processing";
  });

  if (attachments.length > 0 && hasPendingExtraction) {
    // Keep the claim in processing until extraction finishes, then the attachment update trigger will rerun.
    await claimRef.update({
      status: "processing",
      updatedAt: FieldValue.serverTimestamp(),
      automation: {
        inputHash,
        lastProcessedAt: FieldValue.serverTimestamp(),
        lastDecision: "pending_extraction",
        version: 1,
        runCount: FieldValue.increment(1),
      },
    });

    return {
      success: true,
      claimId,
      pendingExtraction: true,
      status: "processing",
    };
  }

  // If there are no documents yet, stay fully automated: request documents and wait.
  if (attachments.length === 0) {
    const requiredDocuments = requiredDocumentsForClaimType(claimType);
    const aiReasoningExplanation = {
      explanation:
        "We’re ready to continue, but we need supporting documents to verify the diagnosis and treatment costs.",
      confidenceScore: 0,
      denialReason: null,
      requiredDocuments,
      questionsForCustomer: [],
      discrepancies: [],
      flagsForReview: requiredDocuments,
      modelUsed: system ? "system" : "rules",
      provider: system ? "system" : "rules",
      processedAt: new Date().toISOString(),
      waitingPeriodSatisfied,
      waitingDays,
      inputHash,
    };

    await claimRef.update({
      status: "awaiting_info",
      aiDecision: "needs_info",
      aiConfidenceScore: 0,
      aiReasoningExplanation,
      updatedAt: FieldValue.serverTimestamp(),
      automation: {
        inputHash,
        lastProcessedAt: FieldValue.serverTimestamp(),
        lastDecision: "needs_more_info",
        version: 1,
        runCount: FieldValue.increment(1),
      },
    });

    return {
      success: true,
      claimId,
      decision: {
        decision: "needs_more_info",
        confidence: 0,
        reasoning: aiReasoningExplanation.explanation,
        denialReason: null,
        requiredDocuments,
        questionsForCustomer: [],
        discrepancies: [],
        flagsForReview: requiredDocuments,
      },
      status: "awaiting_info",
      modelUsed: system ? "system" : "rules",
      provider: system ? "system" : "rules",
      usage: null,
      waitingPeriodSatisfied,
      waitingDays,
    };
  }

  const coverageLimit = plan.isUnlimitedAnnualCoverage === true
    ? "Unlimited"
    : (plan.maxAnnualCoverage ?? null);

  let documentText = "";
  if (hasStructuredAttachments) {
    const done = attachmentDocs
      .filter((a) => String(a.extractionStatus || "").toLowerCase() === "done")
      .slice(0, 2);

    const combined = done
      .map((a) => String(a.extractedText || "").trim())
      .filter((t) => t.length > 0)
      .join("\n\n---\n\n");

    documentText = combined.length > 12000 ? combined.slice(0, 12000) : combined;
  }

  if (!documentText) {
    // Backwards-compatible: fall back to best-effort extraction from URLs.
    documentText = await extractCombinedDocumentText(attachments, {
      maxDocs: 2,
      maxChars: 12000,
    });
  }

  const decisionPrompt = `Review this pet insurance claim and return a decision.\n\nIMPORTANT:\n- If information is missing or inconsistent, do NOT choose \'deny\'. Choose \'needs_more_info\' and specify what to request.\n- Prefer continuing an automated loop (request documents/corrections) instead of routing for manual review.\n\nClaim Details:\n- Type: ${claimType}\n- Amount: $${Number(claim.claimAmount || 0).toFixed(2)}\n- Incident Date: ${incidentDate ? incidentDate.toISOString() : (claim.incidentDate || "")}\n- Description: ${claim.description || ""}\n- Attachments: ${attachments.length}\n\nPolicy Details:\n- Plan: ${plan.name || plan.type || ""}\n- Deductible: $${Number(plan.annualDeductible || 0).toFixed(2)}\n- Reimbursement: ${plan.reimbursementPercent ?? (100 - (plan.coPayPercentage ?? 20))}%\n- Coverage Limit: ${coverageLimit}\n- Waiting Period Satisfied: ${waitingPeriodSatisfied}\n\nDocument Text (best-effort OCR/extraction; may be incomplete):\n${documentText || "(no text extracted)"}\n\nReturn ONLY JSON:\n{\n  "decision": "approve" | "deny" | "needs_more_info",\n  "confidence": <number 0-1>,\n  "reasoning": "brief, customer-safe explanation",\n  "denialReason": "reason if denied, or null",\n  "requiredDocuments": ["specific documents needed"],\n  "questionsForCustomer": ["short questions to clarify"],\n  "discrepancies": ["any mismatches detected"],\n  "flagsForReview": ["actionable next steps"]\n}`;

  // Emulator-safe path: avoid external calls and secrets.
  if (isEmulator()) {
    const emuDecision = {
      decision: "approve",
      confidence: 0.82,
      reasoning: "Emulator mode: auto-approving for end-to-end smoke test.",
      denialReason: null,
      requiredDocuments: [],
      questionsForCustomer: [],
      discrepancies: [],
      flagsForReview: [],
    };

    const normalizedDecision = coerceDecisionString(emuDecision.decision);
    const confidence = Math.max(0, Math.min(1, Number(emuDecision.confidence) || 0));

    const aiDecision = normalizedDecision === "approve"
      ? "approve"
      : normalizedDecision === "deny"
        ? "deny"
        : "needs_info";

    const newStatus = normalizedDecision === "deny"
      ? "denied"
      : normalizedDecision === "needs_more_info"
        ? "awaiting_info"
        : "processing";

    const aiReasoningExplanation = {
      explanation: emuDecision.reasoning,
      confidenceScore: confidence,
      denialReason: null,
      requiredDocuments: [],
      questionsForCustomer: [],
      discrepancies: [],
      flagsForReview: [],
      modelUsed: "emulator",
      provider: "emulator",
      processedAt: new Date().toISOString(),
      waitingPeriodSatisfied,
      waitingDays,
      inputHash,
    };

    await claimRef.update({
      status: newStatus,
      aiDecision,
      aiConfidenceScore: confidence,
      aiReasoningExplanation,
      updatedAt: FieldValue.serverTimestamp(),
      ...(newStatus === "denied" ? {deniedAt: FieldValue.serverTimestamp()} : {}),
      automation: {
        inputHash,
        lastProcessedAt: FieldValue.serverTimestamp(),
        lastDecision: normalizedDecision,
        version: 1,
        runCount: FieldValue.increment(1),
      },
    });

    return {
      success: true,
      claimId,
      decision: {
        decision: normalizedDecision,
        confidence,
        reasoning: emuDecision.reasoning,
        denialReason: null,
        requiredDocuments: [],
        questionsForCustomer: [],
        discrepancies: [],
        flagsForReview: [],
      },
      status: newStatus,
      modelUsed: "emulator",
      provider: "emulator",
      usage: null,
      emulated: true,
    };
  }

  const messages = [
    {
      role: "system",
      content:
        "You are a pet insurance claims adjudication system. Be consistent and follow policy terms. Prefer requesting missing info (needs_more_info) over denying when documentation is insufficient.",
    },
    {role: "user", content: decisionPrompt},
  ];

  let decision;
  let modelUsed;
  let provider;
  let usage;

  // Prefer Gemini when configured.
  if (!isEmulatorOrNoGeminiSecret()) {
    try {
      const geminiResponse = await createGeminiCompletion({
        apiKey: geminiApiKey.value(),
        model: GEMINI_DEFAULT_MODEL,
        messages,
        temperature: 0.2,
        maxOutputTokens: 800,
        response_format: {type: "json_object"},
        timeoutMs: 50000,
      });
      const text = extractGeminiText(geminiResponse);
      if (!text) {
        throw Object.assign(new Error("GEMINI_EMPTY_RESPONSE"), {geminiResponse});
      }
      decision = JSON.parse(text);
      modelUsed = GEMINI_DEFAULT_MODEL;
      provider = "gemini";
      usage = geminiResponse?.usageMetadata ?? null;
    } catch (error) {
      if (isGeminiQuotaError(error) && !isEmulatorOrNoOpenAISecret()) {
        console.warn("processClaimDecisionCore: Gemini quota exceeded; falling back to OpenAI");
      } else if (isGeminiModelNotFoundError(error) && !isEmulatorOrNoOpenAISecret()) {
        console.warn("processClaimDecisionCore: Gemini model not found; falling back to OpenAI");
      } else if ((isGeminiEmptyResponseError(error) || isJsonParseError(error)) && !isEmulatorOrNoOpenAISecret()) {
        console.warn("processClaimDecisionCore: Gemini returned invalid/empty JSON; falling back to OpenAI");
      } else if (isGeminiQuotaError(error)) {
        throw new HttpsError(
          "resource-exhausted",
          "Gemini quota exceeded",
          error.response?.data || error.message,
        );
      } else if (isGeminiEmptyResponseError(error)) {
        throw new HttpsError(
          "failed-precondition",
          "Gemini returned an empty response",
          error?.geminiResponse || error?.message,
        );
      } else {
        console.error("Claim Decision (Gemini) Error:", error.response?.data || error.message);
        throw new HttpsError(
          "internal",
          "Failed to make claim decision",
          error.response?.data || error.message,
        );
      }
    }
  }

  // If Gemini failed (or isn't configured), fall back to OpenAI when available.
  if (!decision) {
    if (isEmulatorOrNoOpenAISecret()) {
      throw new HttpsError(
        "failed-precondition",
        "No AI provider configured (missing GEMINI_API_KEY and OPENAI_API_KEY)",
      );
    }

    let responseData;
    modelUsed = FALLBACK_MODEL;
    provider = "openai";
    try {
      responseData = await createChatCompletion({
        apiKey: openaiApiKey.value(),
        model: modelUsed,
        messages,
        temperature: 0.2,
        max_tokens: 800,
        response_format: {type: "json_object"},
        timeoutMs: 50000,
      });
    } catch (error) {
      console.error("Claim Decision (OpenAI) Error:", error.response?.data || error.message);
      throw new HttpsError(
        "internal",
        "Failed to make claim decision",
        error.response?.data || error.message,
      );
    }

    usage = responseData.usage;
    try {
      decision = JSON.parse(responseData.choices[0].message.content);
    } catch (e) {
      throw new HttpsError("internal", `Invalid JSON from model: ${e?.message || e}`);
    }
  }

  const normalizedDecision = coerceDecisionString(decision.decision);
  const confidence = Math.max(0, Math.min(1, Number(decision.confidence) || 0));
  const requiredDocuments = normalizeStringArray(decision.requiredDocuments);
  const questionsForCustomer = normalizeStringArray(decision.questionsForCustomer);
  const discrepancies = normalizeStringArray(decision.discrepancies);
  const flagsForReview = normalizeStringArray(decision.flagsForReview);
  const actionableNextSteps = [...requiredDocuments, ...questionsForCustomer, ...discrepancies, ...flagsForReview]
    .filter((v, i, arr) => arr.indexOf(v) === i)
    .slice(0, 10);

  const aiDecision = normalizedDecision === "approve"
    ? "approve"
    : normalizedDecision === "deny"
      ? "deny"
      : "needs_info";

  // IMPORTANT: do not mark as 'settling' here until payout initiation is implemented.
  const newStatus = normalizedDecision === "deny"
    ? "denied"
    : normalizedDecision === "needs_more_info"
      ? "awaiting_info"
      : "processing";

  const aiReasoningExplanation = {
    explanation: decision.reasoning || "",
    confidenceScore: confidence,
    denialReason: decision.denialReason || null,
    requiredDocuments,
    questionsForCustomer,
    discrepancies,
    flagsForReview: actionableNextSteps,
    modelUsed,
    provider,
    processedAt: new Date().toISOString(),
    waitingPeriodSatisfied,
    waitingDays,
    inputHash,
  };

  await claimRef.update({
    status: newStatus,
    aiDecision,
    aiConfidenceScore: confidence,
    aiReasoningExplanation,
    updatedAt: FieldValue.serverTimestamp(),
    ...(newStatus === "denied" ? {deniedAt: FieldValue.serverTimestamp()} : {}),
    automation: {
      inputHash,
      lastProcessedAt: FieldValue.serverTimestamp(),
      lastDecision: normalizedDecision,
      version: 1,
      runCount: FieldValue.increment(1),
      provider,
      modelUsed,
    },
  });

  await claimRef.collection("ai_audit_trail").add({
    claimId,
    timestamp: FieldValue.serverTimestamp(),
    eventType: "ai_decision",
    performedBy: system ? "system" : "user",
    performedFor: requestedByUid || claim.ownerId || null,
    decision: {
      decision: normalizedDecision,
      confidence,
      reasoning: decision.reasoning || "",
      denialReason: decision.denialReason || null,
      flagsForReview: actionableNextSteps,
      requiredDocuments,
      questionsForCustomer,
      discrepancies,
    },
    metadata: {
      modelUsed,
      provider,
      inputHash,
    },
  });

  return {
    success: true,
    claimId,
    decision: {
      decision: normalizedDecision,
      confidence,
      reasoning: decision.reasoning || "",
      denialReason: decision.denialReason || null,
      requiredDocuments,
      questionsForCustomer,
      discrepancies,
      flagsForReview: actionableNextSteps,
    },
    status: newStatus,
    modelUsed,
    provider,
    usage: usage ?? null,
    waitingPeriodSatisfied,
    waitingDays,
  };
}

/**
 * Firestore Trigger: Extract text from newly uploaded claim attachments.
 *
 * Writes extractedText + extractionStatus back to the attachment record.
 */
exports.onClaimAttachmentCreated = onDocumentCreated(
  callOptionsWithOpenAISecret({
    maxInstances: 10,
    timeoutSeconds: 540,
    memory: "1GiB",
  }),
  "claims/{claimId}/attachments/{attachmentId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const claimId = event.params.claimId;
    const attachmentId = event.params.attachmentId;
    const ref = db.collection("claims").doc(claimId).collection("attachments").doc(attachmentId);

    // Claim attachments created from older clients might not have fields.
    const data = snap.data() || {};

    const lock = await claimAttachmentExtractionLock(ref);
    if (!lock.claimed) return;

    try {
      const text = await extractTextFromAttachmentRecord(data);
      const trimmed = String(text || "").trim();
      const textHash = crypto.createHash("sha256").update(trimmed).digest("hex");

      await ref.update({
        extractedText: trimmed,
        extractedTextHash: textHash,
        extractionStatus: "done",
        extractedAt: FieldValue.serverTimestamp(),
        nextAttemptAt: FieldValue.delete(),
        extractionError: FieldValue.delete(),
      });
    } catch (e) {
      const attemptCount = Number(lock.attemptCount || 1);
      const backoffSeconds = getExtractionBackoffSeconds(attemptCount);
      const nextAttemptAt = Timestamp.fromMillis(Date.now() + backoffSeconds * 1000);
      await ref.update({
        extractionStatus: "error",
        extractionError: String(e?.message || e),
        extractedAt: FieldValue.serverTimestamp(),
        nextAttemptAt,
      });
    }
  },
);

/**
 * Firestore Trigger: When extraction completes, rerun decisioning automatically.
 */
exports.onClaimAttachmentUpdated = onDocumentUpdated(
  callOptionsWithOpenAISecret({
    maxInstances: 10,
    timeoutSeconds: 540,
    memory: "1GiB",
  }),
  "claims/{claimId}/attachments/{attachmentId}",
  async (event) => {
    const before = event.data?.before?.data() || {};
    const after = event.data?.after?.data() || {};
    const claimId = event.params.claimId;

    const beforeStatus = String(before.extractionStatus || "").toLowerCase();
    const afterStatus = String(after.extractionStatus || "").toLowerCase();
    const transitionedToDone = beforeStatus !== "done" && afterStatus === "done";

    if (!transitionedToDone) return;

    try {
      await processClaimDecisionCore({
        claimId,
        requestedByUid: null,
        isAdmin: true,
        system: true,
      });
    } catch (e) {
      console.error("onClaimAttachmentUpdated decision rerun failed", {
        claimId,
        error: e?.message || e,
      });
    }
  },
);

/**
 * Scheduled retry: picks up attachments that failed extraction and retries after backoff.
 *
 * This avoids relying on client writes to trigger a retry.
 */
exports.retryClaimAttachmentExtractions = onSchedule(
  {
    schedule: "every 5 minutes",
    timeZone: "UTC",
    memory: "1GiB",
    timeoutSeconds: 540,
    maxInstances: 1,
  },
  async () => {
    const now = Timestamp.now();

    // Reclaim any attachments that have been stuck in `processing` too long.
    // This can happen if an instance is terminated mid-extraction.
    const staleProcessingCutoff = Timestamp.fromMillis(Date.now() - 15 * 60 * 1000);
    const staleProcessing = await db
      .collectionGroup("attachments")
      .where("extractionStatus", "==", "processing")
      .where("extractionStartedAt", "<=", staleProcessingCutoff)
      .orderBy("extractionStartedAt", "asc")
      .limit(25)
      .get();

    if (!staleProcessing.empty) {
      await Promise.allSettled(
        staleProcessing.docs.map(async (doc) => {
          const attachmentId = doc.id;
          const claimId = doc.ref.parent?.parent?.id;
          if (!claimId) return;

          const ref = db.collection("claims").doc(claimId).collection("attachments").doc(attachmentId);
          await ref.update({
            extractionStatus: "error",
            extractionError: "stale_processing_reclaimed",
            nextAttemptAt: now,
          });
        }),
      );
    }

    const snap = await db
      .collectionGroup("attachments")
      .where("extractionStatus", "==", "error")
      .where("nextAttemptAt", "<=", now)
      .orderBy("nextAttemptAt", "asc")
      .limit(25)
      .get();

    if (snap.empty) return;

    const tasks = snap.docs.map(async (doc) => {
      // Path: claims/{claimId}/attachments/{attachmentId}
      const attachmentId = doc.id;
      const claimId = doc.ref.parent?.parent?.id;
      if (!claimId) return;

      const ref = db.collection("claims").doc(claimId).collection("attachments").doc(attachmentId);
      const data = doc.data() || {};

      const lock = await claimAttachmentExtractionLock(ref);
      if (!lock.claimed) return;

      try {
        const text = await extractTextFromAttachmentRecord(data);
        const trimmed = String(text || "").trim();
        const textHash = crypto.createHash("sha256").update(trimmed).digest("hex");

        await ref.update({
          extractedText: trimmed,
          extractedTextHash: textHash,
          extractionStatus: "done",
          extractedAt: FieldValue.serverTimestamp(),
          nextAttemptAt: FieldValue.delete(),
          extractionError: FieldValue.delete(),
        });
      } catch (e) {
        const attemptCount = Number(lock.attemptCount || 1);
        const backoffSeconds = getExtractionBackoffSeconds(attemptCount);
        const nextAttemptAt = Timestamp.fromMillis(Date.now() + backoffSeconds * 1000);
        await ref.update({
          extractionStatus: "error",
          extractionError: String(e?.message || e),
          extractedAt: FieldValue.serverTimestamp(),
          nextAttemptAt,
        });
      }
    });

    await Promise.allSettled(tasks);
  },
);

exports._processClaimDecisionCore = processClaimDecisionCore;

function getBaseCallOptions() {
  return {
    maxInstances: 10,
    // Large structured outputs (e.g. parsing long vet PDFs) can legitimately
    // take longer than 60s end-to-end.
    timeoutSeconds: 120,
    memory: "512MiB",
  };
}

function callOptionsWithOpenAISecret(overrides = {}) {
  const baseCallOptions = getBaseCallOptions();
  if (isEmulator() || (!openaiApiKey && !geminiApiKey)) {
    return {
      ...baseCallOptions,
      ...overrides,
    };
  }

  return {
    ...baseCallOptions,
    ...overrides,
    secrets: [openaiApiKey, geminiApiKey].filter(Boolean),
  };
}

function isModelNotFoundError(error) {
  const status = error?.response?.status;
  const data = error?.response?.data;
  const code = data?.error?.code;
  const message = (data?.error?.message || "").toLowerCase();

  if (status === 404) return true;
  if (code === "model_not_found") return true;
  if (status === 400 && message.includes("model") && message.includes("not")) return true;
  if (message.includes("model") && (message.includes("not found") || message.includes("does not exist"))) {
    return true;
  }
  return false;
}

function isGeminiModelNotFoundError(error) {
  const status = error?.response?.status;
  const data = error?.response?.data;
  const detailsMessage = String(data?.error?.message || data?.message || "").toLowerCase();

  if (status === 404) return true;
  if (detailsMessage.includes("not found") && detailsMessage.includes("models/")) return true;
  if (detailsMessage.includes("is not supported") && detailsMessage.includes("generatecontent")) return true;
  return false;
}

function isGeminiQuotaError(error) {
  const status = error?.response?.status;
  const data = error?.response?.data;
  const apiStatus = data?.error?.status;
  const message = String(data?.error?.message || data?.message || "").toLowerCase();

  if (status === 429) return true;
  if (apiStatus === "RESOURCE_EXHAUSTED") return true;
  if (message.includes("quota") && (message.includes("exceeded") || message.includes("limit"))) return true;
  return false;
}

function isJsonParseError(error) {
  return (
    error instanceof SyntaxError ||
    /unexpected token/i.test(String(error?.message || ""))
  );
}

function isGeminiEmptyResponseError(error) {
  return String(error?.message || "") === "GEMINI_EMPTY_RESPONSE";
}

async function createChatCompletion({
  apiKey,
  model,
  messages,
  temperature,
  max_tokens,
  response_format,
  timeoutMs,
}) {
  const response = await axios.post(
      OPENAI_CHAT_COMPLETIONS_URL,
      {
        model,
        messages,
        temperature,
        max_tokens,
        ...(response_format ? {response_format} : {}),
      },
      {
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        timeout: timeoutMs ?? 50000,
      },
  );

  return response.data;
}

function coerceMessagesToGeminiParts(messages, response_format) {
  const parts = [];
  for (const msg of messages || []) {
    if (!msg) continue;
    const role = msg.role;
    const content = typeof msg.content === "string" ? msg.content : "";
    if (!content) continue;

    // Keep things simple: Gemini REST API accepts a single role per content.
    // We inline system guidance into the user prompt.
    if (role === "system") {
      parts.push({text: `System: ${content}`});
    } else {
      parts.push({text: content});
    }
  }

  if (response_format?.type === "json_object") {
    parts.push({text: "Return ONLY valid JSON. Do not include markdown."});
  }

  return parts;
}

function extractGeminiText(geminiResponse) {
  return (
    geminiResponse?.candidates?.[0]?.content?.parts
      ?.map((p) => p?.text)
      .filter(Boolean)
      .join("") ||
    ""
  );
}

function normalizeGeminiModel(requestedModel) {
  const raw = String(requestedModel || "").trim();
  if (!raw) return GEMINI_DEFAULT_MODEL;

  // Backwards compatibility: older clients may request OpenAI model names.
  if (raw.startsWith("gpt-")) return GEMINI_DEFAULT_MODEL;

  // Backwards compatibility: older clients may request legacy Gemini names.
  if (raw == "gemini-1.5-pro" || raw == "gemini-1.5-flash") return "gemini-pro-latest";
  if (raw == "gemini-pro") return "gemini-pro-latest";

  // Backwards compatibility: older clients may request preview model names.
  // Prefer the stable model for reliability.
  if (raw == "gemini-3-pro-preview") return "gemini-pro-latest";

  return raw;
}

async function createGeminiCompletion({
  apiKey,
  model,
  messages,
  temperature,
  maxOutputTokens,
  response_format,
  timeoutMs,
}) {
  // Google Generative Language REST API (Gemini)
  const modelPath = String(model || "").startsWith("models/")
    ? String(model)
    : `models/${String(model)}`;
  const url = `https://generativelanguage.googleapis.com/v1beta/${modelPath}:generateContent?key=${encodeURIComponent(apiKey)}`;
  const parts = coerceMessagesToGeminiParts(messages, response_format);

  const response = await axios.post(
    url,
    {
      contents: [
        {
          role: "user",
          parts,
        },
      ],
      generationConfig: {
        temperature: typeof temperature === "number" ? temperature : 0.7,
        maxOutputTokens: typeof maxOutputTokens === "number" ? maxOutputTokens : 800,
      },
    },
    {
      headers: {
        "Content-Type": "application/json",
      },
      timeout: timeoutMs ?? 50000,
    },
  );

  return response.data;
}

/**
 * Conversational AI Chat Completion
 * Used for the quote flow conversation with Clover
 */
exports.chatCompletion = onCall(
  callOptionsWithOpenAISecret({invoker: "public"}),
    async (request) => {
      // Validate request
      if (!request.data || !request.data.messages) {
        throw new HttpsError(
            "invalid-argument",
            "Messages array is required",
        );
      }

      // Require an authenticated Firebase principal (anonymous auth is fine).
      // Gen2 functions must allow public Cloud Run invocation, so we enforce
      // access control here to reduce abuse.
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "Authentication required",
        );
      }

      const {
        messages,
        // Keep the parameter name for client compatibility, but default to Gemini.
        model = GEMINI_DEFAULT_MODEL,
        temperature = 0.7,
        response_format,
      } = request.data;

      // Non-negotiable: Gemini failures must NOT fall back to alternate LLMs.
      // Also: clients must not be able to force OpenAI usage via model name.

      // Allow callers to request larger outputs (e.g., structured JSON from long PDFs)
      // while enforcing a hard upper bound for cost/safety control.
      const requestedMaxTokens =
        request.data.max_tokens ?? request.data.maxTokens ?? 800;
      const maxTokens = Math.min(
          4096,
          Math.max(1, Number(requestedMaxTokens) || 800),
      );

      try {
        if (isEmulator()) {
          return {
            success: true,
            message:
              response_format?.type === "json_object"
                ? "{}"
                : "(emulator) Clover is running locally.",
            usage: null,
            modelUsed: "emulator",
            provider: "emulator",
            requestedModel: model,
            emulated: true,
          };
        }

        const requestedModel = String(model || "").trim();
        if (requestedModel.startsWith("gpt-")) {
          throw new HttpsError(
            "failed-precondition",
            "OpenAI models are disabled for this endpoint. Use a Gemini model.",
            {requestedModel},
          );
        }

        // Gemini is the only provider.
        {
          if (isEmulatorOrNoGeminiSecret()) {
            throw new HttpsError(
              "failed-precondition",
              "Gemini is not configured (missing GEMINI_API_KEY)",
            );
          }

          const geminiModel = normalizeGeminiModel(model);
          // Gemini 3 "thinking" models can spend a chunk of tokens on thoughts and
          // return empty content if maxOutputTokens is too low. Use a small floor.
          const geminiMaxTokens = Math.max(128, maxTokens);
          try {
            // One quick retry for occasional empty responses.
            let geminiResponse = await createGeminiCompletion({
              apiKey: geminiApiKey.value(),
              model: geminiModel,
              messages,
              temperature,
              maxOutputTokens: geminiMaxTokens,
              response_format,
              timeoutMs: 50000,
            });
            let text = extractGeminiText(geminiResponse);

            if (!text) {
              geminiResponse = await createGeminiCompletion({
                apiKey: geminiApiKey.value(),
                model: geminiModel,
                messages,
                temperature: typeof temperature === "number" ? Math.min(0.3, temperature) : 0.2,
                maxOutputTokens: Math.max(256, geminiMaxTokens + 256),
                response_format,
                timeoutMs: 50000,
              });
              text = extractGeminiText(geminiResponse);
            }

            if (!text) {
              throw Object.assign(new Error("GEMINI_EMPTY_RESPONSE"), {geminiResponse});
            }

            return {
              success: true,
              message: text,
              usage: geminiResponse?.usageMetadata ?? null,
              modelUsed: geminiModel,
              provider: "gemini",
              requestedModel: model,
            };
          } catch (geminiErr) {
            console.error(
              "Gemini failed (no fallback allowed):",
              geminiErr?.response?.data || geminiErr?.message || geminiErr,
            );

            if (isGeminiQuotaError(geminiErr)) {
              throw new HttpsError(
                "resource-exhausted",
                "Gemini quota exceeded",
                geminiErr?.response?.data || geminiErr?.message,
              );
            } else if (isGeminiEmptyResponseError(geminiErr)) {
              throw new HttpsError(
                "failed-precondition",
                "Gemini returned an empty response",
                geminiErr?.geminiResponse || geminiErr?.message,
              );
            } else if (isGeminiModelNotFoundError(geminiErr)) {
              throw new HttpsError(
                "failed-precondition",
                "Requested Gemini model not available",
                geminiErr?.response?.data || geminiErr?.message,
              );
            } else {
              throw geminiErr;
            }
          }
        }
      } catch (error) {
        console.error("chatCompletion Error:", error.response?.data || error.message || error);
        throw new HttpsError(
          "internal",
          "Failed to get AI response",
          error.response?.data || error.message || String(error),
        );
      }
    },
);

/**
 * Risk Analysis for Pet Insurance Quotes
 * Analyzes pet profile and returns risk assessment
 */
exports.analyzeRisk = onCall(
    callOptionsWithOpenAISecret(),
    async (request) => {
      const {petData, ownerData} = request.data;

      if (!petData) {
        throw new HttpsError("invalid-argument", "Pet data is required");
      }

      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      if (isEmulator()) {
        return {
          success: true,
          analysis: {
            riskScore: 42,
            riskFactors: ["emulator_mode"],
            recommendation: "review",
            reasoning: "Emulator mode: returning a deterministic stub response.",
          },
          usage: null,
          modelUsed: "emulator",
          emulated: true,
        };
      }

      const prompt = `Analyze the following pet insurance quote for risk factors:

Pet Details:
- Name: ${petData.name}
- Species: ${petData.species}
- Breed: ${petData.breed}
- Age: ${petData.age} years
- Weight: ${petData.weight} lbs
- Pre-existing conditions: ${petData.preExistingConditions?.join(", ") || "None"}
- Spayed/Neutered: ${petData.isSpayedNeutered ? "Yes" : "No"}

Owner Details:
- Zip Code: ${ownerData?.zipCode || "Unknown"}

Provide a risk score (0-100) and brief analysis of key risk factors. Return ONLY a JSON object with this structure:
{
  "riskScore": <number 0-100>,
  "riskFactors": ["factor1", "factor2"],
  "recommendation": "approve" or "review" or "decline",
  "reasoning": "brief explanation"
}`;

      try {
        const messages = [
          {
            role: "system",
            content: "You are a pet insurance underwriting AI. Analyze risk factors and provide structured JSON responses only.",
          },
          {
            role: "user",
            content: prompt,
          },
        ];

        // Prefer Gemini when configured.
        if (!isEmulatorOrNoGeminiSecret()) {
          try {
            const geminiResponse = await createGeminiCompletion({
              apiKey: geminiApiKey.value(),
              model: GEMINI_DEFAULT_MODEL,
              messages,
              temperature: 0.3,
              maxOutputTokens: 500,
              response_format: {type: "json_object"},
              timeoutMs: 50000,
            });
            const text = extractGeminiText(geminiResponse);
            if (!text) {
              throw Object.assign(new Error("GEMINI_EMPTY_RESPONSE"), {
                geminiResponse,
              });
            }
            const analysis = JSON.parse(text);

            return {
              success: true,
              analysis,
              usage: geminiResponse?.usageMetadata ?? null,
              modelUsed: GEMINI_DEFAULT_MODEL,
              provider: "gemini",
            };
          } catch (geminiErr) {
            if (isGeminiQuotaError(geminiErr)) {
              if (isEmulatorOrNoOpenAISecret()) {
                throw new HttpsError(
                  "resource-exhausted",
                  "Gemini quota exceeded",
                  geminiErr?.response?.data || geminiErr?.message,
                );
              }
              console.warn("analyzeRisk: Gemini quota exceeded; falling back to OpenAI");
            } else if (isGeminiModelNotFoundError(geminiErr)) {
              if (isEmulatorOrNoOpenAISecret()) {
                throw new HttpsError(
                  "failed-precondition",
                  "Gemini model not available",
                  geminiErr?.response?.data || geminiErr?.message,
                );
              }
              console.warn("analyzeRisk: Gemini model not found; falling back to OpenAI");
            } else if ((isGeminiEmptyResponseError(geminiErr) || isJsonParseError(geminiErr)) && !isEmulatorOrNoOpenAISecret()) {
              console.warn("analyzeRisk: Gemini returned invalid/empty JSON; falling back to OpenAI");
            } else {
              throw geminiErr;
            }
          }
        }

        // Fall back to OpenAI if configured.
        if (isEmulatorOrNoOpenAISecret()) {
          throw new HttpsError(
            "failed-precondition",
            "No AI provider configured (missing GEMINI_API_KEY and OPENAI_API_KEY)",
          );
        }

        const responseData = await createChatCompletion({
          apiKey: openaiApiKey.value(),
          model: FALLBACK_MODEL,
          messages,
          temperature: 0.3,
          max_tokens: 500,
          response_format: {type: "json_object"},
          timeoutMs: 50000,
        });

        const analysis = JSON.parse(responseData.choices[0].message.content);

        return {
          success: true,
          analysis,
          usage: responseData.usage,
          modelUsed: FALLBACK_MODEL,
          provider: "openai",
        };
      } catch (error) {
        console.error("Risk Analysis Error:", error.response?.data || error.message);
        throw new HttpsError(
            "internal",
            "Failed to analyze risk",
            error.response?.data || error.message,
        );
      }
    },
);

/**
 * Claim Document Analysis
 * Analyzes veterinary documents for claim processing
 */
exports.analyzeClaimDocument = onCall(
    callOptionsWithOpenAISecret({
      maxInstances: 5,
      timeoutSeconds: 120,
      memory: "512MiB",
    }),
    async (request) => {
      const {documentText, claimType} = request.data;

      if (!documentText) {
        throw new HttpsError("invalid-argument", "Document text is required");
      }

      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      if (isEmulator()) {
        return {
          success: true,
          analysis: {
            claimType: claimType || "general",
            extractedAmount: null,
            notes: "Emulator mode: document analysis stub.",
          },
          usage: null,
          modelUsed: "emulator",
          emulated: true,
        };
      }

      const prompt = `Analyze this veterinary document for a pet insurance claim:

Claim Type: ${claimType || "General"}

Document Text:
${documentText}

Extract and return ONLY a JSON object with:
{
  "diagnosis": "primary diagnosis",
  "treatmentDate": "YYYY-MM-DD or null",
  "veterinarianName": "name or null",
  "clinicName": "clinic name or null",
  "totalAmount": <number or null>,
  "proceduresPerformed": ["procedure1", "procedure2"],
  "confidence": <number 0-1>,
  "flags": ["any concerning items"],
  "isValid": <boolean>
}`;

      try {
        const messages = [
          {
            role: "system",
            content: "You are a veterinary document analysis AI. Extract structured information from vet records for insurance claims.",
          },
          {
            role: "user",
            content: prompt,
          },
        ];

        if (!isEmulatorOrNoGeminiSecret()) {
          try {
            const geminiResponse = await createGeminiCompletion({
              apiKey: geminiApiKey.value(),
              model: GEMINI_DEFAULT_MODEL,
              messages,
              temperature: 0.1,
              maxOutputTokens: 1000,
              response_format: {type: "json_object"},
              timeoutMs: 50000,
            });
            const text = extractGeminiText(geminiResponse);
            if (!text) {
              throw Object.assign(new Error("GEMINI_EMPTY_RESPONSE"), {
                geminiResponse,
              });
            }
            const analysis = JSON.parse(text);

            return {
              success: true,
              analysis,
              usage: geminiResponse?.usageMetadata ?? null,
              modelUsed: GEMINI_DEFAULT_MODEL,
              provider: "gemini",
            };
          } catch (geminiErr) {
            if (isGeminiQuotaError(geminiErr)) {
              if (isEmulatorOrNoOpenAISecret()) {
                throw new HttpsError(
                  "resource-exhausted",
                  "Gemini quota exceeded",
                  geminiErr?.response?.data || geminiErr?.message,
                );
              }
              console.warn("analyzeClaimDocument: Gemini quota exceeded; falling back to OpenAI");
            } else if (isGeminiModelNotFoundError(geminiErr)) {
              if (isEmulatorOrNoOpenAISecret()) {
                throw new HttpsError(
                  "failed-precondition",
                  "Gemini model not available",
                  geminiErr?.response?.data || geminiErr?.message,
                );
              }
              console.warn("analyzeClaimDocument: Gemini model not found; falling back to OpenAI");
            } else if ((isGeminiEmptyResponseError(geminiErr) || isJsonParseError(geminiErr)) && !isEmulatorOrNoOpenAISecret()) {
              console.warn("analyzeClaimDocument: Gemini returned invalid/empty JSON; falling back to OpenAI");
            } else {
              throw geminiErr;
            }
          }
        }

        if (isEmulatorOrNoOpenAISecret()) {
          throw new HttpsError(
            "failed-precondition",
            "No AI provider configured (missing GEMINI_API_KEY and OPENAI_API_KEY)",
          );
        }

        const responseData = await createChatCompletion({
          apiKey: openaiApiKey.value(),
          model: FALLBACK_MODEL,
          messages,
          temperature: 0.1,
          max_tokens: 1000,
          response_format: {type: "json_object"},
          timeoutMs: 50000,
        });

        const analysis = JSON.parse(responseData.choices[0].message.content);

        return {
          success: true,
          analysis,
          usage: responseData.usage,
          modelUsed: FALLBACK_MODEL,
          provider: "openai",
        };
      } catch (error) {
        console.error("Document Analysis Error:", error.response?.data || error.message);
        throw new HttpsError(
            "internal",
            "Failed to analyze document",
            error.response?.data || error.message,
        );
      }
    },
);

/**
 * Claim Decision Engine
 * Makes automated claim approval decisions
 */
exports.makeClaimDecision = onCall(
    callOptionsWithOpenAISecret({
      maxInstances: 5,
      timeoutSeconds: 60,
      memory: "256MiB",
    }),
    async (request) => {
      const {claimData, policyData, documentAnalysis} = request.data;

      if (!claimData || !policyData) {
        throw new HttpsError("invalid-argument", "Claim and policy data required");
      }

      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      if (isEmulator()) {
        return {
          success: true,
          decision: {
            decision: "review",
            approvedAmount: 0,
            confidence: 0.5,
            reasoning: "Emulator mode: returning deterministic decision stub.",
            denialReason: null,
            flagsForReview: ["emulator_mode"],
          },
          usage: null,
          modelUsed: "emulator",
          emulated: true,
        };
      }

      const prompt = `Review this pet insurance claim and make a decision:

Claim Details:
- Type: ${claimData.claimType}
- Amount: $${claimData.claimAmount}
- Incident Date: ${claimData.incidentDate}
- Description: ${claimData.description}

Policy Details:
- Coverage Type: ${policyData.coverageType}
- Deductible: $${policyData.deductible}
- Coverage Limit: $${policyData.coverageLimit}
- Waiting Period Satisfied: ${policyData.waitingPeriodSatisfied}

Document Analysis:
${JSON.stringify(documentAnalysis, null, 2)}

Based on standard pet insurance underwriting guidelines, provide a decision. Return ONLY JSON:
{
  "decision": "approve" or "deny" or "review",
  "approvedAmount": <number or 0>,
  "confidence": <number 0-1>,
  "reasoning": "brief explanation",
  "denialReason": "reason if denied, or null",
  "flagsForReview": ["any items needing human review"]
}`;

      try {
        const messages = [
          {
            role: "system",
            content: "You are a pet insurance claims adjudication AI. Make fair, consistent claim decisions based on policy terms.",
          },
          {
            role: "user",
            content: prompt,
          },
        ];

        if (!isEmulatorOrNoGeminiSecret()) {
          try {
            const geminiResponse = await createGeminiCompletion({
              apiKey: geminiApiKey.value(),
              model: GEMINI_DEFAULT_MODEL,
              messages,
              temperature: 0.2,
              maxOutputTokens: 500,
              response_format: {type: "json_object"},
              timeoutMs: 50000,
            });
            const text = extractGeminiText(geminiResponse);
            if (!text) {
              throw Object.assign(new Error("GEMINI_EMPTY_RESPONSE"), {
                geminiResponse,
              });
            }
            const decision = JSON.parse(text);

            return {
              success: true,
              decision,
              usage: geminiResponse?.usageMetadata ?? null,
              modelUsed: GEMINI_DEFAULT_MODEL,
              provider: "gemini",
            };
          } catch (geminiErr) {
            if (isGeminiQuotaError(geminiErr)) {
              if (isEmulatorOrNoOpenAISecret()) {
                throw new HttpsError(
                  "resource-exhausted",
                  "Gemini quota exceeded",
                  geminiErr?.response?.data || geminiErr?.message,
                );
              }
              console.warn("makeClaimDecision: Gemini quota exceeded; falling back to OpenAI");
            } else if (isGeminiModelNotFoundError(geminiErr)) {
              if (isEmulatorOrNoOpenAISecret()) {
                throw new HttpsError(
                  "failed-precondition",
                  "Gemini model not available",
                  geminiErr?.response?.data || geminiErr?.message,
                );
              }
              console.warn("makeClaimDecision: Gemini model not found; falling back to OpenAI");
            } else if ((isGeminiEmptyResponseError(geminiErr) || isJsonParseError(geminiErr)) && !isEmulatorOrNoOpenAISecret()) {
              console.warn("makeClaimDecision: Gemini returned invalid/empty JSON; falling back to OpenAI");
            } else {
              throw geminiErr;
            }
          }
        }

        if (isEmulatorOrNoOpenAISecret()) {
          throw new HttpsError(
            "failed-precondition",
            "No AI provider configured (missing GEMINI_API_KEY and OPENAI_API_KEY)",
          );
        }

        const responseData = await createChatCompletion({
          apiKey: openaiApiKey.value(),
          model: FALLBACK_MODEL,
          messages,
          temperature: 0.2,
          max_tokens: 500,
          response_format: {type: "json_object"},
          timeoutMs: 50000,
        });

        const decision = JSON.parse(responseData.choices[0].message.content);

        return {
          success: true,
          decision,
          usage: responseData.usage,
          modelUsed: FALLBACK_MODEL,
          provider: "openai",
        };
      } catch (error) {
        console.error("Claim Decision Error:", error.response?.data || error.message);
        throw new HttpsError(
            "internal",
            "Failed to make claim decision",
            error.response?.data || error.message,
        );
      }
    },
);

/**
 * Process Claim Decision (Callable)
 *
 * Server-side claim decisioning to keep OpenAI keys off the client.
 * - Reads /claims/{claimId} and /policies/{policyId}
 * - Calls OpenAI to generate an approve/deny/review decision
 * - Writes aiDecision/aiConfidenceScore/aiReasoningExplanation back to the claim
 * - Keeps status in 'processing' on approval until payout is actually initiated
 */
exports.processClaimDecision = onCall(
    callOptionsWithOpenAISecret(),
    async (request) => {
      const claimId = request.data?.claimId;

      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      if (!claimId || typeof claimId !== "string") {
        throw new HttpsError("invalid-argument", "claimId is required");
      }

      const uid = request.auth.uid;
      const adminFlag = request.auth.token?.admin === true;

      return await processClaimDecisionCore({
        claimId,
        requestedByUid: uid,
        isAdmin: adminFlag,
        system: false,
      });
    },
);

/**
 * Admin: Claim attachment extraction health.
 *
 * Aggregates extraction status counts and returns recent failures so the admin
 * console can monitor the document pipeline.
 */
exports.getClaimAttachmentExtractionHealth = onCall(
  callOptionsWithOpenAISecret({
    timeoutSeconds: 60,
    memory: "256MiB",
  }),
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const adminFlag = request.auth.token?.admin === true;
    if (!adminFlag) {
      throw new HttpsError("permission-denied", "Admin privileges required");
    }

    const nowMs = Date.now();
    const staleCutoff = Timestamp.fromMillis(nowMs - 15 * 60 * 1000);

    const group = db.collectionGroup("attachments");

    async function countSafe(query) {
      try {
        const agg = await query.count().get();
        return Number(agg.data().count || 0);
      } catch (e) {
        // Fallback if AggregateQuery isn't supported in this runtime.
        const snap = await query.limit(1000).get();
        return snap.size;
      }
    }

    const [queued, processing, done, error, staleProcessing] = await Promise.all([
      countSafe(group.where("extractionStatus", "==", "queued")),
      countSafe(group.where("extractionStatus", "==", "processing")),
      countSafe(group.where("extractionStatus", "==", "done")),
      countSafe(group.where("extractionStatus", "==", "error")),
      countSafe(
        group
          .where("extractionStatus", "==", "processing")
          .where("extractionStartedAt", "<=", staleCutoff),
      ),
    ]);

    let recentErrors = [];
    try {
      const recentErrorSnap = await group
        .where("extractionStatus", "==", "error")
        .orderBy("extractedAt", "desc")
        .limit(15)
        .get();

      recentErrors = recentErrorSnap.docs.map((d) => {
        const data = d.data() || {};
        const claimId = d.ref.parent?.parent?.id || null;
        return {
          claimId,
          attachmentId: d.id,
          fileName: data.fileName || null,
          contentType: data.contentType || null,
          extractionError: data.extractionError || null,
          extractionAttemptCount: data.extractionAttemptCount || 0,
          extractedAt: data.extractedAt?.toDate?.().toISOString?.() || null,
          nextAttemptAt: data.nextAttemptAt?.toDate?.().toISOString?.() || null,
        };
      });
    } catch (e) {
      // If indexes aren't ready yet, still return counts.
      recentErrors = [];
    }

    return {
      success: true,
      generatedAt: new Date().toISOString(),
      counts: {
        queued,
        processing,
        done,
        error,
        staleProcessing,
      },
      recentErrors,
    };
  },
);

/**
 * Firestore Trigger: Auto re-run claim decisioning when inputs change.
 *
 * Goal:
 * - Reprocess automatically when documents are uploaded after submission.
 * - Keep the flow automated by moving claims to awaiting_info instead of manual review.
 */
exports.onClaimUpdatedAutoDecision = onDocumentUpdated(
  callOptionsWithOpenAISecret({
    maxInstances: 5,
    timeoutSeconds: 540,
    memory: "1GiB",
  }),
  "claims/{claimId}",
  async (event) => {
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;
    if (!beforeSnap || !afterSnap) return;

    const before = beforeSnap.data() || {};
    const after = afterSnap.data() || {};
    const claimId = event.params.claimId;

    const afterStatus = String(after.status || "").toLowerCase();
    if (["draft", "cancelled", "canceled", "settled", "settling", "denied"].includes(afterStatus)) {
      return;
    }

    const beforeAttachments = normalizeStringArray(before.attachments);
    const afterAttachments = normalizeStringArray(after.attachments);
    const attachmentsAdded = afterAttachments.length > beforeAttachments.length;

    const statusJustSubmitted =
      String(before.status || "").toLowerCase() !== "submitted" && afterStatus === "submitted";

    const claimAmountChanged = Number(before.claimAmount || 0) !== Number(after.claimAmount || 0);
    const claimTypeChanged = String(before.claimType || "") !== String(after.claimType || "");
    const descriptionChanged = String(before.description || "") !== String(after.description || "");
    const incidentBefore = toIsoDateMaybe(before.incidentDate);
    const incidentAfter = toIsoDateMaybe(after.incidentDate);
    const incidentDateChanged = incidentBefore !== incidentAfter;

    const userInputsChanged =
      attachmentsAdded || claimAmountChanged || claimTypeChanged || descriptionChanged || incidentDateChanged;

    if (!statusJustSubmitted && !userInputsChanged) {
      return;
    }

    // Avoid thrashing: if we already processed this exact input hash, skip.
    const inputHash = computeAutomationInputHash(after);
    const existingHash = after.automation?.inputHash;
    if (existingHash && existingHash === inputHash && !attachmentsAdded) {
      return;
    }

    try {
      await processClaimDecisionCore({
        claimId,
        requestedByUid: null,
        isAdmin: true,
        system: true,
      });
    } catch (e) {
      console.error("onClaimUpdatedAutoDecision failed", {
        claimId,
        error: e?.message || e,
      });
    }
  },
);
