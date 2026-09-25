# Where we actually are

**Written 2026-09-25 by Claude Code, for Conor.** A strategic read rather than a
status list — `ROADMAP.md` has the status and `EXECUTION-PLAN.md` has the
blockers. This is about what is true that those two do not say.

Prompted by two things Conor said today: that he has not seen the app live or
tested it, and that the visuals and UI have not been done.

---

## 1. The short version

The roadmap has been measuring the wrong axis. It tracks build state — `built`,
`launch`, `next`, `sky` — and by that measure things are good: 22 of 60 journey
moments built, every spec phase shipped, 789 tests, 27 suites, nothing failing,
1.3s to a fully rendered plan on a throttled phone.

**There is no axis for "who has judged this."** And the honest answer for almost
all of it is: nobody but me.

That is the binding constraint, and it is not a blocker on the list. The A and B
items — the vet, the security reviewer, counsel, the carrier — are real but they
are *known* and they are *other people's*. The unmeasured risk is that a single
agent made several hundred product, copy and design judgements in a fortnight and
the person whose product it is has not seen one of them on a screen.

**Every additional hour of building makes that pile larger rather than smaller.**

## 2. What has actually been built

| | |
|---|---|
| Six surfaces plus a Health File | Home · Care · Rewards · Shop · Coverage · Life |
| 47 components | 7,825 lines |
| 24 pure engines | 8,418 lines, clock-injected, no IO |
| 2,920 customer-facing strings | every one written by me |
| 789 tests | 678 unit, 111 emulator (17 adversarial) |
| 27 end-to-end and static suites | `npm run verify:all` |
| 22 of 60 journey moments `built` | 3 at `launch`, 21 `next`, 14 `sky` |

Roughly 37% of the vision on the partner map is real in the demo. The engines are
the part I would defend hardest: pure, tested, and the only place the product's
claims are computed.

## 3. The three risks, in the order I would rank them

### 3.0 The thing writing this document found, while writing it

I verified the nine-step walkthrough in §6 before handing it over, because
sending somebody to look at a broken link would be a poor way to open this
conversation. Step 3 failed.

Following a link from Max's Health File to Luna showed **Max**, and rewrote the
URL to Max's. A link to one animal opened another animal's record, under the
first animal's name. Found, fixed, given its own suite, and deployed today.

It is the **third bug of that exact shape**, and that is the part worth reading
strategically. `activeId` is state duplicated from the URL, several places wrote
to both, and each fix addressed a sequence rather than the duplication. Every
time, the tests I had were green — because they tested the routes I had thought
of.

**Thirty seconds of a real person navigating found what 789 tests did not.** That
is the argument for everything in §5, made by accident.

### 3.1 Judgement risk — large, unmeasured, and structural

The 27 suites prove the product does what I said it would do. **Nothing tests
whether what I said was right.** That is not laziness in the tests; it is what
tests are. My red-team suite found phrasing gaps in my own lists — *siezure*,
*went floppy* — because those are mechanical. It cannot find a bad judgement,
because it was written by the thing making the judgements.

The places where this matters most are the **six features whose defining
behaviour is a refusal**:

- the lump diary will not say whether a lump grew
- the companion will not say what something is
- the vet summary omits the healthy-years projection
- the safety check will not reassure
- the model composition discards its own output when uncited
- the senior suite carries no quality-of-life score

Each of those is a line I drew. I believe every one is right, and I have written
down why in each file. **But a product defined by what it refuses to say is a
product whose voice is a strategic choice, not an engineering one**, and that
choice is currently mine by default.

The Execution Plan flags this as Track D and files it as a gap to close with
reviewers. That was too gentle. It is not a gap in the plan; it is the plan's
first item.

### 3.2 Rework risk from the design pass — medium, and I can size it exactly

There *is* a visual system. It came partly from the investor demo and partly from
me: eight colours (cream, ink, forest, deep, sage, accent, muted, line), Playfair
Display over Poppins, 22px cards, two shadow depths, a clover gradient. 165 lines
of configuration in total. It is coherent. **It is not designed**, in the sense
that nobody chose it against a brief.

The cost of changing it splits cleanly, and the split is the useful part:

| What changes | Exposure | Cost |
|---|---|---|
| **Colour and brand** | 907 token references, 8 values in one config file | **Hours.** Swap the tokens; every component follows |
| **Typography and spacing** | **34 distinct hard-coded font sizes** and 663 arbitrary bracket values across 47 components. There is no type scale | **A week, touching nearly every component** |

