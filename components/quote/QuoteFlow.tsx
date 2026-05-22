"use client";

import { AnimatePresence, motion } from "framer-motion";
import type { ReactNode } from "react";
import { useEffect, useMemo, useState } from "react";
import { catBreeds, dogBreeds, plans, quoteRiders } from "@/data/site";
import { track } from "@/hooks/useAnalytics";
import type {
  AnnualLimitOption,
  BodyCondition,
  DeductibleOption,
  PetType,
  PlanId,
  QuoteData,
  QuoteErrors,
  ReimbursementOption,
  RiderId,
  YesNoAnswer
} from "@/types";
import {
  CatIllustration,
  DogIllustration
} from "@/components/shared/SpeciesIllustrations";
import type {
  QuoteDecision,
  QuoteDecisionStatus
} from "@/lib/underwriting/quoteDecision";
import {
  evaluateQuoteDecision,
  evaluateQuoteDecisionLocally,
  weightAssessment
} from "@/lib/underwriting/quoteDecision";
import type { NoTouchQuoteResult } from "@/lib/underwriting/noTouchQuote";
import {
  filesToVetRecordUploads,
  submitNoTouchQuote
} from "@/lib/underwriting/noTouchQuote";

type QuoteStep = 1 | 2 | 3 | 4 | 5 | 6;
type UpdateQuoteField = <K extends keyof QuoteData>(
  name: K,
  value: QuoteData[K]
) => void;

type ScreeningStatus = QuoteDecisionStatus;
type ScreeningResult = QuoteDecision;

interface FinalStepContent {
  eyebrow: string;
  title: string;
  body: string;
  consentLabel: string;
  cta: string;
  event: string;
  confirmationTitle: string;
  confirmationBody: string;
}

const noConditions = "None of these";
const totalSteps = 6;

const initialData: QuoteData = {
  quoteCaseId: "",
  petType: "",
  petName: "",
  breed: "",
  weightLbs: "",
  ageYears: "",
  ageMonths: "",
  sex: "",
  altered: "",
  bodyCondition: "",
  diagnosedConditions: [],
  currentSymptoms: "",
  medication: "",
  recentSurgery: "",
  vetRecords: "",
  plan: "",
  deductible: "250",
  reimbursement: "80",
  annualLimit: "20000",
  riders: [],
  conditionDetails: "",
  vetClinicName: "",
  vetClinicPhone: "",
  vetRecordFileNames: [],
  vetRecordUploads: [],
  exclusionAcknowledged: false,
  firstName: "",
  lastName: "",
  email: "",
  zipCode: "",
  consent: false
};

const stepVariants = {
  initial: { x: 40, opacity: 0 },
  animate: { x: 0, opacity: 1 },
  exit: { x: -40, opacity: 0 }
};

const conditionOptions = [
  noConditions,
  "Allergies / skin condition",
  "Ear infections",
  "Digestive issues",
  "Arthritis or joint pain",
  "Hip dysplasia",
  "Cruciate ligament injury",
  "Diabetes",
  "Heart disease",
  "Kidney or urinary disease",
  "Cancer history",
  "Seizures",
  "Other condition"
];

const basePrices: Record<PlanId, number> = {
  essential: 34,
  comprehensive: 49,
  premium: 68
};

const deductibleAdjustments: Record<DeductibleOption, number> = {
  "100": 12,
  "250": 0,
  "500": -8
};

const reimbursementAdjustments: Record<ReimbursementOption, number> = {
  "70": -7,
  "80": 0,
  "90": 10
};

const annualLimitAdjustments: Record<AnnualLimitOption, number> = {
  "10000": -5,
  "20000": 0,
  unlimited: 14
};

const stepNames: Record<QuoteStep, string> = {
  1: "Pet",
  2: "Details",
  3: "Screening",
  4: "Plans",
  5: "Options",
  6: "Finalize"
};

const underwritingFields: Array<keyof QuoteData> = [
  "petType",
  "petName",
  "breed",
  "weightLbs",
  "ageYears",
  "ageMonths",
  "sex",
  "altered",
  "bodyCondition",
  "diagnosedConditions",
  "currentSymptoms",
  "medication",
  "recentSurgery",
  "vetRecords",
  "conditionDetails",
  "vetClinicName",
  "vetClinicPhone",
  "vetRecordFileNames",
  "vetRecordUploads"
];

