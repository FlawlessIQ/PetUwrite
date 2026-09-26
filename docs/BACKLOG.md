# Clovara backlog — everything outstanding, in one place

**Created 2026-09-25. Last updated 2026-09-25 (UI pass).** Consolidated from
`EXECUTION-PLAN.md`, `STRATEGIC-REVIEW-2026-09.md`, `ROADMAP.md`,
`clovara-life/SPEC-COMPANION.md` §10, `clovara-life/SPEC-HORIZON.md` §5 and the
journey map. Nothing here is new work invented for the list.

## How to read this

Every item has a stable id, so it can be referred to in a commit or a
conversation without quoting it. Ids are never reused, and a closed item stays
listed with its outcome rather than being deleted.

**`Judged` is the column that matters and the one the roadmap never had.** The
strategic review's finding was that build state was tracked and *review* state
was not, so work could look finished while nobody but me had formed a view.

| Judged | Meaning |
|---|---|
| **—** | Nobody but Claude Code. This is the default and it is not a good place to be. |
| **C** | Conor has seen it and formed a view |
| **V** | A clinician has read it |
| **L** | Counsel has read it |
| **S** | An independent security reviewer has read it |

Sizes are engineering effort only: **S** hours · **M** days · **L** weeks · **—**
not an engineering task. Items owned by somebody outside this repository carry no
size, because their duration is not mine to estimate.

---

## P · Product validation — the constraint

Ahead of everything else. While these are open, more building enlarges an
unreviewed pile.

| id | Item | Owner | Size | Judged |
|---|---|---|---|---|
| **P1** | **Walk the product.** 30 minutes on a phone, the nine steps in `STRATEGIC-REVIEW-2026-09.md` §6. Steps 5 (collapse) and 9 (marking a pet as died) matter most | Conor | — | — |
| **P2** | **Read the copy that carries judgement.** Not all 2,920 strings — the ~200 that decide something: every refusal, every empty state, the escalation ladder, the death-of-a-pet flow, the Data Covenant. **Claude Code to extract the list as one document first** | Claude Code → Conor | S | — |
| **P3** | **Define the first cohort.** Fifty people, and what we want to learn from them. Unblocks the prioritisation of every J item and gives A2/A3 a date | Conor | — | — |
| **P5** | **Run the UAT** — `docs/UAT-PLAN.md`: Bruno, a Labrador, from nine weeks to goodbye, in Chrome. Three tracks (his life signed out; his family signed in; everywhere), a Judge line per chapter, dry-run against production 2026-09-25. Supersedes the informal P1 walk-through. **Run 1 (Track A, desktop, Claude in Chrome) 2026-09-26:** 43 of 45 pass, 1 fails, 1 left for a human; 19 defects → U4–U7. Still to do: every chapter at phone width, all of Track B, the Judge lines | Conor (+ testers) | — | — |
| **U1** | ~~The Remember pass leaks on Home~~ — **fixed 2026-09-26 and deployed from branch `uat-fixes`.** Enforced in the engines, not per-surface: `planAccuracy` has no next answer and no Home meter for a remembered pet, and `buildHome` returns no score and nothing coming up (a null the type checker makes Home handle). Home's heading becomes the pet's name, and the companion prompt and stage advice go. `verify-remember` now checks the six exact strings the dry-run found, and fails all six against production. UAT-PLAN K1–K2 | Claude Code | done | — |
| **U2** | ~~Every member is greeted as "Conor"~~ — **fixed 2026-09-26 and deployed from branch `uat-fixes`.** Greets by the first word of the signed-in display name, and by no name otherwise — never an email prefix. Signed out, including the investor demo, it is "Good evening" alone. UAT-PLAN K3 | Claude Code | done | — |
| **U3** | ~~"about 1 hours"~~ — **fixed 2026-09-26 and deployed from branch `uat-fixes`.** One rounded number drives the figure and the plural. UAT-PLAN K4 | Claude Code | done | — |
| **U4** | ~~The Remember pass leaks on four more tabs~~ — **fixed 2026-09-26 and deployed from branch `uat-fixes-2`** (UAT run 1, D19). Engines again, not per-screen: `project()` stops the clock at the date they died; `buildRewards` and `buildCoverage` return null and `buildCompanion` nothing, so each tab has to say something else. Rewards, Care, Coverage and #/protect show one quiet line and the way back to the record; Life shows how long they lived and the stages they lived through, with no forecast, no stages to come, no advice and no breed risks. `verify-remember` now visits every tab alive and after — the new checks fail nine times against production | Claude Code | done | — |
| **U5** | ~~The collapse screen has no way to find a vet~~ — **fixed 2026-09-26 and deployed from branch `uat-fixes-2`** (D17). "Find the nearest vet open now" is one shared component (`FindVet`) on both urgent screens; the places seam moved out of `toxins.ts` so the collapse screen does not download the toxin table. `verify-safety` requires it | Claude Code | done | — |
| **U6** | ~~Defaults presented as answers~~ — **fixed 2026-09-26 on branch `uat-fixes-3`, not yet deployed** (D2, D3, D18). Levers carry `told`: an unanswered one shows nothing chosen and "Not asked yet… which moves nothing". Score bands say "Not asked yet" (one called an unasked dog "Intact"), and Home's biggest lever is only ever something the owner told us — never teeth in the puppy stage. The medication form has no preselected frequency | Claude Code | done | — |
| **U7** | ~~Run 1's copy and small defects~~ — **fixed 2026-09-26 on branch `uat-fixes-3`, not yet deployed.** Honesty: the companion's summary line names only what is on file (D11), Care claims a condition only when there is one (D9), Protect says nothing can be bought before the declaration (D12), Coverage says no claim can be made yet (D13). Counsel item D14 reworded to "the products picked for" — **still wants counsel's eye (A2)**. The review tag reads "Still being reviewed by a vet" (D16). The review: "Answer it" / "Skip" for never-asked questions, and Done works at any point (D7, D8 — this reverses a check that deliberately kept Done disabled). Plus D1, D4, D5, D6, D10, D15 | Claude Code (+L for D14) | done | — |
| **P4** | **Ratify or overturn the six refusals.** The lump diary not saying whether a lump grew · the companion not naming a condition · the vet summary omitting the projection · the safety check not reassuring · C3 discarding uncited output · the senior suite carrying no quality-of-life score. Each is a strategic choice currently made by default | Conor (+V for the clinical half) | — | — |

