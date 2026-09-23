# Clovara Life — changelog

One section per SPEC phase. Newest first. Behaviour, not commits — the git log
has the commits.

## P2 — Protect: the attach flow

### Two screens and no form (SPEC §5)

- **Screen 1 is a price nobody had to ask for** — computed from the plan, the
  breed, the age and what has already been said. "Adjust" reveals tier and
  rider; the default is chosen rather than requested.
- **Screen 2 is the screen of truth, and is deliberately the less comfortable
  one.** The commonest reason a pet claim is declined is a pre-existing
  condition, and the commonest reason the owner is blindsided is that nobody
  said it in words before they paid.
- **Waiting periods are dates, not durations.** "14 days" needs arithmetic at
  the exact moment somebody is deciding; "from 15 October 2026" does not. The
  180-day orthopaedic wait is named, because it is the one that catches people.
- **The pre-existing picture is generated per condition, in plain words** — and
  when there is nothing to declare it says so, because a blank space reads as
  "nothing is excluded", which is a promise about the future nobody can make.
- **The buy button stays off until the disclosures have actually been scrolled
  to the bottom**, and the attestation is disabled until then too.
- **The rating adapter is the point.** `RatingAdapter` is the contract the
  Accelerant integration will implement; `MockRatingAdapter` reads the
  illustrative tables already in the repo. Every quote it returns carries
  `illustrative: true`, and the amber label is driven by that flag — a real
  adapter returning filed rates removes the label without anybody editing a
  component.
- **Binding refuses, and says why.** `canBind` is false until the carrier
  programme is live, and the flow states that rather than failing silently.
- Insurance and the wellness rider are two separate lines everywhere, and the
  disclosures say membership points never reduce a premium (invariants 1 and 2).
- The renewal disclosure repeats the Data Covenant's promise: the price never
  moves on anything a tracker measured or the companion was told.
- **The reverse bridge and its VAS free-months variant ship OFF.** Free months
  as an inducement to buy insurance is a rebating question in several states,
  not a marketing decision.
- **LEGAL-REVIEW**: the disclosures, the fraud notice and the waiting periods
  are placeholders with four questions logged for counsel.
- 17 engine tests, 27 browser checks. SPEC's DoD asks for end-to-end attach in
  under 90 seconds; the run does it in 4.6.

## P3 — Launch moments

### CloTag readiness — the fitness adapter (P3.9)

- SPEC §6.9 is explicit: **do not build hardware integration, build the seam.**
  A `FitnessProvider` interface — activity, sleep, vitals, device id — with a
  `SimulatedProvider` behind it. Tractive, Fi or PetPace drops in by
  implementing the interface, and no surface is touched.
- **The seam is real, not decorative.** `buildHome` no longer computes steps
  from a hash of its own; it reads the provider. A test swaps in a fake partner
  SDK and watches the values change through the same call.
- **The simulated values are deterministic, never random** — derived from the
  pet's id and their declared routine. Two people looking at Max see the same
  Max, and the number does not move while an investor is looking at it.
- **The provider reports `simulated: true` and Home renders the disclosure from
  that**, rather than from a hardcoded sentence. When a real device lands, the
  "these are simulated" line disappears on its own instead of being left behind
  as a lie.
- **It reports no device id, rather than inventing one.** A fake id would make a
  fabricated reading look sourced.
- **Resting respiratory rate stays null.** It is the one home measurement with
  real clinical value, which is exactly why it is not fabricated — an invented
  one could be read as reassurance about a heart.

### Renewal, Explained (P3.8) — behind a flag

- Ships dark, per SPEC §6.8: nothing can be renewed until the carrier program is
  live, and a renewal screen driven by illustrative numbers is a screen about
  nothing.
- **It departs from the journey copy, deliberately.** The map describes this as
  "why her premium is what it is — and what her care this year kept it from
  being". The second half cannot be built: the Data Covenant promises premiums
  do not move on this data, *"not up, and not down as a reward for behaving"*.
  A renewal screen crediting an owner's care would break the covenant in the
  direction people find pleasant — which is exactly the direction a product like
  this drifts.
- **Claims experience is not a behaviour score**, and that distinction is what
  the screen turns on. Whether a policy was claimed on is a filed rating factor
  everywhere insurance is sold. How somebody looked after their pet is not, and
  must never become one. The copy says so in both the claimed and unclaimed case.
