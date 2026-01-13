# Underwriting (Current State)

Last updated: 2026-01-09

This document describes the underwriting rules and medical-underwriting approach **as implemented in the codebase today** (Flutter client + Firebase).

## Principles (compliance posture)

- **AI does not approve/decline policies.**
  - AI is used for narrative risk analysis, explainability, and UX assistance.
  - Eligibility, exclusions, and binding enforcement are rules-based and/or deterministic.
- **Two lanes**
  - **Standard lane**: eligible pet → plan selection → checkout → bind.
  - **Medical underwriting lane**: cases with disclosed conditions / exclusions → collect medical history → show plans → bind (with exclusions/decision snapshot).

## Data we collect (customer-facing)

### Quote intake (conversational + wizard)
Collected in the quote flows:
- Pet demographics: species, breed, age, weight, sex, spay/neuter
- Owner basics: email + ZIP/state
- Health disclosures:
  - `hasPreExistingConditions` (yes/no)
  - `preExistingConditionTypes` (multi-select list of condition labels)
  - `isReceivingTreatment` (yes/no/managed)

Implementation:
- Conversational: `ConversationalQuoteFlow` builds a `Pet` with `preExistingConditions` and `isReceivingTreatment`.
- Wizard: `QuoteFlowScreen` captures optional conditions text and routes complex cases into medical underwriting.

### Medical underwriting collection
Medical underwriting collects **structured medical history**:
- Conditions (name, diagnosis date, status, treatment, notes)
- Medications (name, dosage, frequency, dates, purpose, ongoing)
- Allergies (free-text list)
- Vet visits (date, clinic/vet, type, diagnosis/treatment/notes)

Implementation:
- UI and collection: `MedicalUnderwritingScreen`
- Models: `MedicalCondition`, `Medication`, `VetVisit` (and `Pet` fields `medicalConditions`, `medications`, `vetHistory`)

## Underwriting rules (eligibility + exclusions)

### Source of truth
- Firestore document: `admin_settings/underwriting_rules`
- Engine: `UnderwritingRulesEngine`
- Rules are cached in-memory for 15 minutes.

### Rule schema (effective)
The rules engine expects these keys (defaults apply if missing):
- `enabled: bool`
- `maxRiskScore: int` (default 90)
- `minAgeMonths: int` (default 2)
- `maxAgeYears: int` (default 14)
- `excludedBreeds: string[]` (substring match, case-insensitive)
- `criticalConditions: string[]` (substring match, case-insensitive) → **decline**
- `excludableConditions: string[]` (substring match, case-insensitive) → **approve with exclusions**

### Outcomes
`EligibilityResult` supports:
- **Eligible** (standard approval)
- **Eligible with exclusions** (`hasExclusions = true`, `excludedConditions = [...]`)
- **Ineligible** (decline with a reason + violated rule metadata)

### Where it runs
- `quickCheck(pet, conditions)`
  - Early rejection for: excluded breeds, critical conditions, age limits.
- `checkEligibility(pet, riskScore, conditions)`
  - Full check including max risk score and excludable conditions.

## Risk scoring (non-binding)

- Engine: `RiskScoringEngine`
- Produces: `RiskScore` (overall score + factor breakdown + AI narrative)
- AI integration: `GPTService(model: 'gpt-5.2')` via Firebase Cloud Function `chatCompletion`

Important: risk score is **not** the approval decision; it feeds pricing/UX and is then checked against underwriting rules.

## Deterministic underwriting decision (binding artifact)

- Engine: `UnderwritingDecisionEngine`
- Input: `EligibilityResult`
- Output: `UnderwritingDecision` with:
  - outcome: `approve` | `approveWithExclusions` | `decline`
  - reason codes (e.g., `UW_DECLINE`, `UW_APPROVE_WITH_EXCLUSIONS`)
  - structured exclusions (`PolicyExclusion`)

## Routing and enforcement points

### Route to medical underwriting
Current routing logic routes to medical underwriting when any of:
- disclosed pre-existing conditions
- `isReceivingTreatment == true`
- rules engine indicates exclusions (`hasExclusions == true`)

Implementation:
- `AIAnalysisScreen` routes to `MedicalUnderwritingScreen` when underwriting is required.
- `QuoteFlowScreen` routes complex cases to `MedicalUnderwritingScreen` before plan selection.

### Medical underwriting step validation (current)
`MedicalUnderwritingScreen` includes a minimal guardrail so users can’t “click through” chronic disclosures without adding detail:
- If the pet has declared conditions: requires at least one condition item.
- For certain high-detail conditions (e.g., Diabetes) or active treatment:
  - requires either medication OR treatment/notes before continuing
  - requires at least one medication OR vet visit before completing

### Bind-time enforcement
At policy creation time:
- If `underwritingCaseId` is present, the app requires `underwriting_cases/{caseId}/decisions/current` to exist.
- The policy is stamped with an underwriting snapshot (decision + exclusions).

Implementation:
- `ConfirmationScreen` fetches current decision when `underwritingCaseId` exists and blocks binding if missing.

## Persistence model

Underwriting case lane uses:
- `underwriting_cases/{caseId}` (summary + snapshots)
- `underwriting_cases/{caseId}/medical_history/current`
- `underwriting_cases/{caseId}/decisions/current`
- `underwriting_cases/{caseId}/events/*`

Note: case creation currently requires authentication (`UnderwritingCaseService.createCase`).

## Known limitations (current)

- If the user goes through medical underwriting **without** an `underwritingCaseId`, the decision may not be persisted and bind-time enforcement may not run.
- If Firestore rules prevent unauthenticated reads of `admin_settings/underwriting_rules`, the rules engine falls back to default rules (which may not match admin-configured rules).

