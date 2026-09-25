# Underwriting Flow (Current Implementation)

Date: 2026-01-14

This document specifies how underwriting works **today** in this repository.
It is intended to be operationally precise and code-faithful.

---

## 1) System goals + invariants

### System goals

- **AI is assistive, not the underwriter**: AI services are used for text extraction / enrichment (e.g., vet record parsing, risk narrative). Coverage decisions are produced by deterministic system code.
- **Fail-closed underwriting**: when required data is missing, uncertain, or an upstream pipeline fails, the system does not show pricing and routes to deterministic self-serve (`NEED_MORE_INFO`) or deterministic decline.
- **Zero-human automation**: there is no manual-review queue. Ambiguity deterministically routes to `NEED_MORE_INFO` or deterministic `DECLINED`.
- **No customer self-diagnosis**: customers are not asked to self-determine clinical attributes (e.g., severity/chronicity/confirmed-by). When evidence is missing, the system requests verifiable vet records instead.
- **Deterministic critical denies**: a small set of critical condition codes deterministically deny when they are **confirmed**, even if AI pipelines failed.
- **Pricing is gated**: the UI must not show pricing unless all explicit approval gates are satisfied.

### Invariants (what must always be true)

Each invariant includes where it is enforced (file + function/symbol).

1. **Pricing may only be shown when `pricingEnabled == true`, `underwritingStatus == 'APPROVED'`, and `integrityPassed == true`.**
   - Enforced in [lib/services/pricing_gate.dart](lib/services/pricing_gate.dart): `PricingGate.isPricingAllowed(...)`
   - Used by [lib/screens/plan_selection_screen.dart](lib/screens/plan_selection_screen.dart): `_PlanSelectionScreenState._generatePlans()`

2. **The system fails closed on missing route args (no args => no pricing).**
   - Enforced in [lib/services/pricing_gate.dart](lib/services/pricing_gate.dart): `PricingGate.isPricingAllowed(...)` returns `false` when `routeArguments == null`.

3. **Underwriting decisions are not produced by an LLM.**
   - Decisions are produced by deterministic engines:
     - [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart): `UnderwritingIntegrityEngine.assess(...)`
     - [lib/services/underwriting_decision_engine.dart](lib/services/underwriting_decision_engine.dart): `UnderwritingDecisionEngine.buildFromEligibility(...)`

4. **Deterministic critical denies occur before AI-failure fail-closed routing.**
   - Enforced in [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart): `UnderwritingIntegrityEngine.assess(...)`
     - It checks critical confirmed facts first.
  - Only after that it applies the `aiFailure => NEED_MORE_INFO / DECLINED` gate.

5. **AI pipeline failure routes to `NEED_MORE_INFO` with pricing disabled on first occurrence, and to `DECLINED` when persistent (unless a deterministic critical deny already fired).**
   - Enforced in [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart): `UnderwritingIntegrityEngine.assess(...)` (`if (aiFailure) ...`)

6. **Any `unknown` or `suspected` medical fact status routes to `NEED_MORE_INFO` (fail closed), except suspected/unknown *critical* conditions which deterministically `DECLINED` (unless explicitly rule-out language).**
   - Enforced in [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart): `UnderwritingIntegrityEngine.assess(...)` (`hasUncertainStatus` check)

7. **Medical facts builder does not guess missing structured fields.**
   - Enforced in [lib/services/medical_facts_builder.dart](lib/services/medical_facts_builder.dart): `MedicalFactsBuilder.build(...)`
  - User-entered conditions become placeholder facts (no guessing). Underwriting decisions in this flow rely on `conditionCode` + `status`; other structured fields may remain `unknown`.

8. **If conditions are disclosed, approval requires verifiable vet context.**
   - Enforced in [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart): `UnderwritingIntegrityEngine.assess(...)`
  - When `medicalFactsRequired == true` and `medicalFacts` is non-empty, approval is blocked unless vet context is present (e.g., `vetDocumentHashes` or parsed vet text).
  - Outcome: `NEED_MORE_INFO` with reason `VET_RECORDS_REQUIRED`.

