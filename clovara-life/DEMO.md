# Clovara Life — 60-second live demo

## Before you walk in

1. Open the URL with **`?reset`** on the end — `https://clovara-life.web.app/?reset`. That clears
   any pets left over from rehearsals and returns Max, Winston and Luna to a clean state. Bookmark
   that version of the link.
2. Load it once on cellular, not wifi, so the fonts are cached.
3. Check the greeting matches the time of day and the demo pets read as expected.

**Links you can send during or after the meeting** — these open directly on the screen you want:

| | |
|---|---|
| Luna's shelf, the strongest single beat | `/#/pet/demo-luna/shop` |
| Winston's pricing breakdown | `/#/pet/demo-winston/coverage` |
| Max's life journey | `/#/pet/demo-max/life` |

**If something looks wrong mid-demo:** reload. Hash routing means you land back on the same pet and
screen. If the app ever shows a "Something went wrong" card, *Start over* clears storage and
reloads clean.

---


Open on a laptop. Have a phone ready with the same URL loaded, in case someone asks.
Start on **Max**, who loads by default.

---

### 0:00 — Open cold, say nothing for two seconds

Let them read `Max is on track for 9.0–11.9 healthy years`.

> "This is Max. Golden Retriever, six, and a mild hip finding on his 2024 check.
> That's not a lifespan countdown — it's healthy years, and it's a range, because
> anyone showing you a single number is selling you something."

---

### 0:10 — Point at the arc, then the timeline

> "He's a mature adult. That's not an age band we picked — the veterinary guidelines
> define senior as the last quarter of a breed's expected life, so senior arrives at
> seven for a Great Dane and eleven for a Chihuahua. The engine computes it per breed."

Scroll the timeline one notch so **Mature adult** and **Senior** are both visible.

> "Past, present, future. And his hip laxity has already moved from 'watch for this'
> to 'here's how you manage it', because we know it's on his record."

---

### 0:25 — The lever. This is the moment.

Right-hand panel, **Body condition**. Max is at 79 lb against a 55–75 lb breed range,
so he loads as **Overweight**. Click **Ideal**.

**9.0–11.9 → 10.0–12.9.** A full year, live.

> "One pound at a time, that's a year of good health. And that number isn't invented —
> it's the Purina lifetime feeding trial, forty-eight Labradors, lean-fed against
> pair-fed, thirteen years against eleven point two."

Pause on it. Let them see the number sitting there.

---

### 0:38 — The honesty beat. This is what makes them trust the rest.

Point at the three badges: **Strong evidence** / **Associational** / **Directional**.

> "Look at the labels. Weight is strong evidence. Dental is *associational* — there is
> no study showing brushing extends lifespan, and AAHA calls the causal story
> oversimplified, so we move the number a little and we say so. Activity is directional.
>
> Every pet company on earth would have made those three levers look equally scientific.
> We didn't. That's the product."

If you have a second, click **How we work this out** — it opens the sources with the
metric each one measures.

---

### 0:48 — Switch pets. Header menu → **Winston**.

> "French Bulldog, three. Completely different picture — airway, heat, spine, eyes.
> 8.9 to 10.9. It's reading the breed, not the size."

Then → **Luna**.

> "And a cat, nine years old. Cats aren't small dogs — in the largest feline body-
> condition study, *thin* cats carried the risk and mild overweight didn't. So 'lean'
> is a positive in a dog and a negative in a cat, and the engine knows the difference.
> Her dental is set to 'rarely'. Watch."

Click **Daily**. **12.5–16.4 → 13.4–17.2.**

---

### 0:58 — Land it

> "Thirty seconds to add a pet, and every year after that we have a reason to talk to
> them that isn't a renewal notice."

---

## If they ask to add a pet themselves

Hand them the laptop. **Add a pet** → six steps, roughly thirty seconds. The breed field
autocompletes, and "Mixed / not sure" with a size picker is right there. The projection
renders instantly on the last click. It persists in their browser, so it will still be
there if they reload.

Good breed to suggest if they hesitate: **Bernese Mountain Dog** (7–9 years — the giant-breed
drop-off is stark) or **Dachshund (Miniature)** (12.5–15, with disc disease dominating the plan).

## Numbers you might get asked for

| Pet | As-is | Weight → ideal | All three levers best | All three worst |
|---|---|---|---|---|
| Max | 9.0–11.9 | **10.0–12.9** | 11.0–13.9 | 8.0–10.9 |
| Winston | 8.9–10.9 | already ideal | 9.9–11.9 | 6.0–8.0 |
| Luna | 12.5–16.4 | already ideal | 13.8–17.6 | 11.4–15.2 |

