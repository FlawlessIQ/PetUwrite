# Clovara Companion — architecture spec

**Status: the architecture is built; the decisions are still open.** It extends
`SPEC.md` and inherits every invariant in its §2; where this document and SPEC
disagree, SPEC wins until Conor says otherwise.

**What shipped, 2026-09-24** — see `CHANGELOG.md` for the detail:

| | |
|---|---|
| C0 · vet-visit summary | shipped |
| C1 · safety classifier | shipped |
| C2 · retrieval and grounding | shipped |
| C3 · model composition | **built and switched off** — `COMPANION_MODEL_ENABLED` is false pending the privacy decision in §4. Verification, the response schema and 45 red-team checks are all in place |
| C4 · telehealth routing | done as far as it honestly can be. Asking for a vet gets a true answer and a route; `TELEHEALTH_AVAILABLE` is false and no provider interface was invented against an unknown partner API. `docs/TELEHEALTH-PARTNER-REQUIREMENTS.md` is what a partner conversation needs |

C0–C2 use no model at all. **The six decisions in §10 are still open**, and the
one in §4 is what keeps C3 switched off.

Open questions that are Conor's and not engineering's are marked **[DECIDE]**
and collected in §10.

---

## 1. What this is

A companion that knows one animal well, in a product that already knows that
animal well. Everything it says is grounded in the pet graph the rest of Clovara
has been filling in: the breed tables, the projection, the conditions declared,
the vaccinations recorded, the passport, the weights over time.

The demo has a hand-written version of this in `buildCompanion()` — four
deterministic turns that show what it should feel like. This spec is about
replacing that exhibit with something real without losing what the exhibit gets
right: it recalls, it routes, and it never pretends to be a vet.

### What it is not

- **Not a chatbot with a system prompt.** A model given a persona and a pet's
  name will confabulate a medical history by the third turn.
- **Not a triage service.** It does not decide urgency on clinical grounds; it
  recognises a small set of red flags and routes.
- **Not a route into underwriting.** See §4.

---

## 2. Inherited invariants, restated because they bind hardest here

| SPEC §2 | What it means for the companion |
|---|---|
| 4. Never diagnoses | It may describe, recall, and route. It may not name a likely condition from symptoms, rank differentials, or say "it sounds like X". |
| 5. Data Covenant | Conversations never reach underwriting or claims. §4 makes this architectural rather than a promise. |
| 7. Engines stay pure | Retrieval and grounding are pure functions over the pet graph. The model call is IO at the edge, like Stripe. |
| 8. Owner-confirmed only | Nothing said in conversation becomes a stored fact without confirm-chips. The pipeline already exists. |
| 9. "I don't know" is always an answer | The companion must be able to say it does not know, and must prefer that to a confident guess. |

---

## 3. The shape

Four stages. Only the third touches a model.

```
utterance
   │
   ├─ 1. SAFETY CLASSIFIER ──── red flag? ──► escalation surface, no model call
   │                                          (reuses the toxin screen's ladder)
   ├─ 2. RETRIEVAL ─────────── pure, over the pet graph
   │                           returns GroundingSet: facts with sources
   │
   ├─ 3. COMPOSITION ───────── model, constrained
   │                           may only use the GroundingSet; cites every claim
   │
   └─ 4. VERIFICATION ──────── pure, over the response
                               drops or rewrites anything uncited or unsafe
```

### 3.1 Safety classifier — before anything else

Deterministic and model-free. Matches a curated red-flag list (collapse,
laboured breathing, seizure, bloat signs, suspected toxin, uncontrolled
bleeding, straining to urinate in a male cat) and, on a hit, renders the
escalation surface immediately — the same ladder `data/toxins.ts` already
carries.

**A model must never be the thing standing between someone and that message.**
A classifier that is sometimes slow, sometimes down and occasionally wrong is
not acceptable in that position. Regex and a word list are worse at nuance and
better at being there.

**[DECIDE]** Who owns the red-flag list clinically? It is a vet-review artefact,
not an engineering one.

### 3.2 Retrieval — pure, and the heart of it

`buildGroundingSet(pet, projection, utterance, now) → GroundingSet`

No IO, no model, injected clock — testable like every other engine here.

```ts
interface GroundedFact {
  claim: string          // "Hip dysplasia is on Max's record, declared 2024"
  source: FactSource     // where it came from, and how sure we are
  provenance?: Provenance // owner_declared | extracted_confirmed | device | vet_verified
}

type FactSource =
  | { kind: 'pet-record'; field: string }
  | { kind: 'breed-table'; breedId: string; citation: string }
  | { kind: 'projection'; component: string }
  | { kind: 'curated-content'; docId: string }   // husbandry, reviewed
  | { kind: 'vaccination' | 'passport' | 'weights' }
```

Everything the companion can say must already be in a `GroundedFact`. The model
adds language, not information.

### 3.3 Composition — the constrained model call

Server-side, through the existing `LIFE_GEMINI_API_KEY` seam. Structured output,
temperature 0, and a response schema that forces a citation per sentence:

```ts
interface ComposedReply {
  sentences: { text: string; citesFactIds: string[] }[]
  routeTo?: 'vet-soon' | 'vet-now' | 'telehealth' | 'none'
  iDoNotKnow?: boolean
}
```

A sentence with no citation is not rendered. That is a hard gate, not a nudge:
the failure mode of a grounded assistant is a fluent paragraph in which three
sentences are sourced and the fourth is invented, and the fourth is the one an
owner acts on.

