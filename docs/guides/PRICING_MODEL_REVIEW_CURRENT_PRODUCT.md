# Pricing model review (current product)

This document describes **how pricing is computed today** in the PetUwrite app, what inputs drive it, and which parts you can work on fully offline.

> Scope note: This is the **quote/premium model**, not claims decisioning. The premium calculation is currently implemented **client-side in Flutter** and is intentionally carrier-agnostic / simplified.

---

## 1) Where pricing lives (source of truth)

### Core calculator
- **Quote engine (premium math):** `lib/services/quote_engine.dart`
  - `QuoteEngine.generateQuote(...)` → generates 3 plans.
  - `QuoteEngine._calculateBasePremium(...)` → computes base monthly premium from risk + region.
  - `QuoteEngine.priceMonthlyPremium(...)` → applies plan levers (tier, deductible, reimbursement, limit) + add-on fees.

### Product definition (what you sell)
- **Product catalog (tiers/levers/add-ons/features):** `lib/services/product_catalog.dart`
  - Defines tier descriptions and included features.
  - Defines allowed levers: reimbursement %, annual deductible, annual limit.
  - Defines add-on list and descriptive copy.

### Product availability switches (what’s visible)
- **Availability engine:** `lib/services/product_catalog_availability_engine.dart`
- **Admin UI that writes availability:** `lib/admin/admin_product_catalog_page.dart`
- **Public callable for unauth quote flows:** `functions/productCatalogPublic.js` (`getProductCatalogPublic`)

Important: availability toggles **hide/show** tiers and add-ons; they **do not change** the premium math.

---

## 2) Pricing data flow (from user input to displayed premium)

### A. Quote input collection
There are two quote entry experiences; both end in plan selection:

1) Conversational quote flow: `lib/screens/conversational_quote_flow.dart`
   - Builds a `Pet` and `Owner` from answers.
   - Guesses `state` from `zipCode` (simplified mapping).

2) Form-based quote flow: `lib/screens/quote_flow_screen.dart`
   - Builds a `Pet` and `Owner` from form values.
   - Collects `state` directly (user input).

### B. Risk score calculation
- `lib/services/risk_scoring_engine.dart` computes a `RiskScore` (0–100) from:
  - Pet age (`dateOfBirth` → `ageInYears`)
  - Breed
  - Pre-existing conditions (self-reported)
  - Vet history (optional, if parsed)
  - Lifestyle (currently: weight vs ideal + neuter status)

Eligibility rules are checked via `lib/services/underwriting_rules_engine.dart`.

### C. Plan generation + display
- `lib/screens/plan_selection_screen.dart`
  - Calls `QuoteEngine.generateQuote(riskScore, owner.address.zipCode, owner.address.state)`.
  - Displays plans and allows customization.
  - Reprices by rebuilding the selected plan via `QuoteEngine.buildPlan(...)` using the stored `Plan.pricingBasePremium`.

---

## 3) Inputs to pricing (what changes the premium)

### 3.1 Inputs to base premium (before plan levers)
These directly influence the base monthly premium:

1) **Risk score overallScore** (0–100)
   - Produced by `RiskScoringEngine`.
   - Only `overallScore` is used by pricing (not the category breakdown).

2) **Region**
   - `state` (preferred if provided)
   - `zipCode` (used for a simple “high-cost zip” check)

3) **Number of pets**
   - Implemented in pricing engine (multi-pet discounts), but the current plan selection calls it with `numberOfPets: 1`.

### 3.2 Inputs to monthly plan premium (levers)
These adjust the base premium for the specific plan configuration:

- **Tier**: Basic / Plus / Elite
- **Reimbursement percent**: 70 / 80 / 90
- **Annual deductible**: 100 / 250 / 500 / 750 / 1000
- **Annual limit**: 5k / 10k / 15k / 20k / Unlimited
- **Add-ons**: flat monthly fees (wellness, exam fees, etc.)

### 3.3 Inputs that affect eligibility/exclusions but not premium
These affect whether the pet can be quoted and whether exclusions apply, but **do not currently change premium**:

- Underwriting rules thresholds (max risk score, min/max age, excluded breeds, critical conditions, excludable conditions)
  - Source: Firestore doc `admin_settings/underwriting_rules` (or callable `getUnderwritingRulesPublic`)
  - Engine: `lib/services/underwriting_rules_engine.dart`

There is also a model for pricing adjustments (`premiumMultiplier`, `deductibleAdjustment`, `waitingPeriodDays`) in `lib/models/underwriting_decision.dart`, but **it is not applied by `QuoteEngine` today**.

---

## 4) The premium math (exact current formulas)

### 4.1 Base premium
Defined in `QuoteEngine`:

- Constant base price: **$35.00 / month** (`_basePrice = 35.0`)
- Risk multiplier factor: **1.5** (`_riskMultiplierFactor = 1.5`)

Risk multiplier:

- `riskMultiplier = (overallScore / 100) * 1.5`
- `premiumAfterRisk = 35.0 * (1 + riskMultiplier)`

Regional multiplier:
- State-based adjustments:
  - NY: 1.10
  - CA: 1.08
  - MA: 1.09
  - WA: 1.07
  - IL: 1.06
  - TX: 1.02
  - FL: 1.03
  - Default: 1.00
- If state is not recognized, there is a zip heuristic:
  - NYC-ish zips starting with 100/101/102 → uses NY (1.10)

Final base premium:

- `basePremium = premiumAfterRisk * regionalMultiplier`