## Questions you should expect, and the honest answer

**"Where does Max's number come from?"**
The US large-breed life expectancy figure from 13.3 million Banfield records, adjusted down for
the breed's cancer burden. It's flagged `illustrative` in our data because neither big UK study
published a retrievable Golden Retriever figure. We flag it rather than hide it — the app's own
methodology panel says so.

**"Is this ML?"**
No, and deliberately. It's a deterministic rules engine, every input traceable to a citation, in
one reviewable file. You can't explain a model to a state insurance regulator. You can explain this.

**"What's the moat?"**
Not the data — that's public. It's that this runs at the moment of the quote and every year after,
and it turns an annual renewal into an annual conversation about the animal.

**"How accurate is it?"**
It's a breed-average projection presented as a range, which is the honest shape of the claim.
Ask me what we'd need to tighten it and I'll show you the three specific tables we're chasing.


---

# The platform walkthrough — a second 90 seconds

The Life Journey is the proof. The platform is the business. Run the Life demo above
first, then this. The nav is **Home · Care · Rewards · Shop · Coverage · Life**.

### Open on **Home**, with Max

> "This is not an insurance app that opens at claim time. It is Max's daily home."

Point at the score — **55**. Then click **What makes up the score**.

> "Fifty-five, and it tells you exactly why: body condition twelve out of
> thirty-five, feeding four out of ten. It is the same inputs as the projection,
> weighted the same way — weight carries the most because it is the only factor
> we have strong evidence for. And it says, in the product, that it is a construct
> and not a clinical measure."

The nudge below is generated: activity down, and it connects that to the hip
finding already on file.

### → **Care**

> "The companion opens with something specific, because it holds his record.
> Hip dysplasia on file since 2024, and what you are describing fits it. Then it
> routes to a licensed vet — it does not diagnose. That is the legal line and the
> trust line, and they are the same line."

### → **Shop** — switch to **Luna** here

This is the strongest single beat in the platform half.

> "Watch what happens when I change the animal."

Max's shelf: senior screening, hip & joint chews, non-slip ramp, ear cleaner.
Luna's shelf: senior screening, low-entry litter tray, water fountain, perch steps,
feline mobility chews.

> "Nobody merchandised that. Every card says why it is there, and the why is a
> condition on that animal's own risk profile. A Golden Retriever never sees a
> litter tray and a cat never sees a joint chew for dogs."

Click **What the evidence says** on the joint chews.

> "And here is the part I would not expect from a pet brand. Our own supplement
> card says the trial evidence is mixed. We sell it and we tell you that."

### → **Coverage** — the connection you asked about

Open **Why this price**.

> "Base rate by size, times age, times breed risk, times plan. Every factor on the
> screen. Try getting that out of anyone else in this category."

Then the wellness rider.

> "And this is the join. These rider lines are not a fixed list — they are
> generated from Luna's life stage. She is a mature adult, so the rider is paying
> for the oral assessment and the kidney panel that the Life Journey is already
> telling her owner to get. The product recommends the care and the policy pays
> for it, off one engine."

Point at the risk list underneath.

> "And where something is already on the record, we say it is excluded now — not
> at claim time."

### Land it

> "Six surfaces, one engine. The projection drives the score, the score drives the
> nudge, the risks drive the shelf, the life stage drives the rider. Add a pet and
> all six change together, because there is only one thing being computed."

## Platform numbers you might get asked for

| | Max (Golden, 6) | Winston (Frenchie, 3) | Luna (DSH, 9) |
|---|---|---|---|
| Clovara Score | 55 | 84 | 68 |
| Illustrative premium | $58.48 | $39.55 | $24.53 |
| Life stage | Mature adult | Young adult | Mature adult |
| Top shelf item | Senior Screening Voucher | Cooling Mat | Senior Screening Voucher |

Scores and premiums are computed live — check them on the day rather than quoting
this table from memory, since they move if you change a demo pet's profile.

## The three questions this half attracts

**"Is the premium real?"**
No, and the screen says so in an amber box. It demonstrates that rate responds to
species, size, age and breed risk. It is not filed, carries no expense loading, and
must never be shown as a quote.

**"Can points buy down the premium?"**
No — and that is deliberate. Anti-rebating rules in most states make behaviour-based
premium discounts a filing question. Points redeem against products and care services
only. We would rather show the compliant version than the impressive one.

**"Are those real products?"**
Names and prices are placeholders. The matching logic is real and it is the part
worth valuing. Drop a real catalog into `products.ts` with condition targets and the
shelf works unchanged.