- The second half of the page is the point: it names what will **never** be in
  the price — the companion conversations, the tracker, the streaks, the score,
  and whether you opened the app at all. At renewal that sentence is worth more
  than a discount, and it is what makes the first half believable.
- A test greps every generated line for *streak*, *tracker*, *your care*,
  *reward* and *discount for*, in both the claimed and unclaimed case.

### Gotcha Day (P3.7)

- The homecoming anniversary, with a card through the same pipeline as the
  Arrival Certificate — which is why that pipeline was built to be reused.
- **Anchored on the homecoming, never the birthday.** A rescue born in 2017 and
  homed in 2024 has one Gotcha Day behind them, not eight.
- Nothing is offered on the day they arrived, and nothing before a full year —
  a card reading "0 years home" would be a strange thing to be handed.
- It lingers for a week. A prompt that appears only on the exact day is one most
  families never see; one that lingers for a month stops meaning anything.

### Sitter Mode (P3.6)

- An expiring, revocable, read-only link for whoever is minding the animal —
  feeding, medication, quirks, the vet and an emergency contact, all tap-to-call.
- **The only unauthenticated read path in the product**, which is why almost all
  of its 26 emulator checks are refusals or leak checks.
- **The card is assembled server-side and is deliberately tiny.** No projection,
  no conditions as a medical history, no owner email, no household id, nothing
  about membership or billing. A link that leaks should leak a fridge note, not
  a record — asserted by checks that plant an owner email and a diagnosis on the
  pet and prove neither reaches the card.
- **Clients never touch `life_sitter_links`.** Deny-all in both directions: a
  client able to read it could enumerate every live link on the project. Create,
  list, read and revoke all go through the Admin SDK.
- The token is 32 bytes from a CSPRNG rather than the invite alphabet. An invite
  code is short because somebody reads it across a kitchen table; this one is
  pasted, so it can be long and unguessable instead.
- **Expired, revoked and never-existed all return the same 404.** Different
  answers would make the endpoint an oracle for guessing tokens. Verified by
  comparing the responses.
- Expiry and revocation are enforced on the server, seven days by default and
  capped at thirty — proven by rewriting an expiry in Firestore and watching the
  endpoint refuse it.
- A stranger cannot list, read or revoke another household's link, and revoking
  something that is not yours silently succeeds rather than confirming it exists.
- The sitter page renders before the nav, loads no auth and no engine: a
  neighbour with a URL has no account and no business seeing somebody else's
  tab bar.

### "He ate a grape" — toxin lookup (P3.5)

- The highest-stakes screen in the product: somebody opens it when an animal is
  already in trouble. Every decision is biased towards the phone call.
- **The order of the page is the design.** Somebody frightened reads the first
  thing and acts on it, so the poison-line numbers and "do not try to make them
  sick" come *before* the lookup. The calculator is the least important thing on
  the page; its only job is to stop somebody who has decided a small piece of
  chocolate is fine from being right by accident.
- **Nothing is ever a clearance.** The best verdict available is "watch closely,
  and ring if anything changes — this is a guide, not a clearance". A test reads
  the verdict box and fails on the words *safe*, *fine* or *harmless*.
- **Bands out, never numbers out** (SPEC §6.5). Thresholds exist to compute a
  band and are never rendered — an owner given a milligram figure will try to
  decide for themselves; an owner given "ring now" picks up the phone.
- **Thresholds sit deliberately below the published clinical ones.** Chocolate
  signs are described from around 20 mg/kg; we escalate at 8. Over-referring
  costs somebody a phone call. Under-referring costs an animal.
- **Some things are never banded by weight at all** — grapes and raisins are
  idiosyncratic, xylitol acts at tiny amounts, and a lily and a cat is an
  emergency at any exposure including pollen groomed off a coat.
- **Every uncertainty escalates upward**: unknown weight, unknown amount,
  unknown form all resolve to "ring now", and the copy says why.
- **It never tells anybody to induce vomiting.** That injures and kills animals,
  it is contraindicated for corrosives and petroleum products, and people reach
  for it because the internet told them to. Asserted by a test.
- Poison lines are tap-to-call and say **up front that they charge**, rather
  than letting somebody discover it at the worst possible moment.
