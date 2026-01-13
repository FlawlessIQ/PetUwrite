/**
 * Public product catalog availability (Callable)
 *
 * Purpose: allow unauthenticated quote flows to know which products (tiers)
 * and riders (add-ons) are enabled, without opening Firestore reads.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (!admin.apps.length) admin.initializeApp();

let cached = null;
let cachedAtMs = 0;
const CACHE_TTL_MS = 5 * 60 * 1000;

function getDefaultAvailability() {
  return {
    enabled: true,
    enabledTiers: {
      basic: true,
      standard: true,
      plus: true,
      premium: true,
      unlimited: true,
    },
    enabledAddOns: {
      examFees: true,
      wellnessLite: true,
      wellnessPremium: true,
      dentalPlus: true,
      rehab: true,
      behavioral: true,
      prescriptionFood: true,
    },
  };
}

function sanitizeAvailability(data) {
  const allowedKeys = [
    "enabled",
    "enabledTiers",
    "enabledAddOns",
    "lastUpdated",
    "updatedBy",
  ];

  const out = {};
  for (const k of allowedKeys) {
    if (data[k] !== undefined) out[k] = data[k];
  }

  // Ensure tier/add-on maps are { string: boolean }
  for (const mapKey of ["enabledTiers", "enabledAddOns"]) {
    const v = out[mapKey];
    if (v && typeof v === "object" && !Array.isArray(v)) {
      const cleaned = {};
      for (const [key, value] of Object.entries(v)) {
        cleaned[String(key)] = value === false ? false : true;
      }
      out[mapKey] = cleaned;
    }
  }

  if (out.enabled !== undefined) {
    out.enabled = out.enabled === false ? false : true;
  }

  return out;
}

exports.getProductCatalogPublic = onCall(
  {
    maxInstances: 10,
    timeoutSeconds: 20,
    memory: "128MiB",
  },
  async () => {
    try {
      const now = Date.now();
      if (cached && now - cachedAtMs < CACHE_TTL_MS) {
        return cached;
      }

      const snap = await admin
        .firestore()
        .collection("admin_settings")
        .doc("product_catalog")
        .get();

      const defaults = getDefaultAvailability();
      const merged = {
        ...defaults,
        ...(snap.exists ? (snap.data() || {}) : {}),
      };

      const sanitized = sanitizeAvailability(merged);
      cached = sanitized;
      cachedAtMs = now;
      return sanitized;
    } catch (e) {
      throw new HttpsError(
        "internal",
        `Failed to load product catalog availability: ${e?.message || e}`,
      );
    }
  },
);
