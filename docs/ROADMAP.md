# Clovara Roadmap — living document

Last updated: 2026-09-24 (maintained by Claude Code per CLAUDE.md)

Statuses: `planned` · `in progress` · `shipped` · `blocked(<on what>)` · `cut(<why>)`

## Build phases (contract: clovara-life/SPEC.md)

| Phase | Scope | Status |
|---|---|---|
| P0 Foundations | Auth · Firestore households/pets · Stripe trial+sub · analytics gates · email skeleton | `shipped` 2026-09-23 — all eight steps deployed and verified on the live project |
| P1 Onboarding & capture | 60s Tier-0 · live-updating reveal · silhouette BCS · condition chips · accuracy meter · photo · family circle · ask registry · Data Covenant page · annual re-projection · phase metrics · vaccine-card extraction w/ confirm-chips | `shipped except two blocked items` 2026-09-23 — Tier-0, Tier-1 sharpening, silhouette BCS, accuracy meter, Data Covenant, ask registry, family circle, photo, the annual re-projection and the four SPEC §4.3 metrics are all deployed and verified. **Both previously-blocked items are now BUILT AND SWITCHED OFF** (2026-09-23): vet-record extraction ships behind `EXTRACTION_ENABLED` with a `StubExtractor` that returns nothing and says why, and conversational onboarding behind `CONVERSATIONAL_ONBOARDING_ENABLED` with a deterministic fallback. The Firestore security review and an LLM key are now switches, not builds. `records/` stays denied in both rule sets until the review. |
| P2 Protect attach | Pre-priced offer (smart default) · screen of truth · mock rating adapter · post-bind states | `shipped` 2026-09-23 — built against `MockRatingAdapter`; `canBind` is false and binding says so. Post-bind states land with the carrier programme, which is the only thing missing. LEGAL-REVIEW on disclosures, fraud notice and waiting periods. |
| P3 Launch moments | **Arrival certificate `shipped` 2026-09-23** · **first-night mode `shipped` 2026-09-23** · **socialization passport `shipped` 2026-09-23** · **vaccine autopilot `shipped` 2026-09-23** · **"ate a grape" `shipped` 2026-09-23 (ER lookup behind a seam, needs a Places key)** · **sitter mode `shipped` 2026-09-23** · **gotcha day `shipped` 2026-09-23** · **renewal-explained `shipped dark` 2026-09-23 (flag off until real policies)** · **FitnessProvider adapter + simulated provider `shipped` 2026-09-23** | `shipped` 2026-09-23 — all ten P3 items built — building in SPEC §6 order; everything here is buildable without an external dependency except the nearest-open-ER lookup in "ate a grape", which needs a Places API key |

## External dependencies (not engineering; engineering must not fake them)

| Dependency | Owner | Status |
|---|---|---|
| Carrier program live (Accelerant): agreement, filed rates, licensing | Conor | in diligence |
| Wearable partner signed (Tractive / Fi / PetPace diligence) | Conor + Matt | evaluating |
| LEGAL-REVIEW items: disclosures, auto-renew (CA/NY), attestation, toxin copy, VAS state list | Counsel (to engage) | open — **now also the P2 attach disclosures, fraud notice and waiting periods (`data/attach.ts`), with four questions logged** |
| Firestore security review before vet records ship | Conor (budget line exists) — **still needed; see note below** | `blocks switching on P1.7, not building it` — the extraction pipeline, confirm-chips and provenance stamping are built and tested behind a flag. records/ stays denied in both rule sets until the review. |
| Breed data: McMillan 2024 Supp. Table 3 | Conor (file supplied 2026-09-22) | `shipped` — all 23 dog gaps closed; no illustrative dogs remain |
| Breed data: Teng 2024 cat table (5 gaps), Abyssinian figure, AAHA Table 4 | Conor to obtain files | open |
| Vet review pass: condition onset windows; clinical content ownership | Vet advisor | open — **now includes `data/toxins.ts` AND `data/redFlags.ts` (the C1 safety list). Both are the highest-stakes content in the product, both are marked VET-REVIEW, both are biased towards the phone call, and neither has been read by a vet.** |
| Google Places API key + billing (nearest open emergency vet, SPEC §6.5) | Claude Code (2026-09-24) | `shipped` — key created via gcloud, restricted to one API and the `clovara-life.web.app` referrer (403 without it, verified), capped at 60/min and 1,000/day against a 75,000 default. Live in production: five open emergency practices, nearest 2.2km. |
| Real shop SKUs / affiliate agreements | Conor + Dan | open |
| Telehealth partner for companion routing | Conor | open — **requirements written** at `docs/TELEHEALTH-PARTNER-REQUIREMENTS.md`: five questions that decide the integration, and two things we must not agree to. No adapter built, on purpose. |
| Apple Sign-In: Developer Program membership, Services ID, signing key | Conor | `deferred` — needed only when a native iOS app ships; email link + Google cover web |
| Clovara-entity Stripe account (replaces the FlawlessIQ sandbox before go-live) | Conor | open |
| Firebase auth config: `clovara-life.web.app` authorised; email-link provider enabled | Claude Code (2026-09-23) | `shipped` — done via the Identity Platform admin API, not the console; password sign-in for the underwriting app verified unaffected |