- Nearest-open-ER is a `PlacesProvider` seam with a null implementation that
  says plainly it cannot search yet — at 2am, "no results" reads as "there is
  nowhere open". **Needs a Google Places key to switch on.**
- **VET-REVIEW: this content has not been reviewed by a veterinarian.** It is
  the most important item in the open "clinical content ownership" dependency.
- 21 engine tests, 27 browser checks.

### Vaccine Autopilot (P3.4)

- The core course for each species, with typical age windows computed from the
  birthday, and somewhere to record what actually happened.
- **Built as a record with a reminder attached, never a prescription.** A
  vaccination schedule is a veterinary decision that depends on the brand used,
  the local disease picture, the law where somebody lives, and the animal in
  front of the vet. The disclaimer saying so sits **above** the schedule rather
  than under it — whose decision this is needs saying before somebody reads a
  list, not after.
- **There is no "overdue" status, by design.** A dose can be past its typical
  window, which is worth a call; calling it overdue would assert we know it was
  not given, and the commonest reason a dose is missing here is that nobody
  typed it in. The copy asks — "if they have already had these, record them" —
  rather than accusing.
- **Core only.** Leptospirosis, kennel cough, Lyme and feline leukaemia are
  genuinely lifestyle-and-region dependent, so they appear as questions to ask a
  vet and are never scheduled. A test greps the schedule to keep it that way.
- **Rabies is law, not medicine, and the law differs** — mandated for most pets
  in the US, not routinely given in the UK or Ireland outside travel. It carries
  a "depends on local law" flag rather than being omitted or universalised.
- Stops after the first adult booster. Later intervals depend on the product
  used and on local guidance, and a date we cannot know should not appear as
  though we know it.
- Never says a pet is protected, immune or covered — whether a course worked is
  a clinical question, and titres are not something we have.
- 14 engine tests, 28 browser checks, most of them about what it must not say.

### Socialization Passport (P3.3)

- Around a hundred firsts per species, grouped into pages: people, handling,
  sounds, surfaces, things, places, animals, and being a pet.
- **The two windows are not the same, and this is the thing most products get
  wrong.** A puppy's sensitive period runs roughly 3–14 weeks, so one homed at
  eight arrives with most of it ahead of them. A kitten's runs roughly 2–7 and
  is therefore usually **over before they are adopted**. Gamifying a closed
  window would sell somebody a race they never had the chance to enter, so the
  kitten copy says plainly that the early part belonged to whoever raised them
  — and that what remains still works.
- **Nothing rewards speed.** No streak, no daily target, no countdown that
  shames. The failure mode of a gamified checklist is somebody pushing a
  frightened animal through the last few stamps to finish the page, so the
  principle line says a frightened animal has not been socialised — they have
  been frightened, and it does not count.
- Qualitative only, as SPEC requires: "they met this and it was fine", never how
  often or for how long. Asserted by a test that greps the content for counts,
  durations and protocols.
- When a puppy may safely meet unknown dogs is sent to their vet rather than
  answered — it depends on vaccination and on where they live.
- Stamps are stored as ids, so the copy can be rewritten without rewriting
  anybody's history, and a retired stamp stops counting rather than quietly
  filling the passport.
- 18 engine tests, 23 browser checks.

### First-Night Mode (P3.2)

- Puppies and kittens under twelve weeks, for their first seventy-two hours.
  Hour by hour, anchored on when they came home — not on their birthday.
- **Designed for 2am on a phone**, which drove every decision: the block you are
  in is open, everything else is collapsed, and **the escalation list is never
  behind a tap.** Somebody frightened at three in the morning should not have to
  expand anything to find out whether to ring a vet.
- One escalation list, worded identically in every block. Those signs mean the
  same thing at 3am on night one as at noon on day three, and varying the
  wording would imply a variation in urgency that does not exist.
- Every block says what is **normal** at that hour. The failure mode of a 2am
  surface is panic at something ordinary — crying, not eating, a worse second
  night than the first.
- Nothing diagnoses, treats, or names a drug (invariant 4), asserted by a test
  that greps the content for clinical vocabulary.
- Separate content for kittens, which is a different animal in a different
  situation — one room and a litter tray, not a crate and a lead.
