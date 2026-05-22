import type { Plan, QuoteData, VetRecordUpload } from "@/types";
import type { QuoteDecision } from "@/lib/underwriting/quoteDecision";

export type NoTouchAction =
  | "start_payment"
  | "submit_evidence"
  | "record_decline";

export interface NoTouchQuoteResult {
  ok: boolean;
  caseId: string;
  decision: QuoteDecision;
  pricing: {
    status: "priced" | "blocked";
    monthlyPremium?: number;
    reason?: string;
  };
  payment: {
    status:
      | "checkout_created"
      | "configuration_required"
      | "blocked"
      | "not_requested";
    reason?: string;
    policyId?: string;
    checkoutSessionId?: string;
    checkoutUrl?: string;
    monthlyPremium?: number;
  };
  evidence: {
    uploaded: Array<{
      fileName: string;
      contentType: string;
      documentHash: string;
      sizeBytes: number;
      extractionStatus: string;
    }>;
    rawTextCount: number;
    documentHashes: string[];
  };
  noHumanTouch: boolean;
}

const noTouchEndpoint =
  process.env.NEXT_PUBLIC_NO_TOUCH_QUOTE_URL ||
  "https://us-central1-pet-underwriter-ai.cloudfunctions.net/submitNoTouchQuotePublic";

export async function submitNoTouchQuote({
  formData,
  selectedPlan,
  estimatedMonthly,
  action
}: {
  formData: QuoteData;
  selectedPlan: Plan | null | undefined;
  estimatedMonthly: number | null;
  action: NoTouchAction;
}) {
  const response = await fetch(noTouchEndpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      data: {
        caseId: formData.quoteCaseId || undefined,
        action,
        quote: buildQuotePayload(formData),
        contact: {
          firstName: formData.firstName,
          lastName: formData.lastName,
          email: formData.email,
          zipCode: formData.zipCode
        },
        selectedPlan,
        selectedOptions: {
          plan: formData.plan,
          deductible: formData.deductible,
          reimbursement: formData.reimbursement,
          annualLimit: formData.annualLimit,
          riders: formData.riders,
          estimatedMonthly
        },
        evidenceUploads: formData.vetRecordUploads
      }
    })
  });

  if (!response.ok) {
    const detail = await readNoTouchError(response);
    throw new Error(
      `No-touch quote function returned ${response.status}${detail ? `: ${detail}` : ""}`
    );
  }

  const payload: unknown = await response.json();
  const result = unwrapCallableResult(payload);
  if (!isNoTouchQuoteResult(result)) {
    throw new Error("No-touch quote function returned an invalid response");
  }

  return result;
}

export async function filesToVetRecordUploads(files: File[]) {
  const uploads: VetRecordUpload[] = [];

  for (const file of files.slice(0, 6)) {
    if (file.size > 8 * 1024 * 1024) {
      throw new Error(`${file.name} is too large. Upload files under 8 MB.`);
    }

    uploads.push({
      fileName: file.name,
      contentType: file.type || "application/octet-stream",
      sizeBytes: file.size,
      base64: await readFileAsBase64(file)
    });
  }

  return uploads;
}

function readFileAsBase64(file: File) {
  return new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const value = reader.result;
      if (typeof value !== "string") {
        reject(new Error(`Unable to read ${file.name}`));
        return;
      }
      resolve(value.split(",")[1] ?? value);
    };
    reader.onerror = () => reject(reader.error ?? new Error(`Unable to read ${file.name}`));
    reader.readAsDataURL(file);
  });
}

function buildQuotePayload(formData: QuoteData) {
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

function unwrapCallableResult(payload: unknown) {
  if (!isRecord(payload)) return payload;
  if ("result" in payload) return payload.result;
  if ("data" in payload) return payload.data;
  return payload;
}

async function readNoTouchError(response: Response) {
  try {
    const payload: unknown = await response.json();
    if (!isRecord(payload)) return "";

    const error = payload.error;
    if (isRecord(error)) {
      const message = typeof error.message === "string" ? error.message : "";
      const status = typeof error.status === "string" ? error.status : "";
      return [status, message].filter(Boolean).join(" - ");
    }

    const message = payload.message;
    return typeof message === "string" ? message : "";
  } catch {
    return "";
  }
}

function isNoTouchQuoteResult(value: unknown): value is NoTouchQuoteResult {
  return (
    isRecord(value) &&
    typeof value.ok === "boolean" &&
    typeof value.caseId === "string" &&
    isRecord(value.decision) &&
    isRecord(value.pricing) &&
    isRecord(value.payment) &&
    isRecord(value.evidence)
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
