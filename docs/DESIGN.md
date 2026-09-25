# Clovara Design System — build reference (v1, Sept 2026)

Visual rendering of everything below: `docs/styleguide.html` (open in a browser). If a surface disagrees with this document, the surface is wrong. Changes to this system are decisions — log them in `docs/DECISIONS.md`.

## 1. Logo — one file, no drift

**Canonical:** `assets/images/clovara_mark_refined.svg`. Every rendering of the clover derives from this file. Redrawing is prohibited.

**Known drift to fix in the UI pass:**
1. `clovara-life/public/favicon.svg` — circle-built approximation. Regenerate from canonical (update `scripts/make-icons.mjs` to source the canonical SVG, re-run for favicon, apple-touch-icon, og.png).
2. `clovara-life/public/partners/walkthrough.html` — inline `#cloverMark` defs (rounded-rect approximation). Replace all `<use href="#cloverMark">` instances with the canonical file (copy it into `public/partners/` as the existing `mark.svg` — verify that file is the canonical one, then dedupe).
3. Audit any other inline clover paths in `src/` and `public/` — replace with the canonical asset import.

**Usage rules:** clear space = ½ mark width; minimum render 20px (below that, omit); wordmark = "Clovara" in Playfair Display Bold, ink, letter-spacing −0.02em, mark at cap-height × 1.25, gap 10–14px; on photography use a white rounded tile (28px radius, 20px padding). Never: flat recolor, redraw, stretch, effects, gradient-mark on accent orange. Watermark exception: 12° rotation at 14% opacity on forest surfaces only.

## 2. Color tokens (canonical names → tailwind)

Update `tailwind.config.js` to exactly this set (renames noted):

| Token | Hex | Use |
|---|---|---|
| cream | #F6F3EB | page ground (body background everywhere) |
| cream-2 | #EFEBE0 | hover-on-ground, inset wells (NEW) |
| card | #FFFFFF | card surfaces (NEW) |
| line | #E5E1D5 | borders, dividers — **unifies the #E6E1D6 variant; change it** |
| ink | #1B1E1B | primary text, dark buttons |
| ink-2 | #5C635C | secondary text — **replaces `muted` #6B716C; migrate usages** |
| ink-3 | #8A918A | captions, placeholders (NEW) |
| forest | #1A5C38 | primary actions, links, data marks, focus rings |
| deep | #0F3D26 | hero/manifesto bands, text-on-sage |
| sage | #E4EAE0 | positive chips, soft fills, icon wells |
| sage-2 | #D5DFD0 | borders on sage, inactive timeline dots (NEW) |
| accent | #D98A26 | attention only: eyebrows, nudges, watch-states |
| amber | #B27117 | accent-toned *text* (contrast-safe on cream) (NEW) |
| nudge-fill | #FBF4E7 | "worth watching" card fill, with 3px accent left border (NEW) |
| track | #EDEAE0 | ring/chart tracks and grids (NEW) |

Gradient (`bg-clover`, keep): `linear-gradient(140deg,#D98A26 0%,#8FA83E 48%,#1E7A46 100%)` — brand moments ONLY (mark, score ring, life-arc). Never buttons, chrome, text, or data series.

Dark theme (reserved, not shipped — do not build until instructed): bg #101812 · card #1A241C · ink #F0EEE4 · ink-2 #B9C1B6 · ink-3 #84907F · forest #7FB894 · deep/text #CFE3D4 · sage #243328 · line #2C3A2F · accent #E0A050.

## 3. Typography

Faces: **Playfair Display** (display/emotion) + **Poppins** (UI/body). No third face; no system-font fallthrough in shipped UI (declare full stacks).

