# Clovara Life — execution plan

**Written 2026-09-24.** Covers everything not yet done: what is blocked, on whom,
in what order, and what happens if nothing changes.

Sizes are relative (S/M/L) and mine are honest. **I cannot estimate calendar
time for anything owned by somebody else**, so those carry no duration — only
their position in the chain.

---

## Where this actually stands

Built, deployed and verified: P0 Foundations, P1 Onboarding & capture, P2
Protect attach, P3 Launch moments (all ten), and the companion C0–C4. 614 unit
tests, 107 emulator tests, 22 browser suites, 39 commits on
`phase-0-foundations`. Nothing merged to `main`.

**No engineering work blocks a launch.** What blocks a launch is review.

---

## Track A — before any real person uses this

These are not optional and they are not mine. Nothing else on this page matters
if these are not done.

| # | What | Owner | Blocks |
|---|---|---|---|
| **A1** | **A vet reads `data/toxins.ts` and `data/redFlags.ts`** | vet advisor | Everything. These decide what somebody is told when their animal has eaten something or collapsed. Both ship marked VET-REVIEW and **neither has been read by a clinician.** |
| **A2** | Counsel: attach disclosures, fraud notice, CA/NY auto-renewal, Data Covenant, toxin copy | counsel | Taking money, and the Protect flow |
| **A3** | Clovara-entity Stripe account | Conor | Taking money at all. Today it is the FlawlessIQ sandbox, so the wrong company would be merchant of record |
| **A4** | Rotate the Stripe key + webhook secret | Conor | Nothing, but both were exposed by the `.env` incident. One command each: `rotate-stripe-key.sh` |

**A1 is the one I would start today.** Every red-team pass I ran found phrasing
gaps in lists I wrote — *"siezure"*, *"went floppy"*, *"nothing **is** coming
out"* on the most time-critical flag there is. That pattern does not stop by me
writing more lists, and the reviewer needs to be somebody who thinks about how
frightened people type, not only about what is clinically correct.

---

## Track B — unlocks code that is already written and tested

Each of these turns a flag from false to true. No building required.

| # | Decision | Owner | Turns on |
|---|---|---|---|
| **B1** | **Firestore security review** (SPEC §7; $15K line exists) | Conor | Vet-record extraction. The pipeline, confirm-chips and provenance are built and off. My own adversarial pass found **two real holes** in rules I wrote — that is the argument for it, not against |
| **B2** | **May owner-written text go to Google?** | Conor + counsel | Companion C3 **and** conversational onboarding. One decision, two features |
| **B3** | Telehealth partner | Conor | Companion C4's real routing. `docs/TELEHEALTH-PARTNER-REQUIREMENTS.md` is the conversation |
| **B4** | Carrier programme (Accelerant) | Conor | Real binding. `canBind` is false and the flow says why |
| **B5** | Wearable partner | Conor + Matt | A real `FitnessProvider`. The seam is built and the simulated one discloses itself |
| **B6** | Teng 2024 cat table, Abyssinian, AAHA Table 4 | Conor | The last five illustrative feline figures. Every dog breed is published-source |

---

## Track C — what I build, in order

Only C1 and C2 are worth starting before Track A lands. **Everything below adds
surface area that nobody has reviewed**, and that gap is already the largest
risk in the product.

| # | What | Size | Notes |
|---|---|---|---|
| ~~C1~~ | ~~Second opinion~~ — **shipped 2026-09-24** | M | Same rails as extraction. **Ship without the cost range** — the questions are most of the value and none of the risk, and the obvious data source is our own claims, which sits close to a Data Covenant line |
| ~~C2~~ | ~~Meds autopilot~~ — **shipped 2026-09-24** | M | Structured medication replacing the free-text field, plus a "running out" estimate. Records; never advises. Needs a decision on whether a household sees *who* logged a dose |
| ~~C3~~ | ~~Morning briefing~~ — **shipped 2026-09-24**, email delivery still off pending the consent decision | M | `buildHome` already does the work. Blocked on **where it lands** — daily email is possible today, and daily is a different consent from monthly |
| ~~C4~~ | ~~Senior suite~~ — **shipped 2026-09-24**, with no quality-of-life scale | S–M | Assembly over the life stages, as expected. The scale was **declined rather than deferred**: the page says we do not score a life and why, so A1's reviewer inherits a clean question rather than an unreviewed number to correct |
| **C5** | Pack dashboard · lost-pet network · food scanner · DNA | — | **Not specced, and cannot be.** Each needs a product decision first — see `SPEC-HORIZON.md` §2 |
| **C6** | The Remember chapter | — | Deliberately unwritten. The defensive pass is shipped; the chapter needs somebody who has thought about grief |

---

## Track D — the gap I keep flagging

I have now built **five features whose defining behaviour is a refusal**: the
lump diary will not say whether a lump grew, the companion will not say what
something is, the vet summary omits the projection, C1 will not reassure, and
C3 discards its own model's output. Each is a judgement about where a line sits.
**None has been reviewed by anybody but me.**

Two concrete things would close most of it:

- **D1.** A1's reviewer also reads the refusal copy — the "nothing matched"
  screen, the lump-diary caveat, the visit summary's omissions. One session.
- **D2.** Somebody other than me writes red-team cases. Mine has my blind spots
  by construction; the two holes it found in my own rules are the evidence.

---

## The order I would actually run

1. **Commission A1 and B1 this week.** They are the two longest lead times, they
   are independent, and everything else is cheaper afterwards.
2. **A4 while waiting** — ten minutes, and it clears the last credential debt.
3. **Decide B2.** It costs nothing to decide and unlocks two finished features.
4. ~~Build C1 and C2 in the gap.~~ **Done, along with C3 and C4.** Track C is
   **exhausted.** Nothing left on it is buildable without a decision (C5) or a
   document somebody has to write slowly (C6). Everything that remains in this
   plan is now Track A, B or D — a reviewer, a decision, or a launch date.
5. **A2 and A3 when a launch date is real.** Neither is useful early; both are
   blocking at the end.
6. **Everything in C5 stays shut** until its product decision exists. Building
   any of them now would be guessing.

## If nothing changes

The product stays exactly where it is: complete, deployed, verified, and unable
to take a real customer. That is a stable place to sit — nothing rots, the
suites keep passing, and the demo works. It is not a place to launch from, and
the only reason it is not launchable is review rather than code.