## Next horizon

**All fifteen are specced at `clovara-life/SPEC-HORIZON.md`; the lump diary (§1.1), the morning briefing (§1.2), second opinion (§1.3), meds autopilot (§1.4), the senior suite (§1.5) and the defensive Remember pass (§2.5) are all `shipped` 2026-09-24 — **every Tier 1 item is now built**, and all four are flipped to `built` on the journey map. The senior suite ships with **no quality-of-life scale**, which answers §5.5 by declining it: that is a clinical decision for the reviewer who owns `toxins.ts` and `redFlags.ts`, and the surface says so in plain words. The Remember *chapter* itself is deliberately unwritten — it needs somebody who has thought about grief rather than features.** (2026-09-24, draft for Conor).
Deliberately uneven: five have real specs because the machinery exists, five are framed with the
decision that must come first, and five are not engineering specs at all. Eleven decisions are
gathered in its §5. Nothing is built.

**Companion AI architecture — spec at `clovara-life/SPEC-COMPANION.md`; six decisions still open for Conor. C0 (vet-visit summary), C1 (safety check) and C2 (grounded companion) all `shipped` 2026-09-24 — **none of them uses a model.** **C3 (model composition) is BUILT AND SWITCHED OFF** — `COMPANION_MODEL_ENABLED` is false pending the privacy decision; verification, the schema and 45 red-team checks including a jailbroken-model fixture are all in place; **C4 done as far as it honestly can be** — asking for a vet now gets a true answer and a route; no provider interface was invented against an unknown API. `docs/TELEHEALTH-PARTNER-REQUIREMENTS.md` is what a partner conversation needs** · claims operations design · affinity/B2B2C channel product · native apps + push · morning briefing · food scanner · lump diary · second opinion · meds autopilot · pack dashboard · DNA · lost-pet network · Remember chapter · marketing-site realignment · final pricing architecture (annual, multi-pet).

## Spec divergences

- **SPEC-HORIZON §1.5 says the senior suite includes "quality-of-life tracking".**
  It ships without it, deliberately. Every validated scale is clinical content,
  and an unreviewed score of how good an animal's life is would be the most
  consequential number in the product. The surface says we do not score a life
  and where that belongs instead. Flagged for Conor: this is the same reviewer
  as `toxins.ts` and `redFlags.ts`, not a separate decision.
- **SPEC §4.2 assumes indoor/outdoor and age-at-neuter are still to do.** Both landed before P0
  opened (2026-09-22) and are deployed. P1 is smaller than the spec text implies.
- **SPEC §1 says "75+ tests".** It is 678 unit plus 107 emulator plus twenty-five end-to-end scripts, and `npm run verify:all` runs every browser suite in one command.
  Left alone at Conor's instruction; noted so nobody reads it as a target.
- **Apple sign-in is deferred**, not built as SPEC §3 lists it. Web is covered by email link +
  Google; Apple is only needed when a native iOS app ships. Tracked as an external dependency.
