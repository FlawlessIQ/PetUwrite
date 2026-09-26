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
| [BACKLOG.md](BACKLOG.md) | **Everything outstanding, with stable ids and a `Judged` column.** 97 items: product validation, design, the pre-launch reviews, the unlock decisions, 17 open questions, the 38 unbuilt journey moments, known technical debt, and what has been declined so it is not re-litigated. Start here for "what is left". |
| [JUDGEMENT-COPY.md](JUDGEMENT-COPY.md) | **The copy that carries judgement** (BACKLOG P2): 126 items — every refusal, the escalation ladder, the poison flow, the goodbye flow, the disclosures, the Data Covenant — extracted from what the code renders, each with a Verdict column for Conor. |
| [UAT-PLAN.md](UAT-PLAN.md) | **The user-acceptance test**: Bruno's life from nine weeks to goodbye, in Chrome, with copy-paste console snippets for the time jumps and a Judge line per chapter. Dry-run against production; lists the defects it found going in. |
| [STRATEGIC-REVIEW-2026-09.md](STRATEGIC-REVIEW-2026-09.md) | Why the backlog is ordered the way it is: the roadmap tracked build state and never tracked who had judged the work, and that is the binding constraint. Contains the 30-minute walkthrough. |
| [EXECUTION-PLAN.md](EXECUTION-PLAN.md) | The same blockers as four tracks, with the reasoning for each. The backlog is the list; this is the argument. |
| [DEPLOYMENT.md](DEPLOYMENT.md) | The two hosting targets and how to deploy each without hitting the other. **Read before your first deploy.** |
| [FIRESTORE-REVIEW-BRIEF.md](FIRESTORE-REVIEW-BRIEF.md) | What to hand the security reviewer: scope, the two holes already found, and the open question about pet-field provenance. |
| [TELEHEALTH-PARTNER-REQUIREMENTS.md](TELEHEALTH-PARTNER-REQUIREMENTS.md) | The five questions a telehealth partner conversation needs to answer, and two things not to agree to. |
| [CARRIER-PROGRAMME-REQUIREMENTS.md](CARRIER-PROGRAMME-REQUIREMENTS.md) | What a carrier or MGA has to be able to do before `canBind` can go true, and four things not to agree to. |
| [WEARABLE-PARTNER-REQUIREMENTS.md](WEARABLE-PARTNER-REQUIREMENTS.md) | What a tracker has to measure, report and delete before it can back the fitness seam. |
| [MODEL-DATA-DECISION.md](MODEL-DATA-DECISION.md) | Whether owner-written text may go to Google: what each path actually sends, the five options, and a recommendation. |

The Clovara Life build contract lives with its code, not here:
`clovara-life/SPEC.md` and its nine invariants, plus `SPEC-COMPANION.md` and
`SPEC-HORIZON.md`.

## Reference for the underwriting product

Accurate as far as anyone knows, but nobody is checking them the way the living
documents are checked. Treat a claim in here as a lead, not a fact.

- [ARCHITECTURE.md](ARCHITECTURE.md) — system diagram for Pet Underwriter AI
- [ADMIN_CONSOLE_ARCHITECTURE.md](ADMIN_CONSOLE_ARCHITECTURE.md)
- [UNDERWRITING_RULES.md](UNDERWRITING_RULES.md) — canonical rules
- [underwriting_flow.md](underwriting_flow.md) — the deterministic flow, as designed
- [UNDERWRITING_FLOW_IMPLEMENTATION.md](UNDERWRITING_FLOW_IMPLEMENTATION.md) — the same flow as built, in far more detail. It arrived from the repository root as `UNDERWRITING_FLOW.md`, which differed from the file above only by case
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
Every folder now has a README naming what is reference and what is a completion
report. Start there rather than with a filename.

| | |
|---|---|
| [`legal/`](legal/README.md) | Privacy policy, terms, disclaimers, state licensing. **Nothing in it records a counsel review** — Execution Plan A2. |
| [`platform/`](platform/README.md) | Architecture, data model, customer and admin flows, the PDF pipeline. The most coherent folder here. |
| [`setup/`](setup/README.md) | One-time setup per environment. Not deployment — that is [DEPLOYMENT.md](DEPLOYMENT.md). |
| [`guides/`](guides/README.md) | How the underwriting product works. `PRICING_MODEL_REVIEW_CURRENT_PRODUCT.md` is the one to read if you care how a premium is computed. |
| [`admin/`](admin/README.md) | The underwriter console: five features, documented three times each. |
| [`implementation/`](implementation/README.md) | Implementation notes and completion reports. |
| `archive/` | Finished work, kept for history. **Nothing in here should be read as current.** 80 files. |

## Eleven documents arrived from the repository root on 2026-09-25

The root held eleven underwriting and Flutter notes alongside the two files that
belong there. Three were renamed on the way in, and each rename removed a trap:

| From the root | Now | Why renamed |
|---|---|---|
| `ROADMAP.md` | `archive/ROADMAP_VISUAL_SNAPSHOT_2026-01.md` | A second file called ROADMAP.md, unmaintained since January, one directory away from the living one |
| `UNDERWRITING_FLOW.md` | `UNDERWRITING_FLOW_IMPLEMENTATION.md` | Collided with `underwriting_flow.md` by case alone, and macOS would not hold both |
| `QUICK_REFERENCE.md` | `implementation/QUICK_REFERENCE_EI_BI_AND_CHECKOUT.md` | Two quick references concatenated into one file, headings and all; the name now says so |

The rest went to `setup/` (Stripe keys, the Gemini key, iOS simulator),
`implementation/` (Stripe payments, policy management, claim decision
requirements) and `admin/` (the dashboard visual guide).

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
