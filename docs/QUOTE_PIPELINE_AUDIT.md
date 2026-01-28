# Quote Pipeline Audit (Carrier-Grade)

This document maps quote inputs end-to-end and highlights robustness gaps that can produce mispricing, inconsistent underwriting outcomes, or fail-open UX.

## 1) Quote Input Inventory (Pre-bind)

### Conversational quote flow
Source: `lib/screens/conversational_quote_flow.dart`

| Input (key) | Collected as | Normalized into | Used where | Pricing / underwriting impact |
|---|---|---|---|---|
| `ownerName` | free text | `Owner.firstName` + `Owner.lastName` (split) | UI personalization only | None (today) |
| `petName` | free text | `Pet.name` | UI only | None |
| `species` | dog/cat | `Pet.species` | `RiskScoringEngine`, `UnderwritingConstraintEngine` | Risk score + eligibility; affects weight bounds |
| `breed` | picker text | `Pet.breed` | `RiskScoringEngine`, `UnderwritingConstraintEngine`, `UnderwritingRulesEngine` | Risk score + eligibility + anomalies |
| `age` | integer years (0–20) | `Pet.dateOfBirth` (approx: now − age⋅365) | `RiskScoringEngine`, `UnderwritingRulesEngine`, `ProductCatalog` (via `ageYears`) | Risk score + lever availability |
| `weight` | integer lbs | `Pet.weight` (kg) | `UnderwritingConstraintEngine`, `RiskScoringEngine` | Anomaly detection + risk multiplier |
| `gender` | male/female | `Pet.gender` | `RiskScoringEngine` | Minor risk factors (if implemented) |
| `isNeutered` | boolean | `Pet.isNeutered` | `RiskScoringEngine` | Lifestyle / medical risk factor (if implemented) |
| `hasPreExistingConditions` | boolean | influences `Pet.preExistingConditions` | `AIAnalysisScreen` routing + `UnderwritingRulesEngine` | Routes to medical underwriting + can lead to exclusions/decline |
| `preExistingConditionTypes` | multi-select | `Pet.preExistingConditions` | `UnderwritingRulesEngine` | Drives underwriting routing and possible exclusions |
| `preExistingConditionOtherText` | free text | `Pet.preExistingConditions` | `UnderwritingRulesEngine` | Same as above (unstructured) |
| `isReceivingTreatment` | yes/no/managed | `Pet.isReceivingTreatment` | `AIAnalysisScreen` routing | Triggers medical underwriting routing |
| `email` | free text | `Owner.email` | UX + comms | None (today) |
| `zipCode` | free text | `Owner.address.zipCode` | `PricingQuoteService`, `QuoteEngine` | Regional pricing |
| *(derived)* `state` | guessed from ZIP | `Owner.address.state` | `PricingQuoteService`, `QuoteEngine` | Regional pricing; correctness risk (see gaps) |

### Classic multi-step quote flow
Source: `lib/screens/quote_flow_screen.dart`

| Input (key) | Collected as | Normalized into | Used where | Pricing / underwriting impact |
|---|---|---|---|---|
| `petName` | free text | `Pet.name` | UI only | None |
| `species` | dropdown | `Pet.species` | `RiskScoringEngine`, `UnderwritingRulesEngine` | Risk/eligibility |
| `breed` | free text | `Pet.breed` | `RiskScoringEngine`, `UnderwritingRulesEngine` | Risk/eligibility |
| `dateOfBirth` | date picker | `Pet.dateOfBirth` | `RiskScoringEngine`, `ProductCatalog` (via `ageYears`) | Risk + product availability |
| `conditions` | free text | parsed list → `Pet.preExistingConditions` | `UnderwritingRulesEngine` routing | Triggers medical underwriting routing |
| `firstName`/`lastName` | free text | `Owner.firstName/lastName` | UX only | None (today) |
| `email` | free text | `Owner.email` | UX + comms | None (today) |
| `phone` | free text | `Owner.phoneNumber` | UX | None |
| `state` | 2-letter | `Owner.address.state` | `PricingQuoteService`, `QuoteEngine` | Regional pricing |
| `zipCode` | free text | `Owner.address.zipCode` | `PricingQuoteService`, `QuoteEngine` | Regional pricing |
| *(defaults today)* | — | `Pet.weight=10kg`, `Pet.gender='unknown'`, `Pet.isNeutered=false` | `RiskScoringEngine` | Potential mispricing (see gaps) |

### Medical underwriting (pre-bind, conditional)
Source: `lib/screens/medical_underwriting_screen.dart`

