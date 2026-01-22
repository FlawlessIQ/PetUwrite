# Underwriting Rules (Canonical)

This document is auto-generated from the canonical config file:
- config/underwriting_rules.v1.yaml

Do not edit this document manually.

## Current Version

- Version: 1
- Effective date: 2026-01-21
- Change notes: Add market-aligned excluded/restricted breeds and excluded condition categories (additive)

## Enrollment Limits

- Minimum age: 2 months
- Maximum age: 14 years

## Risk Threshold

- Maximum overall risk score: 90 (0–100). If the AI risk score exceeds this value, the pet is declined.

## Excluded Breeds (Auto-Decline)

- American Bully
- American Pit Bull Terrier
- American Staffordshire Terrier
- Cane Corso
- Dogo Argentino
- Presa Canario
- Staffordshire Bull Terrier
- Wolf Dog
- Wolf Hybrid

## Critical Conditions (Auto-Decline)

- cancer
- congestive heart failure
- end stage kidney disease
- end stage liver disease
- malignant tumor
- metastatic cancer
- terminal cancer
- terminal illness

## Excludable Conditions (Approved With Exclusions)

- arthritis
- cranial cruciate ligament
- cruciate
- degenerative joint disease
- djd
- elbow dysplasia
- hip dysplasia
- intervertebral disc disease
- ivdd
- luxating patella
- osteoarthritis
- patellar luxation

---

### How to update

1) Edit config/underwriting_rules.v1.yaml (increment version)
2) node tools/underwriting_rules/render_docs.js
3) node tools/underwriting_rules/publish_underwriting_rules.js --env dev|stage|prod
