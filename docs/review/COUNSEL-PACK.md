# The counsel pack

*Generated from the code by `npm run review:packs` — do not edit by hand. `verify:all` fails if this file no longer matches what the app says, so what you sign off is what ships.*

Everything in Clovara Life that counsel should read before a real person pays or signs up
(BACKLOG **A2**). Exact words, where they appear, and a Verdict line. **Placeholders marked
`LEGAL-REVIEW` are deliberately not drafted by us** — they are yours to supply.

Start with section 1: the things that do not exist yet.

## 1. What is missing entirely

### C1 · Terms of service

> There are none. Nothing in Life links to terms, and signing up does not ask anyone to accept any.

- **Where:** Nowhere — a gap
- Needed before anyone pays; probably before sign-up
- **Verdict:** keep · change (write the change) · discuss

### C2 · Privacy policy

> There is none. The Data Covenant (section 3) makes promises; there is no policy document behind it.

- **Where:** Nowhere — a gap
- **Verdict:** keep · change (write the change) · discuss

### C3 · Auto-renewal disclosure (CA/NY)

> After your 7-day free trial, this membership renews automatically at $22.99 per month until you cancel. You can cancel any time from your account; cancelling stops the next charge and you keep access to the end of the period you have paid for. This is the Clovara membership fee only. It is not insurance and it is not a premium.

- **Where:** Stripe Checkout, before the card
- Currently a marked placeholder; the final wording is yours
- **Verdict:** keep · change (write the change) · discuss

### C4 · The postal address in commercial email

> [LEGAL-REVIEW: postal address, required in every commercial email — counsel to supply]

- **Where:** Foot of every reminder email
- Email cannot be switched on without it
- **Verdict:** keep · change (write the change) · discuss

## 2. Buying cover — the Protect flow

### C5 · The price label

> Illustrative — rates are not yet filed. This is an estimate, not an offer.

- **Where:** Protect, step 1
- **Verdict:** keep · change (write the change) · discuss

### C6 · Before the declaration

> Cover cannot be bought yet — binding waits on the carrier programme. The button below will not buy anything or take any money; it is here so you can see the whole flow.

- **Where:** Protect, step 2
- Added after UAT run 1 (D12): says nothing can be bought before anyone ticks anything
- **Verdict:** keep · change (write the change) · discuss

### C7 · Waiting period — Accidents (3 days)

> Short, because an accident is not something anyone saw coming.

- **Where:** Protect, step 2
- **Verdict:** keep · change (write the change) · discuss

### C8 · Waiting period — Illness (14 days)

> Long enough that a policy cannot be bought for something already brewing, which is what keeps it affordable for everyone else.

- **Where:** Protect, step 2
- **Verdict:** keep · change (write the change) · discuss

### C9 · Waiting period — Cruciate and other orthopaedic conditions (180 days)

> The longest one, and the one worth knowing about before you need it. Joint problems develop slowly and are the most commonly claimed-for thing in large dogs.

- **Where:** Protect, step 2
- **Verdict:** keep · change (write the change) · discuss

### C10 · Anything already there is not covered

> A condition that showed signs before your policy started, or during a waiting period, is not covered — whether or not it had been diagnosed. This is the single most common reason a claim is declined, and it is why the page before this one lists what we already know about.

- **Where:** Protect, step 2 — scroll-to-enable
- **Verdict:** keep · change (write the change) · discuss

### C11 · This price is illustrative

> Rates have not been filed with your state regulator yet. The figure shown is our best current estimate of what the filed rate will be, and the price you are actually offered may differ.

- **Where:** Protect, step 2 — scroll-to-enable
- **Verdict:** keep · change (write the change) · discuss

### C12 · Insurance is separate from membership

> Your Clovara membership and your insurance premium are two different things, billed as two different lines. Cancelling one does not cancel the other, and membership points never reduce a premium.

- **Where:** Protect, step 2 — scroll-to-enable
- **Verdict:** keep · change (write the change) · discuss

### C13 · It renews, and the price can change

> The policy renews annually. The premium at renewal reflects your pet getting older, claims experience, and any change to our filed rates — never anything measured by a tracker or said to the companion.

- **Where:** Protect, step 2 — scroll-to-enable
- **Verdict:** keep · change (write the change) · discuss

### C14 · You can cancel

> Cancel at any time. Depending on your state you may be entitled to a refund of unearned premium; the policy documents set out how that is calculated.

- **Where:** Protect, step 2 — scroll-to-enable
- **Verdict:** keep · change (write the change) · discuss

### C15 · Fraud notice