This step is entered when disclosures indicate underwriting is required (pre-existing conditions, exclusions, or treatment signals).

| Input | Collected as | Normalized into | Used where | Pricing / underwriting impact |
|---|---|---|---|---|
| Condition details | structured (name, dx date, status, notes) | `Pet.medicalConditions`, `UnderwritingMedicalHistory` | `MedicalFactsBuilder`, `UnderwritingIntegrityEngine` | Produces deterministic `UnderwritingAssessment` (approve/need more info/decline) |
| Medications | structured | `Pet.medications` | `MedicalFactsBuilder`, evidence requirements | Underwriting routing (medical facts required) |
| Allergies | structured | `Pet.allergies` | supporting context | May affect evidence requests |
| Vet visit history | structured | `Pet.vetHistory` | supporting context | Used in integrity checks if vet texts exist |
| Vet docs (upload) | files → hashes + extracted text | `vetDocumentHashes`, `_rawVetTexts`, `_aiVetExtraction` | `VetRecordIntegrityGuard`, `DiagnosticTimingGuard`, doc reuse detection | Can block pricing (NEED_MORE_INFO) or decline |
| AI failure count | counter across attempts | `aiFailureCount` | `UnderwritingIntegrityEngine` | Deterministic escalation to decline after threshold |
| Need-more-info attempts | counter across attempts | `needMoreInfoAttempts` | `UnderwritingCaseService.incrementNeedMoreInfoAttempts` | Deterministic escalation to `REQUIRED_EVIDENCE_NOT_PROVIDED` |

### Checkout / bind flow (post-plan-selection)
Sources: `lib/models/checkout_state.dart`, `lib/screens/checkout_screen.dart`, `lib/screens/owner_details_screen.dart`, `lib/screens/payment_screen.dart`, `lib/screens/confirmation_screen.dart`

| Input | Collected as | Stored in | Used where | Impact |
|---|---|---|---|---|
| Owner PII | name/email/phone | `CheckoutProvider.ownerDetails` | policy issuance + comms | Required for policy creation |
| Owner address | line1/line2/city/state/zip | `CheckoutProvider.ownerDetails` | billing + regulatory address record | Drives policy record; may diverge from rating territory inputs |
| Consents | e-sign + privacy consent (UI) | snapshot fields + `OwnerDetails.hasESignConsent` | audit + compliance | Required to bind (UX enforced) |
| Coupon code | string | `PaymentInfo.couponCode` | payment calculations | Pricing discount at payment (not risk) |
| Discount amount | number | `PaymentInfo.discountAmount` | payment calculations | Affects paid amount; must be auditable |
| Stripe IDs | intent/method IDs | `PaymentInfo.paymentIntentId/paymentMethodId` | payment reconciliation | Operational only |
| Underwriting case ID | string | `CheckoutProvider.underwritingCaseId` | `ConfirmationScreen` decision fetch | Governs whether bind requires UW decision |
| Underwriting snapshot | map | `CheckoutProvider.underwritingSnapshot` | persisted to policy | Provides audit trace for bind |
| Exclusions | list | `CheckoutProvider.exclusions` | persisted to policy | Coverage terms |
| Effective date | `DateTime.now()` today | policy document | claim eligibility & waiting periods | Temporal risk if waiting periods not enforced |
| Pricing at bind evidence | plan + breakdown | `underwritingSnapshot.pricingAtBind` | audit | Reproducibility / dispute handling |

## 2) Pricing Inputs (Plan generation)

Source: `lib/screens/plan_selection_screen.dart`, `lib/services/pricing_quote_service.dart`, `lib/services/quote_engine.dart`

- Inputs used for pricing:
  - `riskBand` (from `RiskScore.riskLevel.name`)
  - `zipCode`, `state`
  - `numberOfPets` (currently `1`)
  - Plan levers (tier/reimbursement/deductible/annual limit) and add-ons (currently passed as empty list in quote flows)
- Safety gate:
  - `PricingGate.isPricingAllowed(...)` requires `pricingEnabled == true`, `underwritingStatus == 'APPROVED'`, and `integrityPassed == true`.

### Server-side pricing callable contract
Sources: `functions/pricing.js`, `lib/services/pricing_quote_service.dart`

- Callable: `getPricingQuotePublic` (public invoker)
- Required: `zipCode`
- Optional: `state` (currently used for regional adjustments)
- Required: `riskBand` (sent as `riskBand` from client; server also tolerates `riskLevel`)
- Optional: `skus` list to price a custom SKU; otherwise returns default Day-1 SKUs.
- Response includes: `pricingVersionId`, `pricingVersion`, `effectiveDateIso`, and `plans[]` (each includes `pricingBreakdown`).

