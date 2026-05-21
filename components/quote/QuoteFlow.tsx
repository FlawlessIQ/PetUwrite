"use client";

import { AnimatePresence, motion } from "framer-motion";
import type { ReactNode } from "react";
import { useEffect, useMemo, useState } from "react";
import { catBreeds, dogBreeds, plans } from "@/data/site";
import { track } from "@/hooks/useAnalytics";
import type { PetType, PlanId, QuoteData, QuoteErrors } from "@/types";
import {
  CatIllustration,
  DogIllustration
} from "@/components/shared/SpeciesIllustrations";

type QuoteStep = 1 | 2 | 3 | 4;
type TextFieldName =
  | "petName"
  | "breed"
  | "ageYears"
  | "ageMonths"
  | "firstName"
  | "lastName"
  | "email"
  | "zipCode";

const initialData: QuoteData = {
  petType: "",
  petName: "",
  breed: "",
  ageYears: "",
  ageMonths: "",
  sex: "",
  altered: "",
  plan: "",
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

export function QuoteFlow() {
  const [currentStep, setCurrentStep] = useState<QuoteStep>(1);
  const [formData, setFormData] = useState<QuoteData>(initialData);
  const [errors, setErrors] = useState<QuoteErrors>({});
  const [planError, setPlanError] = useState("");
  const [submitted, setSubmitted] = useState(false);

  useEffect(() => {
    track("quote_started");
  }, []);

  const availableBreeds = formData.petType === "cat" ? catBreeds : dogBreeds;
  const progress = submitted ? 100 : currentStep * 25;

  const petSummary = useMemo(() => {
    const name = formData.petName || "Your pet";
    const breed = formData.breed || formData.petType || "pet";
    return `${name}, ${breed}`;
  }, [formData.breed, formData.petName, formData.petType]);

  const updateField = (name: TextFieldName, value: string) => {
    setFormData((current) => ({ ...current, [name]: value }));
    setErrors((current) => ({ ...current, [name]: undefined }));
  };

  const selectPetType = (petType: PetType) => {
    setFormData((current) => ({ ...current, petType, breed: "" }));
    track("species_selected", { species: petType });
  };

  const completeStep = (step: QuoteStep) => {
    track("quote_step_completed", { step });
  };

  const goToStep = (step: QuoteStep) => {
    setCurrentStep(step);
    setErrors({});
    setPlanError("");
  };

  const validateStepTwo = () => {
    const nextErrors: QuoteErrors = {};

    if (!formData.petName.trim()) {
      nextErrors.petName = "Enter your pet's name.";
    }

    if (!formData.breed.trim()) {
      nextErrors.breed = "Choose your pet's breed.";
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

    setErrors(nextErrors);
    return Object.keys(nextErrors).length === 0;
  };

  const validateContact = () => {
    const nextErrors: QuoteErrors = {};
    const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    const zipPattern = /^\d{5}$/;

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

    if (!formData.consent) {
      nextErrors.consent = "Confirm that we can email your quote.";
    }

    setErrors(nextErrors);
    return Object.keys(nextErrors).length === 0;
  };

  const handleStepOneNext = () => {
    if (!formData.petType) {
      return;
    }

    completeStep(1);
    goToStep(2);
  };

  const handleStepTwoNext = () => {
    if (!validateStepTwo()) {
      return;
    }

    completeStep(2);
    goToStep(3);
  };

  const handleStepThreeNext = () => {
    if (!formData.plan) {
      setPlanError("Choose a plan to continue.");
      return;
    }

    completeStep(3);
    goToStep(4);
  };

  const submitQuote = () => {
    if (!validateContact()) {
      return;
    }

    completeStep(4);
    track("quote_submitted", {
      species: formData.petType,
      breed: formData.breed,
      age: `${formData.ageYears} years, ${formData.ageMonths} months`,
      plan: formData.plan,
      zip: formData.zipCode
    });
    console.log("Quote submitted:", formData);
    setSubmitted(true);
  };

  return (
    <section className="bg-clv-paper px-5 py-24 md:px-8 md:py-28">
      <div className="mx-auto grid max-w-5xl gap-6 lg:grid-cols-[220px_minmax(0,580px)] lg:justify-center">
        <aside className="hidden rounded-2xl border border-clv-gray-border bg-white p-5 lg:block">
          <p className="text-xs uppercase tracking-[0.12em] text-clv-green">
            Your quote
          </p>
          <SummaryList formData={formData} />
        </aside>

        {!submitted && (
          <div className="rounded-full border border-clv-gray-border bg-white px-4 py-2 text-sm text-clv-gray lg:hidden">
            Your pet: <span className="font-semibold text-clv-charcoal">{petSummary}</span>
          </div>
        )}

        <div className="rounded-2xl border border-clv-gray-border bg-white p-6 md:p-10">
          {submitted ? (
            <Confirmation />
          ) : (
            <>
              <div className="mb-10">
                <div className="flex items-center justify-between gap-4">
                  <p className="text-xs text-clv-gray">Step {currentStep} of 4</p>
                  <button
                    type="button"
                    className="text-xs text-clv-gray underline-offset-4 hover:text-clv-green hover:underline"
                    onClick={() => goToStep(1)}
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
                      onNext={handleStepOneNext}
                    />
                  )}
                  {currentStep === 2 && (
                    <StepTwo
                      formData={formData}
                      errors={errors}
                      breeds={availableBreeds}
                      onUpdate={updateField}
                      onSex={(sex) => {
                        setFormData((current) => ({ ...current, sex }));
                        setErrors((current) => ({ ...current, sex: undefined }));
                      }}
                      onAltered={(altered) => {
                        setFormData((current) => ({ ...current, altered }));
                        setErrors((current) => ({ ...current, altered: undefined }));
                      }}
                      onNext={handleStepTwoNext}
                    />
                  )}
                  {currentStep === 3 && (
                    <StepThree
                      petName={formData.petName}
                      selectedPlan={formData.plan}
                      error={planError}
                      onSelect={(plan) => {
                        setFormData((current) => ({ ...current, plan }));
                        setPlanError("");
                        track("plan_selected", { plan });
                      }}
                      onNext={handleStepThreeNext}
                    />
                  )}
                  {currentStep === 4 && (
                    <StepFour
                      formData={formData}
                      errors={errors}
                      onUpdate={updateField}
                      onConsent={(consent) => {
                        setFormData((current) => ({ ...current, consent }));
                        setErrors((current) => ({ ...current, consent: undefined }));
                      }}
                      onSubmit={submitQuote}
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

function SummaryList({ formData }: { formData: QuoteData }) {
  const rows = [
    ["Pet", formData.petType || "Not selected"],
    ["Name", formData.petName || "Not added"],
    ["Breed", formData.breed || "Not added"],
    [
      "Age",
      formData.ageYears
        ? `${formData.ageYears}y ${formData.ageMonths || "0"}m`
        : "Not added"
    ],
    ["Plan", formData.plan || "Not selected"]
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
      <h1 className="font-display text-[28px] font-bold tracking-[-0.02em] text-clv-charcoal">
        Who are we covering today?
      </h1>
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
            Next →
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
  onNext
}: {
  formData: QuoteData;
  errors: QuoteErrors;
  breeds: string[];
  onUpdate: (name: TextFieldName, value: string) => void;
  onSex: (sex: "male" | "female") => void;
  onAltered: (altered: "yes" | "no") => void;
  onNext: () => void;
}) {
  const years = Array.from({ length: 16 }, (_, index) => String(index));
  const months = Array.from({ length: 12 }, (_, index) => String(index));
  const species = formData.petType || "pet";

  return (
    <div>
      <h1 className="font-display text-[28px] font-bold tracking-[-0.02em] text-clv-charcoal">
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
            placeholder="Search breeds"
            className={inputClass(errors.breed)}
            aria-describedby="breed-error"
            aria-invalid={Boolean(errors.breed)}
            onChange={(event) => onUpdate("breed", event.target.value)}
          />
          <datalist id="breed-options">
            {breeds.map((breed) => (
              <option key={breed} value={breed} />
            ))}
          </datalist>
        </Field>

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

        {formData.ageYears === "0" && formData.ageMonths && (
          <p className="rounded-lg bg-clv-sage-light px-4 py-3 text-sm font-semibold text-clv-green">
            Your pet is {formData.ageMonths} months old.
          </p>
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
      </div>
      <button
        type="button"
        className="mt-8 w-full rounded-md bg-clv-charcoal px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-clv-white transition-colors hover:bg-[#333]"
        onClick={onNext}
      >
        Next →
      </button>
    </div>
  );
}

function StepThree({
  petName,
  selectedPlan,
  error,
  onSelect,
  onNext
}: {
  petName: string;
  selectedPlan: PlanId | "";
  error: string;
  onSelect: (plan: PlanId) => void;
  onNext: () => void;
}) {
  return (
    <div>
      <h1 className="font-display text-[28px] font-bold tracking-[-0.02em] text-clv-charcoal">
        Pick the plan that&apos;s right for {petName || "your pet"}.
      </h1>
      <div className="mt-8 space-y-4">
        {plans.map((plan) => {
          const selected = selectedPlan === plan.id;
          return (
            <article
              key={plan.id}
              className={`rounded-xl border p-5 transition-all duration-200 ${
                selected
                  ? "border-2 border-clv-green bg-clv-sage-light"
                  : "border-clv-gray-border bg-white"
              }`}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <div className="flex items-center gap-2">
                    <h2 className="text-base font-semibold text-clv-charcoal">
                      {plan.title}
                    </h2>
                    {plan.recommended && (
                      <span className="rounded bg-clv-green px-2 py-1 text-[11px] font-semibold text-white">
                        Recommended
                      </span>
                    )}
                  </div>
                  {/* TODO: Connect to pricing API. */}
                  <p className="mt-3 font-display text-[32px] font-bold text-clv-green">
                    from {plan.price}
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
                  Select this plan
                </button>
              </div>
              <dl className="mt-4 grid grid-cols-2 gap-3 text-sm">
                <div>
                  <dt className="text-clv-gray">Deductible</dt>
                  <dd className="font-semibold text-clv-charcoal">
                    {plan.deductible}
                  </dd>
                </div>
                <div>
                  <dt className="text-clv-gray">Reimbursement</dt>
                  <dd className="font-semibold text-clv-charcoal">
                    {plan.reimbursement}
                  </dd>
                </div>
              </dl>
              <ul className="mt-4 space-y-2 text-sm text-clv-gray">
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
        Next →
      </button>
    </div>
  );
}

function StepFour({
  formData,
  errors,
  onUpdate,
  onConsent,
  onSubmit
}: {
  formData: QuoteData;
  errors: QuoteErrors;
  onUpdate: (name: TextFieldName, value: string) => void;
  onConsent: (consent: boolean) => void;
  onSubmit: () => void;
}) {
  return (
    <div>
      <h1 className="font-display text-[28px] font-bold tracking-[-0.02em] text-clv-charcoal">
        Almost there. Where do we send your quote?
      </h1>
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

        <div>
          <div className="flex items-start gap-3">
            <input
              id="contactConsent"
              type="checkbox"
              className="mt-1 h-4 w-4 accent-clv-green"
              checked={formData.consent}
              aria-describedby="consent-error"
              aria-invalid={Boolean(errors.consent)}
              onChange={(event) => onConsent(event.target.checked)}
            />
            <label
              htmlFor="contactConsent"
              className="text-sm leading-[1.6] text-clv-gray"
            >
              I agree to receive my quote by email. No spam, unsubscribe any time.
            </label>
          </div>
          {errors.consent && (
            <p id="consent-error" className="mt-2 text-sm text-red-700">
              {errors.consent}
            </p>
          )}
        </div>
      </div>
      <button
        type="button"
        className="mt-8 w-full rounded-md bg-clv-green px-7 py-[13px] text-sm font-semibold tracking-[0.02em] text-white transition-colors hover:bg-clv-green-dark"
        onClick={onSubmit}
      >
        Get my quote →
      </button>
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
      <label htmlFor={id} className="mb-2 block text-sm font-semibold text-clv-charcoal">
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
      <div className="flex gap-3" role="group" aria-label={label}>
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

function Confirmation() {
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
      <h1 className="mt-8 font-display text-[28px] font-bold tracking-[-0.02em] text-clv-charcoal">
        Your quote is on its way.
      </h1>
      <p className="mx-auto mt-3 max-w-sm text-base leading-[1.75] text-clv-gray">
        Check your inbox in the next 2 minutes. We&apos;ve also saved your info so
        you can pick up where you left off.
      </p>
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