- A clock that went backwards renders hour zero rather than an empty screen:
  somebody is standing in their hallway with a puppy.
- 14 engine tests, 20 browser checks at phone width.

### Arrival Certificate, and the share pipeline (P3.1)

- A card at pet creation: the photo, the name, "their plan begins today". Drawn
  on the device with canvas — no dependency, no upload, and it never reaches our
  servers unless the owner shares it.
- **The projection is deliberately not on it.** SPEC §6.1 lists photo, name and
  the line, and that is the whole card. A healthy-years range is a claim about
  one identifiable animal, and putting it on something built to be posted turns
  a private planning number into a prediction strangers read as a deadline.
- Share sheet first on a phone, download everywhere else. Cancelling the sheet
  is a decision, not a failure — it does not fall through to a download nobody
  asked for.
- **The photo is optional at three levels**: absent, failed to load, or loaded
  from a cross-origin URL that taints the canvas so `toBlob` throws a mile from
  the cause. All three fall back to the initial and still produce a card.
- Waits for `document.fonts.ready`. Drawing before the bundled faces arrive
  produces a card in Georgia that looks fine enough that nobody notices it is
  wrong until it is on somebody's timeline.
- The same pipeline serves Gotcha Day (§6.7), as SPEC asks.
- 21 layout tests, and 12 browser checks that read the pixels back — including
  that the card is not blank, which is the failure no pure test can see.

## P1 — Onboarding & capture

### The two blocked P1 items, built and switched off (P1.7 + conversational)

Both were listed as blocked. Neither was blocked on engineering, so both are
now built behind flags — the review and the key become a switch rather than a
build, the same pattern as the rating adapter and the fitness provider.

**Vet-record extraction (P1.7)**
- `ExtractionProvider` is the contract; `StubExtractor` is what runs today.
- **The stub returns nothing and says why.** It must never return
  plausible-looking samples: a stub inventing "Rabies, 12 March 2025" would put
  a fabricated vaccination in front of an owner to confirm, and a confirmed
  fabrication is indistinguishable from a real record forever after.
- **Invariant 8 is enforced by the types.** An extractor returns `Candidate`,
  never a stored field, and the only route to data is `confirm()`.
- `confirm()` stamps `extracted_confirmed` and **never `vet_verified`** — an
  owner reading a scan and tapping yes is not a veterinary attestation, and
  conflating the two would launder a guess into a medical fact.
- **Confidence is never rendered.** A score shown as "94%" invites an owner to
  trust the high ones without reading them, which is the exact failure
  invariant 8 exists to prevent. It orders the list and nothing else.
- **Reject is as prominent as confirm.** A flow where yes is a button and no is
  a grey link collects agreement rather than confirmation.
- Still gated on the Firestore security review: `records/` is denied outright in
  both rule sets, so nothing could be uploaded even if the flag were flipped.

**"Tell me about him" (P1-optional)**
- Built as SPEC asks — "an alternate entry to the same capture functions, not a
  fork". It produces the same `Candidate` list and goes through the same chips.
- The deterministic fallback reads **weight and neuter status only**. A regex
  that guessed at conditions would produce confident nonsense: "no history of
  seizures" contains "seizures". Asserted with four negatives.
- It gets "not neutered" right, which matters because the phrase contains
  "neutered" and the wrong answer would be shown to an owner with our
  confidence behind it.

### The annual re-projection (P1, SPEC §4.3)

- "Anything change this year?" — the yearly data refresh and the moment the
  projection is honestly restated, on one screen.
- **The journey map already marked this `built`.** It was not: there was no code
  behind it. It is now, and the implementation was aligned to what the map
  promises partners rather than the other way round.
- **Anchored on the birthday**, as the map says — not on the anniversary of the
  last review, which drifts later every year somebody answers a fortnight late
  until the ritual lands in a different season than it started.
- **But never before we have known them a year.** A nine-year-old rescue adopted
  six days before their birthday has a birthday behind them and no year for us
  to ask about.
- **It does not ask the questions itself.** Each item offers "still true" or
  "this changed", and "this changed" opens the question that already exists in
  Sharpen. A second set of pickers would be a second set to keep honest and the
  first to drift.
- It says what we currently hold in words — "Rosie was plump" — so answering is
  a correction rather than a fresh interrogation. Where nobody was ever asked it
  says so, rather than showing a default as though it were a fact.