9. **Repeated unresolved `NEED_MORE_INFO` is deterministically escalated to `DECLINED`.**
   - Enforced by:
  - [lib/screens/medical_underwriting_screen.dart](lib/screens/medical_underwriting_screen.dart): `MedicalUnderwritingScreen` loop-breaker logic
  - [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart): `userFailedToProvideRequiredEvidence => REQUIRED_EVIDENCE_NOT_PROVIDED`
  - Persisted via [lib/services/underwriting_case_service.dart](lib/services/underwriting_case_service.dart): `incrementNeedMoreInfoAttempts(...)` / `resetNeedMoreInfoAttempts(...)`

10. **Deterministic eligibility (age/breed/risk threshold) ignores condition strings in this flow.**
   - Enforced in [lib/services/underwriting_rules_engine.dart](lib/services/underwriting_rules_engine.dart): `UnderwritingRulesEngine.checkEligibilityDeterministic(...)` delegates to `checkEligibility(..., const <String>[])`.
   - Used by:
     - [lib/services/risk_scoring_engine.dart](lib/services/risk_scoring_engine.dart): `RiskScoringEngine.calculateRiskScore(...)`
     - [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart): `UnderwritingIntegrityEngine.assess(...)`

11. **Rules engine unavailable/disabled fails closed (deterministic decline).**
   - Rule source failure and disable are expressed as `EligibilityResult.ineligible(... ruleViolated: 'RULES_UNAVAILABLE')` in:
     - [lib/services/underwriting_rules_engine.dart](lib/services/underwriting_rules_engine.dart): `UnderwritingRulesEngine.getRules()` and `UnderwritingRulesEngine.checkEligibility(...)`
   - Interpreted as declined in:
     - [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart): `UnderwritingIntegrityEngine.assess(...)` (`if (eligibility.ruleViolated == 'RULES_UNAVAILABLE') ...`)

---

## 2) End-to-end flow diagram (text-based)

This is the primary quote → underwriting → plan selection pipeline.

### Key types / payload shapes

- `RiskScore` (model): passed between quote flow, analysis screen, underwriting screen, plan selection.
- `VetRecordParseResult` (service type):
  - `parsedData: VetRecordData`
  - `extractedText: String`
  - `aiFailed: bool`
  - `confidence: double`
  - Defined in [lib/services/vet_history_parser.dart](lib/services/vet_history_parser.dart)
- `MedicalConditionFact` (strict model) defined in [lib/models/medical_condition_fact.dart](lib/models/medical_condition_fact.dart)
  - Fields: `conditionCode`, `severity`, `chronicity`, `confirmedBy`, `status`
  - Note: customers are not asked to fill clinical attributes. Underwriting gating in this flow relies on `conditionCode` + `status`; other fields may remain `unknown`.
- `MedicalFactsBuildResult` defined in [lib/services/medical_facts_builder.dart](lib/services/medical_facts_builder.dart)
  - Fields: `facts: List<MedicalConditionFact>`, `aiFailure: bool`, `criticalConditionDetected: bool`
- `UnderwritingAssessment` defined in [lib/models/underwriting_assessment.dart](lib/models/underwriting_assessment.dart)
  - Fields: `underwritingStatus: UnderwritingStatus`, `pricingEnabled: bool`, `reason: String`, `decision?: UnderwritingDecision`
- Route args map to plan selection expects (at minimum):
  - `pricingEnabled: bool`
  - `underwritingStatus: String` (`'APPROVED'|'DENIED'|'DECLINED'|'NEED_MORE_INFO'|'INCOMPLETE'`)
  - `integrityPassed: bool`
  - Optional: `underwritingReason: String`, `exclusions` / `excludedConditions`

- Integrity assessment inputs include (non-exhaustive):
  - `vetDocumentHashes: List<String>` (verifiable vet context)
  - `ruleOutConditionCodes: Set<String>` (to avoid false declines on “rule out” language)

### Numbered flow

1. **User starts a quote**
   - Screen: [lib/screens/conversational_quote_flow.dart](lib/screens/conversational_quote_flow.dart)
   - Pet/Owner are created from answers:
     - `_createPetFromAnswers()` → `Pet` (includes `preExistingConditions`)
     - `_createOwnerFromAnswers()` → `Owner`

2. **(Optional) Early “quick check” heads-up**
   - Trigger: user selects condition types.
   - Code: [lib/screens/conversational_quote_flow.dart](lib/screens/conversational_quote_flow.dart): `_handleConditionSelection(...)`
   - Calls: `UnderwritingRulesEngine().quickCheck(pet, conditions)`.
   - Result stored as `_earlyEligibility` and used only for early messaging / early decline dialog.

