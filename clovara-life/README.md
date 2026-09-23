# Clovara Life

A six-surface pet-health platform — Home, Care, Rewards, Shop, Coverage, Life — built on one
deterministic engine. It projects a pet's healthy years, lays out a stage-by-stage care plan that
adapts as they age, and derives the shop shelf, the wellness rider and the score from that same
projection. Single-page, no backend, no auth. All logic runs client-side from bundled, reviewable
data files. Added pets persist in `localStorage`.

Vite + React + TypeScript + Tailwind. No component libraries.

```bash
npm install
npm run dev        # http://localhost:5173
npm test           # 176 engine, platform and data-integrity tests
npm run build      # → dist/
npm run icons      # regenerate public/og.png and the apple-touch icon
npm run typecheck      # tsc -b. NOT `tsc --noEmit` — tsconfig.json is a solution
                       # file with "files": [], so that form checks nothing.
npm run test:emulator  # 37 more against the real Firestore/Auth emulators and
                       # the real firestore.rules — repository round-trips plus
                       # the denials (a stranger reading your pets, editing the
                       # append-only event log, reading it without admin)
npm run verify:migration  # 11 checks driving localStorage → Firestore in a
                       # browser: pet made signed out, link sign-in, import,
                       # reload, and the pet comes back from the cloud
npm run verify:stripe  # 25 checks on a real Stripe test clock: trial starts,
                       # nothing is charged for 7 days, time advances, a real
                       # $22.99 invoice is paid, cancel — entitlement following
npm run verify:onboarding # 17 checks driving Tier 0 → reveal → Tier 1: five
                       # questions with no account wall, then every answer
                       # moving the projection and persisting

# End-to-end demo checks: crash recovery, routing, iOS zoom, overflow, share tags.
# Point it at a preview server or the deployed URL.
npm run build && npx vite preview --port 4173 &
node scripts/verify-demo.mjs
BASE=https://clovara-life.web.app node scripts/verify-demo.mjs
```

---

## Deploying

The app deploys to Firebase Hosting as a **separate site** from the main Clovara homepage. The
multi-site wiring in the repo root **has already been applied**. Copies of what went in, and of
what was there before, are checked in here:

- `clovara-life/firebase.json.proposed` → repo root `firebase.json`
- `clovara-life/firebaserc.proposed` → repo root `.firebaserc`
- `clovara-life/firebase.json.backup` → the original, for a one-command rollback

The change converts `hosting` from a single object to an array of two entries and names them
`main` (the existing Next.js site, `out/`) and `life` (this app, `clovara-life/dist/`). Nothing
else in the root config is touched — emulators, Firestore, storage and functions are byte-identical.

```bash
# 1. Create the new site (once). If the name is taken, pick another
#    and change it in .firebaserc under targets.pet-underwriter-ai.hosting.life
firebase hosting:sites:create clovara-life

# 2. Build and deploy just this site
cd ~/Development/Clovara/clovara-life && npm install && npm run build
cd .. && firebase deploy --only hosting:life
```

The URL will be `https://clovara-life.web.app`.

The existing homepage now deploys with `firebase deploy --only hosting:main` rather than
`--only hosting`. Plain `firebase deploy --only hosting` deploys both.

**Rollback:** `cp clovara-life/firebase.json.backup firebase.json` and restore `.firebaserc` to
`{"projects":{"default":"pet-underwriter-ai"}}`.

---

## How it is put together

