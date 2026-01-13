/**
 * Public underwriting rules fetcher (Callable)
 *
 * Purpose: make a sanitized subset of underwriting rules available to
 * unauthenticated quote flows without opening Firestore reads directly.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();

// Simple in-memory cache per function instance.
let cached = null;
let cachedAtMs = 0;
const CACHE_TTL_MS = 5 * 60 * 1000;

function getDefaultRules() {
  return {
    enabled: true,
    maxRiskScore: 90,
    minAgeMonths: 2,
    maxAgeYears: 14,
    excludedBreeds: [
      "Wolf Hybrid",
      "Wolf Dog",
      "Pit Bull Terrier",
      "American Pit Bull Terrier",
      "Staffordshire Bull Terrier",
      "Presa Canario",
      "Dogo Argentino",
    ],
    criticalConditions: [
      "cancer",
      "terminal illness",
      "end stage kidney disease",
      "end stage liver disease",
      "congestive heart failure",
      "malignant tumor",
      "terminal cancer",
      "metastatic cancer",
    ],
    excludableConditions: [],
  };
}

function sanitizeRules(rules) {
  const allowedKeys = [
    "enabled",
    "maxRiskScore",
    "minAgeMonths",
    "maxAgeYears",
    "excludedBreeds",
    "criticalConditions",
    "excludableConditions",
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
    maxInstances: 10,
    timeoutSeconds: 20,
    memory: "128MiB",
  },
  async (request) => {
    try {
      const now = Date.now();
      if (cached && now - cachedAtMs < CACHE_TTL_MS) {
        return cached;
      }

      const snap = await admin
        .firestore()
        .collection("admin_settings")
        .doc("underwriting_rules")
        .get();

      const defaults = getDefaultRules();
      const rules = {
        ...defaults,
        ...(snap.exists ? (snap.data() || {}) : {}),
      };

      const sanitized = sanitizeRules(rules);
      cached = sanitized;
      cachedAtMs = now;
      return sanitized;
    } catch (e) {
      throw new HttpsError(
        "internal",
        `Failed to load underwriting rules: ${e?.message || e}`,
      );
    }
  },
);