3. **Risk scoring and deterministic rules eligibility**
   - Code: [lib/screens/conversational_quote_flow.dart](lib/screens/conversational_quote_flow.dart): `_completeQuote()`
   - Calls: `RiskScoringEngine.calculateRiskScoreWithEligibility(...)`.
   - Inside risk scoring:
     - Computes `RiskScore`.
     - Calls deterministic eligibility (conditions ignored):
       - [lib/services/risk_scoring_engine.dart](lib/services/risk_scoring_engine.dart): `UnderwritingRulesEngine.checkEligibilityDeterministic(pet: pet, riskScore: riskScore)`.

4. **Navigate to AI analysis screen**
   - Code: [lib/screens/conversational_quote_flow.dart](lib/screens/conversational_quote_flow.dart): `_completeQuote()` → `Navigator.push(...)` to `AIAnalysisScreen`.
   - Route args include:
     - `pet`, `owner`, `riskScore`
     - `needsMedicalUnderwriting: bool`
     - `hasExclusions: bool`, `excludedConditions: List<String>` (from rules eligibility)

5. **AI analysis screen decides whether to route through medical underwriting**
   - Code: [lib/screens/ai_analysis_screen_v2.dart](lib/screens/ai_analysis_screen_v2.dart): `_AIAnalysisScreenState._startAnalysis()`
   - Determines `requiresUnderwriting` based on:
     - `pet.preExistingConditions` non-empty
     - OR route arg exclusions present
     - OR `needsMedicalUnderwriting == true`
   - If underwriting required: `Navigator.pushReplacement(...)` → `MedicalUnderwritingScreen`.

6. **Vet docs uploaded (or not)**
   - Screen: [lib/screens/medical_underwriting_screen.dart](lib/screens/medical_underwriting_screen.dart)
   - Upload paths:
     - PDFs: `_uploadVetRecordPdfs()`
     - Images: `_uploadVetRecordImages()`
     - Camera: `_takeVetRecordPhoto()`
   - Parser calls (lenient):
     - [lib/services/vet_history_parser.dart](lib/services/vet_history_parser.dart):
       - `parseUploadedPdfBytesForCaseLenient(...)`
       - `parseUploadedImageBytesForCaseLenient(...)`
   - Captured on the screen:
     - `_rawVetTexts.add(result.extractedText)` (always used for deterministic backstop)
     - `_aiVetExtraction.add(result.parsedData)` (structured AI parse output when available)
     - `if (result.aiFailed) _aiVetParseFailed = true`

7. **User-entered conditions (no customer self-diagnosis)**
   - The screen captures the condition list (disclosures) but does not require customers to select clinical attributes like severity/chronicity/confirmed-by.
   - Medical facts are constructed deterministically using placeholders for disclosed conditions, plus any vet-record extraction/backstops.

8. **Facts builder merge (user + AI + deterministic backstop)**
   - Code: [lib/screens/medical_underwriting_screen.dart](lib/screens/medical_underwriting_screen.dart): `_complete()`
   - Calls: [lib/services/medical_facts_builder.dart](lib/services/medical_facts_builder.dart):
     - `MedicalFactsBuilder.build(userEnteredConditions: ..., aiVetExtraction: ..., rawVetTexts: ..., aiFailure: ...)`
   - Builder merges three sources:
     - (a) user conditions (placeholder facts; no guessing)
     - (b) AI vet diagnoses/treatments (`VetRecordData`)
     - (c) deterministic keyword extraction (`_extractFactsFromVetText(...)`)
   - Output: `MedicalFactsBuildResult` including `criticalConditionDetected`.

9. **Integrity engine assess (final underwriting gating + decision)**
   - Code: [lib/screens/medical_underwriting_screen.dart](lib/screens/medical_underwriting_screen.dart): `_complete()`
   - Calls: [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart):
     - `UnderwritingIntegrityEngine.assess(pet, riskScore, medicalFacts, medicalFactsRequired, aiFailure)`
   - Output: `UnderwritingAssessment`.

10. **Rules engine deterministic eligibility (age/breed/risk thresholds)**
   - Called inside integrity engine:
     - [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart): `assess(...)`
     - Uses `UnderwritingRulesEngine.checkEligibilityDeterministic(...)` (conditions ignored).