```
src/
  data/
    engine.ts        ← START HERE. Methodology, adjustment model, life stages, barrel exports.
    types.ts         Input contract for the engine.
    sources.ts       Every published source, each carrying the metric it measures.
    breeds.dogs.ts   53 dog entries incl. 5 mixed-by-size-class fallbacks.
    breeds.cats.ts   14 cat entries.
    conditions.ts    Owner-declarable conditions offered in onboarding.
    demoPets.ts      Max, Winston, Luna.
    products.ts      Shop catalog. ILLUSTRATIVE items, real condition targets.
    coverage.ts      Plan tiers, rider line items by stage, illustrative rate table.
    rewards.ts       Point rules and redemptions. Never redeemable against premium.
  engine/
    project.ts       The pure function. project(profile) → Projection.
    platform.ts      Score, shop, coverage, rewards, companion, home — all pure.
    project.test.ts  53 tests.
    platform.test.ts 41 tests.
  auth/
    config.ts        Firebase web config + the Life data namespace. No secrets.
    session.ts       The pure half of auth: error copy, validation, session hint.
    firebase.ts      The ONLY module that imports the SDK, and only dynamically.
    AuthProvider.tsx React context. One listener, one place that sets status.
    session.test.ts  8 tests.
  store/
    db.ts            Firestore repository. Dynamic imports only, like auth.
    db.emulator.test.ts  10 tests — round trips + rule denials. Needs emulators.
  data/
    stored.ts        What Firestore holds: {value, provenance, updatedAt, updatedBy}.
    fromFirestore.ts The seam. Pure both ways; the engine never learns about IO.
    fromFirestore.test.ts  19 tests.
  analytics/
    events.ts        The closed union of gate names, and prop sanitising.
    queue.ts         Pure queue maths — enqueue, cap, flush prep, dedupe.
    track.ts         The impure glue. Firestore imported only inside flush().
    queue.test.ts    19 tests. track.emulator.test.ts  8 tests.
  components/        UI. No logic lives here that isn't presentational.
```

Both engines are pure — no IO, no randomness, and the clock is injected (`options.now`) so every
test is deterministic. Where a platform surface needs a number we do not measure (step counts,
streak days) it comes from a stable hash of the pet's id and their declared routine, so it is
consistent across reloads rather than random. Every screen showing one says it is simulated.

## The six surfaces

`Home · Care · Rewards · Shop · Coverage · Life`. One `Projection` is computed in `App.tsx` and
passed to all of them — no screen holds its own copy of the truth.

| Surface | What is derived | What is placeholder |
|---|---|---|
| **Home** | Clovara Score from the five declared inputs; the nudge picks the biggest gap or the activity story; "coming up" pulls the current stage's rider item | Step counts and streak days (simulated, stated on screen) |
| **Care** | The whole thread — the declared condition, the in-window risk, the breed's real watch signs and actions | The conversation is scripted; only the specifics are generated |
| **Rewards** | Streaks follow the declared dental and activity routine; redemptions are species- and risk-filtered | Point balances and totals |
| **Shop** | The entire shelf, ranked by the pet's own risk cards and life stage, each with a generated "why" | Product names, prices, images |
| **Coverage** | Premium factors, rider line items by species and life stage, pre-existing exclusions from declared conditions | The rate itself — illustrative, not filed |
| **Life** | Everything (see the engine above) | Nothing beyond the breed baselines already listed |

### Three things the platform surfaces are careful about

1. **Premiums are illustrative and labelled as such, in an amber box on the screen.** They
   demonstrate that rate responds to species, size, age and breed risk. Not filed, no expense or
   jurisdictional loading, never to be shown as a quote. The warning is at the top of
   `data/coverage.ts` too.
2. **Points never redeem against premium.** Anti-rebating statutes in most states make a
   behaviour-based premium discount a rate-filing question. Every redemption is a product, a
   service, or a copay on the non-insurance rider — and there is a test asserting it.
3. **Supplement copy is qualitative.** Nothing in the catalog claims to treat, prevent or slow a
   condition. Each product carries a `claimStrength` — `behaviour` (brushing, portion control),
   `supportive` (mixed evidence, said so), or `comfort` (no health claim) — which drives a badge.
   The joint chews card tells you the trial evidence is mixed.

---

## Accounts

Signing in is **never** a precondition for using Clovara Life. Signed out, the app
behaves exactly as it always has — demo pets, local storage, no network — and that is the state
the investor demo runs in. An account is additive.