## D · Design and UI

| id | Item | Owner | Size | Judged |
|---|---|---|---|---|
| **D-UI1** | ~~Visual direction~~ — **closed 2026-09-25**: Conor issued `docs/DESIGN.md` and `docs/styleguide.html` | Conor | — | **C** |
| **D-UI2** | ~~Type scale~~ — **shipped 2026-09-25**, deployed from branch `type-scale`. 35 hand-set sizes → 19 named tokens (§3 roles, or named as not being one); `verify:brand` rejects arbitrary sizes. Spacing was already on Tailwind's 4px grid (§4) and needed no scale of its own | Claude Code | done | — |
| **D-UI3** | Apply the visual direction across all surfaces — **shipped 2026-09-25**, deployed from branch `ui-pass` after Conor saw the before/after gallery. Fifteen spec/product disagreements flagged in ROADMAP "UI pass: open questions" | Claude Code → Conor | done | **C** |
| **D-UI4** | Palette swap, if the brand itself changes. Cheap and independent of the above: 8 values in one config file, 907 token references follow | Claude Code | S | — |
| **D-UI5** | Dark mode. DESIGN.md §2 reserves a palette and says do not build until instructed | Conor | M | **C** |
| **D-UI7** | ~~Resolve the seventeen UI-pass open questions~~ — **resolved and shipped 2026-09-25**, deployed from branch `d-ui7`. Fourteen closed — four by Conor's decision (emergency screens to amber, no gradient text, a heading role, an honest demo) — and one left open as D-UI8. Outcomes in ROADMAP | Conor + Claude Code | done | **C** |
| **D-UI8** | ~~A `fact` block for the conversation kit~~ — **shipped 2026-09-25**, deployed from branch `d-ui8`. `{ kind:'fact'; claim; source; citation? }` added to §5b; the live companion's recall, escalation and vet routes all render through the kit now, so no path renders free text | Conor → Claude Code | done | **C** |
| **D-UI6** | Empty, loading and error states as a designed set. They exist and are individually considered; they have never been looked at together | Conor + Claude Code | M | — |

