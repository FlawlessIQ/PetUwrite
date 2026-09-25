# Clovara Life — Production Build Spec (v1)

> **How to use this document:** paste it into Claude Code from `~/Development/Clovara`. It is the build contract for taking Clovara Life from investor demo to production product. It supersedes the earlier `clovara-life/HANDOFF.md` where they conflict; the invariants section repeats and extends that file deliberately. Read `clovara-life/README.md` first — it is the authoritative technical reference for what exists.
>
> Work phase by phase, in order. Each phase ends deployed and demonstrable. Ask Conor only for decisions this spec explicitly defers to him.
>
> **Where this stands, 2026-09-25:** the contract below is unchanged, but P0–P3 are all built, deployed and verified, as are the companion architecture (`SPEC-COMPANION.md`) and every Tier 1 item in `SPEC-HORIZON.md`. Read this document for the invariants and the intent; read `../docs/ROADMAP.md` for what is actually done and `CHANGELOG.md` for how. Nothing that blocks a launch is code — `../docs/EXECUTION-PLAN.md` says what it is instead.
>
> (`HANDOFF.md`, referenced above, no longer exists; this document replaced it.)

---

## 1. What exists and what we're building

**Exists (do not rebuild):** the deterministic engines (`src/engine/project.ts`, `src/engine/platform.ts` — pure, clock-injected, 75+ tests), 67-breed evidence-graded database, six working surfaces (Home, Care, Rewards, Shop, Coverage, Life), demo hardening, Firebase multi-site hosting (`main` = homepage, `life` = this app at clovara-life.web.app, `/partners/` = static partner hub in `public/`).

**Building:** the production membership product. Real accounts, real pets in a real database, a paid subscription, the onboarding/data-capture system, the in-app insurance attach flow, and the launch-scope journey moments — all without breaking the demo, which investors still use (demo pets Max, Winston, Luna must always work).