| Role | Spec |
|---|---|
| display-xl | Playfair 600, 40–62px, line-height 1.1, `text-wrap: balance` |
| display | Playfair 600, 26–38px |
| stat | Playfair 700, 24–38px, `tabular-nums` (all prices/scores/counts) |
| title | Poppins 600, 13–16px |
| body | Poppins **300**, 12.5–14.5px, line-height 1.7–1.9, ink-2 (bold spans = 600 ink) |
| eyebrow | Poppins 600, 10–11px, uppercase, letter-spacing .14–.22em, accent or ink-3 |
| caption | Poppins 400, 9.5–11px, ink-3 |

Body copy width ≤ ~65ch. Inputs ≥16px font on mobile (iOS zoom rule — already in index.css, keep).

## 4. Shape, depth, spacing, motion

- Radii: card **22px** · inner card **18px** · wells/inputs **12px** · everything tappable **999px** (pills). (Tailwind `card`/`soft` already match; add `inner: 12px`.)
- Shadows: keep tailwind `soft` (resting cards) and `lift` (modals, phone frames). Borders: 1px `line` on every card.
- Spacing: 4px grid; card padding 14–24px; section rhythm 46–72px; sibling gaps via flex/grid `gap`, never stacked margins.
- Motion: 150ms hover, 300ms transitions, ease; one orchestrated moment per screen (e.g. the projection range animating when an answer lands); always honor `prefers-reduced-motion`.
- Focus: 2.5px forest outline, 2px offset, on every interactive element.

## 5. Components (canonical patterns — match styleguide.html rendering)

- **Buttons:** pills only, verb labels ("Protect Max", never "Submit"). Primary = forest/white. Commitment/payment = ink-dark. Secondary = ghost (1.5px line border). ONE primary per screen. Never gradient or accent-orange buttons.
- **Chips:** sage/deep = good-active · #F6E8D2/amber = attention · line-border/ink-2 = neutral tag · dashed-accent/amber = speculative ("blue sky") · forest/white = built/done. Status = word-or-icon + color, never color alone. Red reserved for destructive confirmation only.
- **Nudge card:** nudge-fill bg, 3px accent left border, radius 12, amber eyebrow, calm copy ("worth a look, not an emergency"). Max one visible at a time.
- **Plan card ("precious object"):** forest bg, white text, canonical mark watermark (14%, 12°, brightened), Playfair stat. Reserved for the pet's plan, coverage, points.
- **Score ring:** track #EDEAE0, 8–9px stroke, round caps, gradient stroke (permitted moment), Playfair number. Micro-label ("Clovara Score") stacked on TWO centered lines inside the ring, 7–8px, letter-spacing .1em, max-width ≈ inner diameter − 10px — a single line clips against the stroke at any ring size. Same fix applies to the walkthrough mockup's ring (drift-list item).
- **Silhouette picker (input pattern):** tap-not-type; options as wells (cream bg, 2px line border, radius 12); selected = sage bg + 2px forest border + forest glyph. "I don't know" always offered.
- **Icons:** outline, 1.7px stroke (2.1px active), round caps/joins, 20–24px grid. No filled sets. Emoji never as UI icons (allowed only as content-image placeholders until real imagery lands).
- **Data viz:** data = forest; attention series = accent; grid/track #EDEAE0; never gradient or rainbow; ranges as bands with emphasized endpoints; evidence badges (strong/associational/directional) accompany any health-claim visual.

### 5b. Companion conversation kit (build these components in the UI pass; scripted engine fills them now, LLM later)

**Architecture rule — this is what guarantees the premium containers:** the companion NEVER renders free text/markdown. Every reply is a typed array of blocks; the renderer maps block → component; an unknown block type degrades to plain `text`. Compliance is enforced by the component set itself: no diagnosis component exists, medical content can only appear as `history_ref` or `watch_signs` with routing actions. Schema:

```
type CompanionBlock =
  | { kind:'text';           md: string }                      // inline bold only, no headings/lists
  | { kind:'history_ref';    lead: string; note: string; date: string }   // "From Max's history"
  | { kind:'watch_signs';    intro: string; signs: string[]; urgency:'monitor'|'soon'|'now' }
  | { kind:'actions';        items: {label:string; style:'primary'|'ghost'; action:string}[] }  // max 3
  | { kind:'booking_confirm';vet: string; when: string; prepared: string }
  | { kind:'product_ref';    productId: string; why: string }
  | { kind:'escalate';       reason: string }                  // urgent-vet routing card
```