- It only re-asks what can change in a year. Breed, birthday and sex are not
  there; neutering is, but only while the answer is still no.
- The range from the last review is stored, so next year has something to
  compare against — without it "re-projection" is only a data refresh.
- A year on the number has usually gone down, because the animal is a year
  older. The copy says that plainly and never implies the owner could have
  prevented the passage of time.
- "Not now" is honoured for the session and deliberately not persisted: a review
  a year overdue should be offered again next visit, not never.
- Pets saved before this existed are given an anchor dated today, not backdated
  — and for cloud pets it is written back, because anchoring only in memory
  would reset the clock on every load and the review would never once fire.
- 26 engine tests and 23 browser checks.

### The four numbers (P1 metrics, SPEC §4.3)

- SPEC names four metrics for this phase — time-to-reveal, tier-1 completion in
  the first session, accuracy-score distribution, records-connected by day 30.
  The event vocabulary already declared three of them. **Nothing emitted any of
  them**, so all four were unmeasured.
- They are computed by a pure module with its own tests, separate from the page
  that renders them: a number that decides whether onboarding is working should
  be checkable without a browser.
- **Demo pets are excluded from all four.** Max, Winston and Luna are walked
  through live in front of investors — a session that reveals in two seconds and
  sharpens nothing. Left in, they would report a wonderful time-to-reveal and a
  terrible tier-1 completion, both meaningless.
- Time-to-reveal is measured from the first onboarding step, not from page load,
  and the stopwatch answers **once**. A returning user reaching their own pet in
  a second is not an onboarding, and counting it would flatter the number into
  uselessness.
- Sessions that answered nothing stay in the tier-1 denominator. A rate that
  silently drops them is always 100%.
- Where there is no data the dashboard says so — "nobody is 30 days old yet",
  not `0%`. Records-connected reads zero because P1.7 is blocked, and the page
  says that on the page rather than leaving someone to infer a usage problem.
- 25 unit tests on the arithmetic, and an 18-check browser run proving the
  events actually fire — including that no pet name, email, or free text ever
  reaches the analytics store.

### A photo of them (P1.4)

- A pet can have a photo. Taken with the camera on a phone, or picked from a
  library anywhere else.
- **It is worth zero to the accuracy meter, on purpose.** Everything else on the
  Life surface sharpens the projection; this one does not, and the app does not
  pretend otherwise. It is offered because it is the screen where someone is
  already looking at their pet.
- Two copies are kept: a 512px square avatar, and a 2048px long-edge copy for
  the body-condition trend SPEC §4.2 wants later. A 10.2MB phone photo becomes
  1.65MB, in the browser, before anything is uploaded.
- The square crop is biased **up** on a portrait photo — a dead-centre crop of a
  standing dog is a picture of its chest.
- With no photo, the fallback is the pet's initial in their own colour. Never a
  stock animal icon: a generic dog silhouette standing in for a specific dog is
  worse than a letter.
- Stored per household and per pet, under rules that deny a stranger the full
  copy even if they know its exact path — asserted by a check that tries it.
- Eight rules checks against the real Storage emulator, seven of them refusals:
  the stranger, the made-up household id, the signed-out visitor, the PDF
  wearing a `.jpg` name, the oversized file, and vet records — which are denied
  outright until the security review SPEC §7 requires has happened. That last
  one was mutation-tested: weaken the rule and the check fails, which is the
  only way to know a denial test is not passing vacuously.

### Ask registry (P1.6)

- SPEC §4.3's declarative table — field, trigger screen, benefit copy — as
  `data/askRegistry.ts`.
- **It is enforced, not advisory.** A test reads the Sharpen source and fails if
  a question appears on a screen the registry does not place it on, or if the
  registry places one the screen forgot to ask. "Just one more field" is how
  onboarding stops ever ending in the bad sense, and this is the thing that
  stops it.
- It caught a real inconsistency the moment it was written: diet was being asked
  on the Life surface, when SPEC §4.3 puts it at the first shop visit. It is
  worth almost nothing to the projection and quite a lot to a shelf of food, so
  it now appears on Shop as a contextual ask that clears once answered.
- A test asserts identity and payment are **never** asked on a pet screen, and
  that payment is only asked at trial end — never to start one.