- **SPEC §4.2 says "store original" for the pet photo; we store a 2048px long-edge JPEG.**
  A 12MB HEIC straight off a phone serves nobody: it costs the owner their data allowance,
  costs us storage forever, and half of it cannot be decoded in a browser. 2048px is ample
  for the body-condition comparison the original was being kept for. The avatar is a
  separate 512px square, so the analysable copy is never the cropped one.
- **The journey map marked "The Annual Re-Projection" as `built` before it was.** It is built
  now (2026-09-23), and all 59 moments were then audited against the page's own definition of
  built — "what's built in the demo today", confirmed by Conor. The other eight `built` claims
  all held: Protect Her Now shows a real pre-filled quote with its breakdown, The Nudge is
  produced by `buildHome` for Max, and Claim in Hours is the claim timeline on Coverage. Two
  moments were behind rather than ahead — Family Circle and the Data Covenant shipped in P1 and
  were still marked `launch`. 11 built, 10 launch, 24 next, 14 sky.
- **The journey map's "Renewal, Explained" promises "what her care this year kept it from being".**
  That is a behaviour credit, and the Data Covenant (invariant 5) promises premiums do not move on
  this data in either direction — "not up, and not down as a reward for behaving". Built as the
  covenant-safe version instead: the filed factors that did move the price, then an explicit list of
  what never will. Claims experience is kept because it is a filed rating factor rather than a
  behaviour score. **The journey copy still says the old thing and needs Conor's call** — it is the
  vision text, not mine to rewrite.

## Credentials

| Key / secret | Scope | Restriction |
|---|---|---|
| `Clovara Life — Places` | browser, in the Life bundle | one API (`places.googleapis.com`), referrer `clovara-life.web.app`; 60/min, 1,000/day |
| `LIFE_GEMINI_API_KEY` | Secret Manager, functions only | one API (`generativelanguage`); mounted as a secretKeyRef, absent from bundle and repo |
| `API key 1` | legacy, unused | **restricted 2026-09-24** — was unrestricted across 31 Maps APIs; now three Clovara referrers and five Maps APIs. No traffic in 30 days and the string is in no local code, so nothing depended on it. Backup of the prior config was taken before the change. |
| Firebase browser / iOS keys | public by design | identify the project, authorise nothing; access control is the rules |
| `GEMINI_API_KEY`, `OPENAI_API_KEY` | underwriting app | not touched — deliberately separate from the Life secrets |

### Where the Stripe key actually is

There is **one** Stripe key, not several. `sk_test_51SI…kyQC`, test mode, on `acct_1SI7vTPzjq9wJkU5`
(the FlawlessIQ sandbox). It appears in three places and they are all the same value:

| Where | Used by |
|---|---|
| Secret Manager `STRIPE_SECRET_KEY` | the deployed Life functions — this is the one that matters |
| `clovara-life/functions/.secret.local` | the local emulator; gitignored |
| `.env` at the repo root | the underwriting app in local dev; gitignored |

`STRIPE_WEBHOOK_SECRET` (`whsec_C50VCE…8lbG`) lives in Secret Manager and `.secret.local`.

**No live Stripe key is configured anywhere in this repo or this project.** Nothing here was using
one, so rolling a live key in the dashboard breaks nothing on this side.