11. **Decision engine creates decision snapshot**
   - Called inside integrity engine:
     - [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart): `assess(...)`
     - Calls [lib/services/underwriting_decision_engine.dart](lib/services/underwriting_decision_engine.dart):
       - `_decisionEngine.buildFromEligibility(eligibility: finalEligibility)`
   - Produces `UnderwritingDecision` with `outcome` and optional `PolicyExclusion[]`.

12. **UI navigation to plan selection**
   - If `assessment.underwritingStatus != approved`: show blocking dialog and stop.
     - Code: [lib/screens/medical_underwriting_screen.dart](lib/screens/medical_underwriting_screen.dart): `_complete()`
   - If approved:
     - `Navigator.pushReplacement(...)` to `PlanSelectionScreen` with route args:
       - `pricingEnabled: true`
       - `underwritingStatus: underwritingStatusToString(computedStatus)`
       - `underwritingReason: computedReason`
       - `integrityPassed: (assessment.underwritingStatus == approved)`
       - optional: `exclusions` list (serialized)
       - `underwritingSnapshot` (decision + medical facts + flags)

13. **PricingGate evaluation**
   - Code: [lib/screens/plan_selection_screen.dart](lib/screens/plan_selection_screen.dart): `_generatePlans()`
   - Calls: [lib/services/pricing_gate.dart](lib/services/pricing_gate.dart): `PricingGate.isPricingAllowed(routeArgs)`
   - If not allowed:
     - `_pricingAllowed = false`, show “Pricing is unavailable” UI.

14. **Checkout receives underwriting snapshot/exclusions**
   - Plan selection continues to `/checkout`:
     - [lib/screens/plan_selection_screen.dart](lib/screens/plan_selection_screen.dart): `_buildContinueButton()`
   - Payload includes:
     - `underwritingCaseId`, `exclusions`, `underwritingSnapshot`
   - Route wiring in [lib/main.dart](lib/main.dart): `onGenerateRoute` for `/checkout`.

---

## 3) State machine for underwriting

This section defines the state machine represented by `UnderwritingStatus` and related outputs.

### State: APPROVED

- Trigger:
  - `UnderwritingIntegrityEngine.assess(...)` returns `UnderwritingStatus.approved`.
  - Requires:
    - No deterministic critical confirmed facts
    - `aiFailure == false`
    - No `unknown`/`suspected` medical facts
    - Medical facts complete if required
    - Deterministic eligibility is eligible (and rules not unavailable)
- UI result:
  - [lib/screens/medical_underwriting_screen.dart](lib/screens/medical_underwriting_screen.dart): `_complete()` navigates to plan selection.
- Pricing allowed:
  - Yes, but only if the route args are explicitly set to:
    - `pricingEnabled: true`
    - `underwritingStatus: 'APPROVED'`
    - `integrityPassed: true`

### State: DENIED

- Trigger:
  - Deterministic critical code is present and `status == confirmed`.
  - Code: [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart): `assess(...)` critical loop.
- UI result:
  - Medical underwriting shows a blocking dialog (“Application declined”).
  - Code: [lib/screens/medical_underwriting_screen.dart](lib/screens/medical_underwriting_screen.dart): `_complete()`.
- Pricing allowed:
  - No (`pricingEnabled: false` in the assessment, and plan screen gating blocks).

### State: MANUAL_REVIEW

This state no longer exists in the current system.

### State: NEED_MORE_INFO

- Trigger (any of):
  - AI pipeline failure on first occurrence (self-serve retry requested).
  - Any medical fact has `status == unknown` or `suspected`.
  - Rule-out/uncertainty language detected in vet text (“rule out HCM”, “possible cancer”).
  - Missing or incomplete medical facts.
- Output behavior:
  - `pricingEnabled: false`
  - `requiredEvidence: EvidenceRequirement[]` populated (deterministic checklist).
- Pricing allowed:
  - No.

### State: DECLINED

- Trigger (any of):
  - Suspected or unknown *critical* condition (HCM/CHF/ACTIVE_CANCER/CKD_STAGE_3_PLUS), unless explicitly marked as rule-out language.
  - AI pipeline failure persists beyond the configured threshold.
  - Rules engine unavailable.
- Pricing allowed:
  - No.

### State: INCOMPLETE