That asymmetry should drive the sequencing. A palette change is nearly free. A
typographic system is not, **and every component built between now and then adds
to the 663.**

So there is one thing I would ask for before any visual work lands: **let me build
a type and spacing scale first, then apply the design to the scale.** Applying a
designer's type ramp directly to 34 ad-hoc sizes means doing the same work twice
and getting it inconsistent both times.

### 3.3 The known blockers — smallest, and already prepared

A1 vet review · A2 counsel · A3 Stripe entity · A4 key rotation · B1 security
review · B2 the model-data decision · B3–B5 partners · B6 five cat figures.

All documented, each with the artefact it needs to be closed in one sitting.
**None of them is mine and none of them is urgent until there is a date.** Which
leads to the thing genuinely missing from the roadmap.

## 4. What the roadmap does not have

**A definition of launch.** No date, no first cohort, no success criterion. The
Execution Plan says "no engineering work blocks a launch; review does," which is
true and incomplete — the prior question is *launch to whom, to learn what?*

Without that:

- A2 and A3 cannot be scheduled, because they are only urgent against a date.
- The remaining 38 journey moments have no prioritisation basis. "Pack dashboard
  or lost-pet network" is unanswerable in the abstract and obvious once you know
  who the first fifty members are.
- "Built" keeps meaning "real in the demo" rather than "survives a stranger."

The demo audience — investors — is served. The next audience is not defined, and
that is the decision that unlocks the most.

## 5. What I would do, in this order

**1. See it. Today, 30 minutes, on your phone.** Section 6 is a walkthrough.
Don't fix anything or write tickets — just notice what makes you wince. The point
is to find out whether the voice is right before more of it exists.

**2. Give the visual direction, and let me build the scale before applying it.**
Whatever the direction is, the type and spacing scale comes first or we pay for it
twice. If the brand itself changes, say so early: that part is cheap right now and
expensive after another 20 components.

**3. Read the copy that carries judgement — not all 2,920 strings.** I can extract
the ~200 that actually decide something: every refusal, every empty state, the
escalation ladder, the death-of-a-pet flow, the Data Covenant. One list, one
sitting. That is the highest-value hour available to this product and it costs
nothing but your attention.

**4. Define the first cohort.** Fifty people, and what we want to learn from them.
Then the remaining roadmap sorts itself and A2/A3 get a date.

**5. Only then, more features.** And the next one should be chosen by what that
cohort needs.

### What I would not do now

Build any more Tier 2 or Tier 3 items. Start the Remember chapter. Add surfaces.
Touch the marketing site. Every one of those increases the unreviewed pile and the
typographic rework, and none of them is the constraint.

## 6. The walkthrough

On a phone, at `https://clovara-life.web.app`. Signed out — the demo path works
without an account.

1. **Home, Max** (golden retriever, 6). The projection, the nudge, the score. *Is
   the first screen the "it knows my dog" moment, or a dashboard?*
2. **Tap into the Health File.** Passport, vaccines, lumps, meds, the senior
   block, what the record holds. *This is the densest screen in the product. Is it
   a relief or a chore?*
3. **Switch to Luna** (domestic shorthair, 9). *Does the product feel like it was
   built for cats, or like a dog product with cats bolted on?*
4. **Switch to Winston** (French bulldog, 3). Breed risk cards. *Does an owner
   feel informed or accused?*
5. **`#/wrong`** — "something's wrong." Type *he's limping after walks*, then
   *he collapsed*. *The second must feel instant and unambiguous. Does it?*
6. **`#/ate`** — "she ate a grape." *Fast enough at 2am? The right amount of
   words?*
7. **`#/protect`** — the insurance attach flow, with the illustrative labelling.
   *Does the labelling read as honesty or as hedging?*
8. **`#/covenant`** — the Data Covenant. *This is the page the whole product's
   promise rests on. Do you believe it?*
9. **The Life tab → mark a pet as died.** Then go back to Home. *Everything goes
   quiet. This is the hardest thing in the product and the thing most likely to be
   wrong.*

Nine screens, about half an hour. **If you only do one, do 5 and 9** — the
collapse flow and the death flow. They are where the judgement calls are most
consequential and where being wrong costs the most.
