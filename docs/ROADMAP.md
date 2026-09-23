# Clovara Roadmap — living document

Last updated: 2026-09-23 (maintained by Claude Code per CLAUDE.md)

Statuses: `planned` · `in progress` · `shipped` · `blocked(<on what>)` · `cut(<why>)`

## Build phases (contract: clovara-life/SPEC.md)

| Phase | Scope | Status |
|---|---|---|
| P0 Foundations | Auth · Firestore households/pets · Stripe trial+sub · analytics gates · email skeleton | `shipped` 2026-09-23 — all eight steps deployed and verified on the live project |
| P1 Onboarding & capture | 60s Tier-0 · live-updating reveal · silhouette BCS · condition chips · accuracy meter · photo · vaccine-card extraction w/ confirm-chips · family circle · ask registry · Data Covenant page | in progress — accuracy meter, Tier-0, Tier-1 sharpening, silhouette BCS and the Data Covenant `shipped`; family circle, ask registry and photo next; **extraction blocked on the Firestore security review** |
| P2 Protect attach | Pre-priced offer (smart default) · screen of truth · mock rating adapter · post-bind states | planned |
| P3 Launch moments | Arrival certificate · first-night mode · socialization passport · vaccine autopilot · "ate a grape" · sitter mode · gotcha day · renewal-explained (flagged) · FitnessProvider adapter + simulated provider | planned |

## External dependencies (not engineering; engineering must not fake them)

| Dependency | Owner | Status |
|---|---|---|
| Carrier program live (Accelerant): agreement, filed rates, licensing | Conor | in diligence |
| Wearable partner signed (Tractive / Fi / PetPace diligence) | Conor + Matt | evaluating |
| LEGAL-REVIEW items: disclosures, auto-renew (CA/NY), attestation, toxin copy, VAS state list | Counsel (to engage) | open |
| Firestore security review before vet records ship | Conor (budget line exists) | `blocking P1.7` — everything else in P1 can ship without it; vet-record extraction cannot. records/ and events/ are denied outright meanwhile |
| Breed data: McMillan 2024 Supp. Table 3 | Conor (file supplied 2026-09-22) | `shipped` — all 23 dog gaps closed; no illustrative dogs remain |
| Breed data: Teng 2024 cat table (5 gaps), Abyssinian figure, AAHA Table 4 | Conor to obtain files | open |
| Vet review pass: condition onset windows; clinical content ownership | Vet advisor | open |
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
- **SPEC §1 says "75+ tests".** It is 242 unit plus 94 emulator plus seven end-to-end scripts.
  Left alone at Conor's instruction; noted so nobody reads it as a target.
- **Apple sign-in is deferred**, not built as SPEC §3 lists it. Web is covered by email link +
  Google; Apple is only needed when a native iOS app ships. Tracked as an external dependency.
- **SPEC §4.2 says "store original" for the pet photo; we store a 2048px long-edge JPEG.**
  A 12MB HEIC straight off a phone serves nobody: it costs the owner their data allowance,
  costs us storage forever, and half of it cannot be decoded in a browser. 2048px is ample
  for the body-condition comparison the original was being kept for. The avatar is a
  separate 512px square, so the analysable copy is never the cropped one.
