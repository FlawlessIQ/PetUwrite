# Clovara Life — changelog

One section per SPEC phase. Newest first. Behaviour, not commits — the git log
has the commits.

## P1 — Onboarding & capture (in progress)

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
