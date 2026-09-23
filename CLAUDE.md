# CLAUDE.md — Clovara repo instructions

Read `clovara-life/SPEC.md` (the build contract and its 9 invariants) and `clovara-life/README.md` before working. Demo pets (Max, Winston, Luna) and the signed-out demo path must always keep working. Deploy only the target you're working on (`firebase deploy --only hosting:life`); never plain `--only hosting`; never touch the `main` target unless asked.

## Living documents protocol — not optional

The roadmap, journey, and decision history are **living documents in this repo**. Keeping them true is part of every task's definition of done. A PR that changes product behavior or scope without the matching doc update is incomplete.

The three documents and when to touch them:

1. **`docs/ROADMAP.md`** — the build state. Update whenever: a phase or feature starts, ships, or is descoped; an external dependency changes state (carrier, wearable partner, legal reviews, data sources); dates or gates move. Set its `Last updated` line and keep entries honest — "blocked" and "cut" are valid statuses.
2. **`clovara-life/public/partners/journey-data.js`** — the **single source of truth for the product journey**, rendering the live partner map at clovara-life.web.app/partners/journey.html. When something ships, flip its horizon to `built`. When scope changes, edit/add/remove moments here (keep the `[name, desc, pillar, horizon, value]` shape and the customer-voice tone). It goes live on the next `hosting:life` deploy — so the vision partners see is always current.
3. **`docs/DECISIONS.md`** — append-only decision log. Add a dated entry whenever a product, pricing, scope, or architecture decision is made or reversed — one line of decision, one line of why. Never rewrite old entries; a reversal is a new entry.

Rules:
- Doc updates ship **in the same commit/PR** as the change they describe.
- On completing a spec phase: update all three, tag the commit `phase-N-complete`.
- If work reveals the SPEC and reality have diverged, don't silently drift: note it in ROADMAP under "Spec divergences" and flag to Conor.
- `docs/VISION.md` changes only when Conor says the vision changed.
- These files are read by humans and future agents; write them plainly, no filler.

## Invariants (full text in SPEC §2 — binding everywhere)

Points never redeem against premium · premiums separate + labelled · no treatment claims on products · companion never diagnoses · Data Covenant honored · no invented breed figures · engines stay pure · extracted data is owner-confirmed with provenance · "I don't know" always allowed.
