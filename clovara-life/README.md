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
npm test           # 75 engine, platform and data-integrity tests
npm run build      # → dist/
npm run icons      # regenerate public/og.png and the apple-touch icon

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
    project.test.ts  31 tests.
    platform.test.ts 41 tests.
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

`scripts/verify-demo.mjs` asserts all of it end to end — 27 checks including deliberately corrupting
localStorage, forcing a render throw, and sweeping every surface at 320px for overflow.

---

## The honest bits

Three things in here are deliberate and worth knowing before the demo.

**1. Studies do not measure the same thing.** "Life expectancy at age 0" includes animals that die
as puppies and kittens and runs systematically below "median survival" or "median age at death".
The two large UK studies disagree by more than five years on the French Bulldog for exactly this
reason. Figures are never averaged across studies; every citation carries its `metric`.

**2. The three levers are not equally evidenced, and the UI says so.** Each carries a badge:

| Lever | Tier | Why |
|---|---|---|
| Body condition | Strong evidence | Purina lifetime feeding trial (13.0 vs 11.2 years median), plus 50,787 US dogs showing the effect is *largest in small breeds* |
| Dental care | Associational | Periodontal disease is associated with kidney disease, but **no study shows dental care extends lifespan** and AAHA calls the causal story "oversimplified". Weighted small on purpose. |
| Activity | Directional | The Dog Aging Project's cognitive-dysfunction finding is cross-sectional and its authors state causality cannot be determined. No lifespan study exists. |

**3. Cats are not small dogs.** In dogs, overweight is the clear risk. In cats, the largest body-
condition study found *thin* cats at markedly higher risk and mild overweight not significantly
associated with shorter survival. So "lean" is a positive in a dog and a mild negative in a cat.
That asymmetry is in the engine, not a bug.

---

## Figures marked illustrative

67 breeds. **32 published**, **6 derived**, **29 illustrative**. "Illustrative" means no
breed-level life expectancy figure was found in the literature searched; the range is anchored to
the published US size-class figure (Montoya 2023: toy 13.36, small 13.53, medium 12.70, large
11.51, giant 9.51) and set by clinical convention. Every one is flagged in the data and surfaced
in the app's own methodology panel.

**Dogs (23):** Golden Retriever, Boston Terrier, Australian Shepherd, Rottweiler, Doberman
Pinscher, Great Dane, Bernese Mountain Dog, Newfoundland, Pomeranian, Miniature Schnauzer,
Whippet, Greyhound, Vizsla, Weimaraner, Rhodesian Ridgeback, Poodle (Standard), Poodle (Miniature
or Toy), Maltese, Havanese, Bichon Frise, Pembroke Welsh Corgi, Basset Hound, Dalmatian

**Cats (6):** Maine Coon, Ragdoll, British Shorthair, Norwegian Forest Cat, Russian Blue,
Abyssinian

**Golden Retriever is on this list, and Max is a Golden Retriever.** Worth knowing if an investor
asks where his number comes from. The honest answer is that the two big UK life-table studies
cover 18 and 155 breeds respectively and neither published a retrievable Golden figure; his range
sits on the US large-breed figure adjusted down for the breed's well-documented cancer burden.

**Where to firm these up, in order of value:**

1. **McMillan 2024 Supplementary Table 3** covers all 155 breeds and would close roughly 20 of the
   29 gaps in one go. It is behind a robots.txt-blocked supplementary PDF — download it manually
   from the article page, or email the corresponding author at Dogs Trust.
2. **Teng 2024 feline breed table.** Five values are known as an unordered set (10.3, 10.0, 9.7,
   9.7, 9.6) belonging to Ragdoll, Maine Coon, British Shorthair, Russian Blue and Norwegian
   Forest Cat. Journal access would resolve the mapping and close five cat gaps immediately. They
   were deliberately not guessed.
3. **AAHA/AAFP 2021 Table 4**, the per-life-stage diagnostic matrix. The stage care templates
   currently follow the guidelines' readable prose; the exact test-by-stage grid needs journal
   access to transcribe.

Separately, **205 of 273 condition onset windows are clinical convention rather than a cited
study** for that specific condition in that specific breed. They are directionally right and
useful, but they are not literature-derived per breed. Worth a veterinary review pass before this
becomes a shipping product rather than a demo.

---

## Known limitations, stated in the app

- Indoor versus outdoor living is one of the largest determinants of feline life expectancy and is
  not asked about.
- Age at neutering is associated with joint disorder risk in dogs over roughly 45 lb; the app
  records neuter status but not the age it happened.
- Everything is a breed average. It says nothing about an individual animal's genetics.

## Guardrails

Informational framing only — the app suggests what to watch and discuss with a vet, and never
diagnoses or prescribes. Projections are always ranges with "on track for" framing. No invented
statistics appear in visible copy; anything not literature-backed is phrased qualitatively.
The footer disclaimer reads: *"Clovara Life shares information to support care decisions. It is
not veterinary advice; your veterinarian decides care."*