## 3) Underwriting & Integrity Routing (Fail-closed map)

Sources: `lib/services/risk_scoring_engine.dart`, `lib/services/underwriting_rules_engine.dart`, `lib/services/underwriting_constraint_engine.dart`, `lib/services/underwriting_integrity_engine.dart`, `lib/services/pricing_gate.dart`, `lib/screens/ai_analysis_screen_v2.dart`, `lib/screens/medical_underwriting_screen.dart`

### Stage A: Quote-stage deterministic scoring
- `UnderwritingConstraintEngine` (catalog-driven; asset `assets/underwriting_constraints/breed_constraints.v1.json`) emits anomaly findings + `confidenceScore` + `credibilityRiskScore` + non-linear `riskMultiplier`.
- `RiskScoringEngine` synthesizes physiological + credibility risk and assigns `RiskScore.riskLevel`.

### Stage B: Quote-stage eligibility (deterministic)
- `UnderwritingRulesEngine.checkEligibilityDeterministic(pet, riskScore)` governs eligibility + exclusions.
- Rules are loaded via public callable `getUnderwritingRulesPublic` and validated; if rules are invalid/unavailable, the system fails closed.

### Stage C: Medical underwriting (deterministic integrity)
- `UnderwritingIntegrityEngine.assess(...)` governs:
  - vet record integrity + pet identity matching + diagnostic timing
  - document reuse checks
  - deterministic handling of critical condition codes
  - deterministic escalation for persistent AI failures or repeated NEED_MORE_INFO loops

### Stage D: Pricing gate
- `PricingGate.isPricingAllowed(routeArgs)` requires explicit approval flags.
- Healthy pets can be routed directly to plans; disclosed/complex pets must complete medical underwriting.

## 4) Cross-field Consistency Matrix (What we check vs what we should check)

This is the carrier-grade “don’t price contradictions” layer. Columns reflect current implementation status.

| Check | Current coverage | Where | Why it matters | Expected effect |
|---|---|---|---|---|
| Breed × Species | ✅ | `UnderwritingConstraintEngine.assess` | Prevents impossible combos | Raises credibility risk; triggers review |
| Breed × Weight plausibility | ✅ | `UnderwritingConstraintEngine._assessWeight` | Prevents gaming/misrating by misreported size | Non-linear risk multiplier; may trigger review |
| Breed × Age/lifespan plausibility | ✅ | `UnderwritingConstraintEngine._assessAge` | Prevents implausible ages and “edge” pricing | Credibility risk + review trigger |
| Multi-inconsistency (“owner reporting risk”) | ✅ | `UnderwritingConstraintEngine.assess` | Fraud/abuse signal; reduces confidence | Review trigger and credibility impact |
| ZIP × State consistency | ⚠️ Partial / heuristic | conversational flow guesses state | Territory compliance; rating correctness | Should be authoritative server-side |
| Weight units correctness (lbs vs kg) | ✅ in conversational; ⚠️ missing in classic | `conversational_quote_flow.dart` converts lbs→kg; classic hardcodes `10kg` | Misrating risk | Should collect weight in classic |
| Age precision consistency (DOB vs age years) | ⚠️ Mixed | conversational derives DOB from int years | Affects underwriting thresholds + product availability | Prefer DOB or month/year |
| Pre-existing conditions typed coding | ⚠️ Mixed | conversational uses multi-select; classic uses free-text split | Exclusions/declines consistency | Prefer canonical condition codes |
| Vet record identity match vs declared pet | ✅ | `PetIdentityMatcher` | Prevents doc substitution | Can block pricing or decline |
| Diagnostic timing vs application date | ✅ | `DiagnosticTimingGuard` | Anti-selection (diagnosis after quote) | Block pricing / need more info |
| Duplicate doc reuse across cases | ✅ (when enabled) | `VetDocumentReuseDetector` via integrity engine | Fraud/abuse | Need more info or decline |
| Waiting periods vs effective date | ❌ (not enforced in pricing/flow) | `ConfirmationScreen` sets effectiveDate now | Anti-selection + regulatory | Should enforce/communicate waiting periods |

## 5) Behavioral, Temporal, and Geographic Review

