# Architecture

## High-level components

- Flutter client (web/iOS/Android/desktop)
  - Navigation is role-gated via an AuthGate (customer vs admin)
  - Implements customer quote, underwriting intake, checkout, confirmation/binding
  - Implements admin dashboard tabs for underwriting review, policies pipeline, claims analytics

- Firebase backend
  - Firestore: primary datastore (users, pets, quotes, policies, underwriting cases, claims, analytics, admin settings)
  - Cloud Functions (2nd Gen, Node): quote/policy triggers, PDF extraction pipeline, scheduled monitoring
  - Storage: vet record PDFs and extracted text artifacts

## Underwriting architecture (compliance posture)

Underwriting is structured so that AI does not approve/decline policies.

### Two lanes

- Instant/standard lane (simple cases)
  - Quote flow can proceed to plan selection/checkout

- Underwriting case lane (complex cases)
  - The quote flow creates an `underwriting_cases/{caseId}` doc and routes the user to the intake/review flow
  - The medical underwriting screen generates a deterministic decision (approve / approve-with-exclusions / decline)

### Decision persistence

- Current decision is stored at:
  - `underwriting_cases/{caseId}/decisions/current`
- Supporting/audit information is captured via:
  - `underwriting_cases/{caseId}/events/*`
  - `underwriting_cases/{caseId}/medical_history/current`

The parent case doc is denormalized with decision summary fields to support admin queries.

### Bind-time enforcement

Policy creation enforces that if an `underwritingCaseId` is present, a current decision exists. Policy issuance stamps a snapshot of underwriting decision + exclusions onto the policy.

## Claims architecture (current)

- Customer claim intake is conversational and captures FNOL details.
- Admin tooling supports analytics and a human review queue.
- The codebase includes an AI-assisted claim decision engine that can auto-process some claims based on thresholds and confidence. If you want a strict “AI cannot settle claims” posture, that would require changing the claim decision path.

## Cloud Functions

Core deployed functions include:

- Quote/policy triggers (analytics + notifications placeholders)
- PDF extraction:
  - HTTP endpoint for extracting PDF text
  - Storage-triggered processing pipeline
- Scheduled PDF extraction failure monitor (log-only)

See [PDF Pipeline & Ops](pdf_pipeline_and_ops.md).
