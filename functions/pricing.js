/**
 * Versioned pricing (Callable)
 *
 * - Admin-managed pricing versions live in Firestore.
 * - Public quote flows call into this function to get priced day-one plans.
 * - Raw pricing configs are never readable by clients via Firestore rules.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const {FieldValue} = require("firebase-admin/firestore");
const zipcodes = require("zipcodes");

if (!admin.apps.length) admin.initializeApp();

function coerceString(v) {
  return (v ?? "").toString();
}

function coerceNumber(v) {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function coerceInt(v) {
  const n = coerceNumber(v);
  if (n === null) return null;
  return Math.trunc(n);
}

async function isAdminCaller(request) {
  if (!request.auth) return false;
  if (request.auth.token?.admin === true) return true;

  try {
    const uid = request.auth.uid;
    const doc = await admin.firestore().collection("users").doc(uid).get();
    const role = doc.exists ? doc.data()?.userRole : null;
    return role === 2 || role === 3;
  } catch (e) {
    logger.warn("isAdminCaller check failed", {error: e?.message});
    return false;
  }
}

function defaultPricingConfig() {
  return {
    version: "v_launch_growth_safe_2026_01",
    effectiveDateIso: "2026-01-11",
    notes:
      "Launch growth-safe pricing: baseRiskRate × riskBandMultiplier × coverage relativities + add-on loads. Availability rules enforced outside pricing math.",
    baseRiskRate: 45.0,
    regionalAdjustments: {
      NY: 1.1,
      CA: 1.08,
      MA: 1.09,
      WA: 1.07,
      IL: 1.06,
      TX: 1.02,
      FL: 1.03,
      DEFAULT: 1.0,
    },
    multiPetDiscounts: {
      1: 0.0,
      2: 0.05,
      3: 0.1,
      4: 0.15,
    },
    riskBandMultipliers: {
      low: 0.85,
      medium: 1.0,
      high: 1.4,
      veryHigh: 1.9,
    },
    reimbursementFactors: {
      70: 0.9,
      80: 1.0,
      90: 1.15,
    },
    deductibleFactors: {
      100: 1.2,
      250: 1.05,
      500: 1.0,
      750: 0.93,
      1000: 0.88,
    },
    annualLimitFactors: {
      5000: 0.9,
      10000: 1.0,
      15000: 1.12,
      20000: 1.25,
      unlimited: 1.65,
    },
    addOnMonthlyLoads: {
      examFees: 5.0,
      wellnessLite: 8.0,
      wellnessPremium: 18.0,
      dentalPlus: 6.0,
      rehab: 5.0,
      behavioral: 4.0,
      prescriptionFood: 3.0,
    },
    minMonthlyPremium: 10.0,
  };
}

function normalizePricingConfig(raw) {
  const cfg = raw && typeof raw === "object" ? raw : {};

  const out = {
    version: coerceString(cfg.version) || defaultPricingConfig().version,
    effectiveDateIso:
      coerceString(cfg.effectiveDateIso) || defaultPricingConfig().effectiveDateIso,
    notes: coerceString(cfg.notes) || defaultPricingConfig().notes,
    baseRiskRate: coerceNumber(cfg.baseRiskRate) ?? defaultPricingConfig().baseRiskRate,
    minMonthlyPremium:
      coerceNumber(cfg.minMonthlyPremium) ?? defaultPricingConfig().minMonthlyPremium,
    regionalAdjustments: {
      ...defaultPricingConfig().regionalAdjustments,
      ...(cfg.regionalAdjustments && typeof cfg.regionalAdjustments === "object"
        ? cfg.regionalAdjustments
        : {}),
    },
    multiPetDiscounts: {
      ...defaultPricingConfig().multiPetDiscounts,
      ...(cfg.multiPetDiscounts && typeof cfg.multiPetDiscounts === "object"
        ? cfg.multiPetDiscounts
        : {}),
    },
    riskBandMultipliers: {
      ...defaultPricingConfig().riskBandMultipliers,
      ...(cfg.riskBandMultipliers && typeof cfg.riskBandMultipliers === "object"
        ? cfg.riskBandMultipliers
        : {}),
    },
    reimbursementFactors: {
      ...defaultPricingConfig().reimbursementFactors,
      ...(cfg.reimbursementFactors && typeof cfg.reimbursementFactors === "object"
        ? cfg.reimbursementFactors
        : {}),
    },
    deductibleFactors: {
      ...defaultPricingConfig().deductibleFactors,
      ...(cfg.deductibleFactors && typeof cfg.deductibleFactors === "object"
        ? cfg.deductibleFactors
        : {}),
    },
    annualLimitFactors: {
      ...defaultPricingConfig().annualLimitFactors,
      ...(cfg.annualLimitFactors && typeof cfg.annualLimitFactors === "object"
        ? cfg.annualLimitFactors
        : {}),
    },
    addOnMonthlyLoads: {
      ...defaultPricingConfig().addOnMonthlyLoads,
      ...(cfg.addOnMonthlyLoads && typeof cfg.addOnMonthlyLoads === "object"
        ? cfg.addOnMonthlyLoads
        : {}),
    },
  };

  // Coerce numeric-like map values to numbers.
  for (const [k, v] of Object.entries(out.regionalAdjustments)) {
    const n = coerceNumber(v);
    if (n !== null) out.regionalAdjustments[k] = n;
  }

  for (const [k, v] of Object.entries(out.multiPetDiscounts)) {
    const n = coerceNumber(v);
    if (n !== null) out.multiPetDiscounts[k] = n;
  }

  for (const [k, v] of Object.entries(out.riskBandMultipliers)) {
    const n = coerceNumber(v);
    if (n !== null) out.riskBandMultipliers[k] = n;
  }

  for (const [k, v] of Object.entries(out.reimbursementFactors)) {
    const n = coerceNumber(v);
    if (n !== null) out.reimbursementFactors[k] = n;
  }

  for (const [k, v] of Object.entries(out.deductibleFactors)) {
    const n = coerceNumber(v);
    if (n !== null) out.deductibleFactors[k] = n;
  }

  for (const [k, v] of Object.entries(out.annualLimitFactors)) {
    const n = coerceNumber(v);
    if (n !== null) out.annualLimitFactors[k] = n;
  }

  for (const [k, v] of Object.entries(out.addOnMonthlyLoads)) {
    const n = coerceNumber(v);
    if (n !== null) out.addOnMonthlyLoads[k] = n;
  }

  return out;
}

async function loadActivePricingConfig() {
  // pricing_meta/active: { activeVersionId: string }
  const metaSnap = await admin
    .firestore()
    .collection("pricing_meta")
    .doc("active")
    .get();

  const activeVersionId = metaSnap.exists
    ? coerceString(metaSnap.data()?.activeVersionId).trim()
    : "";

  if (activeVersionId) {
    const versionSnap = await admin
      .firestore()
      .collection("pricing_versions")
      .doc(activeVersionId)
      .get();

    if (versionSnap.exists) {
      const data = versionSnap.data() || {};
      const cfg = normalizePricingConfig(data.config || data);
      return {versionId: versionSnap.id, config: cfg};
    }
  }

  // Fallback to in-code defaults.
  return {versionId: "default", config: normalizePricingConfig(defaultPricingConfig())};
}

function resolveRiskBand(input) {
  const raw = coerceString(input).trim();
  const norm = raw.toLowerCase();
  if (["low", "medium", "high", "veryhigh", "very_high", "very-high"].includes(norm)) {
    if (norm === "veryhigh" || norm === "very_high" || norm === "very-high") return "veryHigh";
    return norm;
  }
  // Allow Dart enum values like RiskLevel.high
  if (norm.startsWith("risklevel.")) {
    const tail = norm.split(".").pop();
    return resolveRiskBand(tail);
  }
  return "medium";
}

function isHighCostZipCode(zip) {
  const z = coerceString(zip).trim();
  return z.startsWith("100") || z.startsWith("101") || z.startsWith("102");
}

function getRegionalAdjustment({state, zipCode, regionalAdjustments}) {
  const st = coerceString(state).trim().toUpperCase();
  const zip = coerceString(zipCode).trim();

  if (st && regionalAdjustments[st] !== undefined) {
    return {key: st, multiplier: regionalAdjustments[st]};
  }

  if (isHighCostZipCode(zip) && regionalAdjustments.NY !== undefined) {
    return {key: "NYC_ZIP", multiplier: regionalAdjustments.NY};
  }

  return {
    key: "DEFAULT",
    multiplier:
      regionalAdjustments.DEFAULT !== undefined ? regionalAdjustments.DEFAULT : 1.0,
  };
}

function normalizeZipCode(zipCode) {
  // Accept 5-digit ZIP and ZIP+4, but normalize to first 5 digits.
  const raw = coerceString(zipCode).trim();
  const m = raw.match(/^\s*(\d{5})(?:-\d{4})?\s*$/);
  return m ? m[1] : raw;
}

function resolveCanonicalStateFromZip(zipCode) {
  const zip5 = normalizeZipCode(zipCode);
  const rec = zipcodes.lookup(zip5);
  const st = rec && typeof rec.state === "string" ? rec.state.trim() : "";
  return st ? st.toUpperCase() : "";
}

function normalizeState(state) {
  const st = coerceString(state).trim().toUpperCase();
  return /^[A-Z]{2}$/.test(st) ? st : "";
}

function getMultiPetDiscount({numberOfPets, multiPetDiscounts}) {
  const n = coerceInt(numberOfPets) ?? 1;
  if (n >= 4) return coerceNumber(multiPetDiscounts[4]) ?? 0.0;
  return coerceNumber(multiPetDiscounts[n]) ?? 0.0;
}

function getFactor(map, key, defaultValue = 1.0) {
  if (!map || typeof map !== "object") return defaultValue;
  const v = map[key];
  const n = coerceNumber(v);
  return n ?? defaultValue;
}

function normalizeAnnualLimitKey(limit) {
  if (limit === null || limit === undefined) return "unlimited";
  const n = coerceInt(limit);
  if (n === null) return "unlimited";
  return String(n);
}

function buildPricingBreakdown({
  config,
  riskBand,
  regional,
  basePremium,
  multiPetDiscount,
  reimbursementPercent,
  annualDeductible,
  annualLimit,
  addOns,
}) {
  const riskBandMultiplier = getFactor(config.riskBandMultipliers, riskBand, 1.0);
  const reimbursementFactor = getFactor(
    config.reimbursementFactors,
    String(reimbursementPercent),
    1.0,
  );
  const deductibleFactor = getFactor(
    config.deductibleFactors,
    String(annualDeductible),
    1.0,
  );
  const annualLimitFactor = getFactor(
    config.annualLimitFactors,
    normalizeAnnualLimitKey(annualLimit),
    1.0,
  );

  const premiumBeforeAddOns = basePremium * reimbursementFactor * deductibleFactor * annualLimitFactor;

  const addOnMonthlyLoads = {};
  for (const addOn of addOns) {
    const key = coerceString(addOn).trim();
    addOnMonthlyLoads[key] = getFactor(config.addOnMonthlyLoads, key, 0.0);
  }

  const addOnTotal = Object.values(addOnMonthlyLoads).reduce((sum, v) => sum + (coerceNumber(v) ?? 0.0), 0.0);

  const premiumWithAddOns = premiumBeforeAddOns + addOnTotal;
  const minApplied = premiumWithAddOns < config.minMonthlyPremium;
  const finalMonthlyPremium = minApplied ? config.minMonthlyPremium : premiumWithAddOns;

  return {
    pricingVersion: config.version,
    effectiveDateIso: config.effectiveDateIso,
    baseRiskRate: config.baseRiskRate,
    riskBand,
    riskBandMultiplier,
    regionalMultiplier: regional.multiplier,
    regionalKey: regional.key,
    multiPetDiscount,
    pricingBasePremium: basePremium,
    reimbursementPercent,
    reimbursementFactor,
    annualDeductible,
    deductibleFactor,
    annualLimit: annualLimit === undefined ? null : annualLimit,
    annualLimitFactor,
    requestedReimbursementPercent: null,
    requestedAnnualDeductible: null,
    requestedAnnualLimit: null,
    wasCoerced: false,
    coercionReasons: [],
    addOnMonthlyLoads,
    premiumBeforeAddOns,
    addOnTotal,
    minPremiumApplied: minApplied,
    finalMonthlyPremium,
  };
}

function planLabelForTier(tier) {
  switch (tier) {
    case "basic":
      return "Basic";
    case "standard":
      return "Standard";
    case "plus":
      return "Plus";
    case "premium":
      return "Premium";
    case "unlimited":
      return "Unlimited";
    default:
      return tier;
  }
}

function descriptionForTier(tier) {
  switch (tier) {
    case "basic":
      return "Essential accident + illness coverage";
    case "standard":
      return "Balanced coverage for most pets";
    case "plus":
      return "More protection for higher-cost care";
    case "premium":
      return "High coverage with strong reimbursement";
    case "unlimited":
      return "Unlimited annual coverage for peace of mind";
    default:
      return "";
  }
}

function featuresForTier(tier) {
  // Keep server responses minimal; UI can enrich.
  const base = [
    "Accidents + illnesses",
    "Any licensed vet",
    "Fast claims support",
  ];
  if (tier === "unlimited") return [...base, "Unlimited annual limit"];
  return base;
}

function exclusions() {
  // Mirror ProductCatalog.baseExclusions() as closely as possible without duplicating full catalog.
  return [
    "Pre-existing conditions",
    "Elective procedures",
    "Breeding and pregnancy",
  ];
}

function defaultWaitingPeriodsDays() {
  // Keep aligned with ProductCatalog.defaultWaitingPeriodsDays (client).
  return {
    accident: 3,
    illness: 14,
    orthopedic: 180,
  };
}

function defaultPolicyRules() {
  // Keep aligned with QuoteEngine.buildPlan policyRules (client).
  return {
    orthopedicWaiver: {
      eligible: true,
      requiresVetExam: true,
      noPriorSymptomsRequired: true,
      waivedOrthopedicDays: 30,
    },
    curablePreExisting: {
      supported: true,
      monthsSymptomFreeRequired: 12,
      requiresVetRecords: true,
      chronicAlwaysExcludedExamples: [
        "diabetes",
        "cushing's disease",
        "chronic kidney disease",
        "epilepsy",
      ],
    },
  };
}

exports.getPricingQuotePublic = onCall(
  {
    invoker: "public",
    maxInstances: 10,
    timeoutSeconds: 20,
    memory: "256MiB",
  },
  async (request) => {
    try {
      const data = request.data || {};

      const riskBand = resolveRiskBand(
        data.riskBand ?? data.riskLevel ?? data?.riskScore?.riskLevel,
      );

      const zipCode = normalizeZipCode(data.zipCode);
      const providedState = normalizeState(data.state);
      const numberOfPets = coerceInt(data.numberOfPets) ?? 1;

      if (!zipCode) {
        throw new HttpsError("invalid-argument", "zipCode is required");
      }

      // Carrier-grade: derive rating state/territory authoritatively from ZIP.
      // If lookup fails, fall back to a normalized client state if provided.
      const canonicalStateFromZip = resolveCanonicalStateFromZip(zipCode);
      const canonicalState = canonicalStateFromZip || providedState;
      const stateSource = canonicalStateFromZip ? "zip" : (providedState ? "client" : "unknown");
      const stateMismatch = Boolean(
        canonicalStateFromZip && providedState && canonicalStateFromZip !== providedState,
      );

      if (stateMismatch) {
        logger.info("ZIP/state mismatch on pricing quote", {
          zipCode,
          providedState,
          canonicalState: canonicalStateFromZip,
        });
      }

      const addOns = Array.isArray(data.addOns)
        ? data.addOns.map((v) => coerceString(v)).filter(Boolean)
        : [];

      const {versionId, config} = await loadActivePricingConfig();

      const regional = getRegionalAdjustment({
        state: canonicalState,
        zipCode,
        regionalAdjustments: config.regionalAdjustments,
      });

      // Base premium = base risk rate × risk band × regional × (1 - multi-pet)
      const baseBeforeDiscount =
        config.baseRiskRate *
        getFactor(config.riskBandMultipliers, riskBand, 1.0) *
        regional.multiplier;

      const discount = getMultiPetDiscount({
        numberOfPets,
        multiPetDiscounts: config.multiPetDiscounts,
      });

      const basePremium = baseBeforeDiscount * (1 - discount);

      const dayOneSkus = [
        {tier: "basic", reimb: 70, ded: 500, limit: 10000},
        {tier: "standard", reimb: 80, ded: 250, limit: 10000},
        {tier: "plus", reimb: 80, ded: 250, limit: 20000},
        {tier: "premium", reimb: 90, ded: 250, limit: 20000},
        {tier: "unlimited", reimb: 80, ded: 250, limit: null},
      ];

      const allowedTiers = new Set([
        "basic",
        "standard",
        "plus",
        "premium",
        "unlimited",
      ]);

      const requestedSkus = Array.isArray(data.skus) ? data.skus : null;
      const skus = requestedSkus
        ? requestedSkus
            .map((s) => {
              if (!s || typeof s !== "object") return null;
              const tier = coerceString(s.tier).trim();
              const reimb = coerceInt(s.reimb);
              const ded = coerceInt(s.ded);
              const limit = s.limit === null || s.limit === undefined ? null : coerceInt(s.limit);
              if (!allowedTiers.has(tier)) return null;
              if (reimb === null || ded === null) return null;
              return {tier, reimb, ded, limit: limit === null ? null : limit};
            })
            .filter(Boolean)
        : dayOneSkus;

      const plans = skus.map((sku) => {
        const breakdown = buildPricingBreakdown({
          config,
          riskBand,
          regional,
          basePremium,
          multiPetDiscount: discount,
          reimbursementPercent: sku.reimb,
          annualDeductible: sku.ded,
          annualLimit: sku.limit,
          addOns,
        });

        const isUnlimited = sku.limit === null;
        const maxAnnualCoverage = isUnlimited ? null : sku.limit;

        return {
          type: `PlanType.${sku.tier}`,
          name: planLabelForTier(sku.tier),
          description: descriptionForTier(sku.tier),
          pricingBasePremium: basePremium,
          monthlyPremium: breakdown.finalMonthlyPremium,
          annualDeductible: sku.ded,
          coPayPercentage: 100 - sku.reimb,
          maxAnnualCoverage,
          isUnlimitedAnnualCoverage: isUnlimited,
          maxLifetimeCoverage: null,
          numberOfPets,
          multiPetDiscount: discount,
          reimbursementPercent: sku.reimb,
          selectedAddOns: addOns,
          riskBand,
          pricingBreakdown: breakdown,
          waitingPeriodsDays: defaultWaitingPeriodsDays(),
          policyRules: defaultPolicyRules(),
          features: featuresForTier(sku.tier),
          exclusions: exclusions(),
        };
      });

      return {
        pricingVersionId: versionId,
        pricingVersion: config.version,
        effectiveDateIso: config.effectiveDateIso,
        notes: config.notes,
        canonicalState: canonicalState || null,
        stateSource,
        stateMismatch,
        plans,
      };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      throw new HttpsError(
        "internal",
        `Pricing quote failed: ${e?.message || e}`,
      );
    }
  },
);

exports.upsertPricingVersionAdmin = onCall(
  {
    maxInstances: 10,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request) => {
    const ok = await isAdminCaller(request);
    if (!ok) throw new HttpsError("permission-denied", "Admin only");

    const data = request.data || {};
    const versionId = coerceString(data.versionId).trim();
    const config = data.config;

    if (!versionId) {
      throw new HttpsError("invalid-argument", "versionId is required");
    }

    if (!config || typeof config !== "object") {
      throw new HttpsError("invalid-argument", "config object is required");
    }

    const normalized = normalizePricingConfig(config);

    const uid = request.auth?.uid || null;
    const email = request.auth?.token?.email || null;

    await admin
      .firestore()
      .collection("pricing_versions")
      .doc(versionId)
      .set(
        {
          status: coerceString(data.status || "draft"),
          config: normalized,
          updatedAt: FieldValue.serverTimestamp(),
          updatedByUid: uid,
          updatedByEmail: email,
          createdAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );

    await admin.firestore().collection("pricing_audit").add({
      type: "upsert_pricing_version",
      versionId,
      uid,
      email,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {ok: true, versionId};
  },
);

exports.setActivePricingVersionAdmin = onCall(
  {
    maxInstances: 10,
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request) => {
    const ok = await isAdminCaller(request);
    if (!ok) throw new HttpsError("permission-denied", "Admin only");

    const data = request.data || {};
    const versionId = coerceString(data.versionId).trim();

    if (!versionId) {
      throw new HttpsError("invalid-argument", "versionId is required");
    }

    const versionSnap = await admin
      .firestore()
      .collection("pricing_versions")
      .doc(versionId)
      .get();

    if (!versionSnap.exists) {
      throw new HttpsError("not-found", "pricing version not found");
    }

    const uid = request.auth?.uid || null;
    const email = request.auth?.token?.email || null;

    await admin
      .firestore()
      .collection("pricing_meta")
      .doc("active")
      .set(
        {
          activeVersionId: versionId,
          updatedAt: FieldValue.serverTimestamp(),
          updatedByUid: uid,
          updatedByEmail: email,
        },
        {merge: true},
      );

    await admin.firestore().collection("pricing_audit").add({
      type: "set_active_pricing_version",
      versionId,
      uid,
      email,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {ok: true, activeVersionId: versionId};
  },
);