## A · Before any real person uses this

Not optional, and not mine. Unchanged from `EXECUTION-PLAN.md` Track A.

| id | Item | Owner | Blocks | Judged |
|---|---|---|---|---|
| **A1** | **A vet reads `clovara-life/src/data/toxins.ts` and `clovara-life/src/data/redFlags.ts`.** Both ship marked VET-REVIEW and neither has been read by a clinician | vet advisor | everything | — |
| **A2** | Counsel: attach disclosures, fraud notice, CA/NY auto-renewal, the Data Covenant, toxin copy — **and now a sentence on third-party processing** if B2 is a yes | counsel | taking money, the Protect flow | — |
| **A3** | Clovara-entity Stripe account. Today it is the FlawlessIQ sandbox, so the wrong company would be merchant of record | Conor | taking money at all | — |
| **A4** | Rotate the Stripe key and webhook secret. `clovara-life/scripts/rotate-stripe-key.sh`, ten minutes | Conor | nothing — it clears credential debt | — |

## B · Decisions that switch on finished code

Each has the document it needs to be closed in one sitting.

| id | Item | Owner | Turns on | Judged |
|---|---|---|---|---|
| **B1** | Firestore security review. Brief: `FIRESTORE-REVIEW-BRIEF.md` | Conor → reviewer | vet-record extraction | — |
| **B2** | **May owner-written text go to Google?** Memo: `MODEL-DATA-DECISION.md`. Recommendation: extraction and conversational onboarding yes, companion composition later, and ask about Vertex AI rather than the Gemini Developer API | Conor + counsel | **three** features | — |
| **B3** | Telehealth partner. Requirements: `TELEHEALTH-PARTNER-REQUIREMENTS.md` | Conor | companion C4's real routing | — |
| **B4** | Carrier programme. Requirements: `CARRIER-PROGRAMME-REQUIREMENTS.md` | Conor | real binding; `canBind` is false | — |
| **B5** | Wearable partner. Requirements: `WEARABLE-PARTNER-REQUIREMENTS.md` | Conor + Matt | a real `FitnessProvider` | — |
| **B6** | Teng 2024 cat table, the Abyssinian figure, AAHA Table 4. **Needs the published tables themselves** — inventing a breed figure is the one thing invariant 6 forbids outright | Conor | the last five illustrative feline figures | — |

## R · Review gap

| id | Item | Owner | Size | Judged |
|---|---|---|---|---|
| **R1** | A1's reviewer also reads the refusal copy — the "nothing matched" screen, the lump-diary caveat, the visit summary's omissions. One session | vet advisor | — | — |
| **R2** | Somebody other than Claude Code writes red-team cases. The existing suite has its author's blind spots by construction; the two holes it found in rules written by the same author are the evidence | Conor → someone | — | — |
| **R3** | Resolve the **Claims, Corroborated** contradiction. The journey map says a CloTag timeline substantiates a claim; the Data Covenant page says nothing a tracker records decides one. Invariant 5 only forbids using it *against* a claim, so the map may be right and the covenant copy too strict. **One of the two has to change** | Conor | S once decided | — |

## Q · Open questions

Answered-by-building items are marked so, and want ratifying rather than deciding
from scratch.

