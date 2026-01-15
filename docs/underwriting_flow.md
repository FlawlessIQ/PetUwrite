# Underwriting Flow (Deterministic, Zero-Human)

Date: 2026-01-14

This document describes how underwriting works **today** in this repository.
It is intended to be code-faithful and operationally precise.

## Core invariants

1. **AI is assistive only**
   - AI may extract/normalize facts (e.g., OCR + structured vet history parsing) but **never decides** outcomes.
   - Deterministic engines produce all underwriting outcomes.

2. **Fail-closed underwriting (no pricing unless approved)**
   - Pricing is only allowed when the route args satisfy:
     - `pricingEnabled == true`
     - `underwritingStatus == APPROVED`
     - `integrityPassed == true`
   - Enforced by [lib/services/pricing_gate.dart](../lib/services/pricing_gate.dart) and consumed by [lib/screens/plan_selection_screen.dart](../lib/screens/plan_selection_screen.dart).

3. **Zero-human automation**
   - There is no manual-review queue.
   - Any ambiguity routes to deterministic self-serve `NEED_MORE_INFO` or deterministic `DECLINED`.

5. **No customer self-diagnosis**
   - Customers are not asked to self-determine clinical attributes like condition severity/chronicity.
   - When details are missing or uncertain, the system deterministically requests verifiable evidence (vet records) instead.

4. **Deterministic critical denies**
   - Certain critical codes (HCM/CHF/ACTIVE_CANCER/CKD_STAGE_3_PLUS) deterministically deny when **confirmed**, even if AI pipelines fail.
   - Implemented in [lib/services/underwriting_integrity_engine.dart](../lib/services/underwriting_integrity_engine.dart).

## Primary flow (quote → underwriting → plans)

### 1) Risk score computed

- The quote flow computes a `RiskScore`.
- Before eligibility/pricing, the integrity engine validates the risk score is plausible (anti-tampering).
  - Guard: [lib/services/risk_score_sanity_guard.dart](../lib/services/risk_score_sanity_guard.dart)
  - Output on failure: `NEED_MORE_INFO` + evidence requirement `RISK_SCORE_RECALCULATE`.

### 2) Vet documents uploaded and fingerprinted

- Vet documents are parsed leniently so the system can still fail-closed deterministically.
- Every uploaded document gets a deterministic SHA-256 fingerprint (`documentHash`) computed from raw bytes.
  - Implemented in [lib/services/vet_history_parser.dart](../lib/services/vet_history_parser.dart)
  - Persisted to `underwriting_cases/{caseId}/vet_records/*` as `documentHash`.

### 3) Facts builder (strict, no guessing)

- Medical facts are built deterministically from:
  - user-entered conditions + user-captured facts
  - AI vet extraction output (`VetRecordData`) when available
  - deterministic backstop keyword extraction from raw vet text
- Implemented in [lib/services/medical_facts_builder.dart](../lib/services/medical_facts_builder.dart).

### 4) Integrity + fraud gates (before pricing)

The integrity engine is the final authority and applies gates in a fail-closed order.

- Primary engine: [lib/services/underwriting_integrity_engine.dart](../lib/services/underwriting_integrity_engine.dart)

Deterministic integrity/fraud checks include:

1. **Risk score sanity** (anti-tampering)
   - `NEED_MORE_INFO` on invalid/mismatched score/level.

2. **Pet identity matching** (record-to-application consistency)
   - Detects strong species mismatches from vet text.
   - `DECLINED` on hard mismatch (species mismatch).
   - `NEED_MORE_INFO` on weaker mismatches (e.g., name/age mismatch).
   - Guard: [lib/services/pet_identity_matcher.dart](../lib/services/pet_identity_matcher.dart)

3. **Vet record integrity** (document-source plausibility)
   - Requires basic clinic header/contact signals.
   - Flags free-email domains in records (soft-fail).
   - `NEED_MORE_INFO` when integrity cannot be validated.
   - Guard: [lib/services/vet_record_integrity_guard.dart](../lib/services/vet_record_integrity_guard.dart)

4. **Diagnostic timing guard**
   - Requires that the uploaded records include a determinable visit date and are not stale.
   - Flags “pending results” language.
   - `NEED_MORE_INFO` when dates are missing / record too old / diagnostics pending.
   - Guard: [lib/services/diagnostic_timing_guard.dart](../lib/services/diagnostic_timing_guard.dart)

5. **Document reuse detection** (behavioral abuse)
   - Uses deterministic `documentHash` and searches across prior underwriting cases.
   - Implemented by [lib/services/vet_document_reuse_detector.dart](../lib/services/vet_document_reuse_detector.dart)
   - Outcomes:
     - first-time reuse signal → `NEED_MORE_INFO`
     - reuse across multiple other cases → `DECLINED`
   - cross-account reuse (same hash tied to a case owned by a different `userId`, when available) → `DECLINED`

6. **Medical integrity gates**
   - Confirmed critical condition → `DENIED`
   - Suspected/unknown critical condition (unless explicit rule-out language) → `DECLINED`
   - Missing/incomplete/uncertain facts → `NEED_MORE_INFO` + deterministic evidence checklist

### 5) Plan selection pricing gate

- The plan screen always re-checks pricing eligibility via `PricingGate`.
- If any gate failed upstream, pricing is blocked even if the user navigates forward.

## Underwriting statuses

Statuses used in this system:

- `APPROVED` — pricing allowed (only with explicit route args)
- `NEED_MORE_INFO` — self-serve evidence required; pricing blocked
- `DECLINED` — deterministic decline; pricing blocked
- `DENIED` — deterministic deny (e.g., confirmed critical condition); pricing blocked
- `INCOMPLETE` — missing inputs in the flow; pricing blocked

## Deterministic escalation (loop breaker)

To avoid infinite retry loops, unresolved `NEED_MORE_INFO` outcomes are deterministically escalated:

- If the user reaches `NEED_MORE_INFO` repeatedly without resolving required evidence, the flow will be `DECLINED` with reason `REQUIRED_EVIDENCE_NOT_PROVIDED` after a fixed threshold (currently 3 attempts).
- This is a zero-human safeguard: deterministic, auditable, and prevents “try until it passes” behavior.

## Auditing artifacts

- Underwriting decisions and artifacts are written into `underwriting_cases/{caseId}` when a case exists.
- Vet record artifacts are stored in `underwriting_cases/{caseId}/vet_records/*` including `documentHash`, extracted text URL, and parse status.