**Positioning (decided, use this language in all UI copy):**
- Vision: "More good years, together." Product: "your pet's plan for life."
- Three pillars, customer-named: **Plan** (know what's ahead) · **Care** (do the right things, easily) · **Protect** (covered when it counts).
- Membership $22.99/mo, 7-day trial, **trial-only** (no free tier) with one exception: the first Plan reveal is visible pre-trial; saving/continuing starts the trial. A price test ($19.99–$24.99) comes later via config, so price must be a config value, never a literal.
- Vocabulary rules: never "lifecycle," "platform," or standalone "wellness" in customer copy; never promise longer life ("help," "on track for," "more good years"); projections always ranges.

## 2. Invariants — every phase, every PR, non-negotiable

1. **Points/rewards never redeem against insurance premium.** The existing test asserting this must keep passing forever.
2. **Premiums shown only as filed/illustrative-labelled rates**, always a separate line item from the membership fee — in UI, in Stripe, in receipts.
3. **No product copy claims to treat, prevent, or slow a condition.** `claimStrength` badges stay.
4. **The companion never diagnoses** — informs and routes to licensed vets; states it is firewalled from underwriting and claims.
5. **The Data Covenant (new, ships in P1):** a plain-words page — companion conversations and tracker data work for the pet and for aggregate science; they are never used against an individual claim and never change an individual's premium outside a filed, transparent program. Linked from onboarding, settings, and the attach flow.
6. **Metric discipline in breed data:** never average across studies measuring different things; never invent figures; `illustrative` stays `illustrative` until a real source lands.
7. **Engines stay pure.** No IO, no randomness, injected clock. All new features consume the `Projection`; none fork their own truth.
8. **Owner-confirmed data only.** Anything extracted (vet records, conversational parsing, photos) becomes structured data only after the owner confirms it as chips. Every stored field carries provenance: `owner_declared | extracted_confirmed | device | vet_verified`.
9. **"I don't know" is always an answer.** The engine widens ranges honestly; UI says "we'll assume typical for his breed until you know."

## 3. Phase 0 — Foundations (everything else depends on this)

- **Auth:** Firebase Auth — email link + Apple + Google. No passwords if avoidable.
- **Data:** Firestore. Households own pets; users belong to households (see §7 data model). Existing localStorage pets migrate on first sign-in ("Keep working with Max?" one-tap import), and the demo path still works signed-out.
- **Payments:** Stripe subscriptions — $22.99/mo (config), 7-day trial, dunning, cancel/pause. Entitlement flag drives member-only UI (member pricing, rewards redemption, companion depth). CA/NY auto-renewal disclosure copy at checkout — placeholder text marked `LEGAL-REVIEW` for Conor's counsel; do not draft final legal language.
- **Analytics:** event instrumentation for the plan's gates from day one: `reveal_viewed`, `trial_started`, `tier1_field_added`, `accuracy_score`, `records_connected`, `attach_offer_viewed`, `attach_bound`, `week4_active`, churn events. A tiny internal dashboard page (route-guarded) is enough.
- **Email:** transactional + lifecycle skeleton (welcome, trial-ending, first-night series for puppies later).

**Definition of done P0:** a stranger can sign up, import/create a pet, start a trial, be charged in test mode, cancel; events land; demo unaffected; deployed.

## 4. Phase 1 — Onboarding & the data-capture system (the core of this spec)

Principle: **onboarding never ends.** Sixty seconds gets the reveal; everything else arrives progressively, each field asked only on a screen where answering visibly benefits the pet.

### 4.1 Tier 0 — before the reveal (target: <60s, no account)
Species → breed (autocomplete; "Mixed / not sure" → size-class picker) → name → age ("about N" slider or exact DOB toggle) → sex. Five taps + one typed name. Then the **Plan reveal** (exists). No account wall before the reveal; saving the plan starts sign-up + trial.

### 4.2 Tier 1 — sharpening, immediately post-reveal (all optional, all inline)
Each answer **visibly moves the projection** — this is the incentive mechanic, build it as such (animate the range change).
- **Body condition: silhouette picker** — 5 tappable outlines per species (BCS-style), never asks for kg first; weight number optional afterward.
- **Neutered** (and, dogs ≥45 lb, optional age-at-neuter → risk framing only, per HANDOFF Phase 1).
- **Conditions:** searchable chips from `conditions.ts`; "None that I know of" first-class.
- **Lifestyle taps:** activity / dental routine / diet quality; cats add **indoor/outdoor** (engine change per HANDOFF Phase 1 if not landed).
- **Plan-accuracy meter:** e.g. "Max's plan: 68% sharp — add his body condition to reach 80%." Deterministic scoring function in the engine package with tests; surfaced on Home until >90%.
- **Photo:** upload/camera → avatar personalization now; store original for future body-condition trend. (Breed-suggestion from photo is NOT in scope yet.)

### 4.3 Continuous capture (P1 where marked, else fast-follow)
- **Vaccine-card / vet-record photo → extraction (P1):** upload image/PDF → LLM extraction → **confirm-chips** (invariant 8) → structured record. Start with vaccines, conditions, weights, visit dates. Show provenance in the pet's Health File.
- **Records email address (fast-follow):** `<petname>-<code>@records.clovara.com` forwarding into the same pipeline.
- **"Tell me about him" conversational onboarding (prototype behind a flag, P1-optional):** one free-text/voice prompt parsed to the same confirm-chips. If it tests well it can replace parts of 4.1/4.2 — build it as an alternate entry to the same capture functions, not a fork.
- **Family circle (P1):** invite household members; roles; shared pet. Contextual asks route to the person who did the thing (v1: anyone can answer).
- **Contextual field rules (P1, as a config table):** microchip → asked only when enabling lost-pet card; diet detail → first shop visit; address/identity → attach flow only; payment → trial end only. Implement as a declarative "ask registry" (field, trigger screen, benefit copy) so product can tune without code.
- **Annual re-projection (exists as concept)** doubles as the yearly data refresh: "anything change this year?" diff-style review.

**Metrics for this phase:** time-to-reveal, tier-1 completion in first session, accuracy-score distribution, records-connected by day 30.

## 5. Phase 2 — Protect: the in-app attach flow

Per the decided flow design (project doc `clovara_insurance_flow_design.md`). Build the UX now against a **mock rating/binding adapter** with the same interface the Accelerant-program integration will use; real binding is gated on the carrier program going live and is NOT this phase's dependency.

- **Screen 1 — the offer, pre-priced:** one smart default configuration computed from the Plan (no form). "Adjust" reveals deductible/reimbursement options. Entry points: post-reveal moment (primary), Coverage tab quiet line, new-pet added. Premium labelled ILLUSTRATIVE until rates are filed — amber box, exactly like the demo.
- **Screen 2 — the screen of truth:** waiting periods as dated countdowns; **pre-existing picture declared in plain words**, generated from the pet's confirmed conditions ("the 2024 hip note means hip dysplasia isn't covered — here's what is"); disclosures + fraud notice (placeholder `LEGAL-REVIEW` docs, scroll-to-enable), attestation checkbox against the existing record; effective date; pay via card on file — **separate Stripe line/product from membership** (invariant 2).
- Post-bind: policy card in Coverage, live waiting countdowns, wellness-rider follow-up offer, "connect vet records" prompt.
- Web direct path (Path B) stays on the existing homepage/quote flow — out of scope here except: add the reverse-bridge hook (post-bind screen offering the standard membership trial; the VAS-state free-months variant is config-gated OFF until counsel confirms the state list).

**DoD:** end-to-end attach in test mode in <90s from offer tap; all copy passes invariants; events instrumented.

## 6. Phase 3 — Launch-scope journey moments

From the journey map's Launch tags (project doc `clovara_journey_moments_map.md`). Each is small; build in this order, each shippable alone:

1. **Arrival Certificate** — shareable card (image download/share-sheet) at pet creation: photo, name, "her plan begins today."
2. **First-Night Mode** — puppy/kitten <12 weeks: hour-by-hour first-72-hours guidance content surface.
3. **Socialization Passport** — ~100 stamps before 16 weeks, gamified checklist feeding the accuracy/streak system. Content from AAHA-consistent socialization lists; qualitative copy only.
4. **Vaccine Autopilot** — schedule from species/age (engine stage templates), reminders, done-marking feeds the Health File; rider-reimbursement display comes with Protect.
5. **"He Ate a Grape"** — toxin lookup (curated dataset, dose-by-weight *risk banding* only — "call now / vet soon / monitor" categories, never mg thresholds presented as clinical advice), nearest-open-ER (Places API), poison-line tap-to-call, always "this is information, call your vet."
6. **Sitter Mode** — expiring share link: read-only pet card (meds, quirks, vet, contacts). Token-based, 7-day default expiry, revocable.
7. **Gotcha Day** — homecoming anniversary stored at creation; annual card, same share pipeline as (1).
8. **Renewal, Explained** — template exists behind a flag; activates with real policies.
9. **CloTag readiness** — do NOT build hardware integration. Build a `FitnessProvider` adapter interface (activity, sleep, vitals streams + device id) with a `SimulatedProvider` (current hash-based values) behind it, so the partner SDK (Tractive/Fi/PetPace — Conor is diligencing) drops in later without touching surfaces. Fitness score = existing score component reading through the adapter.
10. **Data Covenant page** — see invariant 5; ships in P1 but listed here as content to get right.

## 7. Architecture & data model notes

- Firestore shape: `households/{id}` → members[userId, role], `households/{id}/pets/{petId}` → profile (Tier-0/1 fields, each `{value, provenance, updatedAt, updatedBy}`), `pets/{id}/records/*` (extracted+confirmed docs, original file in Storage), `pets/{id}/events/*` (append-only: weights, vaccines, visits — feeds accuracy + future re-projection).
- The engine stays a pure function; a thin `profileFromFirestore()` maps stored shape → engine input. Uncertainty flows from missing fields, never from nulls crashing.
- Extraction pipeline: Storage upload → callable function → LLM parse → *proposed* fields → client confirm-chips → write with `extracted_confirmed`. Never auto-write. Log parse-vs-confirmed diffs (that delta is training gold).
- Feature flags (Remote Config or a config doc): price, conversational onboarding, renewal-explained, VAS-bridge, provider selection.
- Security rules: household-scoped access; sitter tokens read-only subset; the internal dashboard admin-claim gated. Vet records are sensitive — rules reviewed before P1 ships (the earlier $15K security-review line exists for this; flag readiness to Conor).

## 8. Working rules

- Branch per phase; small described commits; nothing to main without Conor.
- `npm test` green + `verify-demo.mjs` pass before any deploy; deploy ONLY `firebase deploy --only hosting:life` (+ functions when added); never plain `--only hosting`; never touch the `main` target or `/partners/` except when asked.
- Demo pets and the signed-out demo path must keep working after every phase.
- New dependencies: ask first. UI stays on the existing hand-rolled brand system — no component libraries.
- Update `README.md` as behavior changes; keep a `CHANGELOG.md` per phase.
- Copy that is legal-adjacent (disclosures, auto-renew, attestations, toxin guidance) ships marked `LEGAL-REVIEW` and listed in the phase summary for Conor.
- End each phase with: what shipped, events now flowing, open `LEGAL-REVIEW` items, and what you'd build next.

## 9. Out of scope (do not start; the journey map holds them)

Real wearable hardware integration · breed-from-photo · DNA · marketplace inventory/own-brand · direct-pay vet network · Vitality-style rated program · quality-of-life compass · vet PIMS integrations · the web quote flow rebuild · anything tagged Next/Blue-sky on the map.

---

*Companion references living in the Clovara project: positioning (`clovara_product_positioning_sept2026.md`), insurance flow (`clovara_insurance_flow_design.md`), journey moments (`clovara_journey_moments_map.md`), financial gates (`clovara_lean_preseed_model_aug2026.md`).*
