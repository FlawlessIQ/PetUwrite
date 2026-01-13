# PDF Pipeline & Ops

## Vet record upload & parsing

The customer underwriting intake supports uploading vet PDFs. The pipeline:

1) Upload PDF to Firebase Storage
2) Extract text via Cloud Function (`extractPdfText`)
3) Persist extraction status/artifacts and parsed results back to Firestore

Low-confidence parsing can cause the case to be referred for manual review.

## Cloud Functions

### PDF extraction

Implemented in `functions/pdfExtraction.js`:

- HTTP endpoint: extract PDF text on demand
- Storage-triggered processing: handles PDFs uploaded to configured buckets/paths
- Writes extraction status, including failures (with `failedAt` and error message)

### PDF extraction failure monitoring (log-only)

Implemented in `functions/pdfExtractionAlerts.js`:

- Scheduled function queries recent `pdf_extractions` failures via a `collectionGroup` query
- If failures exceed a threshold, it logs an alert to Cloud Logging
- Throttles repeated alerts using `admin_settings/ops_alerts`

## Operational notes

- Firestore indexes are required for some collectionGroup queries (see `firestore.indexes.json`).
- Deploy scripts exist at the repo root (`deploy_web.sh`, `deploy_storage.sh`, `deploy_all_fixes.sh`) alongside standard `firebase deploy` workflows.
