# Clovara — the next horizon, specced

**Status: every Tier 1 item is built. Tiers 2 and 3 still need decisions.**
It covers the fifteen items ROADMAP lists as "needs spec before build".

**Shipped 2026-09-24** — §1.1 lump diary · §1.2 morning briefing · §1.3 second
opinion · §1.4 meds autopilot · §1.5 senior suite · and the defensive pass from
§2.5, which makes every existing surface go quiet when a pet dies. `CHANGELOG.md`
has the detail.

Three of them ship deliberately narrower than specced, and each one answered an
open question by declining it rather than deferring it:

- **No cost range** on second opinion (§1.3). The questions were the value and
  none of the risk.
- **No quality-of-life scale** in the senior suite (§1.5, and §5.5). Adopting a
  validated scale is clinical content and belongs with the reviewer who owns
  `clovara-life/src/data/toxins.ts`.
- **Briefing email off** (§1.2). A daily email is a different consent from a
  monthly one and is not an engineering default.

The Remember *chapter* (§2.5) remains deliberately unwritten. The eleven
decisions in §5 that are not answered above are still open.

## How to read this, and what it deliberately does not do

The fifteen are not one kind of thing, so they do not get one kind of document.

- **Tier 1** items have real specs. The machinery they need already exists in
  this codebase, and I can say concretely what they touch.
- **Tier 2** items get a framing and the decisions that must be made before
  anyone can spec them. Writing detail now would be inventing requirements.
- **Tier 3** items are not engineering specs at all. They are operational,
  commercial or actuarial, and a spec from me would be a guess at a business
  that has not been decided. What each gets is the question it actually turns
  on and who owns it.

**Fifteen documents of equal depth would be fiction for most of them.** The
honest version is uneven on purpose.

Decisions for Conor are marked **[DECIDE]** throughout and gathered in §5.

---

# Tier 1 — specced, and buildable against what exists

## 1.1 Lump diary

**What it is.** Photograph the thing you have found; compare it against the same
thing last month; know whether to watch it or go.

**What already exists.** Nearly all of it. `store/photos.ts` resizes and uploads
two variants; `imageMath.ts` does the geometry; storage rules guard
`life/households/{hh}/pets/{pet}/`; the 2048px "analysable copy" was kept for
exactly this. C0's summary is the thing a vet reads afterwards.

**What to build.**

- A `lumps/{lumpId}` subcollection under the pet, each with a location on the
  body, a first-seen date, and an ordered set of photos.
- A repeat-capture aid: the previous photo shown as a faint overlay so the
  second picture is taken from roughly the same distance and angle. Without
  this, a month-on-month comparison is comparing two different photographs.
- **A physical size reference is compulsory.** A coin, a fingertip, anything of
  known size in frame. Two photos without one cannot be compared, and "it looks
  bigger" from a phone held closer is the failure this feature would otherwise
  manufacture.
- Side-by-side and a date-ordered strip. No measurement, no percentage, no
  trend line.

**What it must never do.**

- **Never say whether it has grown.** That is a measurement we cannot make from
  two handheld photographs, and an owner told "no significant change" will wait.
  The product shows both pictures and lets a person decide.
- **Never categorise a lump.** Not benign, not suspicious, not "consistent
  with". Invariant 4.
- **Never delay.** A new lump in an older animal is a vet visit; the diary is
  for what happens after somebody has been told to monitor it, not instead of
  going. The copy must lead with that.

**[DECIDE]** Does the diary prompt on a schedule? A monthly reminder is the
feature working; it is also a monthly reminder about a lump on your dog.

**Phasing.** L0 capture with overlay and size reference · L1 comparison view ·
L2 attach to the vet summary.

---

## 1.2 Morning briefing

**What it is.** "Slept well. 84° today — walk before ten, pollen high for her
allergies." Her day, not a generic tip.

**What already exists.** `buildHome()` produces the nudge, the score, the
activity trend and what is coming up. The `FitnessProvider` seam is built and
returns simulated values that disclose themselves. The risk cards carry windows
and actions.

**What to build.**

- A `buildBriefing(pet, projection, context, now)` — pure, one more consumer of
  the same `Projection`, per invariant 7.
- A weather/environment provider behind a seam, the same shape as
  `PlacesProvider`. Heat, pollen, and nothing else at first.
