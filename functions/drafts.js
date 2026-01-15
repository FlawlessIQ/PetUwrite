/**
 * Draft save/resume (Callable)
 *
 * Goal: Enable "save & revisit" without explicit signup by using Anonymous Auth
 * silently, plus a high-entropy resume key that can restore the same Firebase uid
 * across devices via a one-time custom auth token.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("crypto");

if (!admin.apps.length) admin.initializeApp();

function sha256Hex(input) {
  return crypto.createHash("sha256").update(String(input), "utf8").digest("hex");
}

function coerceString(x) {
  if (x === null || x === undefined) return "";
  return String(x);
}

function nowServerTimestamps() {
  return {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function sanitizeDraftInput(data) {
  const resumeKey = coerceString(data?.resumeKey).trim();
  if (!resumeKey || resumeKey.length < 16) {
    throw new HttpsError(
      "invalid-argument",
      "resumeKey is required and must be high-entropy",
    );
  }

  const draftType = coerceString(data?.draftType).trim() || "quote";
  const state = coerceString(data?.state).trim() || "QUOTE";

  const snapshot = data?.snapshot;
  if (snapshot === null || snapshot === undefined || typeof snapshot !== "object") {
    throw new HttpsError("invalid-argument", "snapshot must be an object");
  }

  const underwritingCaseId = coerceString(data?.underwritingCaseId).trim();
  const reason = coerceString(data?.reason).trim();
  const requiredEvidence = Array.isArray(data?.requiredEvidence)
    ? data.requiredEvidence
    : [];

  const expiresInDaysRaw = data?.expiresInDays;
  const expiresInDays =
    typeof expiresInDaysRaw === "number" && isFinite(expiresInDaysRaw)
      ? Math.max(1, Math.min(60, Math.floor(expiresInDaysRaw)))
      : 30;

  return {
    resumeKey,
    draftType,
    state,
    snapshot,
    underwritingCaseId: underwritingCaseId || null,
    reason: reason || null,
    requiredEvidence,
    expiresInDays,
  };
}

exports.upsertDraft = onCall(
  {
    invoker: "public",
    timeoutSeconds: 20,
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const input = sanitizeDraftInput(request.data);
    const hash = sha256Hex(input.resumeKey);
    const docRef = admin.firestore().collection("drafts").doc(hash);

    const uid = request.auth.uid;
    const now = new Date();
    const expiresAt = new Date(now.getTime() + input.expiresInDays * 24 * 60 * 60 * 1000);

    const payload = {
      ownerUid: uid,
      draftType: input.draftType,
      state: input.state,
      snapshot: input.snapshot,
      underwritingCaseId: input.underwritingCaseId,
      reason: input.reason,
      requiredEvidence: input.requiredEvidence,
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      ...nowServerTimestamps(),
    };

    await admin.firestore().runTransaction(async (txn) => {
      const snap = await txn.get(docRef);
      if (!snap.exists) {
        txn.set(docRef, {
          ...payload,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      const existing = snap.data() || {};
      const existingOwner = coerceString(existing.ownerUid).trim();
      if (existingOwner && existingOwner !== uid) {
        throw new HttpsError(
          "permission-denied",
          "Draft belongs to a different user",
        );
      }

      txn.set(docRef, payload, {merge: true});
    });

    logger.info("Draft upserted", {draftId: hash, ownerUid: uid, draftType: input.draftType, state: input.state});

    return {
      ok: true,
      draftId: hash,
      ownerUid: uid,
      expiresAt: expiresAt.toISOString(),
    };
  },
);

exports.resolveDraft = onCall(
  {
    invoker: "public",
    timeoutSeconds: 20,
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    const resumeKey = coerceString(request.data?.resumeKey).trim();
    if (!resumeKey || resumeKey.length < 16) {
      throw new HttpsError("invalid-argument", "resumeKey is required");
    }

    const hash = sha256Hex(resumeKey);
    const docRef = admin.firestore().collection("drafts").doc(hash);
    const snap = await docRef.get();

    if (!snap.exists) {
      throw new HttpsError("not-found", "Draft not found");
    }

    const data = snap.data() || {};
    const ownerUid = coerceString(data.ownerUid).trim();
    if (!ownerUid) {
      throw new HttpsError("failed-precondition", "Draft has no owner");
    }

    const expiresAt = data.expiresAt?.toDate ? data.expiresAt.toDate() : null;
    if (expiresAt && Date.now() > expiresAt.getTime()) {
      throw new HttpsError("failed-precondition", "Draft expired");
    }

    // Important: possession of resumeKey is treated as authorization.
    // Return a custom token so the client can sign in as ownerUid across devices.
    const customToken = await admin.auth().createCustomToken(ownerUid);

    return {
      ok: true,
      draftId: hash,
      ownerUid,
      customToken,
      draft: {
        draftType: coerceString(data.draftType) || "quote",
        state: coerceString(data.state) || "QUOTE",
        snapshot: data.snapshot || {},
        underwritingCaseId: data.underwritingCaseId || null,
        reason: data.reason || null,
        requiredEvidence: Array.isArray(data.requiredEvidence) ? data.requiredEvidence : [],
        expiresAt: expiresAt ? expiresAt.toISOString() : null,
      },
    };
  },
);

exports.clearDraft = onCall(
  {
    invoker: "public",
    timeoutSeconds: 20,
    memory: "256MiB",
    maxInstances: 10,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const resumeKey = coerceString(request.data?.resumeKey).trim();
    if (!resumeKey || resumeKey.length < 16) {
      throw new HttpsError("invalid-argument", "resumeKey is required");
    }

    const hash = sha256Hex(resumeKey);
    const docRef = admin.firestore().collection("drafts").doc(hash);

    await admin.firestore().runTransaction(async (txn) => {
      const snap = await txn.get(docRef);
      if (!snap.exists) return;
      const data = snap.data() || {};
      if (coerceString(data.ownerUid).trim() !== request.auth.uid) {
        throw new HttpsError("permission-denied", "Not the owner");
      }
      txn.delete(docRef);
    });

    return {ok: true};
  },
);