### 3.4 Verification — pure, over the model's output

Runs after every call:

- drops sentences citing facts not in the `GroundingSet`
- rejects diagnostic language against a banned-construction list ("sounds like",
  "probably", "most likely X", any condition name not already on the pet's record)
- rejects any claim about longer life (VISION vocabulary)
- rejects dosing, drug names, and any instruction to give or withhold treatment
- if more than a threshold of the reply is dropped, discards the whole thing and
  renders the honest fallback rather than a shredded paragraph

**[DECIDE]** Threshold, and what the fallback says.

---

## 4. The firewall, as architecture

Invariant 4 says the companion "states it is firewalled from underwriting and
claims". A statement is not a firewall. Proposed:

- Conversations live in `households/{id}/pets/{petId}/conversations/*`, denied to
  every client path and to `isAdmin()`.
- The underwriting product's service accounts have **no IAM path** to that
  subtree — not "are not expected to read it", cannot.
- Nothing derived from a conversation may be written to any field the
  projection, the rating adapter or a claim reads. The only write path out of a
  conversation is confirm-chips, which produces `extracted_confirmed` fields the
  owner has seen and approved.
- An adversarial test in the style of `attack.emulator.test.ts` attempts each
  crossing and must fail.

**[DECIDE]** Retention. A conversation is the most intimate thing in the
product, and "forever, for aggregate science" is a different promise from what
the Data Covenant currently makes. Suggested default: 24 months, owner-deletable
at any time, with aggregate learning derived only from confirm-chip *outcomes*
(accepted/rejected) and never from message text.

---

## 5. Memory

**The pet graph is the memory.** The companion has no separate long-term store
of "things it believes about this pet".

Per conversation it carries a short rolling window for coreference ("he", "that
lump"). Anything worth remembering beyond the session becomes a candidate and
goes through confirm-chips, exactly like a vet record.

This is the decision most likely to be argued with, so the reasoning: a second
memory that only the companion can see would drift from the record the rest of
the product reasons over, and within months the companion would be confidently
telling an owner something no other surface agrees with — with no provenance and
no way for them to correct it.

---

## 6. Routing

The companion routes rather than resolves. Three destinations:

| Route | When | Surface |
|---|---|---|
| `vet-now` | safety classifier hit | escalation ladder, poison lines, nearest open emergency vet (built) |
| `vet-soon` | grounded concern, no red flag | "worth a vet's eyes" + the one-page history summary |
| `telehealth` | owner asks, or `vet-soon` and a partner exists | **blocked**: no telehealth partner (ROADMAP) |

The history summary is buildable today from the pet graph and is arguably the
most valuable thing here: a vet gets the conditions on file, the last weigh-ins,
the vaccination record and the current routine, without the owner having to
remember any of it.

**[DECIDE]** Ship the summary as a standalone feature before the companion? It
needs no model and no partner.

---

## 7. Provider seam

`CompanionProvider`, in the pattern already used three times — `RatingAdapter`,
`FitnessProvider`, `ExtractionProvider`. Implementation swaps without a surface
changing; the current Gemini key backs the first one.

Deterministic fixtures for every test: the safety classifier, the retrieval and
the verification are pure and tested without a model at all. Only composition
needs one, and it is tested against recorded responses.

---

## 8. How we would know it is safe

Functional tests are not enough for this surface. Proposed, and this is the part
most likely to be under-resourced:

1. **A red-team suite.** Adversarial utterances that try to extract a diagnosis,
   a dose, or reassurance about something dangerous. Named for the attack, like
   the rules suite. Every one must fail to get what it is asking for.
2. **A grounding audit.** Sample real replies; every sentence traced to a fact.
   Any uncited sentence reaching a user is a P0.
3. **A refusal-rate floor.** If the companion never says "I don't know", it is
   confabulating. That number should be watched, and a floor is healthier than a
   ceiling.
4. **Vet review of the red-flag list and the curated husbandry content**, on the
   same footing as `data/toxins.ts`.

---

## 9. Phasing

| | Scope | Depends on |
|---|---|---|
| **C0** | History summary for a vet visit. No model. | nothing — buildable now |
| **C1** | Safety classifier + escalation routing. No model. | vet review of the red-flag list |
| **C2** | Retrieval + grounding set, rendered as a deterministic companion (an honest version of today's demo). | C1 |
| **C3** | Model composition + verification, behind a flag. | privacy decision (§4), red-team suite |
| **C4** | Telehealth routing. | a partner |

C0–C2 need no model and carry no confabulation risk. That is deliberate: most of
the value is retrieval, and the model is the last thing added rather than the
thing everything is built around.

---

## 10. Decisions for Conor

1. **Clinical ownership of the red-flag list** — who, and on what footing?
2. **Conversation retention** — how long, and what may be learned in aggregate?
3. **Is a conversation ever readable by a human at Clovara?** Support and abuse
   handling usually need it; the Data Covenant does not currently carve it out.
4. **Verification threshold** and what the fallback says when a reply is discarded.
5. **C0 (history summary) as a standalone feature first?** It is the cheapest
   real value in this document.
6. **Does the companion ever initiate?** Everything here is reactive. A companion
   that starts conversations is a different product with different consent.

---

## 11. What this document does not cover

Voice. Multi-pet reasoning in one conversation. Anything the companion might do
for a household rather than a pet. The "Remember" chapter, which is on the
journey map and is a harder emotional problem than anything here.