**Auth lives behind a dynamic import.** The Firebase SDK is ~46KB gzipped across three chunks and
the signed-out path must not pay for it. `src/auth/firebase.ts` is the only module that touches
`firebase/*`, every import in it is dynamic, and exactly two things trigger a load: a real auth
interaction, or a session hint left in `localStorage` by a previous sign-in. A cold signed-out load
fetches **one** script and zero Firebase chunks — there is a check for this below.

| | signed-out load | after opening Sign in |
|---|---|---|
| scripts fetched | 1 | 4 |
| Firebase chunks | **0** | 3 |

The session hint (`clovara-life.session.v1`) is a breadcrumb, never an authority. It says this
browser had a session, so load the SDK and ask; it says nothing about whether that session is still
valid. The real answer always comes from `onAuthStateChanged`.

**Providers:** email link (passwordless) and Google are wired — no passwords, per SPEC §3.
Detecting a link is a pure string test on `mode`+`oobCode` before any SDK load, because
`isSignInWithEmailLink()` would mean loading Firebase on every page just to say "no" to everyone
who is not mid-sign-in. Apple is not — it needs an Apple Developer
Program membership, a Services ID and a signing key configured in the Firebase console first. Once
that exists it is a few lines in `firebase.ts` beside the Google provider.

### One console step is outstanding

Firebase auto-authorises `<project>.web.app`, but **`clovara-life.web.app` is a second hosting site
in the same project and was not added**. The live authorised-domain list is `localhost`,
`pet-underwriter-ai.firebaseapp.com`, `pet-underwriter-ai.web.app`.

| | localhost | clovara-life.web.app |
|---|---|---|
| Email link | works | **needs the domain added** — Firebase refuses to send otherwise |
| Google | works | **fails** — `auth/unauthorized-domain` |

Fix: Firebase Console → Authentication → Settings → Authorized domains → add `clovara-life.web.app`.
No code change, no redeploy.

Until then the app degrades honestly rather than mysteriously — the Google button returns *"This
site is not on the project's authorised domain list yet"* instead of a silent failure or a raw
error code. You can verify the list any time without the console:

```bash
curl -s "https://identitytoolkit.googleapis.com/v1/projects?key=$(grep -o "AIza[A-Za-z0-9_-]*" src/auth/config.ts | head -1)" | python3 -m json.tool | grep -A6 authorizedDomains
```

**Data namespace.** Life members get their own top-level Firestore collection, `life_members/{uid}`
(`MEMBERS_COLLECTION` in `auth/config.ts`) — deliberately *not* the `users/{uid}` that the
underwriting product uses, which carries `userRole`, admin claims and a large reviewed rules block.
The auth user pool is shared, so one Clovara identity works across both products; only the data is
separated, and nothing Life does can collide with or weaken those rules.

**Error copy is mapped, never raw.** `authErrorMessage` turns SDK codes into something an owner can
act on, and deliberately preserves the ambiguity Firebase builds in: `wrong-password` and
`user-not-found` collapse to one code so accounts cannot be enumerated, and our copy must not
helpfully un-collapse it. A test asserts those four codes produce exactly one message.

---

## Membership

$22.99/month with a 7-day trial, on hosted Stripe Checkout and the hosted Customer Portal — so
there is **no client-side Stripe dependency and no publishable key**, and dunning, cancellation and
card changes are Stripe's flows rather than screens we maintain.

**Price is config, never a literal** (SPEC §1). `life_config/pricing` holds the Stripe price id;
clients cannot write it and the function refuses to build a session without it rather than falling
back to a number.

**Membership is its own Stripe Product and the session carries exactly one line item.** Invariant 2
wants premium separate from membership in UI, in Stripe and in receipts — that is not a thing to
retrofit, so it is true from the first session.

**Entitlement is written only by the webhook**, through the Admin SDK. Clients are denied writes to
that field: it unlocks member-only surfaces and lives on a household document its own members can
edit, so without the rule any member could grant themselves a paid membership. There is a test that
tries exactly that and is refused.

`past_due` still counts as a member. A card that failed this morning has not stopped being a
customer, and locking them out is how a recoverable billing problem becomes a cancellation.