### Behavioral / reporting risk signals
- ✅ Multiple contradictions: `UnderwritingConstraintEngine` emits `ownerReportingRisk` when it sees 2+ inconsistencies.
- ✅ Repeated unresolved underwriting loops: `MedicalUnderwritingScreen` increments `needMoreInfoAttempts` and deterministically escalates to `REQUIRED_EVIDENCE_NOT_PROVIDED`.
- ✅ Persistent AI parsing failures: `aiFailureCount` is tracked and the integrity engine deterministically declines after a threshold.
- ❌ Re-quote velocity / spam / “quote-shopping” behavior is not currently persisted as an underwriting signal.

### Temporal / anti-selection logic
- ✅ Diagnostic timing guard exists (`DiagnosticTimingGuard`) when vet context is present.
- ⚠️ Effective date is set to “now” at bind time in `ConfirmationScreen`; waiting periods are not enforced or surfaced in pricing artifacts.

### Geographic / environmental factors
- ✅ Regional pricing uses `zipCode` + optional `state` (pricing callable applies regional adjustments).
- ⚠️ Conversational flow derives state heuristically from ZIP (non-authoritative).
- ❌ No explicit environmental risk layer (wildfire/flood/urban cost indices) beyond the existing regional adjustment configuration.

## 6) Explainability & Audit Artifacts

### Quote-stage artifacts
Sources: `lib/models/risk_score.dart`, `lib/services/risk_scoring_engine.dart`

- `RiskScore` carries:
  - `confidenceScore` (0–1), `physiologicalRiskScore`, `credibilityRiskScore`
  - `anomalyFindings` (serialized) and `reviewTriggers` (notably `POST_BIND_REVIEW`, `POSSIBLE_MISREPORTING`, `AI_ANALYSIS_UNAVAILABLE`)
  - AI analysis text (optional); when unavailable we emit `AI_ANALYSIS_UNAVAILABLE` and a `system` risk factor.

### Pricing artifacts
- Server pricing returns a versioned `pricingBreakdown` per plan.
- Bind-time `underwritingSnapshot.pricingAtBind` persists selected plan + breakdown (supports disputes and regulatory audit).

### Underwriting artifacts
- Medical underwriting builds a deterministic snapshot including decision, status, required evidence, medical facts, AI failure counts, and vet doc hashes.

## 7) Test Coverage (what exists vs what’s still needed)

Existing tests of note:
- `test/services/risk_scoring_engine_test.dart` (deterministic anomaly impact + AI failure fail-soft behavior)
- `test/services/underwriting_integrity_engine_test.dart` (integrity fail-closed scenarios)
- `test/services/pricing_gate_test.dart` (gate invariants)
- `test/services/product_catalog_rules_test.dart` (plan lever constraints)

Still needed (carrier-grade):
- Zip/state mismatch tests and server-side canonicalization behavior.
- Classic flow defaulted fields (weight/neuter/gender) producing mispricing tests.
- Waiting-period enforcement tests (effective date vs eligibility timing).
- Re-quote / rapid retry behavioral signals (rate limiting / anomaly accumulation).

## 8) High-severity Gaps (Ranked)

### CRITICAL
1. **AI failure must not break deterministic scoring**
  - Risk: AI outages previously bubbled up as exceptions; UI paths could fail-open or block without an underwriting band.
  - Fix: `RiskScoringEngine` now fail-softs AI analysis and always returns a deterministic score.
  - TODO: Add explicit monitoring for AI failure rates and surface `AI_ANALYSIS_UNAVAILABLE` in analytics.
  - Risk of inaction: intermittent outage periods will produce inconsistent quoting behavior and undermine auditability (“why was this quote different yesterday?”).

2. **Classic quote flow was missing pricing-gate approval flags**
  - Risk: eligible healthy pets routed to plan selection but pricing was blocked by `PricingGate`.
  - Fix: `quote_flow_screen.dart` now passes `pricingEnabled/underwritingStatus/integrityPassed` for healthy pets.
  - Risk of inaction: healthy pets are incorrectly blocked from pricing, increasing abandonment and creating non-deterministic UX across quote entrypoints.

### HIGH
3. **State derived from ZIP is heuristic (non carrier-grade)**
   - Risk: mismatch between `zipCode` and `state` can lead to incorrect rating territory, wrong taxes/fees, and compliance issues.
   - Recommendation: derive state server-side from ZIP (authoritative lookup) and ignore/validate client-provided state.
  - Risk of inaction: territory misrating and potential regulatory exposure (incorrect filings/fees), plus customer trust issues when corrections occur at bind.

