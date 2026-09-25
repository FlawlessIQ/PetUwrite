# guides/ — how the underwriting product works, and how to work on it

Twenty-five files. Three of them are the ones to read if you want to understand
what the product actually does today; the rest are per-feature guides, quick
references and completion summaries in the usual three-fold pattern.

## Read these first

| | |
|---|---|
| [UNDERWRITING_CURRENT_STATE.md](UNDERWRITING_CURRENT_STATE.md) | What underwriting does now |
| [PRICING_MODEL_REVIEW_CURRENT_PRODUCT.md](PRICING_MODEL_REVIEW_CURRENT_PRODUCT.md) | **How a premium is computed today**, file by file, and which parts can be worked on offline. Every source path in it still resolves. Directly relevant to the "final pricing architecture" item in `../EXECUTION-PLAN.md`, which is a commercial decision rather than an engineering one |
| [UNDERWRITING_GAPS_AND_IMPROVEMENTS.md](UNDERWRITING_GAPS_AND_IMPROVEMENTS.md) | What is missing, as of early 2026 |

## Per-feature reference

- **Rules engine** — [guide](UNDERWRITING_RULES_ENGINE_GUIDE.md) · [quick ref](UNDERWRITING_RULES_QUICK_REF.md). The canonical rules themselves are `../UNDERWRITING_RULES.md`.
- **Eligibility** — [integration guide](ELIGIBILITY_INTEGRATION_GUIDE.md) · [visual flow](ELIGIBILITY_VISUAL_FLOW.md)
- **Explainable AI** — [guide](EXPLAINABILITY_GUIDE.md) · [quick ref](EXPLAINABILITY_QUICK_REF.md) · [overview](EXPLAINABILITY_README.md)
- **Claims analytics and ML retraining** — [guide](CLAIMS_ANALYTICS_GUIDE.md) · [quick ref](CLAIMS_ANALYTICS_QUICK_REF.md)
- **Unauthenticated quote flow** — [guide](UNAUTHENTICATED_FLOW_GUIDE.md) · [quick ref](UNAUTHENTICATED_FLOW_QUICK_REF.md)
- **Declined-quote notifications** — [guide](DECLINED_QUOTE_NOTIFICATIONS_GUIDE.md)
- **Flutter ↔ policy functions** — [integration guide](FLUTTER_INTEGRATION_GUIDE.md)
- **Assets, fonts, branding, avatar, homepage** — [assets](ASSETS_AND_FONTS_GUIDE.md) · [branding](BRANDING_QUICK_REF.md) · [avatar](AI_AVATAR_QUICK_REF.md) · [homepage](HOMEPAGE_QUICK_REF.md)
- **API keys** — [quick ref](API_KEY_QUICK_REF.md)

## Analyses and completion summaries

`UNDERWRITING_FLOW_ANALYSIS.md` · `UNDERWRITING_PROCESS_ANALYSIS.md` ·
`EXPLAINABILITY_SUMMARY.md` · `ELIGIBILITY_INTEGRATION_SUMMARY.md`

Snapshots from 2025–early 2026. True when written; nothing keeps them true.
