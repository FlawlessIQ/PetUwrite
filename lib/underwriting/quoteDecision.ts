import type { PetType, QuoteData } from "@/types";

export type QuoteDecisionStatus =
  | "approved"
  | "approved_with_exclusions"
  | "need_more_info"
  | "declined";

export interface EvidenceRequirement {
  code: string;
  title: string;
  details: string;
}

export interface UnderwritingSignal {
  code: string;
  label: string;
  severity: "low" | "medium" | "high" | "critical";
}

export interface QuoteDecision {
  status: QuoteDecisionStatus;
  label: string;
  body: string;
  reasonCode: string;
  reasons: string[];
  exclusions: string[];
  requiredEvidence: EvidenceRequirement[];
  pricingEnabled: boolean;
  integrityPassed: boolean;
  riskBand: "low" | "medium" | "high" | "veryHigh";
  fraudSignals: UnderwritingSignal[];
  source: "remote" | "local";
}

interface WeightRange {
  min: number;
  max: number;
}

const underwritingEndpoint =
  process.env.NEXT_PUBLIC_UNDERWRITING_EVALUATION_URL ||
  "https://us-central1-pet-underwriter-ai.cloudfunctions.net/evaluateUnderwritingPublic";

const noConditions = "None of these";

const excludedBreedTerms = [
  "american pit bull terrier",
  "american staffordshire terrier",
  "american bully",
  "dogo argentino",
  "presa canario",
  "cane corso",
  "staffordshire bull terrier",
  "wolf dog",
  "wolf hybrid",
  "wolfdog"
];

const criticalDetailPatterns = [
  "active cancer",
  "metastatic",
  "malignant",
  "terminal",
  "congestive heart failure",
  "heart failure",
  "end stage kidney",
  "ckd stage 3",
  "ckd stage 4",
  "ckd stage 5",
  "iris stage 3",
  "iris stage 4",
  "iris stage 5"
];

export async function evaluateQuoteDecision(
  formData: QuoteData
): Promise<QuoteDecision> {
  try {
    const response = await fetch(underwritingEndpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        data: { quote: buildEvaluationPayload(formData) }
      })
    });

    if (!response.ok) {
      throw new Error(`Underwriting function returned ${response.status}`);
    }

    const payload: unknown = await response.json();
    const result = unwrapCallableResult(payload);
    const normalized = normalizeRemoteDecision(result);
    if (normalized) return normalized;
  } catch (error) {
    console.warn(
      "[Underwriting] Remote evaluation unavailable; using local deterministic fallback.",
      error
    );
  }

  return evaluateQuoteDecisionLocally(formData);
}