| id | Question | Source | Status |
|---|---|---|---|
| **Q1** | Clinical ownership of the red-flag list — who, and on what footing? | COMPANION §10.1 | open · same person as **A1** |
| **Q2** | Conversation retention — how long, and what may be learned in aggregate? | COMPANION §10.2 | open · suggested 24 months, owner-deletable, aggregate learning from confirm-chip outcomes only |
| **Q3** | Is a conversation ever readable by a human at Clovara? | COMPANION §10.3 | open · the Data Covenant does not currently carve it out |
| **Q4** | Verification threshold, and what the fallback says | COMPANION §10.4 | **answered by building** — `DISCARD_THRESHOLD = 1/3`. Wants ratifying |
| **Q5** | Does the companion ever initiate? | COMPANION §10.6 | open · everything is reactive today; initiating is a different product and a different consent |
| **Q6** | Does the lump diary prompt on a schedule? | HORIZON §5.1 | open · shipped without one |
| **Q7** | Where does the morning briefing land before native apps? | HORIZON §5.2 | open · email built and switched off |
| **Q8** | Pack dashboard — what is it *for*? | HORIZON §5.6 | open · blocks **J-P1** |
| **Q9** | Lost-pet network — our network, a registry integration, or a poster? | HORIZON §5.7 | open · blocks **J-N7** |
| **Q10** | Food scanner — license a composition database, or drop it? | HORIZON §5.8 | open · blocks **J-N5** |
| **Q11** | DNA — which partner? | HORIZON §5.9 | open · blocks **J-N8** |
| **Q12** | Who writes the Remember chapter? | HORIZON §5.10 | open · the defensive pass is done; the chapter is deliberately unwritten |
| **Q13** | Native apps and push — which build target, and when? | HORIZON §5.11, ROADMAP | open · gates everything time-sensitive, deserves its own document |
| **Q14** | Final pricing architecture — annual terms, multi-pet, membership vs premium | ROADMAP Tier 3 | open · `guides/PRICING_MODEL_REVIEW_CURRENT_PRODUCT.md` is the current state |
| **Q15** | Claims operations design — who reads a claim, on what SLA, with what authority to pay, and what happens at 3am | ROADMAP Tier 3 | open · negotiated partly inside **B4** |
| **Q16** | Affinity / B2B2C channel | ROADMAP Tier 3 | open |
| **Q17** | Marketing-site realignment (the `main` target) | ROADMAP Tier 3 | open · deliberately never touched |

## J · Journey moments not yet built

38 of 60. Ordering here is the map's, not a priority — **P3 is what makes these
sortable.** Each is `[pillar/value]` as the map carries it.

### At `launch` horizon (3)

| id | Moment | |
|---|---|---|
| **J-L1** | The CloTag | Plan/data · blocked on **B5** |
| **J-L2** | The Fitness Score | Plan/data · blocked on **B5** |
| **J-L3** | Renewal, Explained | Protect/love · **built and switched off**; blocked on **B4** |

### At `next` horizon (21)

| id | Moment | |
|---|---|---|
| **J-N1** | The Countdown | Care/love |
| **J-N2** | First Visit, Pre-booked | Care/habit |
| **J-N3** | The Growth Reveal | Plan/love |
| **J-N4** | Two-Minute Trainer | Care/habit |
| **J-N5** | Food Scanner | Care/habit · blocked on **Q10** |
| **J-N6** | Environmental Guardian | Plan/love · the weather seam exists with nothing behind it |
| **J-N7** | Lost-Pet Alert + CloTag Scan | Care/love · blocked on **Q9** and **B5** |
| **J-N8** | The DNA Reveal | Plan/data · blocked on **Q11** |
| **J-N9** | The Pack Dashboard | Plan/revenue · blocked on **Q8** |
| **J-N10** | Points That Give Back | Care/love |
| **J-N11** | Video Vet, With Her History | Care/love · blocked on **B3** |
| **J-N12** | Surgery Companion | Care/love |
| **J-N13** | The Re-Plan | Plan/love |
| **J-N14** | Claims, Corroborated | Protect/love · blocked on **R3** |
| **J-N15** | The Loss-Control Tag | Protect/revenue · blocked on **B4**, **B5** |
| **J-N16** | Mobility Monitor | Plan/data |
| **J-N17** | Bloodwork, Trended | Plan/data |
| **J-N18** | Dignity Coverage | Protect/love · blocked on **Q12** |
| **J-N19** | Her Story | Care/revenue · blocked on **Q12** |
| **J-N20** | The Memorial | Care/love · blocked on **Q12** |
| **J-N21** | When You're Ready | Plan/growth · blocked on **Q12** |

