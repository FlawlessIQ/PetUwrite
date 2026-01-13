# Claims Experience Deep Review (UX + Product + Risk)

This document reviews the current claims experience end-to-end using personas and the implemented code paths, then identifies the biggest gaps and a prioritized roadmap.

## Scope

Covers:
- Customer FNOL intake + documents + submission
- Automated decisioning + explainability
- Claim status tracking + comms
- Admin review workflow + concurrency controls
- Payout processing + reconciliation

Out of scope (for now): full integration testing on Firebase Emulator, production Stripe Connect onboarding, and production-grade OCR infrastructure.

## Where The Current Experience Lives (Code Map)

Customer:
- Intake (conversational FNOL): [lib/screens/claims/claim_intake_screen.dart](../lib/screens/claims/claim_intake_screen.dart)
- Customer home + “File a Claim” entry point: [lib/auth/customer_home_screen.dart](../lib/auth/customer_home_screen.dart)

Decisioning + tracking:
- Claim decision rules + thresholds: [lib/services/claim_decision_engine.dart](../lib/services/claim_decision_engine.dart)
- Claim status messaging + progress: [lib/services/claim_tracker_service.dart](../lib/services/claim_tracker_service.dart)
- Timeline visualization: [lib/widgets/claim_timeline_widget.dart](../lib/widgets/claim_timeline_widget.dart)

Admin:
- Claims review queue + dialog + optimistic conflict checks: [lib/screens/admin/claims_review_tab.dart](../lib/screens/admin/claims_review_tab.dart)

Payout + operations:
- Payout processing (Stripe + notification): [lib/services/claim_payout_service.dart](../lib/services/claim_payout_service.dart)
- Advisory review lock + transactional status updates: [lib/services/claims_service.dart](../lib/services/claims_service.dart)
- Reconciliation (Cloud Functions): [functions/claimsReconciliation.js](../functions/claimsReconciliation.js), [functions/reconcileClaimsState.js](../functions/reconcileClaimsState.js)

Data model + security:
- Claim model + lifecycle fields: [lib/models/claim.dart](../lib/models/claim.dart)
- Firestore rules for claims: [firestore.rules](../firestore.rules)

---

## Personas

### P1 — “Anxious First-Time Claimant” (Core)
- Trigger: unexpected vet visit, emotionally stressed
- Goals: file quickly, know what’s covered, get paid fast
- Failure tolerance: low; confusion = churn

### P2 — “Overwhelmed, Low-Tech Customer” (Accessibility)
- Trigger: emergency visit, poor connectivity, older device
- Goals: minimal typing, camera-first, clear checklist
- Failure tolerance: very low

### P3 — “Routine Wellness Claimer” (Frequency)
- Trigger: predictable checkups/annual wellness
- Goals: repeatable flow, templates, quick reimbursements
- Risks: gaming the system via repeated small claims

### P4 — “Admin Reviewer (Claims Adjuster)” (Throughput)
- Trigger: claims in `processing` requiring human verification
- Goals: review fast, avoid conflicts, see docs + policy context, make defensible decisions
- Failure tolerance: moderate; tools must prevent mistakes under load

### P5 — “Ops / Finance / Reconciliation” (Reliability)
- Trigger: stuck claims, mismatched payout states, retries, audit trails
- Goals: consistent states, idempotent payouts, traceability
- Failure tolerance: low

### P6 — “Fraud / Risk Analyst” (Loss Ratio)
- Trigger: suspicious docs, abnormal patterns, edge-case policy exclusions
- Goals: detect fraud early, reduce leakage, maintain fairness + explainability

---

## Journey Map (Current)

### Customer Journey — FNOL → Decision

1) Entry
- Current: Customer taps “File a Claim” on home; app picks first policy/pet and navigates to intake.
- Code: [lib/auth/customer_home_screen.dart](../lib/auth/customer_home_screen.dart)

2) Conversational intake (date → description → cost → documents)
- Current: Chat-based stages with draft autosave/resume.
- Code: [lib/screens/claims/claim_intake_screen.dart](../lib/screens/claims/claim_intake_screen.dart)

3) Document upload
- Current: image picker; attaches URLs to claim draft.
- Important: `uploadClaimDocument()` currently returns a **mock URL** for mobile.
- Code: [lib/services/claims_service.dart](../lib/services/claims_service.dart)

4) Submission + AI decision
- Current: Claim status transitions to `processing` during analysis, then may become `settled` or `denied` based on thresholds.
- Code: [lib/screens/claims/claim_intake_screen.dart](../lib/screens/claims/claim_intake_screen.dart), [lib/services/claim_decision_engine.dart](../lib/services/claim_decision_engine.dart)

5) Status visibility
- Current: customer home shows “Recent Claims” cards (not obviously tappable, no timeline/details in the main path).
- Available building blocks exist (tracker + timeline), but not wired into primary UX.
- Code: [lib/auth/customer_home_screen.dart](../lib/auth/customer_home_screen.dart), [lib/services/claim_tracker_service.dart](../lib/services/claim_tracker_service.dart), [lib/widgets/claim_timeline_widget.dart](../lib/widgets/claim_timeline_widget.dart)

### Admin Journey — Review → Payout

1) Queue + analytics
- Current: filter/search + monthly analytics summary.
- Code: [lib/screens/admin/claims_review_tab.dart](../lib/screens/admin/claims_review_tab.dart)

