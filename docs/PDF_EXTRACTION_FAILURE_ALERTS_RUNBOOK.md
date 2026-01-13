# PDF Extraction Failure Alerts — Runbook

## What this is
A scheduled Cloud Function (`alertPdfExtractionFailures`) monitors recent failures in Firestore `pdf_extractions` documents and (optionally) posts an alert to Slack.

It is intended to catch repeated failures in the vet record PDF ingestion pipeline.

## How it works
- Schedule: every 15 minutes (UTC)
- Query: Firestore `collectionGroup("pdf_extractions")`
  - `status == "failed"`
  - `failedAt >= now - 1 hour`
- Alerting behavior:
  - Only alerts when `failureCount >= threshold`
  - Throttles alerts to avoid spam
  - Always logs a summary + sample failures to Cloud Logging

## Configuration
This alert is log-only (no Slack/email integration).

### Thresholds / throttling
Defaults are designed to avoid noise:
- Threshold: `3` failures in the last hour
- Throttle: `30` minutes between alerts

You can override via environment variables (optional):
- `PDF_EXTRACTION_FAILURE_ALERT_THRESHOLD` (number)
- `PDF_EXTRACTION_FAILURE_ALERT_THROTTLE_MINUTES` (number)

If you don’t need overrides, leave these unset.

## Where to look when alerted
### 1) Cloud Logs
In Google Cloud / Firebase Functions logs, search for:
- `Repeated PDF extraction failures detected`
- `pdf_extractions failures alert throttled`

The log payload includes:
- `failureCount`
- `lookbackMs`
- `sample` of up to 5 failures

### 2) Firestore
Failures live under `pdf_extractions` subcollections (multiple parents), queried via `collectionGroup`.

Common parent locations:
- `underwriting_cases/{caseId}/pdf_extractions/{extractionId}`
- `pets/{petId}/pdf_extractions/{extractionId}`

Useful fields to inspect:
- `status` (expected `failed`)
- `failedAt`
- `errorMessage`
- `filePath` (Storage path)
- `caseId` / `petId` (if present)

### 3) Cloud Storage
Check the referenced `filePath`:
- Confirm the original PDF exists
- Confirm any extracted text artifacts were (or were not) written

## Common failure causes
- Unsupported/corrupt PDF (scanner output, password-protected PDFs)
- Extraction service timeout or memory pressure
- Permissions/IAM issues accessing Storage objects
- Unexpected file path / missing metadata

## Immediate remediation checklist
- Confirm failures are recent (check `failedAt` timestamps)
- Validate the PDF(s) can be opened locally
- Re-run ingestion by re-uploading a known-good PDF
- Check deploy status and recent changes to `functions/pdfExtraction.js`
- If alert volume is high, raise threshold temporarily or investigate systemic outage

## Deployment notes
This alert relies on a Firestore composite index for the `collectionGroup("pdf_extractions")` query.
If alerts are failing with an index error, deploy Firestore indexes:
- `firebase deploy --only firestore:indexes`
