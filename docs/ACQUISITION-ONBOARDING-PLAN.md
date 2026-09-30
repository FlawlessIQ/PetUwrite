# Acquisition and onboarding plan

Written 2026-09-30 by Claude Code at Conor's request. **A proposal, not a decision**
— §4 lists the calls that are Conor's, and nothing in §5 should be built until the
ones it depends on are made. Backlog ids **AO1–AO12** are added to `BACKLOG.md`.

## 1. In one paragraph

The product was built from the plan reveal inwards. A stranger who finds it today
lands on somebody else's dog, can build their own dog's plan in under a minute, and
then keeps it only in that browser, is never asked to save it, cannot pay, cannot buy
cover, and never hears from Clovara again. The engines, the reveal and the safety
screens are strong — two UAT runs confirm it. What is missing is everything either
side of them: **a front door, a moment that asks you to keep what you made, a reason
to come back, and a way to measure any of it.** Most of that can be built now; the
parts that take money or send email wait on Conor, counsel and a Stripe account.

## 2. What a stranger can do today

Verified against the live code and UAT runs 1–2 (2026-09-26).

| Stage | Today | Gap |
|---|---|---|
| **Arrive** | clovara-life.web.app opens on **"Max's day" — the investor demo**. The marketing site (`main` target) is separate and unaligned (Q17). No search presence, no landing page for Life. | Nothing tells a visitor what this is, or that Max is an example. |
| **Understand** | The demo *is* the explanation. | Works for an investor being walked through it; not for somebody alone on a phone. |
| **Reveal** | Five questions, no account, under a minute: healthy-years range, stages, First Nights, the arrival certificate. On a phone "Add a pet" is inside the pet switcher menu. | The primary action is one menu deep on the device most people use. |
| **Save** | The pet is stored **only in that browser**. Nothing says so. Sign-in (email link or Google) is the last item in the switcher menu; signing in imports the pet into an account. | **The biggest leak.** No prompt, no warning; clearing the browser or switching to a phone loses the dog. |
| **Trial** | "Start 7-day free trial" appears only on the Rewards and Shop gates. Checkout is Stripe **test mode** on the FlawlessIQ sandbox. | Offered away from the moment of value, and no real card can be charged (A3). |
| **Come back** | Nothing reaches the owner. The Life email skeleton (welcome, trial-ending) exists and is tested but **sends nothing** — no provider, no key. The morning briefing email is built and off (X4). No push, no app. | Every habit the product is built on — vaccination windows, the passport's closing weeks, the annual review, Gotcha Day — works only if the owner happens to open the app that day. |
| **Protect** | A real price and every disclosure; "cover cannot be bought yet". | No carrier (B4). |
| **Share** | Arrival and Gotcha Day cards share **as an image only — no link**. | The one organic loop we have ends at the picture: a friend who sees Bruno's card has no way to find Clovara. |
| **Measure** | `reveal_viewed`, `pet_created`, `trial_started`, `week4_active` exist. `signed_up` fires only when an **email link is requested** — a Google sign-in is not counted. No first-touch attribution (no referrer or campaign capture). | The funnel cannot be read end to end, and nothing says where anyone came from. |

**A spec divergence nobody recorded.** SPEC §1: *"trial-only (no free tier) with one
exception: the first Plan reveal is visible pre-trial; saving/continuing starts the
trial."* Today a signed-out visitor gets the whole product, free, indefinitely — Home,
Care, the Health File, the safety screens. That is defensible while nothing can be
charged, but it was never decided. It is now in ROADMAP → Spec divergences, and is
decision **AO-D2** below.

## 3. The funnel we want

Each stage has one event, so the dashboard can read it. **Bold** = missing today.

