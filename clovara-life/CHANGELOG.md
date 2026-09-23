# Clovara Life — changelog

One section per SPEC phase. Newest first. Behaviour, not commits — the git log
has the commits.

## P0 — Foundations (in progress)

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

### Auth (shipped before P0 opened; realigned in P0.1)

- Email/password + Google, behind a dynamic import. Being realigned to email
  link per SPEC §3.