- Trigger (any of):
  - Medical facts required but `medicalFacts.isEmpty`.
  - Medical facts required but at least one is not `isComplete`.
- UI result:
  - Medical underwriting shows blocking dialog (“Underwriting incomplete”).
- Pricing allowed:
  - No.

### “APPROVED_WITH_EXCLUSIONS”

- Note: There is no separate `UnderwritingStatus` enum value for this.
- Representation:
  - `UnderwritingStatus.approved`
  - `UnderwritingAssessment.reason == 'APPROVED_WITH_EXCLUSIONS'`
  - `UnderwritingDecision.outcome == approveWithExclusions`
  - `UnderwritingDecision.exclusions` is non-empty
- UI result:
  - Plan selection displays exclusions callout when route args include `exclusions`/`excludedConditions`.
  - Code: [lib/screens/plan_selection_screen.dart](lib/screens/plan_selection_screen.dart): `_getExclusionNamesFromRoute()` and `_buildExclusionsCallout()`.
- Pricing allowed:
  - Yes (still requires PricingGate approval).

---

## 4) Decision rules (as implemented)

### 4.1 Deterministic critical deny list

- Source: [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart)
- `deterministicCriticalCodes`:
  - `HCM`
  - `CHF`
  - `ACTIVE_CANCER`
  - `CKD_STAGE_3_PLUS`

**Rule**: If any `MedicalConditionFact` has `conditionCode` in that set and `status == MedicalConditionStatus.confirmed`, underwriting returns:

- `UnderwritingAssessment.underwritingStatus = denied`
- `pricingEnabled = false`
- `reason = 'CRITICAL_CONDITION_$code'`
- `decision` built from `EligibilityResult.ineligible(ruleViolated: 'DETERMINISTIC_CRITICAL_CONDITION', violatedValue: code)`

### 4.2 How “confirmed” is determined for backstop vet-text facts

- Source: [lib/services/medical_facts_builder.dart](lib/services/medical_facts_builder.dart)
- Deterministic backstop extraction runs over each `_rawVetTexts` element.

Highlights (exact behavior):

- HCM:
  - If text contains `hcm` or `hypertrophic cardiomyopathy`, builder emits an `HCM` fact.
  - It is **confirmed** only when all are true:
    - echo evidence keyword present (`echo|echocardiogram|echocardio`)
    - confirmation language present (`consistent with|findings are consistent with|diagnosed|diagnosis|confirms|shows|evidence of`)
    - no nearby rule-out/uncertainty language near the match (`rule out|r/o|possible|suspect|concern for|cannot rule out|evaluate for|recommend echo|echo recommended`)
  - Otherwise it is emitted as `suspected`.

- Murmur:
  - If text contains `murmur`, builder emits `HEART_MURMUR` as `suspected`.

- CHF:
  - If text contains `chf|congestive heart failure|heart failure`, builder emits `CHF`.
  - It is `confirmed` when confirmation language (or `dx`/`diagnos*`) exists and no nearby rule-out.

- CKD stage 3+:
  - If text matches CKD/renal keywords plus `stage 3/4/5` or `IRIS stage 3/4/5`, builder emits `CKD_STAGE_3_PLUS`.
  - It is `confirmed` when confirmation language (or `dx`/`diagnos*`/`confirmed`) exists and no nearby rule-out.

- Cancer:
  - Builder will emit `ACTIVE_CANCER` only if:
    - a cancer keyword is present AND
    - malignant signal is present (`malignant|metastatic|carcinoma|sarcoma|lymphoma|adenocarcinoma|osteosarcoma|hemangiosarcoma`) AND
    - benign block terms are not present (`benign|lipoma|cyst|sebaceous|hyperplasia`) AND
    - no nearby rule-out (for confirmation), and confirm language exists.
  - **"tumor" alone does not cause cancer** in the backstop logic.

### 4.3 Suspected/unknown facts

- Source: [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart)
- Rules:
  - If any *critical* condition is `suspected` or `unknown`, underwriting returns:
    - `UnderwritingStatus.declined`
    - `pricingEnabled: false`
    - `reason: 'SUSPECTED_CRITICAL_CONDITION'`
    - `decision: non-null` (decline)
    - Exception: if the code was detected in explicit rule-out language, the system returns `NEED_MORE_INFO` instead.
  - If any non-critical condition is `suspected`/`unknown`, underwriting returns:
    - `UnderwritingStatus.needMoreInfo`
    - `pricingEnabled: false`
    - `reason: 'MISSING_OR_UNCERTAIN_MEDICAL_FACTS'`
    - `decision: null`
    - `requiredEvidence: non-empty`

