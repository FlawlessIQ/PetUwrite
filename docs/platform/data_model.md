# Data Model (Firestore)

This is a pragmatic view of the key collections and how they relate.

## Core customer entities

- `users/{uid}`
  - `userRole` is used for routing/authorization
  - Holds owner contact details (and optionally address)

- `pets/{petId}`
  - Pet demographics used in quote + underwriting

## Quotes

- `quotes/{quoteId}`
  - Owned by a user (`ownerId`)
  - Often references a pet (`petId`)
  - Drives plan selection and checkout

## Underwriting cases

- `underwriting_cases/{caseId}`
  - `userId` (case owner)
  - `status` (e.g., referred/submitted/assessed/approved/approved_with_exclusions/declined)
  - Snapshot fields for pet/owner at the time the case is created
  - Denormalized decision summary fields (outcome, decidedBy, exclusions count, decidedAt)

Subcollections:

- `underwriting_cases/{caseId}/medical_history/current`
  - The current medical underwriting inputs (structured)

- `underwriting_cases/{caseId}/decisions/current`
  - The current underwriting decision

- `underwriting_cases/{caseId}/events/{eventId}`
  - Audit trail events (including disclosure acknowledgements)

## Policies

- `policies/{policyId}`
  - `ownerId`, `petId`
  - `status` (e.g. active)
  - `underwritingCaseId` (optional)
  - Underwriting snapshot and exclusions stamped at bind-time

Also written:

- `users/{uid}/policies/{policyId}`
  - Denormalized reference for easy “my policies” queries

## Claims

The codebase includes more than one claim representation:

- A customer-facing claims flow writing `claims/{claimId}` with statuses like `draft`, `processing`, `settled`, `denied`.
- An analytics/training-oriented claims service that also writes into `claims` (with fields like `riskScoreAtBind`, `wasApprovedManually`, etc.).

If you standardize claims, treat `claims/{claimId}` as the canonical store and migrate older shapes.

## Ops/admin settings

- `admin_settings/ops_alerts`
  - Throttle state and counters for scheduled log-only monitoring

## Security rules

See `firestore.rules` for owner/admin access rules, and admin overrides.
