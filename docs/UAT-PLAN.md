# UAT — Bruno's life

**Written 2026-09-25. Dry-run against https://clovara-life.web.app the same day.**
Quoted lines in "Expected" are what the live app actually showed during that
dry-run, not what the code is meant to do; where the two differ, it is listed
under "Known defects going in". Every console snippet was run exactly as written.

Not clicked through in the dry-run, and expected from the product's own test
suites instead: A1.8, A3.3–A3.4, A5.4–A5.6 and all of Track B. Treat a surprise
there as a finding, not as a mistake in this plan.

---

## 1. What this is

A user-acceptance test of Clovara Life, run in Chrome, following one dog —
**Bruno, a male Labrador Retriever** — from the day he comes home to the day he
dies, with the worries, decisions and people that happen in between.

It is not a regression suite (`npm run verify:all` is that). It asks two things
the suites cannot:

1. **Does it work for a person?** Can someone who has never seen the app do each
   thing without being told how?
2. **Does it feel right?** Tone, weight and timing — especially on the screens
   where being wrong costs most: the collapse screen, the poison screen, and the
   day he dies. Each chapter has a **Judge** line for exactly this. Record a
   reaction, not just a tick.

### Three tracks

| Track | What | Account | Who can drive it |
|---|---|---|---|
| **A — Bruno's life** | Nine chapters, puppy to goodbye | Signed out | A person, or Claude in Chrome |
| **B — Bruno's family** | Accounts, membership, family, sitter, photos, the lump diary | Signed in, two accounts | A person — sign-in and payment steps cannot be done by an agent |
| **C — Everywhere** | Phone and desktop, keyboard, reduced motion, deep links, the investor demo | Either | Either |

Allow about **2½ hours**: A ≈ 90 min, B ≈ 45 min, C ≈ 20 min.

---

## 2. Before you start

### Environment

- **Chrome**, latest. Test every Track A chapter twice: once in **device mode**
  (DevTools → device toolbar → *iPhone 14 Pro*, 393 × 852) and once at **desktop**
  width. Most people will use this on a phone.
- **Site:** https://clovara-life.web.app — the live site. Payments are Stripe
  **test mode**; nothing is charged.
- **Track B** needs two email addresses you can receive mail at, or two Google
  accounts, and a second Chrome profile or an Incognito window for the second
  person.

### How time works — read this

The app reads the real clock, and **a dog's birthday cannot be changed after he is
added.** A tester cannot age Bruno by waiting. So Track A walks his life as
**chapters**: chapter 1 is real onboarding, and every later chapter recreates him
at a later age using a snippet in Chrome's DevTools console. That is the same
technique the automated suites use, and it only touches this browser's local
storage.

**Set up once per session.** Sign out if you are signed in, open DevTools
(⌥⌘J on a Mac, Ctrl+Shift+J on Windows), and paste:

```js
window.uatSeed = (ageDays, homeDays, extra = {}) => {
  const ago = (d) => new Date(Date.now() - d * 864e5).toISOString()
  const bruno = {
    id: 'uat-bruno', name: 'Bruno', species: 'dog', breedId: 'labrador-retriever',
    sex: 'male', weightLb: 70, conditionIds: [],
    birthDate: ago(ageDays).slice(0, 10), knownSince: ago(homeDays), ...extra,
  }
  localStorage.setItem('clovara-life.pets.v1', JSON.stringify([bruno]))
  location.hash = '#/pet/uat-bruno/home'
  location.reload()
}
window.uatReset = () => { localStorage.clear(); location.hash = ''; location.reload() }
```

`uatSeed(age, home)` makes Bruno `age` days old, home for `home` days. Each
chapter gives the exact line to paste. `uatReset()` returns to the investor demo.
Seeding **replaces** any locally saved pets.

### Recording results

For every case, record **Pass / Fail / Blocked**, plus a note. Log every Fail in
§8 with a severity:

| Sev | Meaning |
|---|---|
| **1** | Harm or trust: wrong or missing safety guidance, a diagnosis, data shown to the wrong person, a dead pet being prompted, money taken wrongly |
| **2** | A journey cannot be completed, or the wrong pet's record is shown |
| **3** | Works, but confusing, wrong in tone, or visibly broken |
| **4** | Cosmetic |

---

## 3. Known defects going in