2) Review detail dialog
- Current: loads documents (AI analyses), policy + pet context, submits human override; conflicts guarded by transaction checks.
- Code: [lib/screens/admin/claims_review_tab.dart](../lib/screens/admin/claims_review_tab.dart)

3) Concurrency controls
- Implemented at service layer (advisory lock) and optimistic checks in review submission.
- Code: [lib/services/claims_service.dart](../lib/services/claims_service.dart)

4) Payout
- Current: payout service exists with settling/settled patterns and reconciliation scripts.
- Gap: decision engine can mark a claim `settled` directly (auto-approve) without necessarily creating a payout record.
- Code: [lib/services/claim_payout_service.dart](../lib/services/claim_payout_service.dart), [functions/claimsReconciliation.js](../functions/claimsReconciliation.js)

---

## Gap Analysis (UX / Product / Risk)

### A) Customer UX Gaps (highest leverage)

1) No dedicated “Claim Status” detail surface in the primary customer flow
- Symptom: customers see status label only; no explanation, progress, ETA, or next steps.
- Existing assets: `ClaimTrackerService` + `ClaimTimelineWidget` are ready to power this.

2) Document upload feels “done”, but isn’t real on mobile
- Current mobile upload path returns a mock URL; users may believe docs were submitted when they weren’t.
- Product risk: hard denials / manual review delays caused by missing documentation.

3) High-friction inputs in a stressful moment
- Date parsing via chat is helpful, but users often need a date picker, amount input with keypad, “I don’t know” options, and structured prompts.

4) Missing expectations + transparency
- Customers don’t see:
  - what’s needed to approve (checklist)
  - what’s covered (policy context)
  - how reimbursements are calculated (deductible/reimbursement)

### B) Product & Workflow Gaps

1) Lifecycle/status semantics are inconsistent
- `ClaimStatus` includes `settling` for payout locking, but the decision engine can set `settled` directly.
- Firestore rules mention `pending` status, but the claim model doesn’t define it.

2) Auto-deny on low confidence is risky
- Current rules: confidence < 60 → auto-deny.
- Product fairness & CX: low confidence often means “need more evidence”, not “deny”.

3) Appeals / additional info flow not implemented
- For denials or “more info”, there isn’t a first-class flow to upload additional docs or dispute.

### C) Risk / Security / Compliance Gaps (must-fix before real users)

1) Secrets in client-side services (critical)
- `ClaimPayoutService` and `ClaimDocumentAIService` use API keys (Stripe/OpenAI/Vision) from dotenv; if executed on client builds, those keys are exposable.
- Recommended: move payouts + AI/OCR behind Cloud Functions (callable/HTTPS) and keep keys server-side.

2) Auto-approval threshold lowered for testing
- `autoApproveThreshold = 75.0` (comment indicates it was 85).
- This materially changes loss ratio risk and should be environment-configurable.

3) Payout integrity for auto-approved claims
- If a claim is marked `settled` without a payout record, the system can drift into “paid” UX without actual payment.
- Recommended: make payout creation atomic with status transitions (or introduce `approved`→`settling`→`settled`).

---

## Recommendations (Prioritized)

### 1) Ship a real Customer Claim Status Screen (1–2 weeks)
- Make claim cards tappable and route to a new screen that shows:
  - Clover status message (`ClaimTrackerService.getCurrentMessage()`)
  - progress + ETA (`getProgressPercentage`, `getEstimatedTimeRemaining`)
  - timeline (`ClaimTimelineWidget`)
  - decision explanation if denied/settled
  - next action CTA (upload docs / contact support / appeal)

### 2) Make document upload real + consistent (1–2 weeks)
- Implement Firebase Storage uploads for mobile (`putFile`) and web (`putData`) consistently.
- Persist attachment metadata + show upload state.
- Decide the minimum document set per claim type and enforce it.

### 3) Fix lifecycle semantics + decision outcomes (1–2 weeks)
- Align statuses: avoid setting `settled` until payout is confirmed.
- Replace “auto-deny on low confidence” with “needs info / human review” unless explicit fraud flags.
- Make thresholds configurable via admin settings / remote config.

### 4) Move AI + payout to server (required for production)
- Use Cloud Functions callables (you already have an OpenAI proxy) for:
  - document analysis
  - claim decision
  - payout execution
- Keep client limited to requesting actions + displaying results.

### 5) Add appeals + “request more info” UX (mid-term)
- Customer: upload more docs, answer follow-ups, timeline updates.
- Admin: structured “request info” template + SLA timers.

---

## Metrics to Instrument

Customer:
- FNOL completion rate
- time-to-submit
- % claims with required docs at submit
- claim reopen / additional-doc rate
- customer CSAT after decision

Ops/Risk:
- auto-approve rate (by amount bucket)
- false-approve rate (post-hoc corrections)
- denial rate + top deny reasons
- time in `processing` / `settling`
- reconciliation fixes per day + retry success rate

---

## Open Questions (to finalize roadmap)

1) What’s the intended production claim lifecycle?
- `submitted` → `processing` → `settling` → `settled` vs `submitted` → `processing` → `settled`

2) What’s the target SLA (minutes/hours/days) by claim type and amount?

3) Do we want “soft denials” (needs info) vs hard denials?

4) Do we pay customers or reimburse a card/ACH? (Stripe Connect design)