### Family circle (P1.6)

- Invite someone into a household with an eight-character code; join with one.
- **Both halves run server-side.** A client that could add a uid to a household
  document could add itself to any household it could name, so membership is
  changed only by a Cloud Function using the Admin SDK, and the rules deny
  clients all access to `life_invites` in both directions.
- Codes avoid `0 O 1 I L` — the characters people mistype reading a code across
  a kitchen table, which is exactly how this one gets shared. Single-use, seven
  days, and a key to everything known about someone's pets, which is why it
  expires at all.
- **Joining with pets of your own is refused, not merged.** Two households of
  pets becoming one is a real feature with real ways to lose an animal's record,
  and it is not this one. The refusal says so and offers to sort it out by hand.
- 16 emulator checks, of which 11 are refusals.

### The Data Covenant (P1.5)

- Invariant 5, as a real page at `#/covenant` — linkable, not a modal. Linked
  from onboarding (in a new tab, so it cannot cost anyone their answers), from
  the account panel, and from the footer of every screen. The attach-flow link
  lands with P2.
- Content lives in `data/covenant.ts` rather than in JSX, so it can be read in
  one place, diffed when it changes, and **tested**. Twenty tests assert the
  promises invariants 4 and 5 require are actually present — this is exactly
  the copy that drifts.
- **It refuses the reward framing as explicitly as the penalty framing.** "A
  discount for good behaviour" is the same mechanism wearing a smile, and it is
  the one a product like this drifts into; the copy closes it by name, and a
  test fails if that sentence ever goes missing.
- **It names the filed-programme exception rather than hiding it.** Invariant 5
  allows a filed, transparent, opt-in programme, so a covenant that did not
  mention one would be a promise we already knew we might break.
- Marked `LEGAL-REVIEW` in the source with the four questions counsel needs —
  including whether "never used against an individual claim" as written should
  be enforceable (it should) and whether it survives an MGU agreement that says
  otherwise.

### Tier 0 — sixty seconds to the reveal (P1.2)

- Species → breed → name → age → sex. Five questions, one typed, then the plan.
  **No account wall** — the reveal is the hook, so it comes before any ask.
- Age is an "about N" slider by default, with an exact-date toggle. `birthDateApprox`
  records which it was: a rescue whose age was guessed at the shelter is not the
  same claim as a puppy with papers.
- Weight, conditions, neutering and the daily routine all left onboarding. They
  are Tier 1 now, asked where answering visibly does something.

### Tier 1 — sharpening, inline (P1.3)

- Every Tier-1 question on the Life surface, ordered by the accuracy meter, so
  the fastest route through is also the one that sharpens the plan most.
- **No save button.** Each control writes straight through, the projection
  recomputes, and the range above animates to its new value — SPEC §4.2's
  "each answer visibly moves the projection" is the mechanic, not a flourish.
  `useTween` respects `prefers-reduced-motion` and never animates a first paint.
- A question answered in this visit **stays on screen**. Collapsing it instantly
  means a mis-tapped silhouette cannot be corrected without hunting, and hides
  the confirmation exactly when someone wants to see it. Tidying is for the next
  visit.
- Demo pets have no sharpen panel: they are a fixed exhibit, not someone's
  record.

### Body condition by silhouette (P1.4)

- Five hand-drawn outlines per species, top-down, waist the only thing that
  varies — no other cue is reliable from above. No icon library; the repo does
  not have one and five shapes is not a reason to acquire one.
- **The weight box comes after, and is optional.** SPEC §4.2: never ask for kg
  first. A picked silhouette outranks the weight read in the engine, because it
  is a direct observation of the animal rather than an inference from a number
  against a breed-average range.
- Five scores, three engine values. Salt 2019 and Teng 2018 compare thin and
  overweight against a normal reference; they do not describe a five-band curve,
  so `bodyConditionFromScore` maps 1–2 → lean, 3 → ideal, 4–5 → overweight and
  the engine never behaves as though it knows more than that.

### Plan-accuracy meter (P1.1)

- `planAccuracy(profile)` in the engine package: pure, deterministic, 27 tests.
  Shown on Home until the plan is >90% sharp, per SPEC §4.2.