export function evaluateQuoteDecisionLocally(
  formData: QuoteData
): QuoteDecision {
  const selectedConditions = selectedMedicalConditions(formData);
  const ageMonths = calculateAgeMonths(formData);
  const normalizedBreed = normalizeText(formData.breed);
  const range = expectedWeightRange(formData.petType, formData.breed);
  const weight = Number(formData.weightLbs);
  const reasons: string[] = [];
  const exclusions: string[] = [];
  const requiredEvidence: EvidenceRequirement[] = [];
  const fraudSignals: UnderwritingSignal[] = [];

  if (ageMonths !== null && ageMonths < 2) {
    return declinedDecision({
      reasonCode: "MIN_AGE_MONTHS",
      body: "Pets must be at least 2 months old before a new policy can be bound.",
      reasons: ["Minimum enrollment age not met"],
      fraudSignals
    });
  }

  if (ageMonths !== null && ageMonths > 14 * 12) {
    return declinedDecision({
      reasonCode: "MAX_AGE_YEARS",
      body: "This pet is above the current maximum age for a new policy.",
      reasons: ["Maximum enrollment age exceeded"],
      fraudSignals
    });
  }

  const excludedBreed = excludedBreedTerms.find((term) =>
    normalizedBreed.includes(term)
  );
  if (excludedBreed) {
    return declinedDecision({
      reasonCode: "EXCLUDED_BREED",
      body: "This breed is not eligible under the current underwriting rules. The decision is automatic and no payment is collected.",
      reasons: [`Breed rule matched: ${formData.breed}`],
      fraudSignals
    });
  }

  const detailText = normalizeText(formData.conditionDetails);
  const criticalDetail = criticalDetailPatterns.find((pattern) =>
    detailText.includes(pattern)
  );
  if (criticalDetail) {
    return declinedDecision({
      reasonCode: "DETERMINISTIC_CRITICAL_CONDITION",
      body: "The medical details match a condition that cannot be offered a new policy under the current rules.",
      reasons: ["Critical medical rule matched"],
      fraudSignals
    });
  }

  if (
    formData.petType === "cat" &&
    [
      "retriever",
      "bulldog",
      "shepherd",
      "terrier",
      "poodle",
      "rottweiler",
      "husky",
      "dachshund"
    ].some((term) => normalizedBreed.includes(term))
  ) {
    fraudSignals.push({
      code: "BREED_SPECIES_CONFLICT",
      label: "Breed/species conflict",
      severity: "high"
    });
    requiredEvidence.push(evidence.verifyBreedSpecies);
  }

  if (Number.isFinite(weight) && weight > 0 && range) {
    if (weight > range.max * 1.6 || weight < Math.max(1, range.min * 0.45)) {
      fraudSignals.push({
        code: "WEIGHT_OUTLIER_CRITICAL",
        label: "Weight is far outside expected range",
        severity: "critical"
      });
      requiredEvidence.push(evidence.verifyWeight);
    } else if (
      weight > range.max * 1.15 ||
      weight < Math.max(1, range.min * 0.7)
    ) {
      reasons.push("Weight is outside the typical breed range");
      exclusions.push("Weight-related orthopedic conditions");
      requiredEvidence.push(evidence.verifyWeight);
    }
  }

  if (formData.bodyCondition === "overweight") {
    reasons.push("Overweight body condition disclosed");
    exclusions.push("Weight-related orthopedic conditions");
  }

  if (selectedConditions.length > 0) {
    reasons.push("Medical history disclosed");
    requiredEvidence.push(evidence.provideMedicalHistory);
  }

  if (formData.currentSymptoms === "yes") {
    reasons.push("Current symptoms reported");
    requiredEvidence.push(evidence.currentSymptoms);
  }

  if (formData.medication === "yes") {
    reasons.push("Ongoing medication disclosed");
    requiredEvidence.push(evidence.medicationHistory);
  }

  if (formData.recentSurgery === "yes") {
    reasons.push("Recent surgery or hospital stay reported");
    requiredEvidence.push(evidence.recentSurgery);
  }

  if (formData.vetRecords === "no" && selectedConditions.length > 0) {
    reasons.push("Vet records are not available yet");
    requiredEvidence.push(evidence.provideMedicalHistory);
  }

  if (fraudSignals.some((signal) => signal.severity === "critical")) {
    return needMoreInfoDecision({
      reasonCode: "INTEGRITY_CHECKS_REQUIRED",
      body: "We need to verify a detail before we can show a reliable monthly price. Upload records or provide clinic details to continue underwriting.",
      reasons,
      requiredEvidence,
      fraudSignals
    });
  }

  if (requiredEvidence.length > 0) {
    return needMoreInfoDecision({
      reasonCode:
        selectedConditions.length > 0
          ? "VET_RECORDS_REQUIRED"
          : "VERIFY_INTAKE",
      body: "We need records or clinic details before pricing can be shown. Once the information is available, underwriting can rerun the decision.",
      reasons,
      requiredEvidence,
      fraudSignals
    });
  }

  if (exclusions.length > 0) {
    return {
      status: "approved_with_exclusions",
      label: "Approved with exclusions",
      body: "This application can continue to plan selection. Any exclusions will be shown and must be acknowledged before payment.",
      reasonCode: "APPROVED_WITH_EXCLUSIONS",
      reasons: reasons.length ? reasons : ["Deterministic approval path"],
      exclusions: Array.from(new Set(exclusions)),
      requiredEvidence: [],
      pricingEnabled: true,
      integrityPassed: true,
      riskBand: "medium",
      fraudSignals,
      source: "local"
    };
  }

  return {
    status: "approved",
    label: "Straight-through approved",
    body: "Based on the information provided, this application can continue to plan selection and secure checkout.",
    reasonCode: "APPROVED",
    reasons: ["Clean screening path"],
    exclusions: [],
    requiredEvidence: [],
    pricingEnabled: true,
    integrityPassed: true,
    riskBand: "low",
    fraudSignals,
    source: "local"
  };
}

