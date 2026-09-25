# Wearable partner — what we need from them

**Status: for Conor and Matt, to take into hardware conversations.** Execution
Plan B5. SPEC §6.9 is explicit that the seam is the deliverable and the hardware
is not: *"do NOT build hardware integration."*

## What is already built

`FitnessProvider` is the contract, and `SimulatedProvider` is what everybody sees
today:

```ts
interface FitnessProvider {
  id: string
  simulated: boolean                        // what every surface must disclose
  deviceId(pet): string | null              // null when nothing is paired
  activity(pet, now): { steps, trend[], belowNormal }
  sleep(pet, now):    { hours, disturbances }
  vitals(pet, now):   { restingRespiratoryRate, restingHeartRate }
}
```

Two properties of the simulated provider matter for the partner conversation.

It is **not random** — values derive from the pet's id and their declared
routine, so two people looking at Max see the same Max and the demo is stable in
front of investors. And it reports `simulated: true`, which every surface showing
its numbers uses to say so. **A fabricated step count presented as a measurement
would be the most dishonest thing in the product**, so that disclosure is not
cosmetic and does not come out when a real device lands — it goes false, and the
disclosure disappears on its own.

A real provider is one file implementing those five calls. No surface changes.

## The questions that decide which partner

1. **What do they actually measure, and how often?** `activity` we can get from
   anything. `sleep` needs overnight granularity. `vitals` — resting respiratory
   and heart rate — is the one that matters clinically and the one fewest devices
   do honestly. **The nudge is built on `belowNormal`**, which needs a per-animal
   baseline, so we need history, not a daily total.
2. **Whose baseline is it?** If they give us a cooked "wellness score" instead of
   raw readings, the nudge becomes their judgement rather than this animal's own
   trend, and we cannot explain it. We want the numbers.
3. **Latency and gaps.** A device off the charger for a day must not read as a
   sick animal. What does their API return for a gap — a zero, a null, or nothing?
   **A zero that we render as "no movement" would frighten somebody about a
   charging cable.** The provider contract must be able to say "we do not know",
   which is invariant 9 and is why `vitals` returns `number | null`.
4. **Pairing.** Does the owner pair through their app and we read by API, or can
   we pair in ours? The first is far less work and costs a handoff at exactly the
   moment somebody is enthusiastic.
5. **Who owns the data, and can the owner delete it?** The Data Covenant promises
   deletion on request, including from aggregate work. A partner who cannot delete
   on instruction makes that promise untrue.
6. **Species.** Most of this market is dogs. Cats are half the product and the
   harder engineering problem — a collar on a cat is a different device. A
   dog-only partner is fine if the product says so rather than silently showing
   cats an empty surface.
7. **Hardware economics.** The journey map has the CloTag in the membership from
   day one (`launch` horizon) and, in value-added-services states, given free as a
   loss-prevention device. Both of those are unit-cost questions before they are
   engineering ones.

## What we must not agree to

- **Anything that lets device data reach underwriting, claims or an individual
  premium.** Not upward, and **not downward as a reward** — the Data Covenant
  makes both promises and the second is what keeps the first honest. "Earned
  Rates" exists on the journey map as a `sky` item precisely because it would have
  to be a separately filed, opt-in programme, not a quiet use of this data.
- **A partner who wants to share readings with any insurer**, ours included,
  outside that filed programme.
- **Presenting their score as ours.** If we show a number, we must be able to say
  where it came from and what it means. A black-box score fails that and fails
  invariant 6's spirit.
- **A contract that requires us to prompt for engagement.** Streaks exist to make
  a habit easier, not to feed a partner's DAU metric, and points follow evidence
  rather than engagement.

## What we would need technically

- A sandbox with a simulated device, or a loaner. The suites here verify against
  real test environments; a partner without one cannot meet the same standard.
- Historical reads, not just "today" — the trend and the baseline both need it.
- Explicit nulls for gaps, and a documented backfill policy.
- OAuth or token-based per-owner access, revocable by the owner.