> Any person who knowingly and with intent to defraud an insurer files a claim or application containing materially false information, or conceals information concerning any material fact, commits a fraudulent insurance act, which is a crime and may subject that person to criminal and civil penalties. State-specific wording will replace this notice once filings are complete.

- **Where:** Protect, step 2
- **Verdict:** keep · change (write the change) · discuss

### C16 · The declaration

> Everything I have told Clovara about my pet is accurate as far as I know, and I have read what is and is not covered.

- **Where:** Protect, step 2 — the checkbox
- **Verdict:** keep · change (write the change) · discuss

### C17 · Membership and insurance are separate

> Membership only. Any insurance you choose later is a separate product, billed separately, and shown as its own line.

- **Where:** Checkout
- **Verdict:** keep · change (write the change) · discuss

## 3. The Data Covenant

### C18 · The whole page, as it renders

> The Data Covenant
> 
> Clovara knows things about your pet that could be used against you. This page is our promise about what we will never do with them, written before we had any reason to need it.
> 
> What we hold
> 
> What you have told us: the breed, the birthday, the weight, anything already diagnosed, how the days go. What a tracker sends, if you ever wear one on them. What you and the companion have talked about.
> 
> That is a real picture of an animal, and it is the reason the plan is any good. It is also, in the wrong hands, a list of reasons to charge someone more.
> 
> What it is never used for
> 
> These are the ones that matter, so they are first and they are plain.
> 
> Nothing you tell the companion is used to decide a claim. Not to question one, not to delay one, not to deny one.
> 
> Nothing a tracker records is used to decide a claim either. A quiet week is not evidence of anything.
> 
> Your data does not change your premium. Not up, and not down as a reward for behaving — which is the same promise, and it is the one that keeps the first two honest.
> 
> We do not sell it. Not to brokers, not to advertisers, not to anyone building a model to price people.
> 
> The companion is firewalled
> 
> It helps you notice things and tells you when to call a vet. It does not diagnose, it does not prescribe, and it is not a route into underwriting or claims — the people and systems that decide those never see the conversation.
> 
> That separation is deliberate. A companion you are careful in front of is useless, and one you are honest with only works if honesty is free.
> 
> What it does get used for
> 
> Your pet, first. Everything here exists to make their plan sharper and their care easier.
> 
> And, in aggregate, the science. Pooled across thousands of animals with nothing identifying in it, this data can answer questions the published literature currently cannot — which is how a breed moves from an illustrative figure to a real one. Nothing in that work traces back to a name, an address, or a policy.
> 
> The one exception, stated plainly
> 
> A rated programme — where a tracker genuinely earns someone a different price — is a thing insurers do, and one day we may offer it. If we ever do, it will be a separate product you choose on purpose: filed with the regulator, priced transparently, explained before you opt in, and leavable.
> 
> It will never be this. Joining Clovara does not enrol you in it, and no data you have already given us would be used to price you under it without you saying yes first.
> 
> What you can do about it
> 
> Ask us for everything we hold on your pet and we will send it in a form you can actually read. Ask us to delete it and we will, including from the aggregate work where it has not already been anonymised beyond recovery.
> 
> You do not have to give a reason, and asking does not affect your membership or any policy.
> 
> If this ever changes
> 
> A promise you can quietly edit is not a promise. If we change anything on this page we will say so directly — not in a version note — and the old wording will stay readable beside the new one.

- **Where:** #/covenant — linked from the footer, onboarding and settings
- **If UB12 ships** ("Download everything about your pet"), the Covenant's "ask us for everything" could say it is self-serve — not changed until you have seen it
- **Verdict:** keep · change (write the change) · discuss

## 4. Money and membership lines

### C19 · Shop — membership

> $28$22 for members

- **Where:** Shop
- Reworded in UAT run 1 (D14) from "the products that keep Bruno healthy"
- **Verdict:** keep · change (write the change) · discuss

### C20 · Shop — membership

> $22$17 for members

- **Where:** Shop
- Reworded in UAT run 1 (D14) from "the products that keep Bruno healthy"
- **Verdict:** keep · change (write the change) · discuss

### C21 · Shop — membership

> $45$36 for members

- **Where:** Shop
- Reworded in UAT run 1 (D14) from "the products that keep Bruno healthy"
- **Verdict:** keep · change (write the change) · discuss

### C22 · Shop — membership

> $89$72 for members

- **Where:** Shop
- Reworded in UAT run 1 (D14) from "the products that keep Bruno healthy"
- **Verdict:** keep · change (write the change) · discuss

### C23 · Shop — membership

> $45$36 for members