- Delivery. This is the hard part and it is not engineering: a briefing nobody
  sees is a cron job, and push needs native apps (Tier 3).

**What it must never do.**

- **Never invent a reason.** If the only true thing today is "nothing needs
  attention", it says that. A briefing padded to feel valuable trains people to
  stop reading it, which costs the days when it matters.
- Never present simulated activity as measured — the provider already carries
  `simulated`, and the briefing must render its disclosure the way Home does.

**[DECIDE]** Where does it land before native apps exist? Email is possible
today; the email skeleton and a pluggable sender were built in P0. A daily email
is a different consent from a monthly one.

---

## 1.3 Second opinion

**What it is.** Upload a diagnosis or a £6,000 estimate; get it in plain
language, the questions worth asking, and a fair local cost range.

**What already exists.** The whole extraction pipeline: `ExtractionProvider`,
confirm-chips, `extracted_confirmed` provenance, and the model key. C3's
verification is the same gate this needs.

**What to build.**

- Extraction over an estimate or discharge note, through the existing
  confirm-chips — same rails, different document.
- A **questions** generator: what to ask, given what the document contains. This
  is the valuable half and it is the safe half.
- A cost range, which is the dangerous half. See below.

**What it must never do.**

- **Never second-guess the clinical decision.** "You may not need this" about a
  procedure a vet has recommended, from a product that has not examined the
  animal, is the single most harmful thing in this document. The output is
  *questions to ask the vet who did*, never an alternative view.
- **Never imply the price is wrong.** A range is context, not a verdict, and a
  practice at the top of it may be the better practice.

**[DECIDE]** The cost range needs a data source, and there is not an obvious
one. Options: aggregate our own claims once volume exists (accurate, slow,
and a Data Covenant question — claims data informing a consumer feature is
close to a line), a licensed benchmark, or ship without it and keep the
questions. **My recommendation: ship without it.** The questions are most of the
value and none of the risk.

---

## 1.4 Meds autopilot

**What it is.** What they take, when it runs out, and did today's dose happen.

**What already exists.** `careNotes.meds` (free text, for the sitter card), the
vaccination schedule pattern in `data/vaccines.ts`, and its rule that we record
rather than prescribe.

**What to build.**

- Structured medication records replacing the free-text field: name, what the
  owner was told about frequency, start date, quantity dispensed.
- A "running out" estimate from quantity and frequency — the genuinely useful
  bit, and the reason people run out on a Friday.
- Optional dose logging, and the "did I give it?" question two people in a
  household ask each other. The family circle already exists, so this is shared
  state, not a per-user checkbox.

**What it must never do.**

- **Never tell somebody to give, skip, change or stop a dose.** It records what
  the vet said and reminds; it does not advise. A missed-dose screen that says
  anything other than "ask your vet what to do about a missed dose" is
  prescribing.
- Never carry a dose we were not told. The owner types what is on the label.

**[DECIDE]** Does a shared household see who logged a dose? It prevents double
dosing, and it is also surveillance between partners. Suggested: show that it
was given, not by whom.

---

## 1.5 Senior suite

**What it is.** The care path and the shelf change as an animal gets old —
screening, ramps, orthopaedic beds — computed from the breed's own timeline.

**What already exists.** More than any other item here. AAHA life stages, per-
stage care actions in `data/engine.ts`, stage-gated products in `platform.ts`,
risk cards with onset windows, and the annual re-projection.

**What to build.** Mostly assembly and copy: a senior surface that collects what
the engine already knows, plus quality-of-life tracking, which is new and is the
part that needs care.

**What it must never do.**

- **Never estimate remaining time.** The projection is a planning range built
  from breed medians, and in front of an owner of a thirteen-year-old it would
  read as a countdown. This is the same rule as the vet summary and the share
  cards, and it matters most here.
- Never frame ageing as decline to be fought. VISION's vocabulary rules, and
  the reason the product says "more good years" rather than "more years".

**[DECIDE]** Quality-of-life scales exist clinically (HHHHHMM and others).
Adopting one is a clinical content decision and belongs with the vet who owns
`toxins.ts` and `redFlags.ts`.

---

# Tier 2 — framed, with the decisions that must come first

## 2.1 Pack dashboard