### 4.4 Exclusions for confirmed non-critical conditions

- Source: [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart)
- Rule:
  - For each `MedicalConditionFact`:
    - If `status == confirmed` and `conditionCode` is **not** in `deterministicCriticalCodes`, add the code to `exclusions`.
  - If deterministic eligibility is eligible and exclusions exist:
    - `EligibilityResult.eligibleWithExclusions(excludedConditions: exclusions)`
    - decision outcome becomes `approveWithExclusions`
    - `UnderwritingStatus` is still `approved`

### 4.5 Rules engine unavailable/disabled

- Source: [lib/services/underwriting_rules_engine.dart](lib/services/underwriting_rules_engine.dart)
- If rules are unavailable or `enabled == false`, `checkEligibility(...)` returns:
  - `EligibilityResult.ineligible(... ruleViolated: 'RULES_UNAVAILABLE')`
- Integrity engine interprets that as:
  - `UnderwritingStatus.declined`, `pricingEnabled: false`, `reason: 'RULES_UNAVAILABLE'`

### 4.6 AI failure handling

- Source: [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart)
- If `aiFailure == true` (after deterministic critical check):
  - First occurrence: `UnderwritingStatus.needMoreInfo`, `pricingEnabled: false`, `reason: 'AI_FAILURE'`, `requiredEvidence: non-empty`
  - Persistent: `UnderwritingStatus.declined`, `pricingEnabled: false`, `reason: 'AI_FAILURE_PERSISTED'`

### 4.7 Vet records required when conditions are disclosed

- Source: [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart)
- Rule:
  - If `medicalFactsRequired == true` and `medicalFacts.isNotEmpty` and the pet is otherwise deterministically eligible, the system requires verifiable vet context.
  - Verifiable vet context includes any of:
    - `vetDocumentHashes` non-empty
    - `rawVetTextsForIntegrity` non-empty
    - `aiVetExtractionForIntegrity` non-empty
- Outcome when missing:
  - `UnderwritingStatus.needMoreInfo`, `pricingEnabled: false`, `reason: 'VET_RECORDS_REQUIRED'`
  - `requiredEvidence` includes `PROVIDE_MEDICAL_HISTORY`

### 4.8 Deterministic escalation after repeated unresolved `NEED_MORE_INFO`

- Source:
  - [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart): `userFailedToProvideRequiredEvidence`
  - Triggered by loop-breaker logic in [lib/screens/medical_underwriting_screen.dart](lib/screens/medical_underwriting_screen.dart)
- Rule:
  - If the user has repeatedly hit `NEED_MORE_INFO` without providing required evidence, the system deterministically declines.
- Outcome:
  - `UnderwritingStatus.declined`, `pricingEnabled: false`, `reason: 'REQUIRED_EVIDENCE_NOT_PROVIDED'`

AI failure signals come from:

- Vet parsing (lenient): the parsing returns `VetRecordParseResult.aiFailed == true`.
  - Screen sets `_aiVetParseFailed = true`.
  - Source: [lib/screens/medical_underwriting_screen.dart](lib/screens/medical_underwriting_screen.dart): `_uploadVetRecordPdfs()`, `_uploadVetRecordImages()`, `_takeVetRecordPhoto()`

---

## 5) Example scenarios (code-faithful)

Each example shows the **final `UnderwritingAssessment`** shape.

> Note: These examples focus on the medical-underwriting/integrity-engine assessment, because that is the gate used by PricingGate + plan rendering.

### Example 1: Healthy pet, no docs → approved → pricing allowed

Path:
- Conversational quote → AIAnalysisScreen determines `requiresUnderwriting == false`.
- AIAnalysisScreen pushes PlanSelectionScreen with explicit approval args.

Route args set in [lib/screens/ai_analysis_screen_v2.dart](lib/screens/ai_analysis_screen_v2.dart):
- `pricingEnabled: true`
- `underwritingStatus: 'APPROVED'`
- `underwritingReason: 'NO_DISCLOSED_CONDITIONS'`
- `integrityPassed: true`