**Demo pets are never gated.** The investor demo has to be the whole product, not a paywalled slice.

## Storage and analytics

**Signed out reads the device; signed in reads Firestore.** Never both. The first is where the
investor demo lives and it touches no SDK. On signing in with pets the account has not seen,
"Keep working with Max?" offers a one-tap import — matched on pet id so importing twice is a no-op,
and the local copy is cleared only after the write lands.

**Pets live in `households/{id}/pets/{petId}`** (SPEC §7), not in the `users/{uid}`
collection the underwriting product uses — that one carries `userRole`, admin claims and a large
reviewed rules block. Shared auth pool, separate data.

Every stored value is `{value, provenance, updatedAt, updatedBy}`. `profileFromFirestore()` is the
seam between that and the flat `PetProfile` the engine takes, and it is pure in both directions.

**The load-bearing rule:** every default used for a field nobody has answered is a **zero-delta
reference** in the engine's adjustment model. An unanswered question never flatters a pet and never
punishes one — "I don't know" widens the range, which is what the engine already does for a missing
weight. A test asserts it: a Tier-0-only pet must project with an *empty* factor list, so changing a
default to something with a delta breaks the build.

**Analytics buffers before it can write.** `reveal_viewed` fires before any account exists, and
loading Firestore to record it would break the signed-out demo. So events queue in `localStorage`
against a `visitorId` and flush the moment there is an identity — which is also what makes
reveal → trial a measurable conversion rather than two unrelated numbers.

The honest limitation, which the dashboard prints on itself: a visitor who never signs in never
flushes, so the top of the funnel is a floor rather than a total, and every rate below it is
flattering. A public ingest endpoint closes it.

`life_events` is append-only by construction — write your own, read none — with admin-only reads.
The dashboard at `#/admin/metrics` is lazily loaded; its route guard is convenience and the
Firestore rule is the control. Four emulator tests assert the denials.

---

## Demo hardening

Everything here exists because it would be visible in front of an investor.

| Guard | Where | Why |
|---|---|---|
| **Error boundary** with a *Start over* button that clears storage | `components/ErrorBoundary.tsx` | Any render throw was previously a permanent white screen with no recovery for someone who can't open devtools |
| **Validated storage** — malformed pets are dropped on load | `App.tsx` `isValidPet` | `project()` throws on an unknown breed. A rehearsal pet left behind after a data change would brick that laptop |
| **`?reset`** and a *Reset demo data* item in the pet switcher | `App.tsx` | Rehearsal pets accumulated forever with no way to clear them |
| **16px inputs** | `index.css` `.field` | Below 16px, iOS Safari force-zooms on focus and never zooms back — the rest of the demo is then scrolled sideways |
| **Hash routing** `#/pet/:id/:surface` | `App.tsx` | Deep links you can send, a reload that lands where you were, and back-swipe that moves back a surface instead of leaving |
| **Branded first paint** + `<noscript>` | `index.html` `#boot` | A slow network previously showed a blank cream rectangle |
| **OG card and app icons** | `scripts/make-icons.mjs` | Rendered through the same Chromium and fonts as the app, so the share card can't drift from the product |

`scripts/verify-demo.mjs` asserts all of it end to end — 29 checks including deliberately corrupting
localStorage, forcing a render throw, and sweeping every surface at 320px for overflow.

---

## The honest bits

Five things in here are deliberate and worth knowing before the demo. Points 4 and 5 are the ones
most likely to be argued with, and they are the ones where the app disagrees with the received
wisdom on the evidence rather than on instinct.

**1. Studies do not measure the same thing.** "Life expectancy at age 0" includes animals that die
as puppies and kittens and runs systematically below "median survival" or "median age at death".
The two large UK studies disagree by more than five years on the French Bulldog for exactly this
reason. Figures are never averaged across studies; every citation carries its `metric`.

**2. The levers are not equally evidenced, and the UI says so.** Each carries a badge. Dogs get
three; cats get a fourth.

