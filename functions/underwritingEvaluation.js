/**
 * Public zero-touch underwriting evaluation.
 *
 * This is the JavaScript/Firebase bridge for the rebuilt Next.js quote flow.
 * It intentionally returns deterministic states only:
 * APPROVED, APPROVED_WITH_EXCLUSIONS, NEED_MORE_INFO, DECLINED.
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const {loadUnderwritingRules} = require("./underwritingRulesLoader");

if (!admin.apps.length) admin.initializeApp();

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

function stringList(value) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => coerceString(item)).filter(Boolean);
}

function selectedConditions(quote) {
  return stringList(quote.diagnosedConditions).filter(
    (condition) => condition.toLowerCase() !== "none of these",
  );
}

function ageMonths(quote) {
  const yearsRaw = coerceString(quote.ageYears);
  const monthsRaw = coerceString(quote.ageMonths);
  if (!yearsRaw || !monthsRaw) return null;
  const years = Number(yearsRaw);
  const months = Number(monthsRaw);
  if (!Number.isFinite(years) || !Number.isFinite(months)) return null;
  return Math.trunc(years) * 12 + Math.trunc(months);
}

function weightRange(petType, breedRaw) {
  const breed = normalizeText(breedRaw);
  if (!breed) return null;

  if (breed.includes("mixed small")) return {min: 0, max: 25};
  if (breed.includes("mixed medium")) return {min: 25, max: 55};
  if (breed.includes("mixed large")) return {min: 55, max: 90};
  if (breed.includes("mixed giant")) return {min: 90, max: 200};
  if (breed.includes("mixed") || breed.includes("unknown")) return null;

  if (petType === "cat") {
    if (breed.includes("maine coon")) return {min: 10, max: 25};
    if (breed.includes("ragdoll")) return {min: 10, max: 20};
    if (breed.includes("bengal")) return {min: 8, max: 15};
    if (breed.includes("sphynx")) return {min: 6, max: 12};
    return {min: 7, max: 16};
  }

  const ranges = [
    {terms: ["irish wolfhound"], range: {min: 100, max: 180}},
    {terms: ["great dane"], range: {min: 100, max: 200}},
    {terms: ["mastiff"], range: {min: 120, max: 230}},
    {terms: ["saint bernard"], range: {min: 120, max: 200}},
    {terms: ["newfoundland"], range: {min: 100, max: 150}},
    {terms: ["rottweiler"], range: {min: 80, max: 135}},
    {terms: ["german shepherd"], range: {min: 50, max: 90}},
    {terms: ["golden retriever"], range: {min: 55, max: 85}},
    {terms: ["labrador"], range: {min: 55, max: 90}},
    {terms: ["boxer"], range: {min: 50, max: 80}},
    {terms: ["doberman"], range: {min: 65, max: 100}},
    {terms: ["siberian husky"], range: {min: 35, max: 60}},
    {terms: ["bulldog"], range: {min: 35, max: 55}},
    {terms: ["french bulldog"], range: {min: 16, max: 28}},
    {terms: ["beagle"], range: {min: 18, max: 30}},
    {terms: ["dachshund"], range: {min: 11, max: 32}},
    {terms: ["chihuahua"], range: {min: 3, max: 8}},
    {terms: ["yorkshire"], range: {min: 4, max: 12}},
    {terms: ["poodle"], range: {min: 8, max: 70}},
    {terms: ["shih tzu"], range: {min: 9, max: 16}},
    {terms: ["boston terrier"], range: {min: 12, max: 25}},
  ];

  const match = ranges.find(({terms}) => terms.some((term) => breed.includes(term)));
  return match ? match.range : null;
}

const evidence = {
  medicalHistory: {
    code: "PROVIDE_MEDICAL_HISTORY",
    title: "Upload medical history records",
    details:
      "Upload vet records that list diagnoses, medications, treatments, and relevant lab or imaging results.",
  },
  verifyWeight: {
    code: "VERIFY_WEIGHT",
    title: "Verify current weight",
    details:
      "Upload a recent vet record, invoice, or visit summary showing your pet's weight.",
  },
  verifyBreedSpecies: {
    code: "VERIFY_BREED_SPECIES",
    title: "Verify breed and species",
    details:
      "Upload a record page that clearly shows your pet's name, species, and breed where available.",
  },
  currentSymptoms: {
    code: "CURRENT_SYMPTOMS",
    title: "Clarify current symptoms",
    details:
      "Upload recent visit notes or add clinic details so the system can confirm whether symptoms are pre-existing.",
  },
  medicationHistory: {
    code: "MEDICATION_HISTORY",
    title: "Confirm medication history",
    details:
      "Upload records showing the medication, diagnosis, start date, and whether treatment is ongoing.",
  },
  recentSurgery: {
    code: "RECENT_SURGERY",
    title: "Provide surgery or hospitalization records",
    details:
      "Upload discharge notes or invoices for any surgery or hospital stay in the last 12 months.",
  },
};

function dedupeEvidence(requirements) {
  const byCode = new Map();
  for (const item of requirements) {
    byCode.set(item.code, item);
  }
  return Array.from(byCode.values());
}

function hasVetContext(quote) {
  // Filenames alone are not verifiable evidence. Keep this aligned with the
  // legacy fail-closed rule: only parsed text, document hashes, or structured
  // extraction output can unblock disclosed medical history.
  const hasStructuredVetExtraction =
    quote.aiVetExtraction &&
    typeof quote.aiVetExtraction === "object" &&
    Object.keys(quote.aiVetExtraction).length > 0;
  const hasParsedVetRecords =
    quote.parsedVetRecords &&
    typeof quote.parsedVetRecords === "object" &&
    Object.keys(quote.parsedVetRecords).length > 0;

  return (
    stringList(quote.vetDocumentHashes).length > 0 ||
    stringList(quote.rawVetTexts).length > 0 ||
    hasStructuredVetExtraction ||
    hasParsedVetRecords
  );
}

function declined({reasonCode, body, reasons, fraudSignals = []}) {
  return {
    status: "declined",
    label: "Not eligible",
    body,
    reasonCode,
    reasons,
    exclusions: [],
    requiredEvidence: [],
    pricingEnabled: false,
    integrityPassed: false,
    riskBand: "veryHigh",
    fraudSignals,
  };
}

function needMoreInfo({reasonCode, body, reasons, requiredEvidence, fraudSignals}) {
  return {
    status: "need_more_info",
    label: "More information needed",
    body,
    reasonCode,
    reasons: Array.from(new Set(reasons.length ? reasons : ["Evidence required"])),
    exclusions: [],
    requiredEvidence: dedupeEvidence(requiredEvidence),
    pricingEnabled: false,
    integrityPassed: false,
    riskBand: "medium",
    fraudSignals,
  };
}

function approvedWithExclusions({reasons, exclusions, riskBand = "medium"}) {
  return {
    status: "approved_with_exclusions",
    label: "Approved with exclusions",
    body:
      "This can continue to plan selection with exclusions shown before checkout.",
    reasonCode: "APPROVED_WITH_EXCLUSIONS",
    reasons: Array.from(new Set(reasons.length ? reasons : ["Deterministic approval path"])),
    exclusions: Array.from(new Set(exclusions)),
    requiredEvidence: [],
    pricingEnabled: true,
    integrityPassed: true,
    riskBand,
    fraudSignals: [],
  };
}

function approved() {
  return {
    status: "approved",
    label: "Straight-through approved",
    body:
      "Based on the answers so far, this quote can move directly into plan selection and payment.",
    reasonCode: "APPROVED",
    reasons: ["Clean screening path"],
    exclusions: [],
    requiredEvidence: [],
    pricingEnabled: true,
    integrityPassed: true,
    riskBand: "low",
    fraudSignals: [],
  };
}

function conditionMatches(condition, ruleTerms) {
  const normalized = normalizeText(condition);
  return ruleTerms.some((term) => {
    const t = normalizeText(term);
    return t && (normalized.includes(t) || t.includes(normalized));
  });
}

function evaluateWithRules(quote, rules) {
  const petType = normalizeText(quote.petType);
  const breed = normalizeText(quote.breed);
  const conditions = selectedConditions(quote);
  const age = ageMonths(quote);
  const reasons = [];
  const exclusions = [];
  const requiredEvidence = [];
  const fraudSignals = [];

  const minAgeMonths = Number(rules.minAgeMonths);
  const maxAgeYears = Number(rules.maxAgeYears);
  if (age !== null && Number.isFinite(minAgeMonths) && age < minAgeMonths) {
    return declined({
      reasonCode: "MIN_AGE_MONTHS",
      body: `Pets must be at least ${minAgeMonths} months old before a new policy can be bound.`,
      reasons: ["Minimum enrollment age not met"],
    });
  }

  if (age !== null && Number.isFinite(maxAgeYears) && age > maxAgeYears * 12) {
    return declined({
      reasonCode: "MAX_AGE_YEARS",
      body: "This pet is above the current maximum age for a new policy.",
      reasons: ["Maximum enrollment age exceeded"],
    });
  }

  const excludedBreed = stringList(rules.excludedBreeds).find((term) =>
    breed.includes(normalizeText(term)),
  );
  if (excludedBreed) {
    return declined({
      reasonCode: "EXCLUDED_BREED",
      body:
        "This breed is not eligible under the current underwriting rules. The decision is automatic and no payment is collected.",
      reasons: [`Breed rule matched: ${quote.breed}`],
    });
  }

  if (
    petType === "cat" &&
    ["retriever", "bulldog", "shepherd", "terrier", "poodle", "rottweiler", "husky", "dachshund"]
      .some((term) => breed.includes(term))
  ) {
    fraudSignals.push({
      code: "BREED_SPECIES_CONFLICT",
      label: "Breed/species conflict",
      severity: "high",
    });
    requiredEvidence.push(evidence.verifyBreedSpecies);
  }

  const details = normalizeText(quote.conditionDetails);
  const criticalTerms = stringList(rules.criticalConditions);
  const criticalByCondition = conditions.find((condition) =>
    conditionMatches(condition, criticalTerms),
  );
  const criticalByDetails = criticalTerms.find((term) =>
    details.includes(normalizeText(term)),
  );

  if (criticalByDetails || (criticalByCondition && hasVetContext(quote))) {
    return declined({
      reasonCode: "CRITICAL_CONDITION",
      body:
        "The medical details match a condition that cannot be offered a new policy under the current rules.",
      reasons: ["Critical medical rule matched"],
    });
  }

  const range = weightRange(petType, quote.breed);
  const weight = Number(coerceString(quote.weightLbs));
  if (Number.isFinite(weight) && weight > 0 && range) {
    if (weight > range.max * 1.6 || weight < Math.max(1, range.min * 0.45)) {
      fraudSignals.push({
        code: "WEIGHT_OUTLIER_CRITICAL",
        label: "Weight is far outside expected range",
        severity: "critical",
      });
      requiredEvidence.push(evidence.verifyWeight);
    } else if (weight > range.max * 1.15 || weight < Math.max(1, range.min * 0.7)) {
      reasons.push("Weight is outside the typical breed range");
      exclusions.push("Weight-related orthopedic conditions");
      requiredEvidence.push(evidence.verifyWeight);
    }
  }

  if (quote.bodyCondition === "overweight") {
    reasons.push("Overweight body condition disclosed");
    exclusions.push("Weight-related orthopedic conditions");
  }

  if (conditions.length > 0) {
    reasons.push("Medical history disclosed");
    requiredEvidence.push(evidence.medicalHistory);
  }

  if (quote.currentSymptoms === "yes") {
    reasons.push("Current symptoms reported");
    requiredEvidence.push(evidence.currentSymptoms);
  }

  if (quote.medication === "yes") {
    reasons.push("Ongoing medication disclosed");
    requiredEvidence.push(evidence.medicationHistory);
  }

  if (quote.recentSurgery === "yes") {
    reasons.push("Recent surgery or hospital stay reported");
    requiredEvidence.push(evidence.recentSurgery);
  }

  if (fraudSignals.some((signal) => signal.severity === "critical")) {
    return needMoreInfo({
      reasonCode: "INTEGRITY_CHECKS_REQUIRED",
      body:
        "We need to verify a conflicting or unusual detail before pricing can be shown. This is a self-serve evidence step that reruns automatically once resolved.",
      reasons,
      requiredEvidence,
      fraudSignals,
    });
  }

  // Match the legacy invariant: disclosed conditions need verifiable vet context
  // before pricing can be shown.
  if (conditions.length > 0 && !hasVetContext(quote)) {
    return needMoreInfo({
      reasonCode: "VET_RECORDS_REQUIRED",
      body:
        "We need verifiable vet records before pricing can be shown. Once records are available, the system can rerun the decision automatically.",
      reasons,
      requiredEvidence,
      fraudSignals,
    });
  }

  if (requiredEvidence.length > 0) {
    return needMoreInfo({
      reasonCode: "VERIFY_INTAKE",
      body:
        "We need verifiable evidence before pricing can be shown. Upload the requested records and the automated checks can rerun.",
      reasons,
      requiredEvidence,
      fraudSignals,
    });
  }

  const excludableTerms = stringList(rules.excludableConditions);
  const excludableConditions = conditions.filter((condition) =>
    conditionMatches(condition, excludableTerms),
  );
  if (excludableConditions.length > 0 || exclusions.length > 0) {
    return approvedWithExclusions({
      reasons,
      exclusions: [...excludableConditions, ...exclusions],
      riskBand: "medium",
    });
  }

  return approved();
}

async function evaluateUnderwritingQuote(quote) {
  const loaded = await loadUnderwritingRules({cache: true});
  if (!loaded.ok) {
    logger.error("Underwriting rules unavailable during public evaluation", {
      errorCode: loaded.errorCode,
    });
    return declined({
      reasonCode: "RULES_UNAVAILABLE",
      body:
        "Underwriting rules are unavailable, so the system cannot offer coverage right now.",
      reasons: ["Rules unavailable"],
    });
  }

  return evaluateWithRules(quote, loaded.rules);
}

exports.evaluateUnderwritingQuote = evaluateUnderwritingQuote;

exports.evaluateUnderwritingPublic = onCall(
  {
    invoker: "public",
    maxInstances: 10,
    timeoutSeconds: 20,
    memory: "256MiB",
  },
  async (request) => {
    try {
      const quote = request.data?.quote;
      if (!quote || typeof quote !== "object" || Array.isArray(quote)) {
        throw new HttpsError("invalid-argument", "quote object is required");
      }

      return evaluateUnderwritingQuote(quote);
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      logger.error("evaluateUnderwritingPublic failed", {
        error: error?.message || String(error),
      });
      throw new HttpsError(
        "internal",
        `Underwriting evaluation failed: ${error?.message || error}`,
      );
    }
  },
);