Final `UnderwritingAssessment` (not computed in this branch; effectively treated as approved by explicit route args):
- `underwritingStatus: approved`
- `pricingEnabled: true`
- `reason: 'NO_DISCLOSED_CONDITIONS'`
- `decision: null` (not produced in this shortcut path)

### Example 2: AI failure + confirmed HCM text → denied → no pricing

Inputs:
- Vet upload produced extractedText containing confirmed HCM language.
- `_aiVetParseFailed == true`

Backstop extracts `MedicalConditionFact(conditionCode='HCM', status=confirmed)`.
Integrity engine returns denial **even with AI failure**.

Final `UnderwritingAssessment`:
- `underwritingStatus: denied`
- `pricingEnabled: false`
- `reason: 'CRITICAL_CONDITION_HCM'`
- `decision: non-null` (decline)

### Example 3: AI failure (first occurrence) + murmur-only → need more info → no pricing

Inputs:
- Vet text contains “murmur”, no confirmed critical.
- `_aiVetParseFailed == true`

Backstop extracts `HEART_MURMUR` as suspected.
Integrity engine hits `aiFailure` gate (after no critical deny) and returns `NEED_MORE_INFO`.

Final `UnderwritingAssessment`:
- `underwritingStatus: needMoreInfo`
- `pricingEnabled: false`
- `reason: 'AI_FAILURE'`
- `decision: null`
- `requiredEvidence: non-empty`

### Example 4: Confirmed non-critical condition → approved with exclusions → pricing allowed

Inputs:
- Medical facts include a confirmed non-critical code, e.g. `HIP_DYSPLASIA`.
- No critical confirmed codes.
- No AI failure.
- Deterministic eligibility eligible.
- Vet context is present (e.g., at least one uploaded record so `vetDocumentHashes` is non-empty).

Final `UnderwritingAssessment`:
- `underwritingStatus: approved`
- `pricingEnabled: true`
- `reason: 'APPROVED_WITH_EXCLUSIONS'`
- `decision: non-null` with:
  - `outcome: approveWithExclusions`
  - `exclusions: [PolicyExclusion(conditionName: 'HIP_DYSPLASIA', ...)]`

### Example 5: Rules unavailable → declined → no pricing

Inputs:
- Deterministic eligibility returns `ruleViolated == 'RULES_UNAVAILABLE'`.

Final `UnderwritingAssessment`:
- `underwritingStatus: declined`
- `pricingEnabled: false`
- `reason: 'RULES_UNAVAILABLE'`
- `decision: non-null` (decline)

### Example 6: Disclosed conditions but no vet records → need more info → no pricing

Inputs:
- User discloses at least one condition (so `medicalFactsRequired == true` and `medicalFacts.isNotEmpty`).
- No uploaded vet records and no other vet context (`vetDocumentHashes` empty; no parsed vet text).

Final `UnderwritingAssessment`:
- `underwritingStatus: needMoreInfo`
- `pricingEnabled: false`
- `reason: 'VET_RECORDS_REQUIRED'`
- `requiredEvidence` includes `PROVIDE_MEDICAL_HISTORY`

---

## 6) Audit / logging points

This section lists the current log messages (primarily `print(...)`) and their meanings.

### Integrity engine logs

- [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart): `UnderwritingIntegrityEngine.assess(...)`
  - `🧾 UnderwritingIntegrityEngine: CRITICAL_CONDITION_DETECTED code=$code => DENIED`
    - Operational meaning: deterministic critical deny fired.
  - `🧾 UnderwritingIntegrityEngine: AI_FAILED count=$aiFailureCount threshold=$aiFailureDeclineThreshold => NEED_MORE_INFO|DECLINED`
    - Operational meaning: AI pipeline failure forced fail-closed routing.

### Rules engine logs

- [lib/services/underwriting_rules_engine.dart](lib/services/underwriting_rules_engine.dart)
  - `📚 Underwriting rules loaded (source=callable, ...)`
  - `ℹ️ getUnderwritingRulesPublic unavailable, falling back to Firestore: $e`
  - `⚠️ Underwriting rules not found; underwriting will fail closed`
  - `❌ Error loading underwriting rules: $e`
  - `🧾 Underwriting checkEligibility start: ...`
  - `⚠️ Underwriting rules engine is disabled; failing closed`
  - `⚠️ Underwriting rules unavailable; failing closed`
  - `🧾 Underwriting checkEligibility result: eligible=false rule=... value=...`
  - `🧾 Underwriting checkEligibility result: eligible=true exclusions=...`
  - `❌ Error storing eligibility result: $e`