export function selectedMedicalConditions(formData: QuoteData) {
  return formData.diagnosedConditions.filter(
    (condition) => condition !== noConditions
  );
}

export function weightAssessment(formData: QuoteData) {
  const weight = Number(formData.weightLbs);
  const range = expectedWeightRange(formData.petType, formData.breed);

  if (!formData.weightLbs || Number.isNaN(weight) || weight <= 0) {
    return null;
  }

  if (formData.bodyCondition === "overweight") {
    return {
      status: "review" as const,
      message:
        "Weight risk noted: the body condition selected may affect pricing or eligibility."
    };
  }

  if (!range) {
    return {
      status: "unknown" as const,
      message:
        "Weight captured. We will use breed and age to refine the estimate."
    };
  }

  if (weight > range.max * 1.15) {
    return {
      status: "review" as const,
      message: `Weight is above the expected ${range.min}-${range.max} lb range for this breed.`
    };
  }

  if (weight < range.min * 0.7) {
    return {
      status: "review" as const,
      message: `Weight is below the expected ${range.min}-${range.max} lb range, so we may ask a follow-up.`
    };
  }

  return {
    status: "ok" as const,
    message: `Weight is within the expected ${range.min}-${range.max} lb adult range.`
  };
}

function buildEvaluationPayload(formData: QuoteData) {
  return {
    petType: formData.petType,
    petName: formData.petName,
    breed: formData.breed,
    weightLbs: formData.weightLbs,
    ageYears: formData.ageYears,
    ageMonths: formData.ageMonths,
    sex: formData.sex,
    altered: formData.altered,
    bodyCondition: formData.bodyCondition,
    diagnosedConditions: formData.diagnosedConditions,
    currentSymptoms: formData.currentSymptoms,
    medication: formData.medication,
    recentSurgery: formData.recentSurgery,
    vetRecords: formData.vetRecords,
    conditionDetails: formData.conditionDetails,
    vetClinicName: formData.vetClinicName,
    vetClinicPhone: formData.vetClinicPhone,
    vetRecordFileNames: formData.vetRecordFileNames,
    zipCode: formData.zipCode
  };
}

function normalizeRemoteDecision(value: unknown): QuoteDecision | null {
  if (!isRecord(value)) return null;

  const status = parseStatus(value.status);
  if (!status) return null;

  return {
    status,
    label: readString(value.label, labelForStatus(status)),
    body: readString(value.body, bodyForStatus(status)),
    reasonCode: readString(value.reasonCode, status.toUpperCase()),
    reasons: readStringArray(value.reasons),
    exclusions: readStringArray(value.exclusions),
    requiredEvidence: readEvidenceList(value.requiredEvidence),
    pricingEnabled: value.pricingEnabled === true,
    integrityPassed: value.integrityPassed === true,
    riskBand: parseRiskBand(value.riskBand),
    fraudSignals: readSignalList(value.fraudSignals),
    source: "remote"
  };
}

function unwrapCallableResult(payload: unknown) {
  if (!isRecord(payload)) return payload;
  if ("result" in payload) return payload.result;
  if ("data" in payload) return payload.data;
  return payload;
}

function parseStatus(value: unknown): QuoteDecisionStatus | null {
  const raw = String(value ?? "")
    .trim()
    .toLowerCase();
  if (raw === "approved" || raw === "straight") return "approved";
  if (raw === "approved_with_exclusions" || raw === "conditional") {
    return "approved_with_exclusions";
  }
  if (raw === "need_more_info" || raw === "needmoreinfo" || raw === "review") {
    return "need_more_info";
  }
  if (raw === "declined" || raw === "denied") return "declined";
  return null;
}

