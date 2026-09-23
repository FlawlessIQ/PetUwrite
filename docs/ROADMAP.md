# Clovara Roadmap — living document

Last updated: 2026-09-23 (maintained by Claude Code per CLAUDE.md)

Statuses: `planned` · `in progress` · `shipped` · `blocked(<on what>)` · `cut(<why>)`

## Build phases (contract: clovara-life/SPEC.md)

| Phase | Scope | Status |
|---|---|---|
| P0 Foundations | Auth · Firestore households/pets · Stripe trial+sub · analytics gates · email skeleton | `shipped` 2026-09-23 — all eight steps deployed and verified on the live project |
| P1 Onboarding & capture | 60s Tier-0 · live-updating reveal · silhouette BCS · condition chips · accuracy meter · photo · family circle · ask registry · Data Covenant page · annual re-projection · phase metrics · vaccine-card extraction w/ confirm-chips | `shipped except two blocked items` 2026-09-23 — Tier-0, Tier-1 sharpening, silhouette BCS, accuracy meter, Data Covenant, ask registry, family circle, photo, the annual re-projection and the four SPEC §4.3 metrics are all deployed and verified. **Blocked: vet-record extraction (P1.7)** on the Firestore security review and an LLM key. **Not started: "tell me about him" conversational onboarding**, which SPEC §4.3 marks P1-optional and which also needs an LLM key. |
| P2 Protect attach | Pre-priced offer (smart default) · screen of truth · mock rating adapter · post-bind states | `shipped` 2026-09-23 — built against `MockRatingAdapter`; `canBind` is false and binding says so. Post-bind states land with the carrier programme, which is the only thing missing. LEGAL-REVIEW on disclosures, fraud notice and waiting periods. |
| P3 Launch moments | **Arrival certificate `shipped` 2026-09-23** · **first-night mode `shipped` 2026-09-23** · **socialization passport `shipped` 2026-09-23** · **vaccine autopilot `shipped` 2026-09-23** · **"ate a grape" `shipped` 2026-09-23 (ER lookup behind a seam, needs a Places key)** · **sitter mode `shipped` 2026-09-23** · **gotcha day `shipped` 2026-09-23** · **renewal-explained `shipped dark` 2026-09-23 (flag off until real policies)** · **FitnessProvider adapter + simulated provider `shipped` 2026-09-23** | `shipped` 2026-09-23 — all ten P3 items built — building in SPEC §6 order; everything here is buildable without an external dependency except the nearest-open-ER lookup in "ate a grape", which needs a Places API key |

## External dependencies (not engineering; engineering must not fake them)

| Dependency | Owner | Status |
|---|---|---|
| Carrier program live (Accelerant): agreement, filed rates, licensing | Conor | in diligence |
| Wearable partner signed (Tractive / Fi / PetPace diligence) | Conor + Matt | evaluating |
| LEGAL-REVIEW items: disclosures, auto-renew (CA/NY), attestation, toxin copy, VAS state list | Counsel (to engage) | open |
| Firestore security review before vet records ship | Conor (budget line exists) | `blocking P1.7` — everything else in P1 can ship without it; vet-record extraction cannot. records/ and events/ are denied outright meanwhile |
| Breed data: McMillan 2024 Supp. Table 3 | Conor (file supplied 2026-09-22) | `shipped` — all 23 dog gaps closed; no illustrative dogs remain |
| Breed data: Teng 2024 cat table (5 gaps), Abyssinian figure, AAHA Table 4 | Conor to obtain files | open |
| Vet review pass: condition onset windows; clinical content ownership | Vet advisor | open — **now includes `data/toxins.ts`, which is the highest-stakes content in the product and is marked VET-REVIEW. It is bands-only and biased towards the phone call, but it has not been read by a vet.** |
| Google Places API key + billing (nearest open emergency vet, SPEC §6.5) | Conor | open — the `PlacesProvider` seam and a null implementation are built; the null one says plainly it cannot search rather than returning "no results", which at 2am reads as "nowhere is open" |
| Real shop SKUs / affiliate agreements | Conor + Dan | open |
| Telehealth partner for companion routing | Conor | unscoped |
| Apple Sign-In: Developer Program membership, Services ID, signing key | Conor | `deferred` — needed only when a native iOS app ships; email link + Google cover web |
| Clovara-entity Stripe account (replaces the FlawlessIQ sandbox before go-live) | Conor | open |
| Firebase auth config: `clovara-life.web.app` authorised; email-link provider enabled | Claude Code (2026-09-23) | `shipped` — done via the Identity Platform admin API, not the console; password sign-in for the underwriting app verified unaffected |

## Next horizon (needs spec before build — see docs gap register in project)

Companion AI architecture (the big one) · claims operations design · affinity/B2B2C channel product · native apps + push · morning briefing · food scanner · lump diary · second opinion · meds autopilot · pack dashboard · DNA · lost-pet network · senior suite · Remember chapter · marketing-site realignment · final pricing architecture (annual, multi-pet).

## Spec divergences

- **SPEC §4.2 assumes indoor/outdoor and age-at-neuter are still to do.** Both landed before P0
  opened (2026-09-22) and are deployed. P1 is smaller than the spec text implies.
- **SPEC §1 says "75+ tests".** It is 401 unit plus 94 emulator plus fifteen end-to-end scripts.
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

