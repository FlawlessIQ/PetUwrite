# Clovara

Clovara is a Flutter + Firebase pet insurance platform.

## What’s in this repo

- Customer quote → plan selection → checkout → policy binding
- Deterministic underwriting for complex cases (rules decide; AI assists only)
- Admin dashboard for underwriting review, policies pipeline, and claims analytics/review
- Vet record PDF ingestion + text extraction pipeline

Authoritative documentation lives in:

- [docs/platform/README.md](docs/platform/README.md)

## Quick start

### Prerequisites

- Flutter SDK (3.x)
- Firebase CLI
- Node.js (for Cloud Functions)

### Install and run

- `flutter pub get`
- `flutter run -d chrome` (or your preferred device)

### Cloud Functions

- `cd functions`
- `npm install`
- Deploy via Firebase (or your existing deploy scripts)

## Key implementation pointers

- Underwriting case lane: `lib/services/underwriting_case_service.dart`, `lib/services/underwriting_decision_engine.dart`
- Bind-time enforcement: `lib/screens/confirmation_screen.dart`
- PDF extraction: `functions/pdfExtraction.js`
- PDF failure monitor (log-only): `functions/pdfExtractionAlerts.js`
- Firestore rules: `firestore.rules`

## Legacy docs

Older status reports and “fix” writeups are archived under:

- [docs/archive/2026-01-08/](docs/archive/2026-01-08/)