Component specs (all visible in the walkthrough mockup's Care screen — that rendering is canonical):

| Block | Spec |
|---|---|
| **Bubbles** | user: forest bg, white text, right-aligned, radius 18/18/6/18; ai: card bg, 1px line border, left-aligned, radius 18/18/18/6; max-width 82%; 12.5px, line-height 1.5 |
| **history_ref** | sage inset inside the ai bubble: radius 10, padding 8–10px, deep text 11px, 13px outline clock icon (1.7–2px stroke, deep), bold lead ("From Max's history:"), then note + date. The memory moment — never plain text |
| **watch_signs** | ai-bubble list, each sign with a small forest dot; urgency drives the closing line ("not an emergency, but soon"), calm voice per §6; `now` urgency auto-appends an `escalate` block |
| **actions** | pill row under the ai bubble, left-aligned, max 3: one primary (forest, small) + ghosts. Labels are verbs ("Book telehealth vet"). Tapping renders the user's choice as a user bubble |
| **booking_confirm** | ai bubble with bold vet + time and the "prepared" line ("I've prepared a one-page summary of his hip notes…"). Optional single paw emoji allowed here only |
| **product_ref** | mini product card (§5 product pattern) inline: image well, title, plain-words `why`, member price. Never more than one per reply |
| **escalate** | nudge-pattern card (accent border, nudge-fill) with ER routing action + poison-line style tap-to-call. Alarm-free copy; amber not red |
| **Screen chrome (not model output — cannot be omitted):** | header "Knows Max since 2020"; footer note 9.5px ink-3 centered: "Companion shares information and routes you to licensed vets — it doesn't diagnose. Your conversations here are never used in underwriting or claims."; typebar: card pill, ghost placeholder ("Ask about Max…"), 32px forest send disc |

**Motion:** blocks stream in sequentially (120ms stagger, 300ms ease rise); typing indicator = three sage dots in an ai bubble; respect reduced-motion (render instantly).

## 6. Voice (rendering of positioning rules — full set in docs/VISION.md)

Say: "more good years," "on track for," ranges, the pet's name in every system message, plain-words "why" on recommendations, honesty about mixed evidence. Never: "lifecycle"/"platform"/standalone "wellness" in customer copy, lifespan promises, diagnosis phrasing, alarm framing, treatment claims, premium-linked reward language.

## 7. The ten rules

1. One mark file — everything derives from `clovara_mark_refined.svg`.
2. Gradient = brand moments only.
3. Accent orange is attention, spent sparingly.
4. Playfair for feeling, Poppins for function — no third face.
5. Cream ground, white cards, line borders, soft shadows — depth is quiet.
6. Pills for everything tappable; one forest primary per screen.
7. The pet's name appears wherever the system speaks.
8. Honesty is visual — evidence badges and "illustrative/simulated" labels are design elements, not hidden disclaimers.
9. Calm always — amber before red, questions before alarms, ranges before points.
10. When in doubt, remove one thing.

## 8. UI-pass checklist (ordered)

1. Tailwind token reconciliation (§2) — rename `muted`→`ink-2`, unify `line`, add new tokens; sweep usages.
2. Logo drift fixes (§1) — favicon/app-icon regeneration from canonical; partner-hub inline SVG replacement.
3. Component sweep against §5 — buttons, chips, focus states, radii to spec.
4. Type sweep against §3 — weights (body 300), tabular-nums on all numerals, eyebrow tracking.
5. Screenshot every surface at 390px and 1280px (shots scripts exist); compare against styleguide.html; fix collisions/overflow.
6. Log completion in ROADMAP; any deviation from this doc that survives review becomes a DECISIONS entry.
