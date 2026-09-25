# Firestore security review — what to give the reviewer

**Written 2026-09-24 by Claude Code.** ROADMAP B1 / Execution Plan B1: the
review that gates vet-record extraction. SPEC §7 carries the budget line.

This exists so the engagement does not start with "have a look at the rules."
Everything below is a demonstrated fact about the rules as deployed, not a
worry — each claim is backed by a test in
`clovara-life/src/store/attack.emulator.test.ts`, which is written to break the
rules rather than to confirm them.

**Why an outside reviewer at all, given those tests exist:** I wrote both the
rules and the tests, so they share a blind spot by construction. That is not
theoretical — the adversarial suite found two real holes in rules I had written
and reviewed myself (§3), and it found them only because it was written to
attack rather than to verify. The next two are the ones I did not think to
attack.

---

## 1. What to review

`firestore.rules`, the block from `// CLOVARA LIFE` to the end of
`match /households/{householdId}` (about 90 lines). Everything above it belongs
to the underwriting product and is out of scope — Life shares the auth user pool
and nothing else.

Also in scope:
- `storage.rules`, the `life/households/{hh}/pets/{pet}/` tree, which holds pet
  photographs and lump photographs.
- The Cloud Functions that write with the Admin SDK and therefore bypass rules
  entirely: household invites, joins, sitter links, and the Stripe webhook that
  writes `entitlement`.

## 2. The model, in one paragraph

A household owns pets; users belong to households. Membership is held twice on
the household document — `members` (a map, carrying roles) and `memberIds` (an
array) — because Firestore cannot query map keys and both the rules and the
"find my household" query need to. Pets are documents under
`households/{id}/pets/{petId}`. **Everything below a pet is denied**, which is
why the lump diary stores its entries as a field on the pet document rather than
in a `lumps/` subcollection. Invites, joins, sitter links and entitlement are
written only by Cloud Functions on the Admin SDK.

## 3. Two holes this has already had, for calibration

Both were found by the adversarial suite on 2026-09-24, both were live in
production, and both are now closed and re-tested:

1. **A free paid membership.** `create` on a household validated `createdBy`,
   `memberIds` and `members` and said nothing about any other field — so a
   client could create a household carrying its own
   `entitlement: {status: "active"}`. `update` had always forbidden touching
   `entitlement`; `create` had simply never been asked. Fixed with an
   **allowlist** (`keys().hasOnly([...])`) rather than another named exclusion,
   so anything server-owned added later is excluded by construction.
2. **Evicting the founder.** `update` required only that the writer remained a
   member, which let any member remove the founder from the household holding
   their own animals and keep the pets. `memberIds` and `members` are now frozen
   against client writes entirely.

A scan of every household in production confirmed no forged entitlement existed.

## 4. The question I would put first

**A pet document has no field allowlist.** Any household member may write any
field, including `provenance: 'vet_verified'` and an `updatedBy` naming somebody
else. `BOUNDARY: a member can stamp their own data "vet_verified"` in the
adversarial suite demonstrates it.

Today this is cosmetic: nothing grants a privilege, a price or a claim outcome on
the strength of a pet field. The Data Covenant firewalls underwriting from all of
it, and `canBind` is false. The worst an owner can do is mislabel their own data
in their own app.

It stops being cosmetic the moment anything trusts those fields — a claim, a
rating input, or a "vet verified" badge shown to a sitter who is not the person
who typed it. Since vet-record extraction is exactly what this review gates, the
question is live rather than hypothetical:

- Should provenance be client-writable at all, or only by a Cloud Function?
- If rules must validate it, they cannot iterate map keys, so validation means
  enumerating every known field — which fails closed and silently breaks writes
  the day a field is added. **I did not attempt this**, because a brittle rule
  that blocks legitimate writes is worse than a cosmetic mislabel. A reviewer
  should say whether the enumeration is worth it or whether the write path should
  move server-side.
- `updatedBy` is trivially constrainable to `request.auth.uid` and probably
  should be. It is not today.

## 5. What else I would ask them to look at

- **`get()` costs and failure modes.** `lifeIsMember()` does a `get()` on the
  household for every pet read and write. Confirm the billing shape, and what
  happens to a legitimate member when that `get()` fails.
- **The `{sub=**}` deny.** It is meant to be total. Confirm no path reaches a
  subcollection under a pet, including through a collection-group query.
- **Collection-group queries generally.** Nothing in the app issues one; the
  rules do not mention them.
- **The storage rules against the Firestore rules.** A photograph's path encodes
  a household and a pet; the two rule sets have to agree about membership and
  they are written in different files by different mechanisms.
- **Sitter links.** Deny-all to clients, minted and revoked by a function. The
  token is an unauthenticated read key to a care card. Review the function, the
  token entropy and the expiry, not the rules.
- **Whether an admin should be able to read a household at all.** `isAdmin()`
  appears in the Life block exactly once, on the analytics log; it has no path to
  a household, a pet, or anything in one. Support will eventually want a way in,
  and the Data Covenant does not currently carve one out (SPEC-COMPANION §10.3).

## 6. What they should not spend time on

The underwriting collections, the marketing site, and anything under
`users/` — all out of scope for this engagement. The companion's conversation
store does not exist yet; its firewall is specified in
`clovara-life/SPEC-COMPANION.md` §4 and is worth a separate look when it is built.

## 7. How to run what is already there

```bash
cd clovara-life && npm run test:emulator
```

110 tests against the Firestore, Auth and Storage emulators, of which 16 are
adversarial. `src/store/attack.emulator.test.ts` is the file to read first: each
test is named for the attack rather than the feature.
