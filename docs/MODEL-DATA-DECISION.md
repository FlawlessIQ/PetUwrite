# May owner-written text go to Google?

**Status: a decision for Conor and counsel.** Execution Plan B2. It is one
decision that unlocks three finished features, and it is the cheapest unblock on
the whole plan — it costs a conversation, not a build.

This document says exactly what would leave the building, what would not, what
the options are, and what I would do.

---

## 1. What is switched off, and what switching it on would send

Three flags, all `false`:

| Flag | Where | Feature |
|---|---|---|
| `EXTRACTION_ENABLED` | `clovara-life/src/extract/provider.ts` | Vet-record and vaccine-card extraction (also gated on B1) |
| `CONVERSATIONAL_ONBOARDING_ENABLED` | `clovara-life/src/extract/conversational.ts` | "Tell me about them, in your own words" |
| `COMPANION_MODEL_ENABLED` | `clovara-life/functions/compose.js` | Companion C3 — model-composed replies |

The two paths send different things, and the difference matters more than the
flags do.

**Extraction and conversational onboarding** send the owner's own words and
nothing else. `parseWithGemini(text)` posts a fixed system prompt plus the
sentence the owner typed. No pet name, no record, no identifiers.

**The companion** sends more. `composeReply({ utterance, facts, petName })`
posts the pet's name, the grounded facts retrieved for that question — which
include conditions on the record, weights, and vaccination history — and the
owner's question. **That is health data about a specific animal, with a name
attached.** It is still not owner-identifying: no email, no address, no uid, no
household id. But "the pet's name plus their conditions" is a smaller step from
identifiable than "an unlabelled sentence" is, and the decision should be made
about the second case, not the first.

Nothing in either path is stored by us as a result of the call. The companion's
verification gate then drops any sentence the model returns that is not cited to
a fact we already held, so the model cannot introduce information — but that is a
correctness control, not a privacy one, and it does not bear on this decision.

## 2. Which Google this is, which is the crux

Both paths call `generativelanguage.googleapis.com` with `LIFE_GEMINI_API_KEY`
from Secret Manager. That is the **Gemini Developer API**, not Vertex AI on our
own GCP project — and the two have materially different data-handling terms.
Free-tier Developer API usage in particular is not the same promise as
enterprise terms.

**I am not the right source for what those terms currently say**, and they
change. What I can say is that the choice of endpoint is a one-line change in two
files, and that it probably dominates the decision:

- **Gemini Developer API** (today): simplest, already wired, key already in
  Secret Manager, and the terms are Google's consumer-side terms.
- **Vertex AI**, same models, our own GCP project: enterprise data-handling
  terms, data-residency options, IAM and audit logging we already use for
  everything else, and the calls appear in our own project's logs. Costs a small
  amount of plumbing and a service account.

**Ask counsel about Vertex, not about Gemini.** If the answer for Vertex is yes,
the decision is made on much better ground and the engineering delta is a day.

## 3. What the Data Covenant already promises

The covenant page (`clovara-life/src/data/covenant.ts`) makes four hard
promises: nothing told to the companion decides a claim; no tracker reading
decides a claim; your data does not change your premium, up or down; we do not
sell it. **It does not currently say anything about processing by a third party.**

That silence is the gap. A reader of that page would reasonably assume their
conversation stays with us, and SPEC-COMPANION §10.3 already flags the related
question of whether a human at Clovara may ever read one. **If this decision is
yes, the covenant needs a sentence saying so** — which is A2 work, and is why
this decision and that review want to happen in the same conversation.

The covenant's own commitment on changes applies here: *"If we change anything on
this page we will say so directly — not in a version note — and the old wording
will stay readable beside the new one."*

## 4. The options, honestly

| | What it means | Cost |
|---|---|---|
| **A. Yes, via Vertex AI** | All three features on, enterprise terms, our own project's logs | ~a day of plumbing, plus a covenant sentence and counsel's sign-off |
| **B. Yes, via the Developer API as wired** | All three on today | zero engineering; the weakest position to defend later |
| **C. Yes for owner-written text only, no for the companion** | Extraction and conversational onboarding on; C3 stays off | zero engineering — they are separate flags, which is why they are separate flags |
| **D. No, for now** | All three stay off. The product loses nothing it has today: extraction is also gated on B1, and the companion's deterministic C2 is what ships and is honest | zero |
| **E. No, and self-host** | A model we run. Removes the third party entirely | weeks, and an ongoing operational burden for a product with no traffic yet |

## 5. What I would do

**C first, then A.**

Turn on extraction and conversational onboarding — the paths that send only the
owner's own sentence, with no name and no record — and leave the companion's
model composition off until Vertex is in place and the covenant has the sentence.
That sequencing gets the feature people actually asked for (photograph the
vaccine card, stop typing) without making the harder promise first, and it keeps
the two decisions genuinely separate instead of bundling them because the flags
happened to arrive together.

**E is not worth it now.** A self-hosted model for a product with no traffic is
an operational burden bought to avoid a conversation.

And whichever way this goes, **the honest version of C2 is already live** — a
grounded companion that recalls, routes and never guesses, with no model
anywhere. The decision is about making it fluent, not about making it work.
