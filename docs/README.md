# docs — what is authoritative and what is history

**Last updated: 2026-09-25.**

There are three products in this repository and 203 markdown files across these
folders, 25 of them at this level. Most of them are completion reports from past sessions, which are
worth keeping and are not worth reading as documentation. This page says which
is which, so nobody has to guess from a filename.

**The test of an authoritative document is that somebody keeps it true.** Six do.

---

## Living documents — kept current, and part of every task's definition of done

`CLAUDE.md` at the repo root makes updating these three part of any change that
affects behaviour or scope:

| | What it is |
|---|---|
| [ROADMAP.md](ROADMAP.md) | The build state. Phases, what shipped, what is blocked, on whom. Carries a "Spec divergences" section for where the code and the spec disagree on purpose. |
| [DECISIONS.md](DECISIONS.md) | Append-only decision log. One line of decision, one line of why. A reversal is a new entry; old entries are never rewritten. |
| [VISION.md](VISION.md) | Canonical statements and the customer vocabulary. Changes only when Conor says the vision changed. Enforced in code by `clovara-life/scripts/verify-copy.mjs`. |

The journey map — `clovara-life/public/partners/journey-data.js` — is the fourth
living document and the single source of truth for the product journey. It
renders the partner map at clovara-life.web.app/partners/journey.html and is
enforced by `clovara-life/scripts/verify-journey.mjs`.

## Current working documents — written 2026-09, accurate as of then

| | What it is |
|---|---|
| [EXECUTION-PLAN.md](EXECUTION-PLAN.md) | Everything not yet done, in four tracks: the reviews that gate a launch, the decisions that unlock finished code, what is left to build, and the review gap. |
| [DEPLOYMENT.md](DEPLOYMENT.md) | The two hosting targets and how to deploy each without hitting the other. **Read before your first deploy.** |
| [FIRESTORE-REVIEW-BRIEF.md](FIRESTORE-REVIEW-BRIEF.md) | What to hand the security reviewer: scope, the two holes already found, and the open question about pet-field provenance. |
| [TELEHEALTH-PARTNER-REQUIREMENTS.md](TELEHEALTH-PARTNER-REQUIREMENTS.md) | The five questions a telehealth partner conversation needs to answer, and two things not to agree to. |

The Clovara Life build contract lives with its code, not here:
`clovara-life/SPEC.md` and its nine invariants, plus `SPEC-COMPANION.md` and
`SPEC-HORIZON.md`.

## Reference for the underwriting product

Accurate as far as anyone knows, but nobody is checking them the way the living
documents are checked. Treat a claim in here as a lead, not a fact.

- [ARCHITECTURE.md](ARCHITECTURE.md) — system diagram for Pet Underwriter AI
- [ADMIN_CONSOLE_ARCHITECTURE.md](ADMIN_CONSOLE_ARCHITECTURE.md)
- [UNDERWRITING_RULES.md](UNDERWRITING_RULES.md) — canonical rules
- [underwriting_flow.md](underwriting_flow.md) — the deterministic flow
- [PRODUCT_CATALOG_AND_PRICING.md](PRODUCT_CATALOG_AND_PRICING.md)
- [PDF_EXTRACTION_FAILURE_ALERTS_RUNBOOK.md](PDF_EXTRACTION_FAILURE_ALERTS_RUNBOOK.md) — an actual runbook
- [RECONCILIATION_QUICK_REFERENCE.md](RECONCILIATION_QUICK_REFERENCE.md)
- [SMOKE_TEST_CHECKLIST.md](SMOKE_TEST_CHECKLIST.md)
- [OPENAI_WEB_SETUP.md](OPENAI_WEB_SETUP.md) — for the Flutter app's key handling

## Point-in-time reviews and analyses

Snapshots. They were true when written and were never meant to be maintained;
several describe work that has since been done or dropped.

- [PLATFORM_COMPLETE_ANALYSIS.md](PLATFORM_COMPLETE_ANALYSIS.md) (2026-01)
- [INVESTOR_VALIDATION.md](INVESTOR_VALIDATION.md) (2026-01)
- [QUOTE_PIPELINE_AUDIT.md](QUOTE_PIPELINE_AUDIT.md) (2026-01)
- [CLAIMS_EXPERIENCE_DEEP_REVIEW.md](CLAIMS_EXPERIENCE_DEEP_REVIEW.md) (2026-01)
- [post-auth-experience-audit.md](post-auth-experience-audit.md) (2026-05)
- [MVP_IMPLEMENTATION_COMPLETE.md](MVP_IMPLEMENTATION_COMPLETE.md),
  [PROJECT_CLEANUP_SUMMARY.md](PROJECT_CLEANUP_SUMMARY.md),
  [AUTHENTICATION_FLOW_FIX.md](AUTHENTICATION_FLOW_FIX.md) — completion reports
  that other documents still link to, which is the only reason they are here
  rather than in `archive/`

## Folders

| | |
|---|---|
| `legal/` | Privacy policy, terms, insurance disclaimers, state licensing checklist. **None of them records a counsel review**, and the open counsel item is Execution Plan A2 — so do not assume any of this has been cleared. |
| `platform/` | A structured set with its own README: architecture, data model, customer and admin flows, the PDF pipeline. The most coherent folder here. |
| `setup/` | One-time setup guides — Firebase, auth, environment, keys. |
| `guides/` | How-to and quick-reference sheets, mostly for the admin console. |
| `admin/` | Admin dashboard documentation. |
| `implementation/` | Implementation notes and completion reports, with its own README. |
| `archive/` | Finished work, kept for history. **Nothing in here should be read as current.** 80 files. |

## Three things to know before trusting anything in here

1. **Three front-ends share this repository.** A Next.js marketing site (`app/`,
   deployed as `main`), a Flutter app (`lib/`, served at `/app` under `main`), and
   Clovara Life (`clovara-life/`, deployed as `life`). A document that says "the
   app" may mean any of them. Check the date and the file paths it cites.
2. **Only Clovara Life has enforced documentation.** Its vocabulary, journey map,
   bundle composition and copy are checked by `npm run verify:all`. The
   underwriting docs have no such check, which is why they are marked as leads
   rather than facts above.
3. **`HOSTING_SETUP.md` was archived on 2026-09-25** because it documented a
   single-target Flutter deployment and its commands would now push both live
   sites. If you have it bookmarked, read [DEPLOYMENT.md](DEPLOYMENT.md) instead.
