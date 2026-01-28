const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");

if (!admin.apps.length) admin.initializeApp();

// Prevent Firestore from throwing when optional fields become `undefined`.
// We still sanitize input, but this provides an extra safety net.
try {
  admin.firestore().settings({ignoreUndefinedProperties: true});
} catch (_) {
  // settings() can only be called once per process; ignore if already set.
}

function sanitizeForFirestore(value) {
  if (value === undefined) return null;
  if (value === null) return null;
  if (Array.isArray(value)) return value.map(sanitizeForFirestore);
  if (value instanceof Date) return value;
  if (typeof value !== "object") return value;

  const out = {};
  for (const [key, raw] of Object.entries(value)) {
    if (raw === undefined) continue;
    out[key] = sanitizeForFirestore(raw);
  }
  return out;
}

function requireObject(value, name) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", `${name} must be an object`);
  }
}

exports.createPolicy = onCall(
  {
    region: "us-central1",
    invoker: "public",
  },
  async (request) => {
    try {
      const uid = request.auth?.uid;
      if (!uid) {
        throw new HttpsError(
          "unauthenticated",
          "Must be authenticated to create a policy",
        );
      }

      const data = sanitizeForFirestore(request.data || {});
      const policyNumber = data.policyNumber;

      if (!policyNumber || typeof policyNumber !== "string") {
        throw new HttpsError("invalid-argument", "policyNumber is required");
      }

      requireObject(data.pet, "pet");
      requireObject(data.owner, "owner");
      requireObject(data.plan, "plan");
      requireObject(data.payment, "payment");

      const now = new Date();
      const expirationDate = new Date(
        now.getFullYear() + 1,
        now.getMonth(),
        now.getDate(),
      );

      const policyId = (typeof data.policyId === "string" && data.policyId.trim())
        ? data.policyId.trim()
        : admin.firestore().collection("policies").doc().id;

      const policy = sanitizeForFirestore({
        policyId,
        policyNumber,
        pet: data.pet,
        owner: data.owner,
        plan: data.plan,
        payment: data.payment,
        effectiveDate: (typeof data.effectiveDate === "string" && data.effectiveDate) ? data.effectiveDate : now.toISOString(),
        expirationDate: (typeof data.expirationDate === "string" && data.expirationDate) ? data.expirationDate : expirationDate.toISOString(),
        createdAt: (typeof data.createdAt === "string" && data.createdAt) ? data.createdAt : now.toISOString(),
        status: (typeof data.status === "string" && data.status) ? data.status : "active",
        underwritingCaseId: data.underwritingCaseId ?? null,
        exclusions: Array.isArray(data.exclusions) ? data.exclusions : [],
        underwritingSnapshot: (data.underwritingSnapshot && typeof data.underwritingSnapshot === "object") ? data.underwritingSnapshot : null,

        ownerId: uid,
        createdBy: request.auth?.token?.email ?? null,
        lastUpdated: FieldValue.serverTimestamp(),
      });

      logger.info("createPolicy: writing policy", {
        policyId,
        uid,
        isAnonymous: request.auth?.token?.firebase?.sign_in_provider === "anonymous",
      });

      await admin.firestore().collection("policies").doc(policyId).set(policy);

  // Mirror a lightweight reference under the user's doc for convenience.
  // (Uses admin privileges; no dependency on Firestore client rules.)
  try {
    await admin
      .firestore()
      .collection("users")
      .doc(uid)
      .collection("policies")
      .doc(policyId)
      .set({
        policyId,
        policyNumber,
        petId: data.pet.id ?? null,
        petName: data.pet.name ?? null,
        planName: data.plan.name ?? null,
        monthlyPremium: data.plan.monthlyPremium ?? null,
        status: policy.status,
        effectiveDate: policy.effectiveDate,
        expirationDate: policy.expirationDate,
        createdAt: FieldValue.serverTimestamp(),
      });
  } catch (e) {
    logger.warn("createPolicy: failed to write user policy reference", {
      policyId,
      uid,
      error: e?.message ?? String(e),
    });
  }

  // Return a JSON-safe payload (no FieldValue).
  const policyForReturn = {
    ...policy,
    lastUpdated: null,
  };

  return {ok: true, policy: policyForReturn};
    } catch (e) {
      const msg = e?.message ?? String(e);
      logger.error("createPolicy: failed", {
        message: msg,
        name: e?.name ?? null,
        stack: e?.stack ?? null,
        hasAuth: !!request.auth,
        uid: request.auth?.uid ?? null,
      });

      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", `createPolicy failed: ${msg}`);
    }
});