> **2026-09-26:** K1–K4 are fixed and deployed (BACKLOG U1–U3, branch `uat-fixes`); the rows below record what the dry-run found. Steps that cite K1–K4 should now pass. K5 and K6 are unchanged.

Found in the dry-run. **Recommend fixing K1–K3 before running the UAT**, so testers
spend their judgement on things nobody has seen yet.

| # | Where | What | Sev |
|---|---|---|---|
| **K1** | Home, after "Bruno has died" | Still asks **"Bruno's plan: 72% sharp — add neutered or spayed to reach 81%"**, citing *"Neutering is consistently associated with longer life across large datasets"*, with an "Add neutered or spayed" button. The Remember pass promises the questions stop; `verify-remember` checks for "Sharpen" and this says "sharp" | **1** |
| **K2** | Home, after "Bruno has died" | Still shows a **Clovara Score of 76** and **"On track, with room in one or two places"**, under the heading **"Bruno's day"** | **1** |
| **K3** | Home greeting, every user | **"Good afternoon, Conor"** is hard-coded (`Home.tsx:124`), so every member is greeted as Conor, not just the investor demo | **2** |
| **K4** | Life, first nights | **"Bruno has been home about 1 hours"** — pluralisation | **4** |
| **K5** | Home, a new puppy | "5,042 Steps today · CloTag" and "5 · Dental streak · days this month" for a dog added an hour ago with no tracker. A disclosure exists further down ("Activity and sleep figures here are simulated…") but does not cover the streak, and sits well below the numbers. **Judge in A1 whether this reads as measured** | 3 |
| **K6** | Code only | `senior.ts` lists `'mature'` and `'geriatric'` as senior stages; no stage has those ids. Behaviour is right (the senior suite starts at the *senior* stage, ≈9.4 years for a Labrador), the list is misleading. Not user-visible | — |

---

## 4. Track A — Bruno's life (signed out)

Bruno's breed baseline is **11.5–13.5 years**. Life stages for a Labrador: puppy →
young adult → mature adult (from about 3) → **senior from about 9.4 years**.

### A0 · Before Bruno — the front door
*Reset with `uatReset()`.*

| ID | Step | Expected |
|---|---|---|
| A0.1 | Open the site | The investor demo loads on **Max**: "Max's day", "Max is all set", a Clovara Score ring with the label *inside* it on two lines |
| A0.2 | Open the switcher; choose Winston, then Luna | Each pet's own day and plan. The URL changes to that pet |
| A0.3 | Open **The Data Covenant** from the footer | "The Data Covenant" — what is never done with what you tell us |

**Judge:** does the first screen tell you what this product is, before you have added anything?

### A1 · Day one — nine weeks old, just home
*Real onboarding, no snippet. On a phone, "Add a pet" is inside the pet switcher menu.*