function parseRiskBand(value: unknown): QuoteDecision["riskBand"] {
  const raw = String(value ?? "")
    .trim()
    .toLowerCase();
  if (raw === "low" || raw === "medium" || raw === "high") return raw;
  if (raw === "veryhigh" || raw === "very_high" || raw === "very-high") {
    return "veryHigh";
  }
  return "medium";
}

function readString(value: unknown, fallback: string) {
  return typeof value === "string" && value.trim() ? value : fallback;
}

function readStringArray(value: unknown) {
  return Array.isArray(value)
    ? value.map((item) => String(item)).filter((item) => item.trim())
    : [];
}

function readEvidenceList(value: unknown): EvidenceRequirement[] {
  if (!Array.isArray(value)) return [];
  return value.filter(isRecord).map((item) => ({
    code: readString(item.code, "PROVIDE_EVIDENCE"),
    title: readString(item.title, "Provide evidence"),
    details: readString(
      item.details,
      "Upload records so we can complete the automated decision."
    )
  }));
}

function readSignalList(value: unknown): UnderwritingSignal[] {
  if (!Array.isArray(value)) return [];
  return value.filter(isRecord).map((item) => ({
    code: readString(item.code, "INTEGRITY_SIGNAL"),
    label: readString(item.label, "Integrity signal"),
    severity: parseSeverity(item.severity)
  }));
}

function parseSeverity(value: unknown): UnderwritingSignal["severity"] {
  const raw = String(value ?? "")
    .trim()
    .toLowerCase();
  if (
    raw === "low" ||
    raw === "medium" ||
    raw === "high" ||
    raw === "critical"
  ) {
    return raw;
  }
  return "medium";
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function needMoreInfoDecision({
  reasonCode,
  body,
  reasons,
  requiredEvidence,
  fraudSignals
}: {
  reasonCode: string;
  body: string;
  reasons: string[];
  requiredEvidence: EvidenceRequirement[];
  fraudSignals: UnderwritingSignal[];
}): QuoteDecision {
  return {
    status: "need_more_info",
    label: "More information needed",
    body,
    reasonCode,
    reasons: reasons.length
      ? Array.from(new Set(reasons))
      : ["Evidence required"],
    exclusions: [],
    requiredEvidence: dedupeEvidence(requiredEvidence),
    pricingEnabled: false,
    integrityPassed: false,
    riskBand: "medium",
    fraudSignals,
    source: "local"
  };
}

function declinedDecision({
  reasonCode,
  body,
  reasons,
  fraudSignals
}: {
  reasonCode: string;
  body: string;
  reasons: string[];
  fraudSignals: UnderwritingSignal[];
}): QuoteDecision {
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
    source: "local"
  };
}

function dedupeEvidence(requirements: EvidenceRequirement[]) {
  const byCode = new Map<string, EvidenceRequirement>();
  for (const requirement of requirements) {
    byCode.set(requirement.code, requirement);
  }
  return Array.from(byCode.values());
}

function calculateAgeMonths(formData: QuoteData) {
  if (!formData.ageYears || !formData.ageMonths) return null;
  const years = Number(formData.ageYears);
  const months = Number(formData.ageMonths);
  if (!Number.isFinite(years) || !Number.isFinite(months)) return null;
  return years * 12 + months;
}

function labelForStatus(status: QuoteDecisionStatus) {
  if (status === "approved") return "Straight-through approved";
  if (status === "approved_with_exclusions") return "Approved with exclusions";
  if (status === "declined") return "Not eligible";
  return "More information needed";
}

function bodyForStatus(status: QuoteDecisionStatus) {
  if (status === "approved") {
    return "This quote can move directly into plan selection and payment.";
  }
  if (status === "approved_with_exclusions") {
    return "This quote can move forward with exclusions shown before checkout.";
  }
  if (status === "declined") {
    return "This application is not eligible under the current underwriting rules.";
  }
  return "We need records or clinic details before pricing can be shown.";
}