1. **Arrive** — a first visit, and where it came from → **`first_visit` with first-touch source** (referrer and `utm_*`, stored on the device and attached to later events — no third-party pixels)
2. **Start** — "Add your dog" tapped → **`onboarding_started`**
3. **Reveal** — the plan appears → `reveal_viewed`
4. **Save** — the pet is kept in an account → **`save_prompt_viewed`**, `signed_up` (**fixed to count Google too**), `pets_imported`
5. **Trial** — `trial_started` (server-side, from Stripe)
6. **Habit** — the owner comes back unprompted and prompted → **`return_visit` by day 1 / 7 / 28**, `week4_active`
7. **Paid** — trial converts → **`trial_converted`**, `subscription_cancelled`
8. **Protect** — `attach_offer_viewed`, `attach_bound` (when B4 exists)
9. **Share** — `share_card` → **`shared_link_opened`** → a new first visit

Targets are deliberately not set here: they depend on who the first cohort is (P3),
and a number invented before that would be steered towards.

## 4. Decisions that are Conor's

| id | Decision | Options | Recommendation |
|---|---|---|---|
| **AO-D1** | **Who is the first cohort, and where do they come from?** (This is P3.) | New puppy/kitten owners · owners of an older or unwell pet · a breed community · a partner (shelter, breeder, vet) | **New-puppy owners through one partner.** The product is strongest in the first 16 weeks — First Nights, the passport's closing window, vaccinations, the arrival certificate — and a partner hands over people at exactly the moment they need it. |
| **AO-D2** | **The trial rule** (SPEC §1 vs today). | (a) enforce SPEC now — after the reveal, continuing needs an account and a trial · (b) a permanent free tier, with the trial for member depth · (c) free until money can be taken, then enforce SPEC behind a config flag | **(c).** Gating a trial nobody can pay for only blocks people. Build the save moment now; switch the gate on with A3. Record it in DECISIONS either way. |
| **AO-D3** | **Where the investor demo lives.** | Keep it as the default page · move it to its own link and give strangers a front door | **Move it.** Investors get a link (`/#/demo` or the existing `#/pet/demo-max/home`, which keeps working); everyone else meets their own dog first. The demo pets must keep working — nothing about them changes. |
| **AO-D4** | **Sign-ups before payment exists.** | Let people create accounts now · a waitlist only · both | **Accounts now, and the account is the waitlist.** Saving a dog already needs an account; "we will tell you when membership opens" needs one email, not a new list. No separate collection, no rules change. |
| **AO-D5** | **Email.** | Stay off · transactional only (welcome, saved, trial-ending) · plus a moment-based series by explicit opt-in | **Transactional now, series by opt-in.** Needs a sending domain and a provider key (Conor). The daily briefing stays off (X4: a daily email is a different consent). |
| **AO-D6** | **The marketing site (`main`, Q17).** | Align it now · leave it and let Life's front door stand alone | **Leave `main` untouched for now** and give Life its own front door. Linking from `main` is a one-line change on a site this repo does not deploy without being asked. |
| **AO-D7** | **The front-door line.** | Uses the decided language: *"More good years, together"* / *"your pet's plan for life"* | Conor's words. The page is built around a headline slot, not a written headline. |

## 5. What to build, in order

### Phase A — the front door and the save moment
*No external dependency. Needs AO-D3 and AO-D7; AO-D2 decides whether A2 also offers the trial.*

- **AO1 · A front door for a first visit.** One screen before anything else, shown once: what this is in a sentence, **"Add your dog"** as the only primary action, and "See an example" into the demo. Returning visitors and every existing link (`#/pet/…`, `#/health/…`, `#/wrong`, `#/ate`, the investor links) bypass it. Honest by construction: no pet shown as if it were theirs.
- **AO2 · The save moment.** After the reveal, and again after the first thing that makes the plan worth keeping (an answer, a stamp, a recorded vaccination): *"Keep Bruno's plan — it's only on this device until you do."* One tap into sign-in; the import already exists. Never a modal over the reveal; dismissable; asked at most twice.
- **AO3 · Sign-in where a phone user can find it.** On a phone, "Add a pet" and "Sign in" are the last items in the switcher menu. Put the account entry in the header on every width.
- **AO4 · Measure it.** `first_visit` with first-touch source, `onboarding_started`, `save_prompt_viewed`, `signed_up` for **Google as well as email link**, `return_visit`, `trial_converted`. First-party only — the Data Covenant rules out ad pixels on pet data. The metrics dashboard gains the funnel in §3.

