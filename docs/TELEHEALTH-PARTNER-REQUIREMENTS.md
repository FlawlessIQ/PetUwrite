# Telehealth partner — what we need from them

**Status: for Conor, to take into partner conversations.** No partner exists and
nothing is built against one. SPEC-COMPANION C4.

## Why there is no adapter yet

The other four integration seams in this codebase — rating, fitness, extraction,
places — were each built against a shape that was known: a real API, an
interface specified in SPEC, or a domain with only one sensible model. A
telehealth interface invented now would be a guess at somebody else's API, and
the first real integration would delete it. It would look like progress and
create work for whoever does the real thing.

What is built instead is the honest answer to somebody asking for a vet: we have
no one to put you through to, here is your summary, here is how to reach your
own practice out of hours. That works today and keeps working when a partner
lands.

## The five questions that decide the integration

1. **Scheduled or on-demand?** A booking flow and a queue flow are different
   products. The companion's routing (`vet-soon` versus `vet-now`) only means
   something if the partner can act on the difference.
2. **Do they take our summary?** C0 already produces a one-page history as plain
   text. If they accept it — as a note, an attachment, anything — the
   consultation starts several minutes ahead. If they insist on their own intake
   form, the owner retypes what we already hold, and most of the value is gone.
3. **Who holds the account?** If the owner needs a separate login with them, the
   handoff loses people at exactly the moment they are worried. A token handoff
   or a per-consultation guest session is worth paying for.
4. **What comes back, and may we store it?** A consultation produces findings.
   If those can return to us as structured data, they become records with
   `vet_verified` provenance — the only thing in the product that would carry
   it. If nothing comes back, the pet's record is unchanged by the visit and the
   loop stays open.
5. **Which jurisdictions, and what are they licensed for?** Routing somebody to
   a vet who cannot practise where they live is worse than not routing them.

## What we would need technically

- An API that can create a consultation for one animal, attaching free text.
- A way to hand off an owner without them creating an account first, or a very
  fast one if not.
- A webhook or a poll for outcome, if findings are to come back.
- A sandbox. Everything in this codebase is verified against a real
  test environment — Stripe test clocks, Firebase emulators, a live Places
  call — and a partner without one cannot be integrated to the same standard.

## What we must not agree to

- **Anything that lets consultation content reach underwriting or claims.** The
  Data Covenant and SPEC §2 invariant 4 both forbid it, and SPEC-COMPANION §4
  makes it an IAM boundary rather than a promise. A partner who wants to share
  data with an insurer is not compatible with this product.
- **A revenue share that makes us prefer routing to them over a local vet.** The
  companion routes on what is best for the animal. A commission that quietly
  makes telehealth the answer to everything would corrupt the one thing the
  surface exists to do.