const evidence = {
  provideMedicalHistory: {
    code: "PROVIDE_MEDICAL_HISTORY",
    title: "Upload medical history records",
    details:
      "Upload vet records that list diagnoses, medications, treatments, and relevant lab or imaging results."
  },
  verifyWeight: {
    code: "VERIFY_WEIGHT",
    title: "Verify current weight",
    details:
      "Upload a recent vet record, invoice, or visit summary showing your pet's weight."
  },
  verifyBreedSpecies: {
    code: "VERIFY_BREED_SPECIES",
    title: "Verify breed and species",
    details:
      "Upload a record page that clearly shows your pet's name, species, and breed where available."
  },
  currentSymptoms: {
    code: "CURRENT_SYMPTOMS",
    title: "Clarify current symptoms",
    details:
      "Upload recent visit notes or add clinic details so the system can confirm whether symptoms are pre-existing."
  },
  medicationHistory: {
    code: "MEDICATION_HISTORY",
    title: "Confirm medication history",
    details:
      "Upload records showing the medication, diagnosis, start date, and whether treatment is ongoing."
  },
  recentSurgery: {
    code: "RECENT_SURGERY",
    title: "Provide surgery or hospitalization records",
    details:
      "Upload discharge notes or invoices for any surgery or hospital stay in the last 12 months."
  }
} satisfies Record<string, EvidenceRequirement>;

function expectedWeightRange(
  petType: PetType | "",
  breedRaw: string
): WeightRange | null {
  const breed = normalizeText(breedRaw);

  if (!breed) return null;

  if (breed.includes("mixed small")) return { min: 0, max: 25 };
  if (breed.includes("mixed medium")) return { min: 25, max: 55 };
  if (breed.includes("mixed large")) return { min: 55, max: 90 };
  if (breed.includes("mixed giant")) return { min: 90, max: 200 };
  if (breed.includes("mixed") || breed.includes("unknown")) return null;

  if (petType === "cat") {
    if (breed.includes("maine coon")) return { min: 10, max: 25 };
    if (breed.includes("ragdoll")) return { min: 10, max: 20 };
    if (breed.includes("bengal")) return { min: 8, max: 15 };
    if (breed.includes("sphynx")) return { min: 6, max: 12 };
    return { min: 7, max: 16 };
  }

  const ranges: Array<{ terms: string[]; range: WeightRange }> = [
    { terms: ["irish wolfhound"], range: { min: 100, max: 180 } },
    { terms: ["great dane"], range: { min: 100, max: 200 } },
    { terms: ["mastiff"], range: { min: 120, max: 230 } },
    { terms: ["saint bernard"], range: { min: 120, max: 200 } },
    { terms: ["newfoundland"], range: { min: 100, max: 150 } },
    { terms: ["rottweiler"], range: { min: 80, max: 135 } },
    { terms: ["german shepherd"], range: { min: 50, max: 90 } },
    { terms: ["golden retriever"], range: { min: 55, max: 85 } },
    { terms: ["labrador"], range: { min: 55, max: 90 } },
    { terms: ["boxer"], range: { min: 50, max: 80 } },
    { terms: ["doberman"], range: { min: 65, max: 100 } },
    { terms: ["siberian husky"], range: { min: 35, max: 60 } },
    { terms: ["bulldog"], range: { min: 35, max: 55 } },
    { terms: ["french bulldog"], range: { min: 16, max: 28 } },
    { terms: ["beagle"], range: { min: 18, max: 30 } },
    { terms: ["dachshund"], range: { min: 11, max: 32 } },
    { terms: ["chihuahua"], range: { min: 3, max: 8 } },
    { terms: ["yorkshire"], range: { min: 4, max: 12 } },
    { terms: ["poodle"], range: { min: 8, max: 70 } },
    { terms: ["shih tzu"], range: { min: 9, max: 16 } },
    { terms: ["boston terrier"], range: { min: 12, max: 25 } }
  ];

  const match = ranges.find(({ terms }) =>
    terms.some((term) => breed.includes(term))
  );

  return match?.range ?? null;
}

function normalizeText(value: string) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}
