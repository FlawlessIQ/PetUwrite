/**
 * Public underwriting rules fetcher (Callable)
 *
 * Purpose: make a sanitized subset of underwriting rules available to
 * unauthenticated quote flows without opening Firestore reads directly.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

const {loadUnderwritingRules} = require("./underwritingRulesLoader");

if (!admin.apps.length) admin.initializeApp();

function sanitizeRules(rules) {
  const allowedKeys = [
    "enabled",
    "maxRiskScore",
    "minAgeMonths",
    "maxAgeYears",
    "excludedBreeds",
    "criticalConditions",
    "excludableConditions",
    "rulesVersion",
    "effectiveDate",
    "changeNotes",
    "publishedAt",
    "publishedBy",
    "lastUpdated",
    "updatedBy",
  ];

  const out = {};
  for (const k of allowedKeys) {
    if (rules[k] !== undefined) out[k] = rules[k];
  }

  // Ensure lists are arrays of strings.
  for (const listKey of [
    "excludedBreeds",
    "criticalConditions",
    "excludableConditions",
  ]) {
    const v = out[listKey];
    if (Array.isArray(v)) {
      out[listKey] = v.map((x) => String(x));
    }
  }

  return out;
}

exports.getUnderwritingRulesPublic = onCall(
  {
    invoker: "public",
    maxInstances: 10,
    timeoutSeconds: 20,
    memory: "256MiB",
  },
  async (request) => {
    try {
      const loaded = await loadUnderwritingRules({cache: true});

      if (!loaded.ok) {
        throw new HttpsError(
          "failed-precondition",
          loaded.errorMessage,
          {code: loaded.errorCode},
        );
      }

      return sanitizeRules(loaded.rules);
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      throw new HttpsError(
        "internal",
        `Failed to load underwriting rules: ${e?.message || e}`,
      );
    }
  },
);