### Phase B — a reason to come back
*Needs AO-D5, a sending domain and a provider key (Conor).*

- **AO5 · Transactional email live.** Welcome and trial-ending exist as tested templates; add "your plan is saved" and "membership is open". Unsubscribe and a postal footer (counsel, A2).
- **AO6 · Moment-based emails, opt-in.** Built from engines that already know when something is due — never a newsletter: First Nights for a puppy's first 72 hours, a vaccination window opening, "two weeks of the easy part left", the annual review due, Gotcha Day. The Remember pass applies: a remembered pet gets nothing (MUST_GO_QUIET gains `email`).

### Phase C — the trial where the value is
*Needs A3 (a Clovara-entity Stripe account) and A2 (counsel on CA/NY auto-renewal).*

- **AO7 · Offer the trial at the save moment and after the first useful answer**, not only behind Rewards and Shop.
- **AO8 · Enforce SPEC's trial rule behind a config flag** (AO-D2), switched on only when real money can be taken.

### Phase D — growth loops
*After the first cohort (AO-D1) has produced data.*

- **AO9 · A link on every shared card.** Today the card is an image with no way back. Share the image *with* a link to a page that says what the card is — "Bruno's plan begins today" — and offers "make one for your dog". The page shows the card the sharer chose to share and nothing else from the record.
- **AO10 · Partner intake.** A partner link (shelter, breeder, vet) that opens onboarding pre-filled with what the partner knows — species, breed, birthday, a vaccination record — confirmed by the owner (invariant 8), and attributed to the partner. The Ethical Start Network moment, made small.
- **AO11 · Referral — counsel first.** Rewards for referrals touch insurance-inducement rules in many states, and points can never touch the premium (invariant 1). Only products, care services or giving-back, and only after counsel.
- **AO12 · Record the trial-rule divergence** — done with this plan (ROADMAP → Spec divergences).

## 6. What we will not do

- **No third-party tracking pixels or retargeting.** The Data Covenant promises pet data is never used to sell to people; an ad pixel on a page about a dog's health is that promise broken quietly.
- **No trial that is hard to leave.** Price stated before the card, cancelling through Stripe's own portal (it exists), and the trial-ending email three days out (the template exists; sending waits on AO5).
- **No manufactured urgency.** The only deadlines shown are real ones the engines know — the socialisation window closes when it closes.
- **No referral reward against the premium**, and none at all before counsel.
- **Nothing breaks the demo.** Max, Winston and Luna keep working at their current links.

## 7. Sequence and who

| Order | Item | Blocked by | Who |
|---|---|---|---|
| 1 | AO-D1, AO-D3, AO-D7 | — | **Conor** |
| 2 | AO1 front door · AO2 save moment · AO3 sign-in · AO4 measurement | AO-D3, AO-D7 | Claude Code |
| 3 | AO-D2, AO-D4, AO-D5 | — | **Conor** |
| 4 | AO5 transactional email · AO6 opt-in moments | AO-D5, sending domain + key | Conor → Claude Code |
| 5 | AO7 trial placement · AO8 trial rule | A3 Stripe entity, A2 counsel | Conor → Claude Code |
| 6 | AO9 share links · AO10 partner intake | AO-D1 | Claude Code (+ a partner for AO10) |
| 7 | AO11 referral | A2 counsel | Conor + counsel |

Phase A is size **M** (days) and needs only three answers. It is the part worth
doing before the UAT's Track B: that track tests signing in, and today nothing leads
anyone there.