### 4.2 Multi-pet discount
Discount tiers (multiplier applied to base premium):
- 1 pet: 0%
- 2 pets: 5%
- 3 pets: 10%
- 4+ pets: 15%

Applied as:
- `discountedBasePremium = basePremium * (1 - discount)`

(Current UI path: `numberOfPets` is effectively always 1.)

### 4.3 Plan factors
Monthly premium starts from `discountedBasePremium` and multiplies these factors:

Tier factor:
- Basic: 0.90
- Plus: 1.05
- Elite: 1.25

Reimbursement factor:
- 70%: 0.92
- 80%: 1.00
- 90%: 1.12

Deductible factor:
- $100: 1.22
- $250: 1.10
- $500: 1.00
- $750: 0.93
- $1000: 0.86

Annual limit factor:
- $5,000: 0.92
- $10,000: 1.00
- $15,000: 1.08
- $20,000: 1.15
- Unlimited: 1.25

Premium before add-ons:
- `premium = discountedBasePremium * tierFactor * reimbursementFactor * deductibleFactor * annualLimitFactor`

### 4.4 Add-on fees (flat monthly)
Add-ons are **flat** fees added after multiplying factors:

- Exam fees: +$5
- Wellness Lite: +$8
- Wellness Premium: +$18
- Dental Plus: +$6
- Rehab: +$5
- Behavioral: +$4
- Prescription food: +$3

Premium after add-ons:
- `premium += sum(addOnFees)`

### 4.5 Guardrail
- Minimum monthly premium is capped at **$10**:
  - `if (premium < 10) premium = 10`

---

## 5) How the risk score is computed (what feeds pricing)

Pricing uses only `RiskScore.overallScore`, so it’s important to understand how that score is produced.

### 5.1 Risk scoring inputs
From `RiskScoringEngine.calculateRiskScore(...)`:

Required:
- `Pet`: age (`dateOfBirth`), breed, preExistingConditions, species, weight, isNeutered
- `Owner`: currently used mainly for AI prompt + explainability (state)

Optional:
- `VetRecordData vetHistory` (from PDF parsing / data ingestion)
- `additionalData` map (a few fields are referenced in explainability; lifestyle scoring currently ignores most of it)

### 5.2 Category scoring
The engine scores categories and then builds an overall weighted score.

Categories:
- `age` (0–100-ish)
- `breed` (default 30, or higher if known high-risk breed)
- `preExisting` (0..100; critical conditions heavily increase)
- `medicalHistory` (only if vetHistory provided)
- `lifestyle` (weight deviation + neuter status)

Weights used for the overall weighted average:
- age: 0.25
- breed: 0.25
- preExisting: 0.25
- medicalHistory: 0.15
- lifestyle: 0.10

Then a “critical combination multiplier” is applied:
- If `ageScore >= 60` AND `preExistingScore >= 40` → multiply by 1.4
- Else if `ageScore >= 50` AND `preExistingScore >= 30` → multiply by 1.2

Finally:
- `overallScore = clamp(baseScore * multiplier, 0..100)`

Risk level mapping:
- < 30 → low
- < 60 → medium
- < 80 → high
- ≥ 80 → veryHigh

---

## 6) What you can do fully offline

### ✅ Fully offline (no network required)
- Modify and test premium math in `QuoteEngine`.
- Run the app and compute premiums as long as you provide a `RiskScore` (or stub it).

### ⚠️ Potentially online dependencies
If you’re truly offline (no network), these may fail unless you stub/disable them:

1) **AI risk analysis**
   - `RiskScoringEngine` calls `AIService.generateText(...)`.
   - It catches errors and falls back to a traditional analysis string, but the call attempt still happens.

2) **Underwriting rules callable**
   - `UnderwritingRulesEngine` first tries the callable `getUnderwritingRulesPublic`.
   - If that fails, it falls back to Firestore.

Offline recommendation: for offline pricing work, you can:
- Short-circuit the AI call in your AIService implementation (return a fixed response), or
- Provide a local/stub `RiskScore` directly to plan selection, or
- Add a “traditional-only risk scoring” mode toggle.

---

## 7) Known gaps / simplifications (important when reviewing)

- **No true rating tables**: There’s no actuarial table by breed/age/zip; risk score is a proxy.
- **Regional pricing is coarse**: State multipliers + a single NYC-ish zip heuristic.
- **Multi-pet discount is implemented but not wired through current UI** (plan selection uses `numberOfPets: 1`).
- **Underwriting pricing adjustments exist as a model but are not applied** to premium yet.
- There are two “quote/plan” model tracks:
  - Newer: `PlanType` + `Plan` in `lib/services/quote_engine.dart` (used by plan selection)
  - Older: `Quote`/`CoveragePlan` in `lib/models/quote.dart` (appears unused in current flow)

---

## 8) Quick reference: knobs you’ll likely edit

- Base premium parameters: `_basePrice`, `_riskMultiplierFactor`
- Regional multipliers: `_regionalAdjustments`
- Plan factors: `tierFactor`, `reimbursementFactor`, `deductibleFactor`, `annualLimitFactor`
- Add-on fees: the switch over `AddOnType` in `priceMonthlyPremium`
- Risk score weighting: `_calculateOverallScore` weights + critical multiplier logic

---

## 9) Suggested next step (if you want)

If you tell me what “offline pricing work” means for you (e.g., new rating table, breed/age curve, claims-loss model, or simple tuning), I can:
- add a tiny CLI Dart script that prints premiums for sample pets/zipcodes,
- or add a deterministic “traditional-only” risk scoring mode,
- or refactor the pricing constants into a local JSON config so you can iterate without recompiling.