- **It measures projection sharpness, not engagement.** A field earns points in
  proportion to how much it moves or narrows the projection, so the meter and
  the engine cannot disagree. A photo is worth nothing — it is the most
  satisfying thing an owner can add and it sharpens the projection not at all.
- **Tier 0 is worth 40 of the 100.** The breed baseline and the age *are* the
  projection; everything in Tier 1 adjusts a number those two produced. Scoring
  them at zero would tell someone their reveal was worthless at the moment they
  were most impressed by it.
- **You cannot reach 100% on a mixed breed**, and the meter says why. A
  size-class fallback means we genuinely know less, and no amount of answering
  fixes it. Ceilings: 85% mixed, 88% illustrative, 94% derived.
- Only asks what applies. A dog is never marked down for the cat question; a
  small dog is never asked about neuter age, because Hart found no effect there.
- "None that I know of" is a real answer (invariant 9). `conditionsReviewed`
  records that the owner saw the list and chose none, so the meter stops asking
  rather than nagging forever at someone whose pet is simply healthy.

### Tier 0 / Tier 1 split in the model

`activity`, `dental`, `diet` and `neutered` are now **optional** on `PetProfile`.
SPEC §4.1 puts them after the reveal, and while they were required the meter
could not tell "answered" from "defaulted" — it was claiming to know the daily
routine of a pet whose owner had answered five questions. The engine resolves
absent to its own zero-delta reference, so projections are unchanged; what
changed is that the difference is now representable.

## P0 — Foundations (complete)

### Entitlement gating (P0.6)

- Member-only surfaces per SPEC §3: member pricing in Shop, point redemption in
  Rewards.
- **A gate never hides what is behind it.** SPEC §1 makes the reveal the hook —
  the product has to be visible to be wanted — so a gated surface shows the
  thing and says what unlocks it. Points keep accruing; the redemption list
  stays on screen.
- **Demo pets are never gated.** Max, Winston and Luna are shown to investors
  and the demo has to be the whole product, not a paywalled slice. They are
  labelled "Demo" in the switcher, so nobody mistakes one for their own.
- Entitlement is watched with a live listener rather than read once, because of
  the return from Checkout: someone lands back seconds before the webhook
  writes. With a read they would see "start your trial" having just started one.
- Account panel says where the membership stands in plain words, and
  deliberately does not tell a `past_due` member they have been cut off —
  nothing has been lost, Stripe is still retrying.

### Email skeleton (P0.8)

- Pluggable sender, console provider, **no live sending** — there is no audience
  yet and no key. The shape is what ships: swapping in SendGrid is a provider
  and a key, not a rewrite.
- Templates are pure functions, so the copy can be diffed and tested. Nine tests
  assert the vocabulary rules from `docs/VISION.md` hold — no "lifecycle", no
  "platform", and nothing that promises a longer life.
- Trial-ending is triggered by Stripe's own `customer.subscription.trial_will_end`,
  three days out. No scheduler of ours, and it fires from the same source of
  truth that decides when the trial actually ends.
- One bug the tests caught before it shipped: with no price in the payload the
  trial email read "membership is undefined a month". It now omits the amount
  rather than inventing one, because the price is config and may be under test.


### Membership: Stripe trial and subscription (P0.5)

- Hosted **Checkout** and hosted **Customer Portal**. No client-side Stripe
  dependency, no publishable key, and dunning, retries, cancellation and
  payment-method changes are Stripe's flows rather than screens we maintain.
- New Cloud Functions codebase `life` (`clovara-life/functions`), separate from
  the underwriting functions so `--only functions:life` never has them in its
  deploy set.
- **Price is config, never a literal** (SPEC §1). `life_config/pricing` holds the
  Stripe price id; clients cannot write it and the functions refuse to build a
  session without it. Seeded by `scripts/seed-config.mjs`.
- **Membership is its own Stripe Product with exactly one line item** — invariant
  2 needs premium separate from membership in UI, Stripe and receipts, and that
  is not a thing to retrofit. Asserted in the verification.
- Entitlement (`trialing`/`active`/`past_due`/`canceled`) is written **only** by
  the webhook through the Admin SDK. Clients are denied writes to that field —
  it lives on a document its own members can edit, so without the rule anyone
  could grant themselves a paid membership.