- **Where:** Shop
- Reworded in UAT run 1 (D14) from "the products that keep Bruno healthy"
- **Verdict:** keep · change (write the change) · discuss

### C24 · Shop — membership

> You're seeing list prices. Members pay less on every order and earn points back on the products picked for Bruno.

- **Where:** Shop
- Reworded in UAT run 1 (D14) from "the products that keep Bruno healthy"
- **Verdict:** keep · change (write the change) · discuss

### C25 · Shop — membership

> Total Care members save on every order and earn points back on the products picked for Bruno. Membership is priced separately from insurance.

- **Where:** Shop
- Reworded in UAT run 1 (D14) from "the products that keep Bruno healthy"
- **Verdict:** keep · change (write the change) · discuss

### C26 · Coverage — standing disclaimer

> Illustrative pricing shown to demonstrate how rate varies with species, size, age and breed. Not a quote and not a filed rate.

- **Where:** Coverage
- **Verdict:** keep · change (write the change) · discuss

### C27 · Rewards — standing disclaimer

> Points redeem toward products and care services only, never toward your premium. Streak data in this preview is simulated.

- **Where:** Rewards
- **Verdict:** keep · change (write the change) · discuss

## 5. Claims the product makes to a new visitor

### C28 · The front door

> More good years, together
> Your pet’s plan for life
> Tell us five things about your dog or cat and see the healthy years ahead of them, the stages they will go through, and what matters most for their breed. It takes about a minute, and you do not need an account.
> The example is Max, a demonstration Labrador — not anyone’s real dog.

- **Where:** First visit to the site
- **Verdict:** keep · change (write the change) · discuss

### C29 · Keep the plan

> Bruno’s plan lives only in this browser until you save it. Saved, it’s on your phone too. No card needed.

- **Where:** After the plan reveal, and Home
- **Verdict:** keep · change (write the change) · discuss

## 6. Email

### C30 · Every email, rendered

> See EMAIL-PREVIEW.md in this folder — welcome, trial ending, plan saved, and one of each reminder.

- **Where:** docs/review/EMAIL-PREVIEW.md
- **Verdict:** keep · change (write the change) · discuss

### C31 · Reminder opt-in (not yet shown to anyone)

> Email me when something is due — Vaccination windows, the socialisation window, the yearly check and Gotcha Day. Never more than three a day, one tap to stop, and off unless you turn it on.

- **Where:** Account panel, once email is switched on
- **Verdict:** keep · change (write the change) · discuss

### C32 · Unsubscribe page — Turn off reminders

> Turn off reminders?
> You will stop getting emails about vaccinations, the socialisation window, the yearly check and Gotcha Day. Nothing else changes.
> Turn off reminders

- **Where:** The link at the foot of every reminder
- **Verdict:** keep · change (write the change) · discuss

### C33 · Unsubscribe page — Reminders off

> Reminders are off
> You will not get these emails any more. Everything in your pets’ plans is still there, and you can turn reminders back on from your account.

- **Where:** The link at the foot of every reminder
- **Verdict:** keep · change (write the change) · discuss

### C34 · Unsubscribe page — Link not recognised

> We do not recognise that link
> It may be from an old email. You can change reminders from your account in Clovara Life.

- **Where:** The link at the foot of every reminder
- **Verdict:** keep · change (write the change) · discuss

## 7. What data goes where — our description, for you to check against the Covenant

### C35 · Analytics

> Event names and simple values (never a pet name, email or free text), a random id per browser, and — on a first visit — the referring site's host (never the full address) and any utm tags. Stored on the device, sent to our database only once someone signs in. No third-party pixels or trackers.

- **Where:** Everywhere
- If AO13 ships, anonymous visits would also reach our database, with the same fields and no account
- **Verdict:** keep · change (write the change) · discuss

### C36 · A shared card's link

> Carries only what is printed on the card — the pet's name, breed, age, the date and which card. Never the photo (which stays on the sharer's phone), an id or anything else from the record. Nothing is uploaded.

- **Where:** Arrival and Gotcha Day cards
- **Verdict:** keep · change (write the change) · discuss

### C37 · The calendar file

> Made on the device and handed to the browser as a download. Nothing is sent to us or anyone else.

- **Where:** Health File → Reminders
- **Verdict:** keep · change (write the change) · discuss

### C38 · Owner-written text and Google

> Switched off. Vet-record reading and conversational onboarding would send owner-written text to Google; that is decision B2, with a memo (docs/MODEL-DATA-DECISION.md).

- **Where:** Not live
- **Verdict:** keep · change (write the change) · discuss
