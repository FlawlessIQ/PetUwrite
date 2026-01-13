# Underwriting gaps & improvements

Last updated: 2026-01-09

This is a review of the current medical history + underwriting requirements and where the implementation has gaps.

## Summary (highest-risk gaps)

1) **Configured underwriting rules may not apply for unauthenticated quotes**
- Risk: the client reads `admin_settings/underwriting_rules` directly. If Firestore rules restrict reads to authenticated users, unauth quote flows will fall back to defaults.
- Impact: inconsistent eligibility outcomes, inconsistent exclusions, and reduced auditability.

2) **Medical underwriting decisions/exclusions are not reliably carried into checkout/binding when no case ID exists**
- Risk: `MedicalUnderwritingScreen` only persists decisions when `underwritingCaseId` exists.
- Impact: a user can complete medical underwriting, select a plan, authenticate at checkout, and bind a policy without a persisted underwriting decision snapshot and possibly without exclusions stamped.

3) **Condition taxonomy mismatch + shallow structured requirements**
- Risk: condition names are free-form strings in multiple places (multi-select list, text, vet record parsing).
- Impact: brittle matching for `criticalConditions` / `excludableConditions`, inconsistent underwriting behavior, and difficulty producing defensible exclusions.

## Requirements coverage review

### A) Medical history intake requirements (what should be collected)
For each disclosed pre-existing condition (especially chronic ones like diabetes), underwriting typically needs:
- Condition name + standardized code (taxonomy)
- Diagnosis month/year (or age at diagnosis)
- Current status: active/resolved/managed/stable
- Treatment plan summary (diet/insulin/monitoring, etc.)
- Medication details (drug, dose, frequency, start/end)
- Last evaluation and follow-up schedule
- Complications / comorbidities / hospitalizations
- Vet/clinic attribution (at minimum clinic name + last visit date)
- Attestation: "true and complete" disclosure acknowledgement

Current implementation:
- UI collects conditions/meds/vet visits but does not enforce the above per-condition completeness (beyond a minimal “supporting detail required” gate for select conditions).

### B) Underwriting rules requirements (eligibility + exclusions)
Rules engine supports:
- Hard declines: excluded breeds, age limits, critical conditions, max risk score
- Conditional approvals: excludable conditions → exclusions list

Gaps:
- Default rules do not include `excludableConditions`, so conditional approvals may never occur unless configured.
- Matching is substring-based on human-readable strings → easy to miss (e.g., “Diabetes mellitus”, “DM”, “insulin dependent”).

### C) Decision persistence + audit requirements
Desired properties:
- Every bind has a decision snapshot and exclusions stamped.
- Every underwriting decision is reproducible and traceable (inputs + versioned rules + engine version).

Current gaps:
- Decision persistence is conditional on an `underwritingCaseId`.
- Eligibility audit logging only occurs when a `quoteId` is passed to the risk scoring engine; most quote flows don’t pass it.

## Recommended improvements (prioritized)

### P0 (correctness/compliance)
1) **Make underwriting rules available to unauth quote flows safely**
- Option A (preferred): create a Cloud Function `getUnderwritingRulesPublic()` returning a sanitized rules subset for quotes.
- Option B: store a separate Firestore doc `public_config/underwriting_rules_public` that is readable unauthenticated.
- Option C: allow read to `admin_settings/underwriting_rules` for unauth users (least preferred if you consider rules sensitive).

2) **Always stamp exclusions into policy at bind time**
- Ensure checkout receives the current exclusions list even when there is no underwriting case.
- If you keep the “case lane” concept, create the underwriting case immediately after auth at checkout and persist the decision used to generate exclusions.

3) **Force a persisted decision whenever medical underwriting ran**
- If the user went through `MedicalUnderwritingScreen`, require an `underwritingCaseId` before allowing checkout OR generate a deterministic decision snapshot stored on the policy request.

### P1 (quality/defensibility)
4) **Introduce a condition taxonomy + synonym mapping**
- Use canonical IDs (e.g., `COND_DIABETES`) in UI selections, and map display labels separately.
- Add synonyms for vet record parsing and user free-text.
- Update rules to match canonical IDs instead of substrings.

5) **Per-condition completeness requirements**
- For high-impact conditions (Diabetes, CHF, CKD, cancer history): require minimum data per condition:
  - diagnosis month/year
  - current status
  - at least one of: medication OR active monitoring/treatment plan
  - last vet visit date within a range (e.g., last 18 months) OR explicit “no recent care” flag

6) **Add explicit attestation + disclosure acknowledgement**
- Require a checkbox like “I confirm this medical history is complete and accurate.”
- Log the attestation and the versioned rules/engine versions used.

### P2 (UX + ops)
7) **Explain exclusions clearly at plan selection**
- If rules engine excludes conditions, show a “coverage exclusions” callout before checkout.
- If medical underwriting generated exclusions, show them alongside the plan.

8) **Better separation: quote vs bind**
- Keep quotes viewable unauthenticated, but present “final coverage subject to underwriting and record review” consistently.

## Concrete next steps (implementation map)

- Underwriting rules distribution: adjust `UnderwritingRulesEngine.getRules()` to read from a public endpoint/doc for unauth quote flows.
- Exclusions propagation: pass exclusions through route arguments from medical underwriting → plan selection → checkout; then stamp them in `PolicyService.createPolicy()`.
- Persistence: add a “bind requires decision” check when medical underwriting ran (even without a case ID), or create a case at checkout after auth.