- `past_due` still counts as a member. Someone whose card failed this morning has
  not stopped being a customer; locking them out is how a recoverable payment
  problem becomes a cancellation. Stripe's dunning gets its chance first.
- CA/NY auto-renewal disclosure at checkout, marked `LEGAL-REVIEW` in
  `functions/legal.js` with the four questions counsel needs to rule on.
- `npm run verify:stripe` — 25 checks on a real **test clock**, which is the only
  way to prove "charged in test mode" rather than assert it: trial starts, no
  money moves for 7 days, the clock advances, a real $22.99 invoice is paid, the
  subscription goes active, cancellation lands, and entitlement follows at every
  step.

### Data model and the engine seam (P0.2)

- `households/{id}` and `households/{id}/pets/{petId}` per SPEC §7. A household
  of one is created on first sign-in; the P1 family circle adds members to it
  rather than migrating anything.
- Every stored value carries `{value, provenance, updatedAt, updatedBy}`
  (invariant 8). Provenance is one of `owner_declared`, `extracted_confirmed`,
  `device`, `vet_verified`.
- `profileFromFirestore()` maps stored shape to engine input and back. Pure both
  ways; the engine keeps its own purity (invariant 7).
- **Unanswered questions cost nothing.** Every default used for a field nobody
  has answered is a zero-delta reference in the engine's adjustment model, so
  "I don't know" (invariant 9) widens the range rather than nudging the number.
  Asserted by a test: a Tier-0-only pet must project with an empty factor list.
- Firestore reads are defensive. A malformed field costs the field, not the pet.
  A raw value with no provenance envelope is rejected however plausible it looks.

### Analytics (P0.7)

- Every gate SPEC §3 names, as a closed union of event names — a typo is a
  compile error, not a hole in the funnel discovered six weeks later.
- Events buffer in `localStorage` against a `visitorId` and flush once there is
  an identity to attribute them to. This is what lets `reveal_viewed`, which
  happens before any account exists, be counted at all — and it is why the
  signed-out demo still loads zero Firebase chunks.
- `life_events` is append-only by construction: a client may write its own
  events and may never read, edit or delete any. Admin-only reads.
- Props are sanitised — four simple types, snake_case keys, strings truncated.
  Analytics is the easiest place in a product to start accidentally storing
  personal data.
- Internal dashboard at `#/admin/metrics`, lazily loaded so it costs the demo
  path nothing. The route guard is UX; the Firestore rule is the control.
- **The dashboard states its own undercount.** A visitor who never signs in
  never flushes, so the top of the funnel is a floor, not a total. A public
  ingest endpoint closes it; until then the page says so rather than reporting a
  flattering conversion rate.

### Auth — email link + Google (P0.1)

- Passwordless. A one-time link or Google; no password to choose badly, forget,
  or reuse from another site. Password sign-in removed from the product.
- Detecting a sign-in link normally means `isSignInWithEmailLink()`, which lives
  in the SDK — so answering "no" for every ordinary visitor would cost the demo
  ~46KB. A pure string test on `mode`+`oobCode` runs first; the SDK gets the
  authoritative say only once a link actually brought someone here.
- Handles opening the link on a different device (Firebase wants the address
  back as proof, so the UI asks) and strips the one-time parameters after use,
  so a reload cannot replay a spent code or retry a dud one forever.

### localStorage → Firestore migration (P0.4)

- Two sources, never both: signed out reads the device, signed in reads
  Firestore. The investor demo lives in the first and never touches the SDK.
- "Keep working with Max?" appears when you sign in on a device holding pets the
  account has not seen. Matched on pet id, so importing twice is a no-op rather
  than a duplicate.
- The local copy is cleared **only after** the batch write lands. A failed
  import leaves everything where it was and the offer still standing.
- Dismissing costs nothing and deletes nothing.
- `npm run verify:migration` drives the whole path in a browser against the
  emulators — make a pet signed out, request a link, complete it, import,
  reload — and asserts the pet comes back from Firestore rather than the device.

### The typecheck was a no-op (found in P0.1)

`tsconfig.json` is a solution file with `"files": []`, so the `tsc --noEmit` in
the build script typechecked nothing. `tsc -b` respects the references and found
14 errors, one of which (`JSX.Element` in `Nav.tsx`) had never compiled under a
real check. Build is now `tsc -b && vite build`.