### Risk scoring logs

- [lib/services/risk_scoring_engine.dart](lib/services/risk_scoring_engine.dart)
  - `🧾 RiskScoringEngine eligibility: eligible=... hasExclusions=... excluded=... rule=...`
  - `🧾 RiskScoringEngine eligibility (returning): eligible=... hasExclusions=...`
  - `✅ AI Risk Analysis completed`
  - `⚠️ AI Risk Analysis failed: $e`

### UI routing logs

- [lib/screens/ai_analysis_screen_v2.dart](lib/screens/ai_analysis_screen_v2.dart)
  - `🧭 Underwriting routing: requires=... preExisting=... hasRuleExclusions=... needsMedicalUnderwriting=... conditions=...`

### Vet parsing / referral logs

- [lib/services/vet_history_parser.dart](lib/services/vet_history_parser.dart)
  - Writes Firestore events (not stdout logs) with event types such as:
    - `referred_vet_parse_failed`
    - `referred_low_confidence_vet_parse`
  - Includes `_aiDebugTag()` suffix in stored error messages when provider/model is available.

---

## 7) How to extend safely

This section describes **how** to extend underwriting without breaking invariants.

### Add a new deterministic critical condition

1. Add the new code to the set:
   - [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart): `UnderwritingIntegrityEngine.deterministicCriticalCodes`
2. Ensure `MedicalFactsBuilder._isDeterministicCriticalCode(...)` is updated consistently.
   - [lib/services/medical_facts_builder.dart](lib/services/medical_facts_builder.dart)
3. Ensure the mapper can canonicalize names to the new code.
   - [lib/services/medical_condition_fact_mapper.dart](lib/services/medical_condition_fact_mapper.dart)
4. Add unit tests that prove:
   - Confirmed new code denies deterministically.
  - Suspected/unknown does not deny (routes to `NEED_MORE_INFO`, except suspected/unknown *critical* which deterministically `DECLINED` unless explicit rule-out language).

### Adjust confirmation heuristics (vet-text backstop)

- Modify only:
  - [lib/services/medical_facts_builder.dart](lib/services/medical_facts_builder.dart): `_extractFactsFromVetText(...)`
- Preserve invariants:
  - Do not “confirm” on rule-out language.
  - Prefer `suspected` when uncertain.
  - Do not fabricate structured fields (keep unknowns as unknowns).

### Add a new underwriting rule (non-medical)

- Implement it in the deterministic rules engine path:
  - [lib/services/underwriting_rules_engine.dart](lib/services/underwriting_rules_engine.dart): `checkEligibility(...)`
- Ensure it flows through integrity engine:
  - [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart)
- Preserve fail-closed behavior:
  - If the rule cannot be evaluated (missing data / rules unavailable), prefer `RULES_UNAVAILABLE` semantics so the integrity engine deterministically declines and pricing stays off.

---

## Appendix: Minimum reviewed files

This document was derived from these files (minimum set requested):

- [lib/screens/conversational_quote_flow.dart](lib/screens/conversational_quote_flow.dart)
- [lib/services/risk_scoring_engine.dart](lib/services/risk_scoring_engine.dart)
- [lib/screens/medical_underwriting_screen.dart](lib/screens/medical_underwriting_screen.dart)
- [lib/services/medical_facts_builder.dart](lib/services/medical_facts_builder.dart)
- [lib/services/medical_condition_fact_mapper.dart](lib/services/medical_condition_fact_mapper.dart)
- [lib/services/underwriting_integrity_engine.dart](lib/services/underwriting_integrity_engine.dart)
- [lib/services/underwriting_rules_engine.dart](lib/services/underwriting_rules_engine.dart)
- [lib/services/underwriting_decision_engine.dart](lib/services/underwriting_decision_engine.dart)
- [lib/services/pricing_gate.dart](lib/services/pricing_gate.dart)
- [lib/screens/plan_selection_screen.dart](lib/screens/plan_selection_screen.dart)
- [lib/services/vet_history_parser.dart](lib/services/vet_history_parser.dart)