Multiple pets in one view. The household model already supports it and the pet
switcher already lists them.

**[DECIDE]** What is it *for*? A list of pets is not a feature. The plausible
answers — a shared care rota, one view of what is due across animals, spotting
that two cats are both losing weight — are three different products. Until one
is chosen there is nothing to spec.

## 2.2 Lost-pet network

The lost-pet card and the microchip ask are already placed in the registry
(`trigger: 'lost-pet-card'`), so the field is collected at the right moment.

**[DECIDE]** A network needs other people. Is this our network, an integration
with an existing chip registry, or a shareable poster? The third is buildable in
a day and is most of the value; the first is a two-sided marketplace and a
different company.

## 2.3 Food scanner

Scan a label; know whether it suits this animal.

**[DECIDE]** This needs a food composition database, and the honest options are
licensing one or building it. Without it, the feature is OCR with nothing behind
it. Also: any output is dietary advice for an animal with conditions, which is
clinical ground.

## 2.4 DNA

**[DECIDE]** Entirely a partner question (Wisdom, Embark). What we would do with
a result is specced already in principle — breed mix would sharpen the
projection, and `illustrative` figures become real ones — but nothing can be
built before the partner and the data-sharing terms exist.

## 2.5 The Remember chapter

Everything after a pet dies. It is on the journey map and it is the hardest
thing in this document.

**Not specced here, deliberately.** It needs its own document written slowly,
and it needs somebody who has thought about grief rather than features. What I
can say is what it must not do: not ask for a rating, not recommend a new pet,
not send a renewal notice, and not keep sending the morning briefing. **Those
four failures are all shipped by real products today** and each is the result of
nobody owning the end of the relationship. A defensive pass — making sure every
existing surface goes quiet — is worth doing before the chapter is designed.

---

# Tier 3 — not engineering specs

## 3.1 Claims operations design
Who reads a claim, on what SLA, with what authority to pay, and what happens at
3am. An operational design that engineering then supports. **Owner: Conor.**

## 3.2 Affinity / B2B2C channel
A distribution decision — who sells Clovara to whom and on what terms. It has
product consequences (co-branding, data separation, per-partner pricing) that
can be specced *after* the shape is chosen. **Owner: Conor.**

## 3.3 Native apps + push
The largest item here and the one gating the morning briefing, the lump-diary
reminder and everything time-sensitive. It is a build-target decision — React
Native against the existing web, or fully native, or PWA push where it is supported —
with real cost either way. Apple Sign-In is already logged as its dependency.
**[DECIDE]** and it deserves its own document.

## 3.4 Final pricing architecture
Annual terms, multi-pet, and how membership and premium interact. Actuarial and
commercial, and constrained by invariants 1 and 2 — points never touch premium,
and the two are always separate lines. **Owner: Conor + whoever prices.**

## 3.5 Marketing-site realignment
The `main` hosting target, which this engagement has deliberately never touched.
**Owner: Conor.**

---

# 5. Decisions, gathered

1. **Lump diary:** does it prompt on a schedule?
2. **Morning briefing:** where does it land before native apps — daily email?
3. **Second opinion:** ship without a cost range? (Recommended: yes.)
4. **Meds autopilot:** does a household see *who* logged a dose?
5. **Senior suite:** which quality-of-life scale, if any — a clinical decision.
6. **Pack dashboard:** what is it for?
7. **Lost-pet network:** our network, a registry integration, or a poster?
8. **Food scanner:** license a composition database, or drop it?
9. **DNA:** which partner?
10. **Remember:** who writes it — and can we do the defensive pass now?
11. **Native apps:** which build target, and when?

# 6. What I built first, and in what order

Recorded rather than rewritten, because the reasoning was the useful part and it
held up. Both were built on 2026-09-24, in this order, followed by second
opinion, the meds autopilot, the morning briefing and the senior suite.

**The lump diary**, and not because it is the most valuable. It is the one where
the machinery is already built, the scope is small and honest, and the thing it
must never do — tell somebody whether a lump has grown — is a rule I can hold in
code rather than a judgement somebody has to make each time.

**The defensive Remember pass** is the one I would do next, and it is nearly
free: making sure that when a pet is marked as died, nothing keeps briefing,
nudging, reminding or renewing. That failure is live in real products today and
it is the cruellest thing software does to people.