| ID | Step | Expected |
|---|---|---|
| A1.1 | Switcher → **Add a pet** → *A dog* → search "Labrador" → **Labrador Retriever** → name **Bruno** → *I know the exact date* → a date **63 days ago** → *Male* → **See Bruno's plan** | Five steps, "Step N of 5"; nothing asks for an account |
| A1.2 | The reveal | Lands on Life: "LABRADOR RETRIEVER · 2 MONTHS OLD · MALE", "**Bruno is on track for** [a range, e.g. 11.2–13.7] **healthy years**" in solid forest (not gradient), "Currently a puppy" |
| A1.3 | Scroll on | **FIRST NIGHTS** — "The first few hours", hour-by-hour advice. *(K4: "about 1 hours")* |
| A1.4 | Find the arrival certificate | A square keepsake card: the canonical clover, "Clovara *Life*", Bruno's name, "Bruno's plan begins today", today's date. Share or save it |
| A1.5 | **Home** | "Bruno's day"; a sharpness meter — "**Bruno's plan: 40% sharp — add body condition to reach 59%**"; the briefing "**Around now is when DHP / DAPP is usually given.**"; "No policy yet" as a neutral (not green) chip. *(K3, K5)* |
| A1.6 | Tap **Add body condition**, choose a silhouette | Chosen option turns sage with a forest border (not solid green); the meter rises |
| A1.7 | Open the **Health File** (#/health/…) | **PASSPORT** — "**6 weeks of the easy part left**"; **VACCINATIONS** with DHP / DAPP due "around now" |
| A1.8 | Stamp three passport firsts; record DHP as given today | Progress updates; the briefing stops saying DHP is due |

**Judge:** 2am, a crying puppy — is First Nights calm and specific enough? Do the step count and streak (K5) look measured?

### A2 · Puppyhood — thirteen weeks
```js
uatSeed(91, 28)
```

| ID | Step | Expected |
|---|---|---|
| A2.1 | Home | No First Nights (he has been home more than 72 hours) |
| A2.2 | Health File → Passport | "**1 week of the easy part left**" — the socialisation window closes at 14 weeks |
| A2.3 | Health File → Vaccinations | Doses he should have had show "**Window passed**" until recorded. Record them |
| A2.4 | Life → the plan | "Puppy vaccination series and exams" — "Finish the vaccination and parasite schedule, and get a full physical exam at each visit." |

**Judge:** does "1 week left" create useful urgency, or guilt?

### A3 · One year home — the first review, and Gotcha Day
```js
uatSeed(430, 366)
```

| ID | Step | Expected |
|---|---|---|
| A3.1 | Life | "**A year with Bruno**" — the annual review is due |
| A3.2 | Life | "**Bruno's Gotcha Day**" — a year since he came home |
| A3.3 | Complete the review | The projection is re-drawn; the review is no longer due |
| A3.4 | Share the Gotcha Day card | The canonical mark; no gradient text |

**Judge:** does the review feel like a ritual or a form?

### A4 · Everyday life — four years old
```js
uatSeed(4 * 365 + 40, 4 * 365 - 23, { lastReviewedAt: new Date(Date.now() - 38 * 864e5).toISOString() })
```

| ID | Step | Expected |
|---|---|---|
| A4.1 | Home | "**Nothing needs doing for Bruno today. Mature adult stage, and nothing on our list has come round.**" — said plainly, not padded |
| A4.2 | Life → change a lever (weight, exercise) | The range moves; "How we work this out" names sources and confidence |
| A4.3 | **Care** → the scripted conversation | It streams in and **waits** at "**Send Bruno's history to your vet**". Tap it → your choice appears as your own bubble → "I have put together a one-page summary for your vet…". There is **no** telehealth booking |
| A4.4 | Care → the footer | "Companion shares information and routes you to licensed vets — it doesn't diagnose. Your conversations here are never used in underwriting or claims." |
| A4.5 | **Coverage**, then **Protect** (#/protect) | Plan card with the brightened clover watermark; every price labelled illustrative; binding says why it cannot happen yet |
| A4.6 | **Shop** | Each product says why it was picked for Bruno; no product claims to treat or prevent anything |
| A4.7 | **Rewards** | Points follow evidence; nothing links points to the premium |
| A4.8 | Health File → **"For the vet"** | A one-page summary; **no** healthy-years projection on it |

**Judge:** is there anything on Home you would not look at twice?

### A5 · A worry
*Continue from A4 — no new snippet.*

| ID | Step | Expected |
|---|---|---|
| A5.1 | **Something's wrong** (#/wrong): type "He seems a bit quiet today and is sleeping more" → **Check it** | "**We have not spotted anything on our urgent list.**" then "That is a statement about our list, not about your pet… If you are worried, ring your practice." **Never** reassurance |
| A5.2 | Replace with "He collapsed in the garden and his gums look pale" → **Check it** | "**Stop and ring a vet now.**" on the **amber** nudge pattern (accent left border, amber headline — not red). Lists the matched signs ("Collapsed, or will not get up", "Pale, white or tacky gums") and tap-to-call numbers |
| A5.3 | **Ate something** (#/ate) → **Grapes, raisins, sultanas or currants** | "**Ring your vet or a poison line now.**", "**Ring now**", "This tells you how urgent it is. It never tells you it is fine." No amounts, no doses |
| A5.4 | Tap a phone number | It dials — or on desktop, offers to |
| A5.5 | Health File → **Second opinion**: type "Vet recommends TPLO surgery, estimate $6,000" | Questions to ask the vet who recommended it; it never second-guesses the recommendation or judges the price |
| A5.6 | Health File → **Meds**: add a medication with a quantity; log today's dose | "Running out" estimate appears; a logged dose shows it was given, **not who** gave it; a missed dose says to ask your vet |

**Judge:** A5.2 is the most important screen in the product. Amber was a deliberate choice (D-UI7). **Is it unmissable?** Would you ring?

### A6 · Seven years — a condition on the record
```js
uatSeed(7 * 365 + 40, 7 * 365 - 23, { conditionIds: ['hip-dysplasia'], conditionsReviewed: true })
```

| ID | Step | Expected |
|---|---|---|
| A6.1 | Care → *Ask about Bruno*: "His hip seems sore after walks" → **Ask** | Your question as your bubble; the answer as **fact cards**, each with its source — "from what you told us", "from the breed research · … evidence" — and a closing line in bold: "This is recall, not an opinion — we have not examined Bruno…" |
| A6.2 | Ask "Can I speak to a vet about this?" | "We cannot put you through to a vet ourselves", "There is no video vet behind Clovara yet", and an **Open Bruno's summary** link (a real link, not a button) |
| A6.3 | Ask anything, then read every line | No line names what something is, says "sounds like", or "fits that picture" |

**Judge:** does it feel like it remembers Bruno, or like it is reading a database at you?

### A7 · Senior — ten and a half
```js
uatSeed(Math.round(10.5 * 365), 10 * 365, { conditionIds: ['hip-dysplasia'], conditionsReviewed: true, lastReviewedAt: new Date(Date.now() - 20 * 864e5).toISOString() })
```

| ID | Step | Expected |
|---|---|---|
| A7.1 | Home | "Nothing needs doing for Bruno today. **Senior stage**…"; the plan adds "Add blood pressure and thyroid testing to the senior panel." |
| A7.2 | Health File | "**Making the house easier for Bruno**" — rugs, ramps, a thicker bed; "**Worth mentioning at the next visit**" — observations, none named as a condition |
| A7.3 | Health File | "**We do not score how good your pet's life is.**" — no quality-of-life score, no remaining-time estimate anywhere |

**Judge:** does it respect him, or count him down?

### A8 · Goodbye — twelve and a half
```js
uatSeed(Math.round(12.5 * 365), 12 * 365, { conditionIds: ['hip-dysplasia'], conditionsReviewed: true, lastReviewedAt: new Date(Date.now() - 20 * 864e5).toISOString() })
```

| ID | Step | Expected |
|---|---|---|
| A8.1 | Health File | "If Bruno has died, telling us stops everything — the reminders, the suggestions, the questions. Nothing is deleted." and a **Bruno has died** button |
| A8.2 | Tap it; it asks for a date and **nothing else** — no cause, no rating | Choose yesterday → **Save** |
| A8.3 | After saving | "**Bruno's record is still here**", "We have stopped everything that would have carried on… Nothing has been deleted, and nothing will be.", "**Undo — this was a mistake**" |
| A8.4 | Home | **Should be quiet**: no briefing, no nudge, no annual review, no activity numbers, no Protect offer — all confirmed quiet in the dry-run. **Fails today on K1 and K2** |
| A8.5 | Every tab | Nothing asks a question, suggests a product, or congratulates |
| A8.6 | **Undo** | Everything returns |

**Judge:** this is the hardest screen in the product. Read it as someone whose dog died yesterday.

---

## 5. Track B — Bruno's family (signed in)

**Human only.** Sign-in, account creation and card entry cannot be done by an
agent. Use Chrome profile 1 for **Owner** and profile 2 (or Incognito) for
**Partner**.

| ID | Step | Expected |
|---|---|---|
| B1 | As Owner, add Bruno (as A1), then **Account → sign in** with email link or Google | Bruno moves to the account; nothing is lost |
| B2 | Reload; open on another device | The same Bruno, the same record |
| B3 | **Start 7-day free trial** → Stripe Checkout (test mode) → card **4242 4242 4242 4242**, any future date, any CVC | Membership active; member-only surfaces unlock. The page states **$22.99 a month** after the trial |
| B4 | Account → manage membership | Stripe's portal opens in test mode |
| B5 | **Family circle** → create an invite code | A code to share |
| B6 | As Partner, sign in and join with the code | Partner sees Bruno — the same plan and record |
| B7 | As Partner, log a dose | Owner sees it given, **not who** gave it |
| B8 | Try to remove Owner from the household | Not possible (the rules forbid it) |
| B9 | **Sitter mode** → create a link; open it in Incognito, signed out | A care card: meds, quirks, vet, emergency contacts — nothing else. Revoke it → the link stops working. **Revoke is the only red on the site** |
| B10 | Add a **photo** of Bruno | It appears as his avatar and on the share card |
| B11 | **Lump diary** → it asks for a size reference **before** the camera opens → add a first photo, then another | Side by side, first against latest. It **never** says whether it grew |
| B12 | Sign out | Back to the investor demo; Bruno is not visible |

**Judge:** does sharing a pet with a partner feel like sharing, or like being monitored?

---

## 6. Track C — everywhere

| ID | Check | Expected |
|---|---|---|
| C1 | Every A chapter at 393px and 1280px | No sideways scroll, no text over text, nothing cut off |
| C2 | Keyboard only (Tab / Shift-Tab / Enter) through onboarding and "Something's wrong" | A visible **forest ring** on every focused control, including text boxes |
| C3 | macOS *Reduce motion* on, reload Care | The conversation appears at once, no animation |
| C4 | Paste #/pet/demo-luna/home into a fresh tab; then follow a link from Max's Health File to Luna | The pet in the link, and the switcher names that pet |
| C5 | Back and forward | Returns to the pet you were on |
| C6 | `uatReset()` and re-check Max, Winston, Luna | The investor demo works exactly as before the UAT |
| C7 | Search every screen you visit for "lifecycle", "platform", "live longer" | None in customer copy |
| C8 | The browser tab | The canonical clover favicon (open loops, not four circles) |

---

## 7. Exit criteria

- Every case in A1, A5, A8 and B3 passes. Those are the ones where failure costs most.
- No open **Sev 1**; no open **Sev 2** without an agreed date.
- A **Judge** note recorded for every chapter.
- C6 passes: the investor demo is intact.

---

## 8. Defect log

### Run 1 — Track A, 2026-09-26, Claude in Chrome, production (after U1–U3 deployed)

Desktop width only (1470px): the Chrome window would not resize to 393px, so **every
chapter still needs its phone pass** (C1). Signed out. Seeded with `uatSeed` as written,
except that `uatReset()` was not used — it clears all of localStorage — only the pets key.

**Result: of 45 cases, 43 pass, 1 fails (A8.5), 1 not exercised (A5.4 — tapping a number
would dial).** Three passes stop short of their last action, each an outward one left for a
human: A1.4 and A3.4 save/share (a download), and A4.5 pressing "Protect Bruno" (a purchase
control — the code shows it answers "Binding is not live yet"). The "Find the nearest vet"
button was not pressed either (it asks for location). C6 passes: the investor demo is intact afterwards.

| # | Case | What happened | Expected | Sev | Screenshot | Found by | Status |
|---|---|---|---|---|---|---|---|
| **D19** | A8.5 | After "Bruno has died": **Life** still says "Bruno is on track for 12.9–15.2 healthy years"; **Rewards** "973 points · +130 this week, from care streaks and activity", streaks, Redeem; **Care** keeps the Ask box and the scripted "Should I be worried?… Worth a vet's eyes"; **Coverage** "Take this cover for Bruno" with a monthly price. `verify-remember` covers only Life's offers, Home, Shop and the Health File | Nothing asks, suggests, sells or reports activity | **1** | — | Claude | fixed and deployed (U4) |
| **D17** | A5.2 | "Stop and ring a vet now" (collapse, pale gums) offers only three poison lines. "Find the nearest vet open now" exists on #/ate but not here | A way to find an emergency vet on the most urgent screen | **2** | — | Claude | fixed and deployed (U5) |
| **D2** | A1.2, A4.2 | "What you can change" shows Body condition *Ideal* and Dental *Weekly* and says "Set to what you told us" — neither was asked (the vet summary correctly says "Not asked") | Defaults not presented as answers | 3 | — | Claude | fixed and deployed (U6) |
| **D3** | A1.5 | Home's biggest lever for a 9-week-old: "Dental care is the easiest win for Bruno — Weekly." Untold, and his own plan says brush "once the adult teeth are through" | No lever built on an unasked default; nothing age-inappropriate | 3 | — | Claude | fixed and deployed (U6) |
| **D18** | A5.6 | Add a medication preselects "Twice a day"; saved without choosing, it drives "About 15 days left" | Dosing frequency has no default | 3 | — | Claude | fixed and deployed (U6) |
| **D11** | A4.3 | Scripted reply: the vet summary has "the last three weigh-ins… and what he is currently taking" — Bruno has one weight and no medication, under "every specific in it is pulled from Bruno's record" | Only what is on the record | 3 | — | Claude | fixed and deployed (U7) |
| **D9** | A4.3 | Care intro: "built from Bruno's own record — the condition on file" when none is on file | Says what is actually there | 3 | — | Claude | fixed and deployed (U7) |
| **D12** | A4.5 | That binding is not live appears only after ticking the declaration and pressing "Protect Bruno for $59.13"; the message's "Everything up to this point is real" sits under "This price is illustrative" | Said before the commitment; no contradiction | 3 | — | Claude | fixed and deployed (U7) |
| **D13** | A4.5 | Coverage "How a claim works": "Auto-reviewed in hours", "Paid straight to your account" with no caveat that no claim can be made; "Bruno was added during this session" for a pet saved earlier | Honest about what exists | 3 | — | Claude | fixed and deployed (U7) |
| **D14** | A4.6 | Shop: members "earn points back on the products that keep Bruno healthy" | No health claim attached to products — for counsel (A2) | 3 | — | Claude | fixed and deployed (U7) |
| **D16** | A5.1–2 | "VET-REVIEW: this list is under veterinary review…" shown to customers | The disclosure without the internal tag | 3 | — | Claude | fixed and deployed (U7) |
| **D1** | A0.2 | Luna: "85% sharp — add anything diagnosed to reach 85%" (capped at 85%) | No promise of a gain that cannot happen | 3 | — | Claude | fixed and deployed (U7) |
| **D7** | A3.1 | Annual review offers "Still true" on four questions marked "we have never asked" | A first answer, not a confirmation | 3 | — | Claude | fixed and deployed (U7) |
| **D8** | A3.3 | "Done" stays disabled until all five are answered, under "4 left, none of them required"; pressing it does nothing | Done works after any answer, or says why not | 3 | — | Claude | fixed and deployed (U7) |
| **D4** | A1.6 | "Add body condition" on Home lands at the top of Life, not at the question | Lands on the question | 3 | — | Claude | fixed and deployed (U7) |
| **D5** | A1.7, A5.6 | UK examples in a US product: second opinion "about £4,800", sitter "01234 567890", "07700 900000" | Dollars, US numbers | 3 | — | Claude | fixed and deployed (U7) |
| **D6** | A1.7, A5 | Top nav highlights the previous tab on Health File, #/wrong and #/ate (Home, Rewards) | No tab, or the right one | 4 | — | Claude | fixed and deployed (U7) |
| **D10** | A4.3 | "He is 4.1 and a Labrador Retriever" | "4 years old" | 4 | — | Claude | fixed and deployed (U7) |
| **D15** | A4.7 | Rewards: "Monthly weigh-in logged" with frequency "Weekly" | They agree | 4 | — | Claude | fixed and deployed (U7) |

**For the Judge lines** (observations, not defects — Conor's call):
- A1 · K5 as expected: "6,027 steps · CloTag" and "6 · Dental streak" for a dog added minutes ago; Rewards shows "2/2 care visits done this year".
- A1 · Breed step: the chosen breed is a sage fill with no border, while the unchosen "Mixed / not sure" has the stronger border.
- A1 · A nine-week-old's Health File puts the Lump diary above the Passport. Stamped firsts are shown struck through, which can read as cancelled.
- A2 · The briefing leads with "Around now is when Rabies is usually given" while two DHP doses show "Window passed".
- A4–A7 · The Clovara Score is 76, "On track, with room in one or two places", at 9 weeks, 4 years, 7 years with hip dysplasia and 10.5 years.
- A5.2 · At desktop the urgent answer is mid-screen; on a phone it will sit below the text box — check it scrolls into view. For a collapse the only numbers are poison lines (ASPCA charges a fee) — one for the A1 vet reviewer.
- A6 · Each new question replaces the previous answer; there is no running conversation. The first question typed straight after the page loaded was lost once — not reproduced, worth trying on a phone.

---

## 9. Driving Track A with Claude in Chrome

Track A and C can be run by Claude in Chrome with no credentials: it can open
DevTools-equivalent JavaScript on the page to run `uatSeed`, click through each
chapter, and screenshot every case into the defect log. It will **stop and hand
over** for anything in Track B: sign-in, account creation, the Stripe card, and
the second person's account. The **Judge** lines are yours either way; an agent
can report what a screen says, not whether it is right for someone whose dog
just collapsed.