| Lever | Tier | Why |
|---|---|---|
| Body condition | Strong evidence | Purina lifetime feeding trial (13.0 vs 11.2 years median), plus 50,787 US dogs showing the effect is *largest in small breeds* |
| Dental care | Associational | Periodontal disease is associated with kidney disease, but **no study shows dental care extends lifespan** and AAHA calls the causal story "oversimplified". Weighted small on purpose. |
| Activity | Directional | The Dog Aging Project's cognitive-dysfunction finding is cross-sectional and its authors state causality cannot be determined. No lifespan study exists. |
| Outdoor access *(cats)* | Associational | Direction documented, magnitude not. See below — it is the one lever whose weight is larger than its tier, and the app says so on the lever itself. |

**3. Cats are not small dogs.** In dogs, overweight is the clear risk. In cats, the largest body-
condition study found *thin* cats at markedly higher risk and mild overweight not significantly
associated with shorter survival. So "lean" is a positive in a dog and a mild negative in a cat.
That asymmetry is in the engine, not a bug.

**4. Outdoor access costs less than everyone says, and the app is the one saying so.** The line
everyone repeats — indoor cats live fifteen years, outdoor cats live two to five — comes from feral
colony work and does not describe an owned cat with a house to come back to. The owned-cat evidence
is narrower and more useful:

- **McDonald 2017** (2,738 UK cats): median age at death 14.0 years across all causes, **3.0 years
  where the cause was trauma**, 2.7 where it was a road traffic accident.
- **Kent 2022** (3,108 necropsies): outdoor-only cats died younger than indoor-only and
  indoor–outdoor cats across all ages (7.25 vs 9.43 and 9.82) — but **among cats who had already
  reached one year, the three groups were not significantly different** (9.98 / 10.09 / 9.80,
  p = 0.11). Indoor–outdoor was never the worse group.

So the cost is real and is paid almost entirely by young cats. Three things follow, and all three
are in the engine: `indoor-outdoor` is the **reference**, not the penalty; the penalty for a
free-roaming cat **tapers with age** (full weight to two, decaying to a floor of 35% by ten); and
the range **widens** for an outdoor cat, because a farm track and a main road are the same answer on
our form. The magnitude and the shape of the taper are ours, not published, and the lever says that
on screen.

**5. Age at neutering is recorded and deliberately not projected.** Hart 2020 found joint disorder
incidence rising with early neutering in dogs over roughly 45 lb, and nothing in small breeds. We
ask for it — only of neutered dogs whose breed is big enough to be in that group — and use it to
frame the hip, elbow and cruciate cards. It moves no number. Hart measured joint disorder
incidence, not survival, and converting one into the other would mean inventing a figure. It is
also the only input on the form nobody can act on after the fact.

---

## Figures marked illustrative

67 breeds. **57 published**, **4 derived**, **6 illustrative** — and every remaining illustrative
entry is a cat. There are no illustrative dogs left.

"Illustrative" means no breed-level life expectancy figure was found in the literature searched;
the range is anchored to the published US size-class figure (Montoya 2023: toy 13.36, small 13.53,
medium 12.70, large 11.51, giant 9.51) and set by clinical convention. Every one is flagged in the
data and surfaced in the app's own methodology panel.

**Dogs: none.**

**Cats (6):** Maine Coon, Ragdoll, British Shorthair, Norwegian Forest Cat, Russian Blue,
Abyssinian

### How the 23 dog gaps were closed

McMillan 2024 Supplementary Table 3 (Kaplan–Meier estimates for all 155 breeds) was transcribed in
full. Twenty-one entries went straight to `published`; four that were `derived` off a
life-expectancy-at-age-0 figure were upgraded on a real median; the two Poodle entries went the
other way, to `derived`, for the reason below.

Each new range was set by one rule, applied uniformly and stated here so it can be argued with:

```
baseline.low  = median − 1.4      rounded to the nearest 0.5
baseline.high = median + 0.9      rounded to the nearest 0.5
```

