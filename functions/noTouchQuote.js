/**
 * Public no-touch quote orchestration.
 *
 * This function is the Next.js bridge back to the deterministic underwriting
 * contract: collect quote/evidence, hash records, run integrity gates, persist
 * the case, and only create checkout when approval gates are explicit.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");
const crypto = require("crypto");
const pdfParse = require("pdf-parse");
const vision = require("@google-cloud/vision");
const {evaluateUnderwritingQuote} = require("./underwritingEvaluation");

if (!admin.apps.length) admin.initializeApp();

let visionClient;

function getVisionClient() {
  if (!visionClient) {
    visionClient = new vision.ImageAnnotatorClient();
  }
  return visionClient;
}

function coerceString(value) {
  return (value ?? "").toString().trim();
}

function normalizeText(value) {
  return coerceString(value)
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function sha256Hex(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function emailHash(email) {
  const normalized = coerceString(email).toLowerCase();
  return normalized ? sha256Hex(normalized) : null;
}

function sanitizeForFirestore(value) {
  if (value === undefined) return null;
  if (value === null) return null;
  if (Array.isArray(value)) return value.map(sanitizeForFirestore);
  if (
    typeof value === "object" &&
    value !== null &&
    (typeof value.isEqual === "function" ||
      "_methodName" in value ||
      "_delegate" in value)
  ) {
    return value;
  }
  if (typeof value !== "object") return value;

  const out = {};
  for (const [key, raw] of Object.entries(value)) {
    if (raw === undefined) continue;
    out[key] = sanitizeForFirestore(raw);
  }
  return out;
}

function asObject(value, name) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${name} must be an object`);
  }
  return value;
}

function stringList(value) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => coerceString(item)).filter(Boolean);
}

function safeFileName(name) {
  const cleaned = coerceString(name)
    .replace(/[/\\]/g, "-")
    .replace(/[^A-Za-z0-9._ -]/g, "")
    .replace(/\s+/g, "_")
    .slice(0, 120);
  return cleaned || "vet-record";
}

function decodeUpload(upload) {
  const base64 = coerceString(upload.base64).replace(/^data:[^,]+,/, "");
  if (!base64) {
    throw new HttpsError("invalid-argument", "Evidence upload is missing base64 content");
  }

  const buffer = Buffer.from(base64, "base64");
  if (!buffer.length) {
    throw new HttpsError("invalid-argument", "Evidence upload is empty");
  }
  if (buffer.length > 8 * 1024 * 1024) {
    throw new HttpsError("invalid-argument", "Evidence upload must be under 8 MB");
  }

  return buffer;
}

function looksLikePdf(fileName, contentType) {
  return contentType.includes("pdf") || /\.pdf$/i.test(fileName);
}

function looksLikeText(fileName, contentType) {
  return contentType.startsWith("text/") || /\.(txt|csv)$/i.test(fileName);
}

function looksLikeImage(fileName, contentType) {
  return contentType.startsWith("image/") || /\.(png|jpe?g|heic|webp)$/i.test(fileName);
}

async function extractTextFromUpload({buffer, fileName, contentType}) {
  try {
    if (looksLikePdf(fileName, contentType)) {
      const parsed = await pdfParse(buffer);
      return {
        status: parsed.text?.trim() ? "extracted" : "empty",
        text: parsed.text || "",
        metadata: {provider: "pdf-parse", pages: parsed.numpages || null},
      };
    }

    if (looksLikeText(fileName, contentType)) {
      const text = buffer.toString("utf8");
      return {
        status: text.trim() ? "extracted" : "empty",
        text,
        metadata: {provider: "plain-text"},
      };
    }

    if (looksLikeImage(fileName, contentType)) {
      const [result] = await getVisionClient().documentTextDetection({
        image: {content: buffer},
      });
      const text = result?.fullTextAnnotation?.text || "";
      return {
        status: text.trim() ? "extracted" : "empty",
        text,
        metadata: {provider: "google-cloud-vision"},
      };
    }

    return {
      status: "unsupported",
      text: "",
      metadata: {provider: "none"},
    };
  } catch (error) {
    logger.warn("Evidence extraction failed", {
      fileName,
      contentType,
      error: error?.message || String(error),
    });
    return {
      status: "failed",
      text: "",
      metadata: {provider: "none", error: error?.message || String(error)},
    };
  }
}

async function processEvidenceUploads({caseId, uploads, contact}) {
  const out = [];
  const rawVetTexts = [];
  const vetDocumentHashes = [];
  const bucketName = getStorageBucketName();
  if (!bucketName) {
    throw new HttpsError(
      "failed-precondition",
      "Missing storage bucket configuration for vet record uploads",
    );
  }
  const bucket = admin.storage().bucket(bucketName);
  const contactEmailHash = emailHash(contact.email);

  for (const upload of uploads.slice(0, 6)) {
    const fileName = safeFileName(upload.fileName);
    const contentType = coerceString(upload.contentType) || "application/octet-stream";
    const buffer = decodeUpload(upload);
    const documentHash = sha256Hex(buffer);
    const objectPath = `vet_records/cases/${caseId}/${documentHash}_${fileName}`;

    await bucket.file(objectPath).save(buffer, {
      contentType,
      metadata: {
        metadata: {
          caseId,
          documentHash,
          originalFileName: fileName,
        },
      },
    });

    const extraction = await extractTextFromUpload({buffer, fileName, contentType});
    if (extraction.text.trim()) rawVetTexts.push(extraction.text);
    vetDocumentHashes.push(documentHash);

    const record = sanitizeForFirestore({
      caseId,
      fileName,
      contentType,
      objectPath,
      documentHash,
      sizeBytes: buffer.length,
      extractionStatus: extraction.status,
      extractionMetadata: extraction.metadata,
      contactEmailHash,
      createdAt: FieldValue.serverTimestamp(),
    });

    await admin
      .firestore()
      .collection("underwriting_cases")
      .doc(caseId)
      .collection("vet_records")
      .doc(documentHash)
      .set(record, {merge: true});

    out.push({
      fileName,
      contentType,
      objectPath,
      documentHash,
      sizeBytes: buffer.length,
      extractionStatus: extraction.status,
    });
  }

  return {records: out, rawVetTexts, vetDocumentHashes};
}

async function checkDocumentReuse({caseId, hashes, contact}) {
  const matchedCaseIds = new Set();
  const contactEmailHash = emailHash(contact.email);

  for (const hash of hashes) {
    const hashDoc = await admin.firestore().collection("vet_document_hashes").doc(hash).get();
    const hashData = hashDoc.exists ? hashDoc.data() || {} : {};
    const seenCases = Array.isArray(hashData.caseIds) ? hashData.caseIds : [];
    const seenEmailHashes = Array.isArray(hashData.contactEmailHashes)
      ? hashData.contactEmailHashes
      : [];
    for (const seenCaseId of seenCases) {
      const id = coerceString(seenCaseId);
      if (id && id !== caseId) matchedCaseIds.add(id);
    }

    if (
      contactEmailHash &&
      seenEmailHashes.some((seenHash) => {
        const normalized = coerceString(seenHash);
        return normalized &&
          normalized !== "unknown" &&
          normalized !== contactEmailHash;
      })
    ) {
      return {
        action: "decline",
        reasonCode: "VET_DOCUMENT_REUSE_CROSS_ACCOUNT",
        matchedCaseIds: Array.from(matchedCaseIds).sort(),
      };
    }

    let queryDocs = [];
    try {
      const query = await admin
        .firestore()
        .collectionGroup("vet_records")
        .where("documentHash", "==", hash)
        .limit(10)
        .get();
      queryDocs = query.docs;
    } catch (error) {
      if (!isFirestoreIndexUnavailable(error)) throw error;
      logger.warn(
        "Skipping vet_records reuse fallback; index unavailable",
        {
          caseId,
          documentHash: hash,
          error: error?.message || String(error),
        },
      );
    }

    for (const doc of queryDocs) {
      const data = doc.data() || {};
      const otherCaseId = coerceString(data.caseId);
      if (otherCaseId && otherCaseId !== caseId) matchedCaseIds.add(otherCaseId);
      if (
        data.contactEmailHash &&
        contactEmailHash &&
        data.contactEmailHash !== contactEmailHash
      ) {
        return {
          action: "decline",
          reasonCode: "VET_DOCUMENT_REUSE_CROSS_ACCOUNT",
          matchedCaseIds: Array.from(matchedCaseIds).sort(),
        };
      }
    }

    if (matchedCaseIds.size >= 2) {
      return {
        action: "decline",
        reasonCode: "VET_DOCUMENT_REUSE_MULTI_CASE",
        matchedCaseIds: Array.from(matchedCaseIds).sort(),
      };
    }
  }

  if (matchedCaseIds.size > 0) {
    return {
      action: "need_more_info",
      reasonCode: "VET_DOCUMENT_REUSE_DETECTED",
      matchedCaseIds: Array.from(matchedCaseIds).sort(),
    };
  }

  return {action: "pass", reasonCode: "NO_REUSE", matchedCaseIds: []};
}

function isFirestoreIndexUnavailable(error) {
  const message = coerceString(error?.message || error);
  return (
    message.includes("FAILED_PRECONDITION") &&
    message.includes("collection vet_records") &&
    message.includes("documentHash")
  );
}

async function recordDocumentHashes({caseId, records, contact}) {
  const contactEmailHash = emailHash(contact.email);
  const batch = admin.firestore().batch();

  for (const record of records) {
    const ref = admin.firestore().collection("vet_document_hashes").doc(record.documentHash);
    batch.set(
      ref,
      {
        documentHash: record.documentHash,
        caseIds: FieldValue.arrayUnion(caseId),
        contactEmailHashes: contactEmailHash
          ? FieldValue.arrayUnion(contactEmailHash)
          : FieldValue.arrayUnion("unknown"),
        lastSeenAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
  }

  await batch.commit();
}

function needMoreInfoDecision({reasonCode, body, reasons, requiredEvidence, fraudSignals}) {
  return {
    status: "need_more_info",
    label: "More information needed",
    body,
    reasonCode,
    reasons: Array.from(new Set(reasons.filter(Boolean))),
    exclusions: [],
    requiredEvidence,
    pricingEnabled: false,
    integrityPassed: false,
    riskBand: "medium",
    fraudSignals,
  };
}

function declinedDecision({reasonCode, body, reasons, fraudSignals}) {
  return {
    status: "declined",
    label: "Not eligible",
    body,
    reasonCode,
    reasons: Array.from(new Set(reasons.filter(Boolean))),
    exclusions: [],
    requiredEvidence: [],
    pricingEnabled: false,
    integrityPassed: false,
    riskBand: "veryHigh",
    fraudSignals,
  };
}

const evidenceRequirements = {
  officialVetRecord: {
    code: "VET_RECORD_WITH_CLINIC_HEADER",
    title: "Upload an official vet record",
    details:
      "Upload a record page with clinic letterhead, visit date, and clinic contact information.",
  },
  petIdentity: {
    code: "PET_IDENTITY_CONFIRMATION",
    title: "Confirm pet identity",
    details:
      "Upload a record page that clearly shows your pet's name, species, age or date of birth.",
  },
  recentRecord: {
    code: "RECENT_VET_RECORD",
    title: "Upload a recent vet record",
    details:
      "Upload a veterinary record with a visible visit date within the last 24 months.",
  },
  finalDiagnostics: {
    code: "DIAGNOSTIC_RESULTS",
    title: "Upload final diagnostic results",
    details:
      "Upload the final lab, imaging, pathology, or specialist report for pending diagnostics.",
  },
};

function getStorageBucketName() {
  const explicit = process.env.STORAGE_BUCKET;
  if (explicit) return explicit;

  const fromAdmin = admin.app()?.options?.storageBucket;
  if (fromAdmin) return fromAdmin;

  try {
    const raw = process.env.FIREBASE_CONFIG;
    if (raw) {
      const parsed = JSON.parse(raw);
      if (parsed?.storageBucket) return parsed.storageBucket;
      if (parsed?.projectId) return `${parsed.projectId}.firebasestorage.app`;
    }
  } catch (_) {
    // Fall through to environment/project-id fallback.
  }

  const projectId =
    process.env.GCLOUD_PROJECT ||
    process.env.GCP_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT;
  return projectId ? `${projectId}.firebasestorage.app` : null;
}

function vetRecordIntegrity(rawVetTexts) {
  const joined = rawVetTexts.join("\n");
  if (!joined.trim()) return null;
  const text = joined.toLowerCase();
  const hasClinicSignal =
    /\b(veterinary|animal\s+hospital|vet\s+clinic|clinic|hospital|dvm|vmd|phone|fax|address|www\.|http)\b/.test(text);
  const hasPhone = /\b\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b/.test(text);
  const emails = joined.match(/[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/g) || [];
  const freeDomains = new Set([
    "gmail.com",
    "yahoo.com",
    "outlook.com",
    "hotmail.com",
    "icloud.com",
    "aol.com",
    "proton.me",
    "protonmail.com",
  ]);

  if (!hasClinicSignal && !hasPhone && emails.length === 0) {
    return {
      reasonCode: "VET_RECORD_INTEGRITY_INSUFFICIENT_HEADER",
      requiredEvidence: [evidenceRequirements.officialVetRecord],
    };
  }

  for (const email of emails) {
    const domain = email.split("@").pop().toLowerCase();
    if (freeDomains.has(domain)) {
      return {
        reasonCode: "VET_RECORD_FREE_EMAIL_DETECTED",
        requiredEvidence: [evidenceRequirements.officialVetRecord],
      };
    }
  }

  return null;
}

function identityCheck(quote, rawVetTexts) {
  const joined = rawVetTexts.join("\n");
  const text = joined.toLowerCase();
  if (!text.trim()) return null;

  const species = extractSpecies(text);
  const petType = normalizeText(quote.petType);
  if (species && petType && species !== petType) {
    return {
      action: "decline",
      reasonCode: "PET_IDENTITY_SPECIES_MISMATCH",
      reasons: ["Vet record species does not match the application"],
    };
  }

  const extractedName = extractPetName(joined);
  if (extractedName && quote.petName && !namesRoughlyMatch(quote.petName, extractedName)) {
    return {
      action: "need_more_info",
      reasonCode: "PET_IDENTITY_NAME_MISMATCH",
      requiredEvidence: [evidenceRequirements.petIdentity],
      reasons: ["Vet record pet name does not clearly match the application"],
    };
  }

  const extractedAge = extractAgeYears(joined);
  const quotedAge = Number(quote.ageYears);
  if (
    Number.isFinite(extractedAge) &&
    Number.isFinite(quotedAge) &&
    Math.abs(extractedAge - quotedAge) >= 2
  ) {
    return {
      action: "need_more_info",
      reasonCode: "PET_IDENTITY_AGE_MISMATCH",
      requiredEvidence: [evidenceRequirements.petIdentity],
      reasons: ["Vet record age does not clearly match the application"],
    };
  }

  return null;
}

function extractSpecies(text) {
  if (/\b(species\s*[:\-]\s*cat|feline)\b/.test(text)) return "cat";
  if (/\b(species\s*[:\-]\s*dog|canine)\b/.test(text)) return "dog";
  if (/\bcat\b/.test(text) && /\bfeline\b/.test(text)) return "cat";
  if (/\bdog\b/.test(text) && /\bcanine\b/.test(text)) return "dog";
  return null;
}

function extractPetName(raw) {
  const lines = raw.split(/[\r\n]+/);
  for (const line of lines) {
    const match = /\b(patient|pet\s*name|name)\s*[:\-]\s*([A-Za-z][A-Za-z'\- ]{1,30})\b/i.exec(line);
    if (match?.[2]) return match[2].trim();
  }
  return null;
}

function extractAgeYears(raw) {
  const ageMatch = /\bage\s*[:\-]\s*(\d{1,2})\s*(years|yrs|y)\b/i.exec(raw);
  if (ageMatch?.[1]) return Number(ageMatch[1]);

  const dobMatch = /\b(dob|date\s*of\s*birth)\s*[:\-]\s*(\d{4}[\-/]\d{2}[\-/]\d{2})\b/i.exec(raw);
  if (!dobMatch?.[2]) return null;
  const dob = new Date(dobMatch[2].replace(/\//g, "-"));
  if (!Number.isFinite(dob.getTime())) return null;
  const now = new Date();
  let years = now.getFullYear() - dob.getFullYear();
  const beforeBirthday =
    now.getMonth() < dob.getMonth() ||
    (now.getMonth() === dob.getMonth() && now.getDate() < dob.getDate());
  if (beforeBirthday) years -= 1;
  return Math.max(0, years);
}

function namesRoughlyMatch(a, b) {
  const left = normalizeText(a).replace(/\s/g, "");
  const right = normalizeText(b).replace(/\s/g, "");
  if (!left || !right) return true;
  if (left === right || left.includes(right) || right.includes(left)) return true;
  const distance = levenshtein(left, right);
  const maxLen = Math.max(left.length, right.length);
  if (maxLen <= 5) return distance <= 1;
  if (maxLen <= 10) return distance <= 2;
  return distance <= 3;
}

function levenshtein(a, b) {
  const prev = Array.from({length: b.length + 1}, (_, i) => i);
  const curr = Array(b.length + 1).fill(0);
  for (let i = 1; i <= a.length; i++) {
    curr[0] = i;
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      curr[j] = Math.min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost);
    }
    for (let j = 0; j <= b.length; j++) prev[j] = curr[j];
  }
  return prev[b.length];
}

function timingCheck(rawVetTexts) {
  const joined = rawVetTexts.join("\n");
  if (!joined.trim()) return null;

  if (
    /\b(pending|awaiting\s+results|results\s+pending|send\s*out|sent\s+out|biopsy\s+pending|pathology\s+pending|culture\s+pending|labs?\s+pending|recheck\s+pending)\b/i.test(joined)
  ) {
    return {
      reasonCode: "DIAGNOSTIC_RESULTS_PENDING",
      requiredEvidence: [evidenceRequirements.finalDiagnostics],
      reasons: ["Uploaded records indicate diagnostic results are pending"],
    };
  }

  const dates = Array.from(
    joined.matchAll(/\b(20\d{2}|19\d{2})[-/](0?[1-9]|1[0-2])[-/](0?[1-9]|[12]\d|3[01])\b/g),
  )
    .map((match) => new Date(match[0].replace(/\//g, "-")))
    .filter((date) => Number.isFinite(date.getTime()));

  if (!dates.length) {
    return {
      reasonCode: "VET_RECORD_DATE_MISSING",
      requiredEvidence: [evidenceRequirements.recentRecord],
      reasons: ["Uploaded records do not show a clear visit date"],
    };
  }

  const mostRecent = dates.reduce((best, date) => (date > best ? date : best), dates[0]);
  const ageDays = Math.floor((Date.now() - mostRecent.getTime()) / 86400000);
  if (ageDays > 730) {
    return {
      reasonCode: "VET_RECORD_TOO_OLD",
      requiredEvidence: [evidenceRequirements.recentRecord],
      reasons: ["Uploaded records appear older than 24 months"],
    };
  }

  return null;
}

function applyIntegrityOverrides({decision, quote, rawVetTexts, reuseCheck}) {
  const fraudSignals = [...(decision.fraudSignals || [])];

  if (reuseCheck.action === "decline") {
    return declinedDecision({
      reasonCode: reuseCheck.reasonCode,
      body:
        "The uploaded document matches prior underwriting records in a way that cannot be accepted for a new application.",
      reasons: ["Vet document reuse detected"],
      fraudSignals: [
        ...fraudSignals,
        {
          code: reuseCheck.reasonCode,
          label: "Vet document reuse detected",
          severity: "critical",
        },
      ],
    });
  }

  const identity = identityCheck(quote, rawVetTexts);
  if (identity?.action === "decline") {
    return declinedDecision({
      reasonCode: identity.reasonCode,
      body:
        "The uploaded vet record does not match the pet on the application.",
      reasons: identity.reasons,
      fraudSignals: [
        ...fraudSignals,
        {
          code: identity.reasonCode,
          label: "Pet identity mismatch",
          severity: "critical",
        },
      ],
    });
  }

  const blockers = [];
  if (reuseCheck.action === "need_more_info") {
    blockers.push({
      reasonCode: reuseCheck.reasonCode,
      requiredEvidence: [evidenceRequirements.officialVetRecord],
      reasons: ["Vet document reuse requires confirmation"],
      signal: {
        code: reuseCheck.reasonCode,
        label: "Vet document reuse requires confirmation",
        severity: "high",
      },
    });
  }

  const integrity = vetRecordIntegrity(rawVetTexts);
  if (integrity) blockers.push({...integrity, reasons: ["Vet record source needs verification"]});

  if (identity?.action === "need_more_info") {
    blockers.push({
      reasonCode: identity.reasonCode,
      requiredEvidence: identity.requiredEvidence,
      reasons: identity.reasons,
    });
  }

  const timing = timingCheck(rawVetTexts);
  if (timing) blockers.push(timing);

  if (!blockers.length) return decision;

  return needMoreInfoDecision({
    reasonCode: blockers[0].reasonCode,
    body:
      "We need verifiable records or a cleaner intake signal before pricing can be shown. Upload the requested evidence and the system can rerun the decision automatically.",
    reasons: [
      ...(decision.reasons || []),
      ...blockers.flatMap((blocker) => blocker.reasons || []),
    ],
    requiredEvidence: dedupeEvidence(blockers.flatMap((blocker) => blocker.requiredEvidence || [])),
    fraudSignals: [
      ...fraudSignals,
      ...blockers.map((blocker) => blocker.signal).filter(Boolean),
    ],
  });
}

function dedupeEvidence(items) {
  const byCode = new Map();
  for (const item of items) byCode.set(item.code, item);
  return Array.from(byCode.values());
}

function maybeEscalateEvidenceFailure({decision, priorAttempts, action}) {
  if (decision.status !== "need_more_info") return {decision, attempts: priorAttempts};
  const nextAttempts = action === "submit_evidence" ? priorAttempts + 1 : priorAttempts;
  if (nextAttempts >= 2) {
    return {
      attempts: nextAttempts,
      decision: declinedDecision({
        reasonCode: "REQUIRED_EVIDENCE_NOT_PROVIDED",
        body:
          "The required evidence was not provided after the automated follow-up path, so the application cannot continue.",
        reasons: ["Required evidence not provided"],
        fraudSignals: decision.fraudSignals || [],
      }),
    };
  }
  return {decision, attempts: nextAttempts};
}

function hasMedicalDisclosure(quote) {
  const conditions = stringList(quote.diagnosedConditions).filter(
    (condition) => condition.toLowerCase() !== "none of these",
  );
  return (
    conditions.length > 0 ||
    quote.currentSymptoms === "yes" ||
    quote.medication === "yes" ||
    quote.recentSurgery === "yes"
  );
}

function calculateSelectedMonthly({selectedPlan, selectedOptions}) {
  const plan = coerceString(selectedPlan?.id || selectedPlan?.plan || selectedPlan);
  const base = {
    essential: 34,
    comprehensive: 49,
    premium: 68,
  }[plan] || 49;
  const deductible = coerceString(selectedOptions?.deductible || "250");
  const reimbursement = coerceString(selectedOptions?.reimbursement || "80");
  const annualLimit = coerceString(selectedOptions?.annualLimit || "20000");
  const riders = Array.isArray(selectedOptions?.riders) ? selectedOptions.riders : [];

  const total =
    base +
    ({100: 12, 250: 0, 500: -8}[deductible] || 0) +
    ({70: -7, 80: 0, 90: 10}[reimbursement] || 0) +
    ({10000: -5, 20000: 0, unlimited: 14}[annualLimit] || 0) +
    riders.reduce((sum, rider) => {
      return sum + ({wellness: 18, examFees: 5, dentalIllness: 6, rehab: 5}[rider] || 0);
    }, 0);

  return Math.max(18, total);
}

async function createCheckoutIfAllowed({caseId, decision, contact, selectedPlan, selectedOptions}) {
  if (
    !(decision.status === "approved" || decision.status === "approved_with_exclusions") ||
    decision.pricingEnabled !== true ||
    decision.integrityPassed !== true
  ) {
    return {status: "blocked", reason: "UNDERWRITING_NOT_APPROVED"};
  }

  const stripeKey = process.env.STRIPE_SECRET_KEY;
  if (!stripeKey) {
    return {status: "configuration_required", reason: "STRIPE_SECRET_KEY_MISSING"};
  }

  const monthly = calculateSelectedMonthly({selectedPlan, selectedOptions});
  const stripe = require("stripe")(stripeKey);
  const baseUrl =
    process.env.NEXT_PUBLIC_SITE_URL ||
    process.env.PUBLIC_SITE_URL ||
    "https://pet-underwriter-ai.web.app";
  const policyId = admin.firestore().collection("policies").doc().id;

  const session = await stripe.checkout.sessions.create({
    mode: "subscription",
    client_reference_id: caseId,
    customer_email: coerceString(contact.email) || undefined,
    success_url: `${baseUrl}/quote?checkout=success&caseId=${caseId}`,
    cancel_url: `${baseUrl}/quote?checkout=cancelled&caseId=${caseId}`,
    subscription_data: {
      metadata: {
        caseId,
        policyId,
        underwritingStatus: decision.status,
      },
    },
    line_items: [
      {
        quantity: 1,
        price_data: {
          currency: "usd",
          recurring: {interval: "month"},
          unit_amount: Math.round(monthly * 100),
          product_data: {
            name: `Clovara ${coerceString(selectedPlan?.title || selectedPlan?.id || "Pet Insurance")} policy`,
            metadata: {caseId, policyId},
          },
        },
      },
    ],
    metadata: {
      caseId,
      policyId,
      underwritingStatus: decision.status,
    },
  });

  await admin.firestore().collection("policy_bindings").doc(policyId).set({
    policyId,
    caseId,
    status: "checkout_created",
    checkoutSessionId: session.id,
    monthlyPremium: monthly,
    selectedPlan: sanitizeForFirestore(selectedPlan),
    selectedOptions: sanitizeForFirestore(selectedOptions),
    underwritingSnapshot: sanitizeForFirestore(decision),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  return {
    status: "checkout_created",
    policyId,
    checkoutSessionId: session.id,
    checkoutUrl: session.url,
    monthlyPremium: monthly,
  };
}

exports.submitNoTouchQuotePublic = onCall(
  {
    invoker: "public",
    maxInstances: 10,
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (request) => {
    try {
      const data = request.data || {};
      const quote = asObject(data.quote, "quote");
      const contact = asObject(data.contact, "contact");
      const selectedPlan = data.selectedPlan || null;
      const selectedOptions = data.selectedOptions || {};
      const action = coerceString(data.action) || "save";
      const uploads = Array.isArray(data.evidenceUploads) ? data.evidenceUploads : [];

      const existingCaseId = coerceString(data.caseId);
      const caseRef = existingCaseId
        ? admin.firestore().collection("underwriting_cases").doc(existingCaseId)
        : admin.firestore().collection("underwriting_cases").doc();
      const caseId = caseRef.id;
      const existing = await caseRef.get();
      const priorAttempts = Number(existing.data()?.needMoreInfoAttempts || 0);

      await caseRef.set(
        {
          caseId,
          status: "received",
          source: "next_quote_flow",
          quote: sanitizeForFirestore(quote),
          contact: sanitizeForFirestore({
            firstName: contact.firstName,
            lastName: contact.lastName,
            email: contact.email,
            zipCode: contact.zipCode,
            emailHash: emailHash(contact.email),
          }),
          selectedPlan: sanitizeForFirestore(selectedPlan),
          selectedOptions: sanitizeForFirestore(selectedOptions),
          updatedAt: FieldValue.serverTimestamp(),
          createdAt: existing.exists ? existing.data()?.createdAt || FieldValue.serverTimestamp() : FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

      const processed = uploads.length
        ? await processEvidenceUploads({caseId, uploads, contact})
        : {records: [], rawVetTexts: [], vetDocumentHashes: []};

      const rawVetTexts = [
        ...stringList(quote.rawVetTexts),
        ...processed.rawVetTexts,
      ];
      const vetDocumentHashes = [
        ...stringList(quote.vetDocumentHashes),
        ...processed.vetDocumentHashes,
      ];

      const reuseCheck = await checkDocumentReuse({
        caseId,
        hashes: vetDocumentHashes,
        contact,
      });

      const baseDecision = await evaluateUnderwritingQuote({
        ...quote,
        rawVetTexts,
        vetDocumentHashes,
      });
      let overridden = applyIntegrityOverrides({
        decision: baseDecision,
        quote,
        rawVetTexts,
        reuseCheck,
      });
      if (
        processed.records.length > 0 &&
        rawVetTexts.filter((text) => text.trim()).length === 0 &&
        hasMedicalDisclosure(quote)
      ) {
        overridden = needMoreInfoDecision({
          reasonCode: "VET_RECORD_TEXT_EXTRACTION_FAILED",
          body:
            "The uploaded record could not be read clearly enough to complete automated underwriting. Upload a clearer PDF, image, or official clinic record and the system can rerun the decision.",
          reasons: ["Vet record text extraction failed"],
          requiredEvidence: [evidenceRequirements.officialVetRecord],
          fraudSignals: overridden.fraudSignals || [],
        });
      }
      const escalated = maybeEscalateEvidenceFailure({
        decision: overridden,
        priorAttempts,
        action,
      });
      const decision = escalated.decision;

      if (processed.records.length) {
        await recordDocumentHashes({caseId, records: processed.records, contact});
      }

      const pricingSnapshot =
        decision.pricingEnabled === true && decision.integrityPassed === true
          ? {
              status: "priced",
              monthlyPremium: calculateSelectedMonthly({selectedPlan, selectedOptions}),
              selectedPlan: sanitizeForFirestore(selectedPlan),
              selectedOptions: sanitizeForFirestore(selectedOptions),
            }
          : {status: "blocked", reason: "UNDERWRITING_NOT_APPROVED"};

      const payment =
        action === "start_payment"
          ? await createCheckoutIfAllowed({
              caseId,
              decision,
              contact,
              selectedPlan,
              selectedOptions,
            })
          : {status: "not_requested"};

      await caseRef.set(
        sanitizeForFirestore({
          status: decision.status,
          underwritingStatus: decision.status,
          pricingEnabled: decision.pricingEnabled,
          integrityPassed: decision.integrityPassed,
          decision,
          pricingSnapshot,
          payment,
          action,
          needMoreInfoAttempts: escalated.attempts,
          evidenceUploads: processed.records,
          vetDocumentHashes,
          vetRecordExtractionTextCount: rawVetTexts.filter((text) => text.trim()).length,
          documentReuse: reuseCheck,
          decidedBy: "system",
          noHumanTouch: true,
          decidedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }),
        {merge: true},
      );

      return {
        ok: true,
        caseId,
        decision,
        pricing: pricingSnapshot,
        payment,
        evidence: {
          uploaded: processed.records,
          rawTextCount: rawVetTexts.filter((text) => text.trim()).length,
          documentHashes: vetDocumentHashes,
        },
        noHumanTouch: true,
      };
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error("submitNoTouchQuotePublic failed", {
        error: error?.message || String(error),
        stack: error?.stack || null,
      });
      throw new HttpsError(
        "internal",
        `No-touch quote submission failed: ${error?.message || error}`,
      );
    }
  },
);
