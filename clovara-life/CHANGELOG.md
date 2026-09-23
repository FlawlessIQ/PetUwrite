# Clovara Life — changelog

One section per SPEC phase. Newest first. Behaviour, not commits — the git log
has the commits.

## P0 — Foundations (in progress)

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