### At `sky` horizon (14)

| id | Moment | |
|---|---|---|
| **J-S1** | The Matchmaker | Plan/growth |
| **J-S2** | Ethical Start Network | Plan/growth |
| **J-S3** | Walk Intelligence | Care/habit |
| **J-S4** | Smart-Home Senses | Plan/data |
| **J-S5** | Pet Passport | Care/love |
| **J-S6** | New-Baby Mode | Care/love |
| **J-S7** | Moving-House Mode | Care/love |
| **J-S8** | The Second-Pet Matchmaker | Plan/growth |
| **J-S9** | The Research Pack | Plan/data |
| **J-S10** | Gait Check | Plan/data |
| **J-S11** | Vet Visit Recorder | Care/love |
| **J-S12** | Direct-Pay Network | Protect/love |
| **J-S13** | Earned Rates | Protect/revenue · a separately filed programme, never a use of covenant data |
| **J-S14** | The Quality-of-Life Compass | Care/love · the vet-partnered version of what the senior suite declined |

## T · Technical, known and deliberate

Nothing here is urgent. All of it is written down so it is not rediscovered.

| id | Item | Size |
|---|---|---|
| **T1** | **A pet document has no field allowlist.** Any member can write `provenance: 'vet_verified'` and an `updatedBy` naming somebody else. Cosmetic today; not cosmetic the moment anything trusts those fields. First question in `FIRESTORE-REVIEW-BRIEF.md` — the rules-level fix means enumerating every field, which fails closed | M, and gated on **B1** |
| **T2** | `updatedBy` could be constrained to `request.auth.uid` today, unlike the rest of T1 | S, and needs the rules-change protocol |
| **T3** | Entry chunk is 536kB (157kB gzipped) and the breed tables are most of it. **Measured and declined**: 1.3s to a fully rendered plan on 4G with 4× CPU throttling, and the plan renders *from* the breed table, so splitting it puts a loading state on the first screen | — |
| **T4** | The shop catalogue rides in the entry chunk because `platform.ts` holds both the home builders and `recommendProducts`. ~4kB gzipped to separate | S |
| **T5** | `functions/policyEmails.js` still uses the deprecated `functions.config()`. Life uses Secret Manager | S |
| **T6** | SPEC §1 says "75+ tests"; it is 789 plus 27 suites. Left alone at Conor's instruction, noted in ROADMAP's spec divergences | — |
| **T7** | `activeId` is state duplicated from the URL. Three bugs came from it; `verify:routing` now pins the behaviour, but the duplication itself remains | M |
| **T8** | `screenlog.0` and `_to_delete/` are untracked at the repo root. Conor's to remove | — |

## X · Declined, so it is not re-litigated

| id | Decision | Why |
|---|---|---|
| **X1** | No cost range on second opinion | The questions were the value and none of the risk; the plausible data source was our own claims |
| **X2** | No quality-of-life scale in the senior suite | Clinical content; folds into **A1**. See **J-S14** for the version that could exist |
| **X3** | No dose attribution in a household | That it was given prevents the double dose; who gave it turns a shared record into a ledger of who forgot |
| **X4** | Briefing email ships off | A daily email is a different consent from a monthly one |
| **X5** | No `TelehealthProvider` interface invented against an unknown API | The first real integration would delete it; requirements were written instead |
| **X6** | The faint repeat-capture overlay in the lump diary | Impossible — `capture="environment"` hands off to the OS camera |
| **X7** | Lumps live on the pet document, not a subcollection | Everything under a pet is denied pending **B1**; now covered by adversarial tests |