export function QuoteFlow() {
  const [currentStep, setCurrentStep] = useState<QuoteStep>(1);
  const [formData, setFormData] = useState<QuoteData>(initialData);
  const [errors, setErrors] = useState<QuoteErrors>({});
  const [planError, setPlanError] = useState("");
  const [submitted, setSubmitted] = useState(false);
  const [isEvaluating, setIsEvaluating] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submissionResult, setSubmissionResult] =
    useState<NoTouchQuoteResult | null>(null);
  const [submissionError, setSubmissionError] = useState("");
  const [decisionResult, setDecisionResult] = useState<QuoteDecision | null>(
    null
  );

  useEffect(() => {
    track("quote_started");
  }, []);

  const availableBreeds = useMemo(() => {
    const breeds = formData.petType === "cat" ? catBreeds : dogBreeds;
    return Array.from(new Set(breeds));
  }, [formData.petType]);

  const localScreeningResult = useMemo(
    () => evaluateQuoteDecisionLocally(formData),
    [formData]
  );
  const screeningResult = decisionResult ?? localScreeningResult;

  const selectedPlan = plans.find((plan) => plan.id === formData.plan);
  const estimatedMonthly = estimateMonthly(formData, screeningResult.status);
  const finalStepContent = getFinalStepContent(
    screeningResult.status,
    estimatedMonthly
  );
  const progress = submitted ? 100 : (currentStep / totalSteps) * 100;

  const petSummary = useMemo(() => {
    const name = formData.petName || "Your pet";
    const breed = formData.breed || formData.petType || "pet";
    return `${name}, ${breed}`;
  }, [formData.breed, formData.petName, formData.petType]);

  const updateField: UpdateQuoteField = (name, value) => {
    setFormData((current) => ({ ...current, [name]: value }));
    setErrors((current) => ({ ...current, [name]: undefined }));
    if (underwritingFields.includes(name)) {
      setDecisionResult(null);
    }
  };

  const selectPetType = (petType: PetType) => {
    setFormData((current) => ({
      ...current,
      petType,
      breed: "",
      diagnosedConditions: [],
      plan: ""
    }));
    setDecisionResult(null);
    track("species_selected", { species: petType });
  };

  const toggleCondition = (condition: string) => {
    setFormData((current) => {
      if (condition === noConditions) {
        return { ...current, diagnosedConditions: [noConditions] };
      }

      const withoutNone = current.diagnosedConditions.filter(
        (item) => item !== noConditions
      );
      const next = withoutNone.includes(condition)
        ? withoutNone.filter((item) => item !== condition)
        : [...withoutNone, condition];

      return { ...current, diagnosedConditions: next };
    });
    setErrors((current) => ({ ...current, diagnosedConditions: undefined }));
    setDecisionResult(null);
  };

  const toggleRider = (riderId: RiderId) => {
    setFormData((current) => ({
      ...current,
      riders: current.riders.includes(riderId)
        ? current.riders.filter((id) => id !== riderId)
        : [...current.riders, riderId]
    }));
  };

  const updateVetRecordFiles = async (files: File[]) => {
    try {
      const uploads = await filesToVetRecordUploads(files);
      setFormData((current) => ({
        ...current,
        vetRecordFileNames: uploads.map((upload) => upload.fileName),
        vetRecordUploads: uploads
      }));
      setErrors((current) => ({ ...current, vetRecordFileNames: undefined }));
      setDecisionResult(null);
    } catch (error) {
      setErrors((current) => ({
        ...current,
        vetRecordFileNames:
          error instanceof Error
            ? error.message
            : "We could not read that file. Try another record."
      }));
    }
  };

  const completeStep = (step: QuoteStep) => {
    track("quote_step_completed", { step });
  };

  const goToStep = (step: QuoteStep) => {
    setCurrentStep(step);
    setErrors({});
    setPlanError("");
  };

  const startOver = () => {
    setFormData(initialData);
    setErrors({});
    setPlanError("");
    setSubmitted(false);
    setSubmissionResult(null);
    setSubmissionError("");
    setDecisionResult(null);
    setCurrentStep(1);
  };

  const validateDetails = () => {
    const nextErrors: QuoteErrors = {};
    const weight = Number(formData.weightLbs);

    if (!formData.petName.trim()) {
      nextErrors.petName = "Enter your pet's name.";
    }

    if (!formData.breed.trim()) {
      nextErrors.breed = "Choose your pet's breed.";
    }

    if (!formData.weightLbs || Number.isNaN(weight) || weight <= 0) {
      nextErrors.weightLbs = "Enter a valid weight.";
    }

    if (!formData.ageYears) {
      nextErrors.ageYears = "Choose years.";
    }

    if (!formData.ageMonths) {
      nextErrors.ageMonths = "Choose months.";
    }

    if (!formData.sex) {
      nextErrors.sex = "Choose male or female.";
    }

    if (!formData.altered) {
      nextErrors.altered = "Tell us if your pet is spayed or neutered.";
    }

    if (!formData.bodyCondition) {
      nextErrors.bodyCondition = "Choose the closest body condition.";
    }

    setErrors(nextErrors);
    return Object.keys(nextErrors).length === 0;
  };

  const validateScreening = () => {
    const nextErrors: QuoteErrors = {};

    if (formData.diagnosedConditions.length === 0) {
      nextErrors.diagnosedConditions =
        "Select None or choose any diagnosed conditions.";
    }

    if (!formData.currentSymptoms) {
      nextErrors.currentSymptoms = "Choose yes or no.";
    }

    if (!formData.medication) {
      nextErrors.medication = "Choose yes or no.";
    }

    if (!formData.recentSurgery) {
      nextErrors.recentSurgery = "Choose yes or no.";
    }

    if (!formData.vetRecords) {
      nextErrors.vetRecords = "Choose yes or no.";
    }

    setErrors(nextErrors);
    return Object.keys(nextErrors).length === 0;
  };

  const validateContact = () => {
    const nextErrors: QuoteErrors = {};
    const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const zipPattern = /^\d{5}$/;
    const needsEvidencePacket = screeningResult.status === "need_more_info";
    const needsExclusionAck =
      screeningResult.status === "approved_with_exclusions" &&
      screeningResult.exclusions.length > 0;

    if (!formData.firstName.trim()) {
      nextErrors.firstName = "Enter your first name.";
    }

    if (!formData.lastName.trim()) {
      nextErrors.lastName = "Enter your last name.";
    }

    if (!emailPattern.test(formData.email)) {
      nextErrors.email = "Enter a valid email address.";
    }

    if (!zipPattern.test(formData.zipCode)) {
      nextErrors.zipCode = "Enter a 5-digit ZIP code.";
    }

    if (needsExclusionAck && !formData.exclusionAcknowledged) {
      nextErrors.exclusionAcknowledged =
        "Acknowledge the likely exclusions before continuing.";
    }

    if (needsEvidencePacket && !formData.conditionDetails.trim()) {
      nextErrors.conditionDetails =
        "Add a short note about the condition, treatment, or current status.";
    }

    if (
      needsEvidencePacket &&
      formData.vetRecordFileNames.length === 0 &&
      !formData.vetClinicName.trim()
    ) {
      nextErrors.vetRecordFileNames =
        "Upload records or add the vet clinic so we know how to request them.";
      nextErrors.vetClinicName =
        "Add the clinic name or upload records directly.";
    }

    if (!formData.consent) {
      nextErrors.consent = "Confirm this before continuing.";
    }

    setErrors(nextErrors);
    return Object.keys(nextErrors).length === 0;
  };

  const completeScreening = async () => {
    if (!validateScreening()) return;

    setIsEvaluating(true);
    try {
      const decision = await evaluateQuoteDecision(formData);
      setDecisionResult(decision);
      completeStep(3);

      if (
        decision.status === "need_more_info" ||
        decision.status === "declined"
      ) {
        goToStep(6);
        return;
      }

      goToStep(4);
    } finally {
      setIsEvaluating(false);
    }
  };

  const submitQuote = async () => {
    if (!validateContact()) {
      return;
    }

    setIsSubmitting(true);
    setSubmissionError("");

    try {
      const action =
        screeningResult.status === "approved" ||
        screeningResult.status === "approved_with_exclusions"
          ? "start_payment"
          : screeningResult.status === "declined"
            ? "record_decline"
            : "submit_evidence";
      const result = await submitNoTouchQuote({
        formData,
        selectedPlan,
        estimatedMonthly,
        action
      });

      setSubmissionResult(result);
      setDecisionResult(result.decision);
      setFormData((current) => ({ ...current, quoteCaseId: result.caseId }));
      completeStep(6);
      track(finalStepContent.event, {
        species: formData.petType,
        breed: formData.breed,
        weight: formData.weightLbs,
        screeningStatus: result.decision.status,
        plan: formData.plan,
        riders: formData.riders,
        exclusions: result.decision.exclusions,
        vetRecordCount: result.evidence.uploaded.length,
        zip: formData.zipCode,
        estimatedMonthly,
        caseId: result.caseId,
        paymentStatus: result.payment.status
      });
      track("quote_submitted", {
        species: formData.petType,
        breed: formData.breed,
        weight: formData.weightLbs,
        screeningStatus: result.decision.status,
        plan: formData.plan,
        riders: formData.riders,
        exclusions: result.decision.exclusions,
        vetRecordCount: result.evidence.uploaded.length,
        zip: formData.zipCode,
        caseId: result.caseId
      });
      console.log("Quote submitted:", {
        ...formData,
        caseId: result.caseId,
        screening: result.decision,
        finalAction: finalStepContent.event,
        estimatedMonthly,
        payment: result.payment
      });

      if (result.payment.checkoutUrl) {
        window.location.assign(result.payment.checkoutUrl);
        return;
      }

      setSubmitted(true);
    } catch (error) {
      setSubmissionError(
        error instanceof Error
          ? error.message
          : "The automated quote submission failed. Please try again."
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <section className="bg-clv-paper px-5 py-16 md:px-8 md:py-20">
      <div className="mx-auto grid max-w-6xl gap-6 lg:grid-cols-[260px_minmax(0,720px)] lg:justify-center">
        <aside className="hidden rounded-2xl border border-clv-gray-border bg-white p-5 lg:block">
          <p className="text-xs uppercase tracking-[0.12em] text-clv-green">
            Your quote
          </p>
          <SummaryList
            formData={formData}
            screeningResult={screeningResult}
            estimatedMonthly={estimatedMonthly}
          />
        </aside>

        {!submitted && (
          <div className="rounded-full border border-clv-gray-border bg-white px-4 py-2 text-sm text-clv-gray lg:hidden">
            Your pet:{" "}
            <span className="font-semibold text-clv-charcoal">
              {petSummary}
            </span>
          </div>
        )}

        <div className="rounded-2xl border border-clv-gray-border bg-white p-6 md:p-10">
          {submitted ? (
            <Confirmation
              screeningResult={screeningResult}
              estimatedMonthly={estimatedMonthly}
              content={finalStepContent}
              submissionResult={submissionResult}
            />
          ) : (
            <>
              <div className="mb-8">
                <div className="flex items-center justify-between gap-4">
                  <div>
                    <p className="text-xs text-clv-gray">
                      Step {currentStep} of {totalSteps}
                    </p>
                    <p className="mt-1 text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
                      {stepNames[currentStep]}
                    </p>
                  </div>
                  <button
                    type="button"
                    className="text-xs text-clv-gray underline-offset-4 hover:text-clv-green hover:underline"
                    onClick={startOver}
                  >
                    Start over
                  </button>
                </div>
                <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-clv-sage-light">
                  <motion.div
                    className="h-full rounded-full bg-clv-green"
                    animate={{ width: `${progress}%` }}
                    transition={{ duration: 0.3 }}
                  />
                </div>
              </div>

              <AnimatePresence mode="wait">
                <motion.div
                  key={currentStep}
                  variants={stepVariants}
                  initial="initial"
                  animate="animate"
                  exit="exit"
                  transition={{ duration: 0.24, ease: "easeOut" }}
                >
                  {currentStep === 1 && (
                    <StepOne
                      selected={formData.petType}
                      onSelect={selectPetType}
                      onNext={() => {
                        if (!formData.petType) return;
                        completeStep(1);
                        goToStep(2);
                      }}
                    />
                  )}
                  {currentStep === 2 && (
                    <StepTwo
                      formData={formData}
                      errors={errors}
                      breeds={availableBreeds}
                      onUpdate={updateField}
                      onSex={(sex) => updateField("sex", sex)}
                      onAltered={(altered) => updateField("altered", altered)}
                      onBodyCondition={(bodyCondition) =>
                        updateField("bodyCondition", bodyCondition)
                      }
                      onNext={() => {
                        if (!validateDetails()) return;
                        completeStep(2);
                        goToStep(3);
                      }}
                    />
                  )}
                  {currentStep === 3 && (
                    <StepThree
                      formData={formData}
                      errors={errors}
                      screeningResult={screeningResult}
                      onToggleCondition={toggleCondition}
                      onUpdate={updateField}
                      isEvaluating={isEvaluating}
                      onNext={completeScreening}
                    />
                  )}
                  {currentStep === 4 && (
                    <StepFour
                      formData={formData}
                      screeningResult={screeningResult}
                      selectedPlan={formData.plan}
                      error={planError}
                      onSelect={(plan) => {
                        updateField("plan", plan);
                        setPlanError("");
                        track("plan_selected", { plan });
                      }}
                      onNext={() => {
                        if (!formData.plan) {
                          setPlanError("Choose a plan to continue.");
                          return;
                        }
                        completeStep(4);
                        goToStep(5);
                      }}
                    />
                  )}
                  {currentStep === 5 && (
                    <StepFive
                      formData={formData}
                      selectedPlan={selectedPlan}
                      screeningResult={screeningResult}
                      estimatedMonthly={estimatedMonthly}
                      onDeductible={(deductible) =>
                        updateField("deductible", deductible)
                      }
                      onReimbursement={(reimbursement) =>
                        updateField("reimbursement", reimbursement)
                      }
                      onAnnualLimit={(annualLimit) =>
                        updateField("annualLimit", annualLimit)
                      }
                      onToggleRider={toggleRider}
                      onNext={() => {
                        completeStep(5);
                        goToStep(6);
                      }}
                    />
                  )}
                  {currentStep === 6 && (
                    <StepSix
                      formData={formData}
                      errors={errors}
                      screeningResult={screeningResult}
                      selectedPlan={selectedPlan}
                      estimatedMonthly={estimatedMonthly}
                      content={finalStepContent}
                      onUpdate={updateField}
                      onVetRecordFiles={updateVetRecordFiles}
                      onExclusionAcknowledged={(exclusionAcknowledged) =>
                        updateField(
                          "exclusionAcknowledged",
                          exclusionAcknowledged
                        )
                      }
                      onConsent={(consent) => updateField("consent", consent)}
                      onSubmit={submitQuote}
                      isSubmitting={isSubmitting}
                      submissionError={submissionError}
                    />
                  )}
                </motion.div>
              </AnimatePresence>
            </>
          )}
        </div>
      </div>
    </section>
  );
}

function SummaryList({
  formData,
  screeningResult,
  estimatedMonthly
}: {
  formData: QuoteData;
  screeningResult: ScreeningResult;
  estimatedMonthly: number | null;
}) {
  const rows = [
    ["Pet", formData.petType || "Not selected"],
    ["Name", formData.petName || "Not added"],
    ["Breed", formData.breed || "Not added"],
    [
      "Age / weight",
      formData.ageYears
        ? `${formData.ageYears}y ${formData.ageMonths || "0"}m, ${
            formData.weightLbs || "-"
          } lbs`
        : "Not added"
    ],
    ["Screening", screeningResult.label],
    ["Plan", formData.plan || "Not selected"],
    ["Monthly", estimatedMonthly ? `About $${estimatedMonthly}/mo` : "Pending"]
  ];

  return (
    <dl className="mt-6 space-y-5">
      {rows.map(([label, value]) => (
        <div key={label}>
          <dt className="text-[11px] uppercase tracking-[0.1em] text-clv-gray">
            {label}
          </dt>
          <dd className="mt-1 text-sm font-semibold capitalize text-clv-charcoal">
            {value}
          </dd>
        </div>
      ))}
    </dl>
  );
}

function StepOne({
  selected,
  onSelect,
  onNext
}: {
  selected: PetType | "";
  onSelect: (petType: PetType) => void;
  onNext: () => void;
}) {
  return (
    <div>
      <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
        Quote intake
      </p>
      <h1 className="mt-2 font-display text-[32px] font-bold tracking-[-0.02em] text-clv-charcoal">
        Who are we covering today?
      </h1>
      <p className="mt-3 max-w-xl text-base leading-[1.7] text-clv-gray">
        We will use this to tailor breed, weight, and medical questions before
        showing plan options.
      </p>
      <div className="mt-8 grid gap-4 sm:grid-cols-2">
        <PetCard
          label="Dog"
          selected={selected === "dog"}
          onClick={() => onSelect("dog")}
          illustration={<DogIllustration decorative size={100} />}
        />
        <PetCard
          label="Cat"
          selected={selected === "cat"}
          onClick={() => onSelect("cat")}
          illustration={<CatIllustration decorative size={100} />}
        />
      </div>
      <AnimatePresence>
        {selected && (
          <motion.button
            type="button"
            className="mt-8 w-full rounded-md bg-clv-charcoal px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-clv-white transition-colors hover:bg-[#333]"
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            onClick={onNext}
          >
            Continue →
          </motion.button>
        )}
      </AnimatePresence>
    </div>
  );
}

function PetCard({
  label,
  selected,
  illustration,
  onClick
}: {
  label: string;
  selected: boolean;
  illustration: ReactNode;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      className={`rounded-xl border-2 p-8 text-center transition-all duration-200 hover:shadow-[0_2px_12px_rgba(45,106,79,0.15)] ${
        selected
          ? "border-clv-green bg-clv-sage-light"
          : "border-clv-gray-border bg-white"
      }`}
      aria-pressed={selected}
      onClick={onClick}
    >
      <span className="flex justify-center">{illustration}</span>
      <span className="mt-4 block text-base font-semibold text-clv-charcoal">
        {label}
      </span>
    </button>
  );
}

function StepTwo({
  formData,
  errors,
  breeds,
  onUpdate,
  onSex,
  onAltered,
  onBodyCondition,
  onNext
}: {
  formData: QuoteData;
  errors: QuoteErrors;
  breeds: string[];
  onUpdate: UpdateQuoteField;
  onSex: (sex: "male" | "female") => void;
  onAltered: (altered: "yes" | "no") => void;
  onBodyCondition: (bodyCondition: BodyCondition) => void;
  onNext: () => void;
}) {
  const years = Array.from({ length: 16 }, (_, index) => String(index));
  const months = Array.from({ length: 12 }, (_, index) => String(index));
  const species = formData.petType || "pet";
  const weightResult = assessWeight(formData);

  return (
    <div>
      <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
        Pet profile
      </p>
      <h1 className="mt-2 font-display text-[32px] font-bold tracking-[-0.02em] text-clv-charcoal">
        Tell us about your {species}.
      </h1>
      <div className="mt-8 space-y-5">
        <Field
          id="petName"
          label="Pet name"
          error={errors.petName}
          describedBy="petName-error"
        >
          <input
            id="petName"
            value={formData.petName}
            placeholder="e.g. Biscuit"
            className={inputClass(errors.petName)}
            aria-describedby="petName-error"
            aria-invalid={Boolean(errors.petName)}
            onChange={(event) => onUpdate("petName", event.target.value)}
          />
        </Field>

        <Field
          id="breed"
          label="Breed"
          error={errors.breed}
          describedBy="breed-error"
        >
          <input
            id="breed"
            list="breed-options"
            value={formData.breed}
            placeholder="Search or choose a breed"
            className={inputClass(errors.breed)}
            aria-describedby="breed-help breed-error"
            aria-invalid={Boolean(errors.breed)}
            onChange={(event) => onUpdate("breed", event.target.value)}
          />
          <datalist id="breed-options">
            {breeds.map((breed) => (
              <option key={breed} value={breed} />
            ))}
          </datalist>
          <p id="breed-help" className="mt-2 text-xs text-clv-gray">
            Includes mixed-size buckets and unknown options for rescue pets.
          </p>
        </Field>

        <div className="grid gap-4 sm:grid-cols-[1fr_150px]">
          <div className="grid gap-4 sm:grid-cols-2">
            <Field
              id="ageYears"
              label="Years"
              error={errors.ageYears}
              describedBy="ageYears-error"
            >
              <select
                id="ageYears"
                value={formData.ageYears}
                className={inputClass(errors.ageYears)}
                aria-describedby="ageYears-error"
                aria-invalid={Boolean(errors.ageYears)}
                onChange={(event) => onUpdate("ageYears", event.target.value)}
              >
                <option value="">Select years</option>
                {years.map((year) => (
                  <option key={year} value={year}>
                    {year}
                  </option>
                ))}
              </select>
            </Field>
            <Field
              id="ageMonths"
              label="Months"
              error={errors.ageMonths}
              describedBy="ageMonths-error"
            >
              <select
                id="ageMonths"
                value={formData.ageMonths}
                className={inputClass(errors.ageMonths)}
                aria-describedby="ageMonths-error"
                aria-invalid={Boolean(errors.ageMonths)}
                onChange={(event) => onUpdate("ageMonths", event.target.value)}
              >
                <option value="">Select months</option>
                {months.map((month) => (
                  <option key={month} value={month}>
                    {month}
                  </option>
                ))}
              </select>
            </Field>
          </div>

          <Field
            id="weightLbs"
            label="Weight"
            error={errors.weightLbs}
            describedBy="weightLbs-error"
          >
            <input
              id="weightLbs"
              type="number"
              inputMode="decimal"
              min="1"
              value={formData.weightLbs}
              placeholder="lbs"
              className={inputClass(errors.weightLbs)}
              aria-describedby="weightLbs-error"
              aria-invalid={Boolean(errors.weightLbs)}
              onChange={(event) => onUpdate("weightLbs", event.target.value)}
            />
          </Field>
        </div>

        {formData.ageYears === "0" && formData.ageMonths && (
          <p className="rounded-lg bg-clv-sage-light px-4 py-3 text-sm font-semibold text-clv-green">
            Your pet is {formData.ageMonths} months old.
          </p>
        )}

        {weightResult && (
          <p className={weightResult.className}>{weightResult.message}</p>
        )}

        <ToggleGroup
          label="Sex"
          error={errors.sex}
          options={[
            { label: "Male", value: "male" },
            { label: "Female", value: "female" }
          ]}
          selected={formData.sex}
          onSelect={(value) => onSex(value as "male" | "female")}
        />

        <ToggleGroup
          label="Spayed/neutered"
          error={errors.altered}
          options={[
            { label: "Yes", value: "yes" },
            { label: "No", value: "no" }
          ]}
          selected={formData.altered}
          onSelect={(value) => onAltered(value as "yes" | "no")}
        />

        <ToggleGroup
          label="Body condition at last vet visit"
          error={errors.bodyCondition}
          options={[
            { label: "Lean", value: "lean" },
            { label: "Ideal", value: "ideal" },
            { label: "Overweight", value: "overweight" },
            { label: "Not sure", value: "not_sure" }
          ]}
          selected={formData.bodyCondition}
          onSelect={(value) => onBodyCondition(value as BodyCondition)}
        />
      </div>
      <button
        type="button"
        className="mt-8 w-full rounded-md bg-clv-charcoal px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-clv-white transition-colors hover:bg-[#333]"
        onClick={onNext}
      >
        Continue to screening →
      </button>
    </div>
  );
}

function StepThree({
  formData,
  errors,
  screeningResult,
  onToggleCondition,
  onUpdate,
  isEvaluating,
  onNext
}: {
  formData: QuoteData;
  errors: QuoteErrors;
  screeningResult: ScreeningResult;
  onToggleCondition: (condition: string) => void;
  onUpdate: UpdateQuoteField;
  isEvaluating: boolean;
  onNext: () => void;
}) {
  return (
    <div>
      <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
        Medical screening
      </p>
      <h1 className="mt-2 font-display text-[32px] font-bold tracking-[-0.02em] text-clv-charcoal">
        Can {formData.petName || "your pet"} go straight through?
      </h1>
      <p className="mt-3 text-base leading-[1.7] text-clv-gray">
        These answers decide whether pricing can be shown now, whether coverage
        needs exclusions, or whether the system needs more evidence first.
      </p>

      <div className="mt-8 space-y-6">
        <div>
          <p className="mb-3 text-sm font-semibold text-clv-charcoal">
            Has your pet ever been diagnosed with any of these?
          </p>
          <div className="grid gap-3 sm:grid-cols-2">
            {conditionOptions.map((condition) => {
              const selected = formData.diagnosedConditions.includes(condition);
              return (
                <button
                  key={condition}
                  type="button"
                  className={`rounded-lg border px-4 py-3 text-left text-sm font-semibold transition-colors ${
                    selected
                      ? "border-clv-green bg-clv-sage-light text-clv-green"
                      : "border-clv-gray-border text-clv-charcoal hover:border-clv-green"
                  }`}
                  aria-pressed={selected}
                  onClick={() => onToggleCondition(condition)}
                >
                  {condition}
                </button>
              );
            })}
          </div>
          {errors.diagnosedConditions && (
            <p className="mt-2 text-sm text-red-700">
              {errors.diagnosedConditions}
            </p>
          )}
        </div>

        <div className="grid gap-5 sm:grid-cols-2">
          <ToggleGroup
            label="Any symptoms right now?"
            error={errors.currentSymptoms}
            options={yesNoOptions}
            selected={formData.currentSymptoms}
            onSelect={(value) =>
              onUpdate("currentSymptoms", value as YesNoAnswer)
            }
          />
          <ToggleGroup
            label="Any ongoing medication?"
            error={errors.medication}
            options={yesNoOptions}
            selected={formData.medication}
            onSelect={(value) => onUpdate("medication", value as YesNoAnswer)}
          />
          <ToggleGroup
            label="Surgery or hospital stay in 12 months?"
            error={errors.recentSurgery}
            options={yesNoOptions}
            selected={formData.recentSurgery}
            onSelect={(value) =>
              onUpdate("recentSurgery", value as YesNoAnswer)
            }
          />
          <ToggleGroup
            label="Can you provide vet records?"
            error={errors.vetRecords}
            options={yesNoOptions}
            selected={formData.vetRecords}
            onSelect={(value) => onUpdate("vetRecords", value as YesNoAnswer)}
          />
        </div>

        <ScreeningCard result={screeningResult} />
      </div>

      <button
        type="button"
        className="mt-8 w-full rounded-md bg-clv-charcoal px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-clv-white transition-colors hover:bg-[#333] disabled:cursor-wait disabled:opacity-70"
        disabled={isEvaluating}
        onClick={onNext}
      >
        {isEvaluating ? "Running underwriting checks..." : "Continue →"}
      </button>
    </div>
  );
}

function StepFour({
  formData,
  screeningResult,
  selectedPlan,
  error,
  onSelect,
  onNext
}: {
  formData: QuoteData;
  screeningResult: ScreeningResult;
  selectedPlan: PlanId | "";
  error: string;
  onSelect: (plan: PlanId) => void;
  onNext: () => void;
}) {
  return (
    <div>
      <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
        Plan assessment
      </p>
      <h1 className="mt-2 font-display text-[32px] font-bold tracking-[-0.02em] text-clv-charcoal">
        Plans for {formData.petName || "your pet"}.
      </h1>
      <div className="mt-5">
        <ScreeningCard result={screeningResult} compact />
      </div>
      <div className="mt-8 space-y-4">
        {plans.map((plan) => {
          const selected = selectedPlan === plan.id;
          const price = estimateMonthly(
            { ...formData, plan: plan.id },
            screeningResult.status
          );

          return (
            <article
              key={plan.id}
              className={`rounded-xl border p-5 transition-all duration-200 ${
                selected
                  ? "border-2 border-clv-green bg-clv-sage-light"
                  : "border-clv-gray-border bg-white"
              }`}
            >
              <div className="flex flex-wrap items-start justify-between gap-4">
                <div>
                  <div className="flex items-center gap-2">
                    <h2 className="text-lg font-semibold text-clv-charcoal">
                      {plan.title}
                    </h2>
                    {plan.recommended && (
                      <span className="rounded bg-clv-green px-2 py-1 text-[11px] font-semibold text-white">
                        Recommended
                      </span>
                    )}
                  </div>
                  <p className="mt-2 text-sm leading-[1.6] text-clv-gray">
                    {planDescription(plan.id)}
                  </p>
                  <p className="mt-4 font-display text-[34px] font-bold text-clv-green">
                    ${price}/mo
                  </p>
                </div>
                <button
                  type="button"
                  className={`rounded-md px-4 py-2 text-sm font-semibold transition-colors ${
                    selected
                      ? "bg-clv-green text-white"
                      : "border border-clv-gray-light text-clv-gray hover:border-clv-green hover:text-clv-green"
                  }`}
                  onClick={() => onSelect(plan.id)}
                >
                  {selected ? "Selected" : "Select plan"}
                </button>
              </div>
              <dl className="mt-4 grid grid-cols-3 gap-3 text-sm">
                <PlanMetric label="Deductible" value={plan.deductible} />
                <PlanMetric label="Reimburses" value={plan.reimbursement} />
                <PlanMetric label="Screening" value={screeningResult.label} />
              </dl>
              <ul className="mt-4 grid gap-2 text-sm text-clv-gray sm:grid-cols-2">
                {plan.highlights.map((highlight) => (
                  <li key={highlight}>✓ {highlight}</li>
                ))}
              </ul>
            </article>
          );
        })}
      </div>
      {error && <p className="mt-4 text-sm text-red-700">{error}</p>}
      <button
        type="button"
        className="mt-8 w-full rounded-md bg-clv-charcoal px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-clv-white transition-colors hover:bg-[#333]"
        onClick={onNext}
      >
        Customize plan →
      </button>
    </div>
  );
}

function StepFive({
  formData,
  selectedPlan,
  screeningResult,
  estimatedMonthly,
  onDeductible,
  onReimbursement,
  onAnnualLimit,
  onToggleRider,
  onNext
}: {
  formData: QuoteData;
  selectedPlan: (typeof plans)[number] | undefined;
  screeningResult: ScreeningResult;
  estimatedMonthly: number | null;
  onDeductible: (deductible: DeductibleOption) => void;
  onReimbursement: (reimbursement: ReimbursementOption) => void;
  onAnnualLimit: (annualLimit: AnnualLimitOption) => void;
  onToggleRider: (riderId: RiderId) => void;
  onNext: () => void;
}) {
  return (
    <div>
      <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
        Coverage settings
      </p>
      <h1 className="mt-2 font-display text-[32px] font-bold tracking-[-0.02em] text-clv-charcoal">
        Tune the plan before we send it.
      </h1>
      <div className="mt-6 rounded-xl border border-clv-gray-border bg-clv-sage-light p-5">
        <div className="flex flex-wrap items-start justify-between gap-4">
          <div>
            <p className="text-sm font-semibold text-clv-charcoal">
              {selectedPlan?.title || "Selected plan"}
            </p>
            <p className="mt-1 text-sm leading-[1.6] text-clv-gray">
              {screeningResult.body}
            </p>
          </div>
          <p className="font-display text-[34px] font-bold text-clv-green">
            ${estimatedMonthly ?? "--"}/mo
          </p>
        </div>
      </div>

      <div className="mt-8 space-y-7">
        <OptionPicker
          label="Annual deductible"
          selected={formData.deductible}
          options={[
            { label: "$100", value: "100" },
            { label: "$250", value: "250" },
            { label: "$500", value: "500" }
          ]}
          onSelect={(value) => onDeductible(value as DeductibleOption)}
        />
        <OptionPicker
          label="Reimbursement rate"
          selected={formData.reimbursement}
          options={[
            { label: "70%", value: "70" },
            { label: "80%", value: "80" },
            { label: "90%", value: "90" }
          ]}
          onSelect={(value) => onReimbursement(value as ReimbursementOption)}
        />
        <OptionPicker
          label="Annual limit"
          selected={formData.annualLimit}
          options={[
            { label: "$10k", value: "10000" },
            { label: "$20k", value: "20000" },
            { label: "Unlimited", value: "unlimited" }
          ]}
          onSelect={(value) => onAnnualLimit(value as AnnualLimitOption)}
        />

        <div>
          <p className="mb-3 text-sm font-semibold text-clv-charcoal">
            Optional riders
          </p>
          <div className="grid gap-3 sm:grid-cols-2">
            {quoteRiders.map((rider) => {
              const selected = formData.riders.includes(rider.id);
              return (
                <button
                  key={rider.id}
                  type="button"
                  className={`rounded-xl border p-4 text-left transition-colors ${
                    selected
                      ? "border-clv-green bg-clv-sage-light"
                      : "border-clv-gray-border bg-white hover:border-clv-green"
                  }`}
                  aria-pressed={selected}
                  onClick={() => onToggleRider(rider.id)}
                >
                  <span className="block text-sm font-semibold text-clv-charcoal">
                    {rider.title}
                  </span>
                  <span className="mt-1 block text-sm text-clv-gray">
                    {rider.body}
                  </span>
                  <span className="mt-3 block text-sm font-semibold text-clv-green">
                    +${rider.price}/mo
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      </div>

      <button
        type="button"
        className="mt-8 w-full rounded-md bg-clv-charcoal px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-clv-white transition-colors hover:bg-[#333]"
        onClick={onNext}
      >
        Continue to contact →
      </button>
    </div>
  );
}

function StepSix({
  formData,
  errors,
  screeningResult,
  selectedPlan,
  estimatedMonthly,
  content,
  onUpdate,
  onVetRecordFiles,
  onExclusionAcknowledged,
  onConsent,
  onSubmit,
  isSubmitting,
  submissionError
}: {
  formData: QuoteData;
  errors: QuoteErrors;
  screeningResult: ScreeningResult;
  selectedPlan: (typeof plans)[number] | undefined;
  estimatedMonthly: number | null;
  content: FinalStepContent;
  onUpdate: UpdateQuoteField;
  onVetRecordFiles: (files: File[]) => void;
  onExclusionAcknowledged: (exclusionAcknowledged: boolean) => void;
  onConsent: (consent: boolean) => void;
  onSubmit: () => void;
  isSubmitting: boolean;
  submissionError: string;
}) {
  const showExclusions =
    screeningResult.status === "approved_with_exclusions" &&
    screeningResult.exclusions.length > 0;
  const showRecords = screeningResult.status === "need_more_info";
  const showPlanSummary = Boolean(selectedPlan || estimatedMonthly);

  return (
    <div>
      <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-clv-green">
        {content.eyebrow}
      </p>
      <h1 className="mt-2 font-display text-[32px] font-bold tracking-[-0.02em] text-clv-charcoal">
        {content.title}
      </h1>
      <p className="mt-3 max-w-xl text-base leading-[1.7] text-clv-gray">
        {content.body}
      </p>

      {showPlanSummary && (
        <div className="mt-6 rounded-xl border border-clv-gray-border bg-clv-sage-light p-5">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <p className="text-sm font-semibold text-clv-charcoal">
                {selectedPlan?.title || "Selected plan"}
              </p>
              <p className="mt-1 text-sm text-clv-gray">
                {screeningResult.label} · {formData.reimbursement}%
                reimbursement · ${formData.deductible} deductible
              </p>
              {formData.riders.length > 0 && (
                <p className="mt-1 text-sm text-clv-gray">
                  Riders: {formatRiderNames(formData.riders)}
                </p>
              )}
            </div>
            <p className="font-display text-[34px] font-bold text-clv-green">
              ${estimatedMonthly ?? "--"}/mo
            </p>
          </div>
          <div className="mt-4">
            <ScreeningCard result={screeningResult} compact />
          </div>
        </div>
      )}

      {!showPlanSummary && (
        <div className="mt-6">
          <ScreeningCard result={screeningResult} />
        </div>
      )}

      {showExclusions && (
        <div className="mt-6 rounded-xl border border-clv-amber bg-clv-amber-light p-5">
          <p className="text-sm font-semibold text-clv-charcoal">
            Likely exclusions before binding
          </p>
          <p className="mt-2 text-sm leading-[1.6] text-clv-gray">
            These items are surfaced before checkout so the plan decision is
            explicit before payment.
          </p>
          <div className="mt-4 flex flex-wrap gap-2">
            {screeningResult.exclusions.map((exclusion) => (
              <span
                key={exclusion}
                className="rounded-md border border-clv-amber bg-white px-3 py-2 text-sm font-semibold text-clv-charcoal"
              >
                {exclusion}
              </span>
            ))}
          </div>
          <CheckboxRow
            id="exclusionAcknowledged"
            checked={formData.exclusionAcknowledged}
            error={errors.exclusionAcknowledged}
            onChange={onExclusionAcknowledged}
          >
            I understand these conditions may be excluded before coverage is
            final.
          </CheckboxRow>
        </div>
      )}

      {showRecords && (
        <div className="mt-6 rounded-xl border border-clv-gray-border bg-white p-5">
          <p className="text-sm font-semibold text-clv-charcoal">
            Medical details and records
          </p>
          <p className="mt-2 text-sm leading-[1.6] text-clv-gray">
            Add enough detail for the automated underwriting checks to rerun.
            Upload records now or tell us which clinic to request them from.
          </p>

          {screeningResult.requiredEvidence.length > 0 && (
            <div className="mt-4 rounded-lg bg-clv-sage-light p-4">
              <p className="text-xs font-semibold uppercase tracking-[0.1em] text-clv-green">
                Required evidence
              </p>
              <ul className="mt-3 space-y-3 text-sm text-clv-charcoal">
                {screeningResult.requiredEvidence.map((item) => (
                  <li key={item.code}>
                    <span className="font-semibold">{item.title}</span>
                    <span className="block text-clv-gray">{item.details}</span>
                  </li>
                ))}
              </ul>
            </div>
          )}

          <div className="mt-5 space-y-5">
            <Field
              id="conditionDetails"
              label="Condition details"
              error={errors.conditionDetails}
              describedBy="conditionDetails-error"
            >
              <textarea
                id="conditionDetails"
                value={formData.conditionDetails}
                rows={4}
                placeholder="Diagnosis date, current status, treatment, medication, or what your vet told you."
                className={`${inputClass(errors.conditionDetails)} py-3`}
                aria-describedby="conditionDetails-error"
                aria-invalid={Boolean(errors.conditionDetails)}
                onChange={(event) =>
                  onUpdate("conditionDetails", event.target.value)
                }
              />
            </Field>

            <div>
              <label
                htmlFor="vetRecordsUpload"
                className="mb-2 block text-sm font-semibold text-clv-charcoal"
              >
                Upload vet records
              </label>
              <input
                id="vetRecordsUpload"
                type="file"
                multiple
                accept=".pdf,.jpg,.jpeg,.png,.heic"
                className="block w-full rounded-md border border-clv-gray-border bg-white px-4 py-3 text-sm text-clv-charcoal file:mr-4 file:rounded-md file:border-0 file:bg-clv-green file:px-4 file:py-2 file:text-sm file:font-semibold file:text-white"
                aria-describedby="vetRecordFileNames-error"
                aria-invalid={Boolean(errors.vetRecordFileNames)}
                onChange={(event) =>
                  onVetRecordFiles(Array.from(event.target.files ?? []))
                }
              />
              {formData.vetRecordFileNames.length > 0 && (
                <ul className="mt-3 space-y-1 text-sm text-clv-gray">
                  {formData.vetRecordFileNames.map((fileName) => (
                    <li key={fileName}>✓ {fileName}</li>
                  ))}
                </ul>
              )}
              {errors.vetRecordFileNames && (
                <p
                  id="vetRecordFileNames-error"
                  className="mt-2 text-sm text-red-700"
                >
                  {errors.vetRecordFileNames}
                </p>
              )}
            </div>

            <div className="grid gap-4 sm:grid-cols-2">
              <Field
                id="vetClinicName"
                label="Vet clinic name"
                error={errors.vetClinicName}
                describedBy="vetClinicName-error"
              >
                <input
                  id="vetClinicName"
                  value={formData.vetClinicName}
                  placeholder="e.g. Austin Animal Clinic"
                  className={inputClass(errors.vetClinicName)}
                  aria-describedby="vetClinicName-error"
                  aria-invalid={Boolean(errors.vetClinicName)}
                  onChange={(event) =>
                    onUpdate("vetClinicName", event.target.value)
                  }
                />
              </Field>
              <Field
                id="vetClinicPhone"
                label="Clinic phone"
                error={errors.vetClinicPhone}
                describedBy="vetClinicPhone-error"
              >
                <input
                  id="vetClinicPhone"
                  value={formData.vetClinicPhone}
                  placeholder="Optional"
                  className={inputClass(errors.vetClinicPhone)}
                  aria-describedby="vetClinicPhone-error"
                  aria-invalid={Boolean(errors.vetClinicPhone)}
                  onChange={(event) =>
                    onUpdate("vetClinicPhone", event.target.value)
                  }
                />
              </Field>
            </div>
          </div>
        </div>
      )}

      <div className="mt-8 space-y-5">
        <div className="grid gap-4 sm:grid-cols-2">
          <Field
            id="firstName"
            label="First name"
            error={errors.firstName}
            describedBy="firstName-error"
          >
            <input
              id="firstName"
              value={formData.firstName}
              className={inputClass(errors.firstName)}
              aria-describedby="firstName-error"
              aria-invalid={Boolean(errors.firstName)}
              onChange={(event) => onUpdate("firstName", event.target.value)}
            />
          </Field>
          <Field
            id="lastName"
            label="Last name"
            error={errors.lastName}
            describedBy="lastName-error"
          >
            <input
              id="lastName"
              value={formData.lastName}
              className={inputClass(errors.lastName)}
              aria-describedby="lastName-error"
              aria-invalid={Boolean(errors.lastName)}
              onChange={(event) => onUpdate("lastName", event.target.value)}
            />
          </Field>
        </div>

        <Field
          id="email"
          label="Email address"
          error={errors.email}
          describedBy="email-error"
        >
          <input
            id="email"
            type="email"
            value={formData.email}
            className={inputClass(errors.email)}
            aria-describedby="email-error"
            aria-invalid={Boolean(errors.email)}
            onChange={(event) => onUpdate("email", event.target.value)}
          />
        </Field>

        <Field
          id="zipCode"
          label="ZIP code"
          error={errors.zipCode}
          describedBy="zipCode-error"
        >
          <input
            id="zipCode"
            inputMode="numeric"
            maxLength={5}
            value={formData.zipCode}
            className={inputClass(errors.zipCode)}
            aria-describedby="zipCode-error"
            aria-invalid={Boolean(errors.zipCode)}
            onChange={(event) => onUpdate("zipCode", event.target.value)}
          />
        </Field>

        <CheckboxRow
          id="contactConsent"
          checked={formData.consent}
          error={errors.consent}
          onChange={onConsent}
        >
          {content.consentLabel}
        </CheckboxRow>
      </div>
      <button
        type="button"
        className="mt-8 w-full rounded-md bg-clv-green px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-white transition-colors hover:bg-clv-green-dark disabled:cursor-not-allowed disabled:bg-clv-gray"
        onClick={onSubmit}
        disabled={isSubmitting}
      >
        {isSubmitting ? "Running automated checks..." : content.cta}
      </button>
      {submissionError && (
        <p className="mt-3 text-sm font-semibold text-red-700">
          {submissionError}
        </p>
      )}
    </div>
  );
}

function ScreeningCard({
  result,
  compact = false
}: {
  result: ScreeningResult;
  compact?: boolean;
}) {
  const styles: Record<ScreeningStatus, string> = {
    approved: "border-clv-green bg-clv-sage-light text-clv-green",
    approved_with_exclusions:
      "border-clv-green-mid bg-clv-sage-light text-clv-green",
    need_more_info: "border-clv-amber bg-clv-amber-light text-clv-amber",
    declined: "border-red-700 bg-red-50 text-red-800"
  };

  return (
    <article className={`rounded-xl border p-5 ${styles[result.status]}`}>
      <p className="text-sm font-semibold">{result.label}</p>
      <p className="mt-2 text-sm leading-[1.6] text-clv-charcoal">
        {result.body}
      </p>
      {!compact && result.reasons.length > 0 && (
        <ul className="mt-4 space-y-2 text-sm text-clv-gray">
          {result.reasons.map((reason) => (
            <li key={reason}>✓ {reason}</li>
          ))}
        </ul>
      )}
      {result.exclusions.length > 0 && (
        <div className="mt-4 rounded-lg bg-white/80 p-3">
          <p className="text-xs font-semibold uppercase tracking-[0.1em] text-clv-gray">
            Exclusions
          </p>
          <p className="mt-1 text-sm font-semibold text-clv-charcoal">
            {result.exclusions.join(", ")}
          </p>
        </div>
      )}
      {!compact && result.requiredEvidence.length > 0 && (
        <div className="mt-4 rounded-lg bg-white/80 p-3">
          <p className="text-xs font-semibold uppercase tracking-[0.1em] text-clv-gray">
            Evidence required
          </p>
          <p className="mt-1 text-sm font-semibold text-clv-charcoal">
            {result.requiredEvidence.map((item) => item.title).join(", ")}
          </p>
        </div>
      )}
      {!compact && result.fraudSignals.length > 0 && (
        <div className="mt-4 rounded-lg bg-white/80 p-3">
          <p className="text-xs font-semibold uppercase tracking-[0.1em] text-clv-gray">
            Integrity signals
          </p>
          <p className="mt-1 text-sm font-semibold text-clv-charcoal">
            {result.fraudSignals.map((item) => item.label).join(", ")}
          </p>
        </div>
      )}
    </article>
  );
}

function CheckboxRow({
  id,
  checked,
  error,
  onChange,
  children
}: {
  id: string;
  checked: boolean;
  error?: string;
  onChange: (checked: boolean) => void;
  children: ReactNode;
}) {
  return (
    <div className="mt-4">
      <div className="flex items-start gap-3">
        <input
          id={id}
          type="checkbox"
          className="mt-1 h-4 w-4 accent-clv-green"
          checked={checked}
          aria-describedby={`${id}-error`}
          aria-invalid={Boolean(error)}
          onChange={(event) => onChange(event.target.checked)}
        />
        <label htmlFor={id} className="text-sm leading-[1.6] text-clv-gray">
          {children}
        </label>
      </div>
      {error && (
        <p id={`${id}-error`} className="mt-2 text-sm text-red-700">
          {error}
        </p>
      )}
    </div>
  );
}

function Field({
  id,
  label,
  error,
  describedBy,
  children
}: {
  id: string;
  label: string;
  error?: string;
  describedBy: string;
  children: ReactNode;
}) {
  return (
    <div>
      <label
        htmlFor={id}
        className="mb-2 block text-sm font-semibold text-clv-charcoal"
      >
        {label}
      </label>
      {children}
      {error && (
        <p id={describedBy} className="mt-2 text-sm text-red-700">
          {error}
        </p>
      )}
    </div>
  );
}

function ToggleGroup({
  label,
  options,
  selected,
  error,
  onSelect
}: {
  label: string;
  options: Array<{ label: string; value: string }>;
  selected: string;
  error?: string;
  onSelect: (value: string) => void;
}) {
  return (
    <div>
      <p className="mb-2 text-sm font-semibold text-clv-charcoal">{label}</p>
      <div className="flex flex-wrap gap-3" role="group" aria-label={label}>
        {options.map((option) => (
          <button
            key={option.value}
            type="button"
            className={`rounded-[24px] border px-5 py-2 text-sm font-semibold transition-colors ${
              selected === option.value
                ? "border-clv-green bg-clv-green text-white"
                : "border-clv-gray-light text-clv-gray hover:border-clv-green hover:text-clv-green"
            }`}
            aria-pressed={selected === option.value}
            onClick={() => onSelect(option.value)}
          >
            {option.label}
          </button>
        ))}
      </div>
      {error && <p className="mt-2 text-sm text-red-700">{error}</p>}
    </div>
  );
}

function OptionPicker({
  label,
  options,
  selected,
  onSelect
}: {
  label: string;
  options: Array<{ label: string; value: string }>;
  selected: string;
  onSelect: (value: string) => void;
}) {
  return (
    <div>
      <p className="mb-3 text-sm font-semibold text-clv-charcoal">{label}</p>
      <div className="grid gap-3 sm:grid-cols-3">
        {options.map((option) => (
          <button
            key={option.value}
            type="button"
            className={`rounded-lg border px-4 py-3 text-sm font-semibold transition-colors ${
              selected === option.value
                ? "border-clv-green bg-clv-green text-white"
                : "border-clv-gray-border text-clv-charcoal hover:border-clv-green"
            }`}
            aria-pressed={selected === option.value}
            onClick={() => onSelect(option.value)}
          >
            {option.label}
          </button>
        ))}
      </div>
    </div>
  );
}

function PlanMetric({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-clv-gray">{label}</dt>
      <dd className="mt-1 font-semibold text-clv-charcoal">{value}</dd>
    </div>
  );
}

function Confirmation({
  screeningResult,
  estimatedMonthly,
  content,
  submissionResult
}: {
  screeningResult: ScreeningResult;
  estimatedMonthly: number | null;
  content: FinalStepContent;
  submissionResult: NoTouchQuoteResult | null;
}) {
  const paymentStatus = submissionResult?.payment.status;
  const confirmationBody =
    paymentStatus === "configuration_required"
      ? "The application passed automated underwriting, but Stripe checkout is not configured in this environment. No policy was bound."
      : content.confirmationBody;

  return (
    <div className="py-12 text-center">
      <motion.svg
        role="img"
        aria-label="Quote submitted"
        width="96"
        height="96"
        viewBox="0 0 96 96"
        className="mx-auto"
      >
        <motion.circle
          cx="48"
          cy="48"
          r="36"
          fill="none"
          stroke="#2D6A4F"
          strokeWidth="4"
          initial={{ pathLength: 0 }}
          animate={{ pathLength: 1 }}
          transition={{ duration: 0.55, ease: "easeOut" }}
        />
        <motion.path
          d="M31 49 L43 61 L66 36"
          fill="none"
          stroke="#2D6A4F"
          strokeWidth="5"
          strokeLinecap="round"
          strokeLinejoin="round"
          initial={{ pathLength: 0 }}
          animate={{ pathLength: 1 }}
          transition={{ delay: 0.35, duration: 0.45, ease: "easeOut" }}
        />
      </motion.svg>
      <h1 className="mt-8 font-display text-[30px] font-bold tracking-[-0.02em] text-clv-charcoal">
        {content.confirmationTitle}
      </h1>
      <p className="mx-auto mt-3 max-w-md text-base leading-[1.75] text-clv-gray">
        {confirmationBody}
      </p>
      {submissionResult?.caseId && (
        <p className="mt-3 text-xs font-semibold uppercase tracking-[0.12em] text-clv-green">
          Case {submissionResult.caseId}
        </p>
      )}
      {(screeningResult.status === "approved" ||
        screeningResult.status === "approved_with_exclusions") && (
        <div className="mx-auto mt-6 max-w-sm rounded-xl border border-clv-gray-border bg-clv-sage-light p-4 text-left">
          <p className="text-sm font-semibold text-clv-charcoal">
            Estimated payment
          </p>
          <p className="mt-1 font-display text-[30px] font-bold text-clv-green">
            ${estimatedMonthly ?? "--"}/mo
          </p>
          <p className="mt-2 text-sm leading-[1.6] text-clv-gray">
            {paymentStatus === "checkout_created"
              ? "Secure checkout was created. If you were not redirected, use the checkout link below."
              : "Payment is blocked until checkout configuration is available. The underwriting decision is still recorded automatically."}
          </p>
          {submissionResult?.payment.checkoutUrl && (
            <a
              href={submissionResult.payment.checkoutUrl}
              className="mt-3 inline-flex text-sm font-semibold text-clv-green underline-offset-4 hover:underline"
            >
              Open secure checkout →
            </a>
          )}
        </div>
      )}
    </div>
  );
}

function inputClass(error?: string) {
  return `min-h-[48px] w-full rounded-md border bg-white px-4 text-base text-clv-charcoal transition-colors placeholder:text-clv-gray ${
    error
      ? "border-red-600 focus:border-red-600"
      : "border-clv-gray-border focus:border-clv-green"
  }`;
}

const yesNoOptions = [
  { label: "Yes", value: "yes" },
  { label: "No", value: "no" }
];

function planDescription(plan: PlanId) {
  const descriptions: Record<PlanId, string> = {
    essential: "Lower monthly price with core accident and illness coverage.",
    comprehensive:
      "A stronger middle plan with prescription and cancer treatment support.",
    premium:
      "Highest reimbursement, lowest deductible, and the broadest package."
  };
  return descriptions[plan];
}

function getFinalStepContent(
  status: ScreeningStatus,
  estimatedMonthly: number | null
): FinalStepContent {
  if (status === "approved") {
    return {
      eyebrow: "Review and start coverage",
      title: "Ready to continue to payment?",
      body: "This application is approved for straight-through processing. Review the plan summary, confirm your details, then continue to secure payment.",
      consentLabel:
        "I confirm these application details are accurate and understand payment does not waive waiting periods, exclusions, or final policy terms.",
      cta: "Continue to payment →",
      event: "payment_started",
      confirmationTitle: "Payment is the next step.",
      confirmationBody: `Your application is ready for checkout at about $${
        estimatedMonthly ?? "--"
      }/mo. In production, this should open secure payment before coverage is bound.`
    };
  }

  if (status === "approved_with_exclusions") {
    return {
      eyebrow: "Review exclusions",
      title: "Review exclusions before payment.",
      body: "The application can continue to payment, but the exclusions shown here are part of the automated decision and must be acknowledged first.",
      consentLabel:
        "I understand the listed exclusions apply before coverage can be bound.",
      cta: "Continue to payment →",
      event: "payment_started_with_exclusions",
      confirmationTitle: "Exclusions acknowledged.",
      confirmationBody:
        "The plan is ready for secure payment with the automated exclusions attached to the policy record."
    };
  }

  if (status === "declined") {
    return {
      eyebrow: "Automated decision",
      title: "This application is not eligible.",
      body: "The decision was made automatically from the current underwriting rules. No payment is collected, and the outcome is complete.",
      consentLabel:
        "I confirm the contact details are correct so Clovara can send the decision notice.",
      cta: "Send decision notice →",
      event: "quote_declined",
      confirmationTitle: "Decision recorded.",
      confirmationBody:
        "The automated decision has been recorded. No payment was collected."
    };
  }

  return {
    eyebrow: "More information needed",
    title: "Finish the evidence step.",
    body: "Pricing is blocked until the required evidence is provided. Upload records or clinic details here so the system can rerun the decision automatically.",
    consentLabel:
      "I agree to save this evidence request and receive the secure follow-up link by email.",
    cta: "Save evidence request →",
    event: "underwriting_evidence_requested",
    confirmationTitle: "Evidence request saved.",
    confirmationBody:
      "The requested evidence has been saved. Once records are available, the automated underwriting checks can rerun before payment."
  };
}

function formatRiderNames(riderIds: RiderId[]) {
  return riderIds
    .map((riderId) => quoteRiders.find((rider) => rider.id === riderId)?.title)
    .filter((title): title is string => Boolean(title))
    .join(", ");
}

function estimateMonthly(
  formData: QuoteData,
  screeningStatus: ScreeningStatus
) {
  if (!formData.plan) return null;

  const riderTotal = formData.riders.reduce((total, riderId) => {
    const rider = quoteRiders.find((item) => item.id === riderId);
    return total + (rider?.price ?? 0);
  }, 0);

  const screeningAdjustment =
    screeningStatus === "approved_with_exclusions" ? 5 : 0;

  const total =
    basePrices[formData.plan] +
    deductibleAdjustments[formData.deductible] +
    reimbursementAdjustments[formData.reimbursement] +
    annualLimitAdjustments[formData.annualLimit] +
    screeningAdjustment +
    riderTotal;

  return Math.max(18, total);
}

function assessWeight(formData: QuoteData) {
  const result = weightAssessment(formData);
  if (!result) return null;

  return {
    ...result,
    className:
      result.status === "review"
        ? "rounded-lg bg-clv-amber-light px-4 py-3 text-sm font-semibold text-clv-amber"
        : "rounded-lg bg-clv-sage-light px-4 py-3 text-sm font-semibold text-clv-green"
  };
}
