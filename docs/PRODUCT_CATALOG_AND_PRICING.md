# Product Catalog & Pricing (Market-Aligned)

This document describes the **carrier-agnostic** product blueprint implemented in the app, how it’s represented in code, and how it flows through quote → plan selection → checkout → binding.

## Goals

- Provide **market-standard levers** users expect (reimbursement, deductible, annual limit, add-ons).
- Keep quoting **unauthenticated**; require authentication only at checkout/binding.
- Ensure underwriting decisions/exclusions are **visible, acknowledged, and persisted** through bind.
- Keep the product definition **config-driven** in code so it can later map to a carrier filing.

## User-Facing Product Shape

### Core levers

- **Reimbursement**: 70% / 80% / 90%
- **Annual deductible**: $100 / $250 / $500 / $750 / $1000
- **Annual limit**: $5k / $10k / $15k / $20k / **Unlimited**

These map to the plan’s pricing and displayed benefit summary.

### Tiers

The app still presents tiers (e.g., Basic/Plus/Elite) as a starting point, but each tier is now a *configuration baseline* rather than a single fixed plan.

### Add-ons (optional riders)

Implemented as a discrete list so they can be displayed, priced, and carried into checkout/binding.

Examples included in the catalog:

- Wellness / routine care
- Dental illness
- Exam fees
- Behavioral therapy
- Alternative therapies
- Boarding / kennel

(Exact list lives in the catalog file; the UI allows selecting any subset.)

### Waiting periods & policy rules

Represented explicitly on the plan so they can be displayed consistently wherever the plan is summarized.

- Accident waiting period (days)
- Illness waiting period (days)
- Orthopedic waiting period (days)
- Pre-existing condition rule text (e.g., “curable pre-existing may be covered after X months symptom-free”)

## How It’s Implemented

### Catalog definition

- Source of truth: [lib/services/product_catalog.dart](../lib/services/product_catalog.dart)

This file defines:

- Allowed values for reimbursement/deductible/limits
- Waiting periods
- Rule text (carrier-agnostic phrasing)
- Add-on enumeration + metadata

### Admin switches (dynamic enable/disable)

You can enable/disable **products (tiers)** and **riders (add-ons)** from the Admin Dashboard.

- Admin UI: [lib/admin/admin_product_catalog_page.dart](../lib/admin/admin_product_catalog_page.dart)
- Storage: Firestore doc `admin_settings/product_catalog`
- Public read for unauth quote flows: callable `getProductCatalogPublic`

Document shape:

```json
{
  "enabled": true,
  "enabledTiers": { "basic": true, "plus": true, "elite": true },
  "enabledAddOns": { "examFees": true, "wellnessLite": true, "...": true },
  "lastUpdated": "<serverTimestamp>",
  "updatedBy": "admin@email"
}
```

If a tier is disabled, it is hidden in plan selection. If an add-on is disabled, it is not offered in the customization panel.

### Quote engine + Plan model

- Quote/pricing: [lib/services/quote_engine.dart](../lib/services/quote_engine.dart)

Key concepts:

- `QuoteEngine.buildPlan(...)`: builds a `Plan` from tier + selected levers + add-ons.
- `QuoteEngine.priceMonthlyPremium(...)`: prices a plan using:
  - tier factor
  - reimbursement factor
  - deductible factor
  - annual limit factor (including Unlimited)
  - add-on flat fees

#### Plan fields (high level)

The `Plan` model (currently defined in `quote_engine.dart`) now carries:

- Pricing: `pricingBasePremium`, `monthlyPremium`
- Levers: `reimbursementPercent`, `annualDeductible`, annual limit (via `maxAnnualCoverage` + `isUnlimitedAnnualCoverage`)
- Add-ons: `selectedAddOns`
- Policy terms: `waitingPeriodsDays`, `policyRules`

This enables downstream screens (checkout, confirmation) to display **exactly what the user selected**, not just the tier label.

### Plan selection UI

- UI: [lib/screens/plan_selection_screen.dart](../lib/screens/plan_selection_screen.dart)

The plan selection screen now includes a customization panel:

- Dropdowns for reimbursement/deductible/annual limit
- Chips for add-ons
- Repricing is performed by rebuilding the plan via `QuoteEngine.buildPlan(...)` so features/rules remain consistent.

## Data Flow: Quote → Bind

### 1) Quote (unauthenticated)

- User answers questions.
- Underwriting runs and produces:
  - decision/snapshot
  - exclusions (if any)
- Plans are generated and shown without requiring sign-in.

### 2) Plan selection

- User selects a tier and optionally customizes levers/add-ons.
- Exclusions are shown at plan selection if present.

### 3) Checkout review

- Exclusions are shown again.
- User must explicitly acknowledge exclusions to proceed.

### 4) Payment

- Exclusions summary is shown again.
- User must acknowledge exclusions again before payment can be submitted.

### 5) Confirmation / binding

- The bound policy stores an underwriting snapshot that includes:
  - exclusions
  - evidence that exclusions were acknowledged (with timestamps)
  - the final plan configuration (tier + levers + add-ons)

## Notes / Known Follow-ups

- If you want add-ons and lever selections to appear more prominently in checkout and the final policy summary, the next step is to ensure those screens render `Plan.selectedAddOns`, `Plan.reimbursementPercent`, `Plan.annualDeductible`, and annual limit consistently.
- Some unit tests unrelated to product work may require Firebase initialization/mocking if they instantiate Firestore-backed services.
