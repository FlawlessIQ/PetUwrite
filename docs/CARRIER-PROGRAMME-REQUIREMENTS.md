# Carrier programme — what we need from them

**Status: for Conor, to take into carrier and MGA conversations.** Execution
Plan B4. Nothing binds today: `MockRatingAdapter.canBind` is `false`, every quote
is labelled illustrative, and the attach flow says so on the screen rather than
pretending.

## What is already built, and what it costs to switch on

SPEC §5 called for the UX to be built against a mock adapter with the same
interface the real programme will use. It was, and the interface is three calls:

```ts
interface RatingAdapter {
  id: string
  canBind: boolean                                   // false until a programme is live
  quote(pet, projection, opts): Quote                // Quote carries `illustrative`
  smartDefault(pet, projection): QuoteOptions        // the configuration we suggest
  bind(req: BindRequest): Promise<BindResult>
}
```

Every surface goes through it. **A real adapter is one file**: implement those
three calls, set `canBind: true`, return `illustrative: false`, and the amber
"illustrative" box disappears on its own because the UI keys off that flag rather
than off a hard-coded string. No screen changes.

That is the whole engineering cost of B4. Everything else below is what the
programme itself has to be able to do.

## The questions that decide the integration

1. **Is rating ours or theirs?** If they rate, `quote()` becomes a network call
   and the attach flow needs a loading state it does not have today — the current
   flow is instant because the mock is pure. If they give us filed rate tables,
   `quote()` stays synchronous and the flow keeps its speed. **Either works; they
   are different builds**, and the second is a better product.
2. **Which states, on day one?** The flow asks for an address only at attach
   (SPEC §4.3's contextual field rules). If a state is not covered we must say so
   before that, which means a covered-states list we can read at quote time.
3. **What are the filed rating factors?** Ours today are breed, age, species,
   size class and postcode. If their filing needs anything we do not hold, it
   becomes an onboarding question, and every new question costs completion.
   **Ask for the factor list before agreeing to a launch date.**
4. **Can the wellness rider be separate?** Invariant 2 requires the membership
   and the premium to be separate, labelled lines, and the rider is
   non-insurance. A programme that bundles them into one number cannot be sold
   through this product without breaking that.
5. **What does binding actually return?** We need a policy number, an effective
   date and a document URL, synchronously or by webhook. `BindResult` already has
   that shape. If binding is a human process with a next-day answer, the flow
   needs a pending state — buildable, but it is a different screen from the one
   that exists.
6. **Renewal, and who explains it?** `RenewalExplained` is built and switched
   off. It shows the filed factors line by line, then the list of what is *not*
   in the price. For it to be true we need the actual rate-change components at
   renewal, not a single new number.
7. **Claims: who pays, who decides, on what SLA?** This is the promise the
   product is built around — "Claim in Hours" is on the journey map as `built` in
   the demo. A programme whose real claims path is ten working days makes that
   moment a lie. Operational design is Execution Plan A-track, but the SLA is
   negotiated here.

## What we must not agree to

- **Anything that prices on data the Data Covenant protects.** No companion
  conversation, no tracker reading, no engagement metric may touch an individual
  premium — not upward, and **not downward as a reward**, which is the half
  people forget and the half that keeps the other half honest. A programme that
  wants our wellness data as a rating input is not compatible with this product.
  A separately filed, opt-in, transparently priced telematics programme is the
  only route, and it is a different product an owner chooses on purpose.
- **Claims access to the pet graph beyond what the owner has confirmed.** Records
  carry provenance; `extracted_confirmed` means the owner saw it and agreed. A
  claims process that wants the raw conversation or the unconfirmed extraction is
  asking for something we have promised not to give.
- **A filing that needs a question we cannot ask honestly.** If a factor requires
  an owner to guess — an exact weight for a cat nobody can weigh, a neuter date
  from a rescue — the answer is noise and the rate is built on it. We would rather
  widen the range than invent the input.
- **Exclusivity that outlasts the programme's own performance.** Not an
  engineering concern; it is the one that costs most to undo.

## What we would need technically

- A sandbox with test rates and test binding. Everything here is verified against
  a real test environment — Stripe test clocks, Firebase emulators, a live Places
  call — and a partner without one cannot be integrated to the same standard.
- Rate tables as data, or an API with a documented latency budget.
- A webhook for anything asynchronous: binding, endorsement, renewal, cancellation.
- Their filed wording for the disclosures, early enough for counsel (A2) to read
  it alongside ours rather than after.