That envelope was read off the thirteen entries already authored against a McMillan median before
this pass (offsets ran −0.6 to −1.8 at the low end and +0.2 to +1.4 at the high end, widths 2.0 to
2.5 years). Healthy years sit below total lifespan, which is why the midpoint lands under the
published median rather than on it.

Three things worth knowing about the result:

- **Size-class anchoring was badly wrong at the top end.** Great Dane, Bernese Mountain Dog and
  Newfoundland were each about two years low, because the giant size class is dominated by
  shorter-lived molossers. Pomeranian and Bichon Frise were about a year high in the other
  direction. If anyone asks what "illustrative" actually cost in accuracy, this is the answer.
- **The two Poodle entries are now `derived`, not `published`.** The study reports one pooled
  "Poodle" figure of 14.0 years and its own breed table leaves Body Size as `NA` for that row — the
  records do not separate Standard from Miniature and Toy. Attributing the pooled figure to either
  variant would assert a breed-level result the study does not make.
- **Every McMillan figure already in the file was verified against Table S3.** All thirteen
  matched exactly, including the mixed-breed fallbacks' crossbred figure of 12.0.
- **Eight breeds were re-anchored off the wrong metric.** Boxer, Cavalier King Charles Spaniel,
  Cocker Spaniel, German Shepherd, English Springer Spaniel, Staffordshire Bull Terrier, Yorkshire
  Terrier and Jack Russell Terrier were all `published` already — but on Teng's life expectancy at
  age 0, which counts puppies that die young and runs systematically low. All eight now sit on a
  McMillan median with the Teng figure retained beside it, metric attached. The Cavalier was the
  worst affected at more than a year low. **Every dog in the file is now anchored to median
  survival, and a test asserts it.**

  The Cocker Spaniel needed a judgement call: the app keeps one generic entry covering both
  Cockers, and the study reports them separately (English, 26,303 dogs; American, 657). Both
  landed on exactly 13.3 years, which is the only reason one entry is still defensible. Had they
  diverged it would have had to split in two or drop to `derived`.

**Golden Retriever is no longer on this list, and Max is a Golden Retriever.** His range moved from
10.5–12.5 to 12.0–14.0 on a published median of 13.2 years from 11,506 dogs. If an investor asks
where his number comes from, that is now a one-sentence answer instead of a caveat.

**Where to firm the rest up, in order of value:**

1. **Teng 2024 feline breed table.** Five values are known as an unordered set (10.3, 10.0, 9.7,
   9.7, 9.6) belonging to Ragdoll, Maine Coon, British Shorthair, Russian Blue and Norwegian
   Forest Cat. Journal access would resolve the mapping and close five of the six remaining gaps
   immediately. They were deliberately not guessed.
2. **A breed-level figure for the Abyssinian**, the sixth and last gap.
3. **AAHA/AAFP 2021 Table 4**, the per-life-stage diagnostic matrix. The stage care templates
   currently follow the guidelines' readable prose; the exact test-by-stage grid needs journal
   access to transcribe.

Separately, **205 of 273 condition onset windows are clinical convention rather than a cited
study** for that specific condition in that specific breed. They are directionally right and
useful, but they are not literature-derived per breed. Worth a veterinary review pass before this
becomes a shipping product rather than a demo.

---

## Known limitations, stated in the app

- The outdoor-access magnitude, and the rate at which it tapers with age, are ours. The direction is
  documented; no study puts years on it for an owned cat.
- Nothing here knows the road outside the door. "Outdoor" covers a cat on a farm track and a cat on
  a main road, and those are not the same animal.
- Age at neutering frames the joint cards and nothing else, for the reason above.
- Everything is a breed average. It says nothing about an individual animal's genetics.

## Guardrails

Informational framing only — the app suggests what to watch and discuss with a vet, and never
diagnoses or prescribes. Projections are always ranges with "on track for" framing. No invented
statistics appear in visible copy; anything not literature-backed is phrased qualitatively.
The footer disclaimer reads: *"Clovara Life shares information to support care decisions. It is
not veterinary advice; your veterinarian decides care."*
