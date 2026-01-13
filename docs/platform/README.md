# Platform Guide (Source of Truth)

This folder is the authoritative, code-aligned documentation for PetUwrite.

## What this platform is

PetUwrite is a Flutter + Firebase pet insurance platform with:

- Customer quote intake and checkout
- A compliant underwriting lane that is deterministic (rules decide; AI assists only)
- Policy binding that enforces underwriting at bind-time
- Claims intake + admin analytics/review tooling
- Vet record PDF ingestion + text extraction pipeline

## Start here

- [Architecture](architecture.md)
- [Data Model](data_model.md)
- [Customer Flows](customer_flows.md)
- [Admin Flows](admin_flows.md)
- [PDF Pipeline & Ops](pdf_pipeline_and_ops.md)

## Key implementation pointers

- App routing/auth gate: `lib/main.dart`, `lib/auth/auth_gate.dart`
- Quote → underwriting routing: `lib/screens/conversational_quote_flow.dart`
- Case underwriting decisioning (deterministic): `lib/screens/medical_underwriting_screen.dart`, `lib/services/underwriting_decision_engine.dart`
- Disclosure acknowledgement UI: `lib/widgets/underwriting_disclosure_dialog.dart`
- Bind-time enforcement + snapshot stamping: `lib/screens/confirmation_screen.dart`
- Underwriting case persistence/denormalization: `lib/services/underwriting_case_service.dart`
- PDF extraction functions + triggers: `functions/pdfExtraction.js`
- PDF failure monitor (log-only): `functions/pdfExtractionAlerts.js`
- Firestore security rules: `firestore.rules`

## Notes on “AI”

- Underwriting: deterministic; AI is used only for assistive tasks (e.g., document parsing/extraction).
- Claims: the codebase includes AI-assisted claim decisioning logic (`lib/services/claim_decision_engine.dart`). This guide documents current behavior as implemented.