**Rotation is deferred** (2026-09-24, Conor's call) — it is a test key on a sandbox with no real
money behind it, so it is hygiene rather than an incident. `clovara-life/scripts/rotate-stripe-key.sh`
does it in one command when the Clovara-entity account exists. Both the key and the webhook secret
were exposed by the same `.env` leak and both should roll together at that point.

**Deferred:** rotating the Stripe test key — see below.

## The Firestore security review

**Still required, and still Conor's to commission.** SPEC §7 budgets $15K for an independent
review before vet records ship. That cannot be satisfied by the author of the rules reviewing
their own work — the blind spots are shared.

What has been done to make it cheaper and shorter (2026-09-24): an adversarial rules suite that
attacks rather than confirms, kept at `src/store/attack.emulator.test.ts`. It found two real
vulnerabilities in rules that a 94-test intent-based suite had passed:

1. **A client could create a household carrying its own `entitlement: {status: "active"}`** and
   take a paid membership for nothing. `update` forbade touching entitlement; `create` had never
   been asked. Fixed with a field allowlist.
2. **Any household member could remove the founder** from the household holding their own animals
   and keep the pets. Fixed by freezing membership against all client writes.

Both were in paths I had not thought to have an intention about, which is exactly the class of
bug an author cannot find by checking their own intent. **That is the argument for the external
review, not against it.**

Both fixes were deployed 2026-09-24 and verified by running the attacks against **production**,
not the emulator — all three denied, legitimate household creation unaffected. A scan of every
household on the project found **no forged entitlement**: one household carries one, `canceled`
and backed by a real Stripe customer and subscription, which is the test-clock run from the P0
verification. So the hole existed but was never used.

For the reviewer: the rules are `firestore.rules` (Life block) and `storage.rules`; the access
model is one document — a household owns pets, users belong to households; the adversarial suite
above is the starting point, not the finish.

## Known scars

- **The Life surface was allowed to reach 15.6 phone screens** by building every P3 moment onto
  it one at a time, each verified alone. Repaired 2026-09-23 by moving the persistent records to a
  Health File and adding `verify:length`, which holds a 12-screen ceiling and a 9.5-screen settled
  budget. If it fails, the question is what comes off — not what the limit should be.
- **The residual length is mostly pre-existing projection content** — sharpening, timeline, risk
  cards, levers — at 7.5–8.0 screens on the demo pets. Cutting further means collapsing the
  timeline or the risk cards, which are the "it knows my dog" payload in front of investors. That
  is a demo-impact decision for Conor, not an engineering one.

## Measured, and deliberately not done

- **Splitting the breed tables out of the main bundle.** They are 133kB of source and the bulk of
  the 505kB main chunk. On throttled 4G (1.6Mbps, 150ms RTT) the plan is visible in 1.1s and first
  paint is 452ms, so splitting them would mean refactoring `project()` — the most load-bearing code
  in the repo — against a problem that does not exist. Revisit only if a real user on a real
  connection complains.

## The plan

**`docs/EXECUTION-PLAN.md`** (2026-09-24) sequences everything remaining into four tracks: what
must happen before a real person uses this (all of it review, none of it engineering), what unlocks
code already written and switched off, what I build and in what order, and the review gap on five
features whose defining behaviour is a refusal. The order to run it in is at the foot.

## What is left

Every buildable item on this roadmap is built. What remains is not engineering:

| | Needed for |
|---|---|
| Firestore security review | switching on vet-record extraction — the model key now exists, so this is the only remaining gate |
| A privacy/processor decision | switching on **both** conversational onboarding and companion C3. Both are built, tested and off; both send owner-written text to Google when enabled. This is now the single gate on the most product surface. |


| Counsel | attach disclosures, fraud notice, CA/NY auto-renewal, Data Covenant, toxin copy, VAS state list |
| A vet | `data/toxins.ts` above all, plus condition onset windows |
| Carrier programme | real binding; `canBind` is false and the flow says so |
| Clovara-entity Stripe account | anything going live |
| Teng 2024 cat table, Abyssinian, AAHA Table 4 | the last five illustrative feline figures |
| Wearable partner | a real `FitnessProvider`; the seam is built |
| Stripe test key rotation | recommended after the earlier `.env` exposure |
- **SPEC-HORIZON §1.1 asked for a faint overlay of the previous photo during capture.** Not
  possible: capture hands off to the OS camera (`capture="environment"`), so there is no preview to
  draw on. Shipped as the previous photo shown large immediately before the camera opens. A live
  in-app camera would allow the real thing and is a native-app question.
- **SPEC-HORIZON §1.1 put lumps in a subcollection.** Every `{sub=**}` under a pet is denied
  pending the Firestore security review, so they are stored on the pet document instead. No rules
  change was needed and the feature is clear of that gate.
- **SPEC-HORIZON §1.3 assumed second opinion would extract from an uploaded estimate.** That sits
  behind the Firestore security review. Shipped as typed text instead — no storage, no model, no
  review needed, and the questions were always the value. Upload can be added later through the
  extraction pipeline that already exists.