4. **Classic flow uses placeholder pet fields (weight, neuter status, gender)**
   - Risk: deterministic anomaly engine and risk scoring cannot reliably price without these; defaults can bias pricing.
   - Recommendation: collect these fields (match conversational quick details), or mark unknown and price conservatively.
  - Risk of inaction: mispricing (especially for breed/weight edge cases) and weakened credibility/anomaly detection.

5. **Waiting periods & effective date governance is not enforced/surfaced**
  - Risk: bind-time can set `effectiveDate` to “now” without explicit waiting period disclosure/enforcement; increases anti-selection exposure.
  - Recommendation: make waiting periods explicit pricing artifacts and enforce at bind (and in policy artifacts).
  - Risk of inaction: elevated loss ratios from immediate-coverage abuse and potential regulatory/compliance issues.

### MEDIUM
6. **Unstructured condition text in classic flow**
   - Risk: free-text conditions can evade deterministic condition coding; underwriting/exclusion behavior may be inconsistent.
   - Recommendation: migrate to typed condition capture (like conversational flow) and map to canonical condition codes.
  - Risk of inaction: coverage disputes and inconsistent exclusions because identical conditions can be expressed in many ways.

## 9) Implementation TODOs (Recommended order)

1. **Authoritative ZIP→State (and rating territory) resolution**
  - Add server-side ZIP lookup and return canonical `state` (and optionally county/territory) from `getPricingQuotePublic`.
  - Client should stop guessing state and should trust the callable’s response.
  - Touchpoints: `functions/pricing.js`, `lib/services/pricing_quote_service.dart`, `lib/screens/conversational_quote_flow.dart`.

2. **Eliminate classic-flow placeholder pet fields**
  - Collect weight + spay/neuter + sex (match conversational quick details panel).
  - Touchpoints: `lib/screens/quote_flow_screen.dart`, `lib/models/pet.dart`.

3. **Canonical condition coding**
  - Replace free-text condition parsing with typed selections mapped to canonical codes.
  - Touchpoints: `lib/screens/quote_flow_screen.dart`, `lib/screens/medical_underwriting_screen.dart`, `lib/services/underwriting_integrity_engine.dart`.

4. **Waiting periods & effective date governance**
  - Add explicit waiting period fields on plans (server + client) and enforce/communicate at bind.
  - Touchpoints: `functions/pricing.js`, `lib/services/pricing_quote_service.dart`, `lib/screens/confirmation_screen.dart`.

5. **Behavioral signals: re-quote velocity and anomaly accumulation**
  - Persist quote attempts per device/session and add a deterministic review trigger for suspicious retry patterns.
  - Touchpoints: `lib/services/user_session_service.dart`, `functions/drafts.js` (if used for unauth), analytics events.

6. **Test suite expansion for carrier-grade invariants**
  - Add tests for ZIP/state mismatch behavior, classic-flow defaults, waiting periods, and retry signals.
  - Touchpoints: `test/services/*`.

## 10) Acceptance Criteria Alignment

- Implausible or contradictory inputs should not yield a “normal” quote (priced plans shown without friction).
  - Deterministic constraint/anomaly scoring must materially affect `riskBand` and/or emit review triggers for contradictions.
  - Pricing must be blocked unless `PricingGate.isPricingAllowed(...)` conditions are satisfied.
- AI enrichment failures must not produce a missing or null `RiskScore`.
  - If AI analysis is unavailable, the quote must carry `AI_ANALYSIS_UNAVAILABLE` plus a human-auditable reason in risk factors.
- Bind-time should preserve defensible artifacts.
  - Persist `pricingAtBind` (version + breakdown) and the underwriting snapshot so later disputes are explainable.

## Appendix: Files referenced

- Quote intake:
  - `lib/screens/conversational_quote_flow.dart`
  - `lib/screens/quote_flow_screen.dart`
- Risk/eligibility:
  - `lib/services/risk_scoring_engine.dart`
  - `lib/services/underwriting_constraint_engine.dart`
  - `lib/services/underwriting_rules_engine.dart`
- Pricing:
  - `lib/services/pricing_quote_service.dart`
  - `lib/services/quote_engine.dart`
  - `lib/services/pricing_gate.dart`
  - `lib/screens/plan_selection_screen.dart`

- Checkout / bind:
  - `lib/models/checkout_state.dart`
  - `lib/screens/checkout_screen.dart`
  - `lib/screens/owner_details_screen.dart`
  - `lib/screens/payment_screen.dart`
  - `lib/screens/confirmation_screen.dart`

- Cloud Functions:
  - `functions/pricing.js`
