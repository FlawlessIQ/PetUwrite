# What can be built with no blockers and no decisions

Written 2026-09-30 by Claude Code at Conor's request. Everything here can be built
without an answer from Conor, a reviewer, a partner or a supplier. Backlog ids
**UB1–UB12** are in `BACKLOG.md`.

**The rules it keeps.** No new runtime dependency. No copy that needs judgement is
written as final — anything customer-facing is marked unread, as usual. Only
`hosting:life` deploys; anything that needs a functions or rules deploy is built
and tested and then waits for Conor's word, as T2 and the email functions do.
Nothing adds product surface: the strategic review's advice — no new features
before the UAT and the reviews — still stands, so no journey moments are here.

## Why this order

What actually gates a real customer now is people, not code: the vet, counsel,
Conor's phone pass and the first cohort. So the first track makes *their* work
faster. The second makes sure the cohort can be measured from their first visit.
The third and fourth harden what is already live.

## Track 1 — Make the reviews quick to do

The vet and counsel reviews gate nearly everything customer-facing, and Conor's
phone pass is the UAT's missing half. Each of these turns a vague "please review
the app" into a bounded document.

| id | Build | Size | What it unblocks |
|---|---|---|---|
| **UB1** | **The vet pack.** One document: the 17 red flags, the escalation copy, the 16 poison entries with their urgency, First Nights, the senior suite's "worth mentioning" lines, the vaccination schedule's wording — each with where it appears and a Verdict column. Drawn from `JUDGEMENT-COPY.md` §1–3 plus the data files, regenerated from code so it cannot drift | S | **A1, R1** — the clinical review can start the day it is sent |
| **UB2** | **The counsel pack.** The Protect disclosures and fraud notice, the Data Covenant, the Shop membership line (D14), every email template rendered with sample data, the unsubscribe page, the shared-card link's privacy note, and a list of what is *missing* (CA/NY auto-renewal text, the postal address) — marked, never drafted | S | **A2** — and the email switch-on, which waits on counsel's footer |
| **UB3** | **Email previews.** `npm run email:preview` renders every template (welcome, trial ending, plan saved, each moment) with sample data into a readable file. Feeds UB2, and lets Conor read the unread email copy in one sitting | S | Conor's read of the email copy |
| **UB4** | **The phone book for the UAT.** Every Track A step captured at iPhone size (393×852), in order, on one page with the Expected line beside each shot. Conor still judges on his own phone; this shows him where to look and what "right" is | M | **P5** — the phone pass in a fraction of the time |

## Track 2 — Measure the cohort from their first visit

| id | Build | Size | Notes |
|---|---|---|---|
| **UB5** | **AO13: count visitors who never sign up.** A small public ingest endpoint on the Life functions: accepts only the anonymous visitor id, event names and the flat props events already carry; rate-limited; no names, emails or free text (the same sanitiser as today). The client sends signed-out events there. **Built and tested in the emulator; deploying it is Conor's word** (a `functions:life` deploy) | M | The funnel's first steps stop being an undercount |
| **UB6** | **The funnel by source, and returns by week.** The admin dashboard gains: each stage broken down by `utm_source` / referrer, day-1/7/28 return rates, and a **campaign link builder** that makes a tagged link for any partner or post. Admin-only | S | Answers "did the rescue's link work" on day one |
| **UB7** | **Client errors, first-party.** An error boundary and `window.onerror` record a `client_error` event (message and component only — never a stack with user data in it) through the same queue | S | Tells us when the cohort hits something broken before they tell us |

## Track 3 — Harden what is live

| id | Build | Size | Notes |
|---|---|---|---|
| **UB8** | **Security headers for `hosting:life`.** `Referrer-Policy: strict-origin-when-cross-origin` (a pet's URL never leaks to another site), `X-Content-Type-Options: nosniff`, `frame-ancestors 'none'` against clickjacking, and a `Permissions-Policy` that allows only what the app uses (location for the vet finder, camera for the lump diary). A verify script checks them on the live site. The `main` target is not touched | S | The Covenant's privacy promises, enforced by the browser |
| **UB9** | **The test suite, steadier.** Replace the fixed waits in the flakiest scripts with waits for the thing itself; a preflight that says "run `npx playwright install chromium`" instead of 21 failures; `verify:all` reporting every failure instead of stopping at the first | S | Every future change lands faster |
| **UB10** | **CI for Life.** A GitHub Actions workflow that runs the typecheck, unit tests, functions tests and the static checks on every push to a Life branch — no secrets, no deploy. The two existing workflows belong to the underwriting app and are not touched | S | Nobody has to remember to run the suite |
| **UB11** | **One way to call the functions.** Four copies of the same `callable` helper become one | S | Cleanup — the kind that stops a fix landing in three of four places |

## Track 4 — Make a Covenant promise self-serve

| id | Build | Size | Notes |
|---|---|---|---|
| **UB12** | **"Download everything about Bruno."** The Data Covenant says "ask us for everything we hold on your pet". A Health File button produces it on the device: a readable document of the record, plus a machine-readable copy. The Covenant's wording is **not** changed — that is counsel's — until they have seen it | S | The first Covenant promise that needs no email to us |

## Found while planning — one new decision

**US or British English?** The product is priced in dollars and pounds weight for
a US launch, but the copy is written in British English — *socialisation*,
*colour*, *organise*, "ring your vet". Nothing about that is wrong, but it is a
choice nobody has made, and it touches every screen. Added as **AO-D8**. Not in
this plan: changing it is a sweep, and doing it before the decision would be
guessing.

## Not in this plan, on purpose

- **New journey moments** (about 20 are technically unblocked) — the strategic review's
  advice holds until the UAT and the reviews are done.
- **Anything that needs a decision:** the trial rule, partner intake (AO10), the
  trial at the moment of value (AO7/8), the `main` site, D-UI6's design pass.
- **Deploys that are Conor's:** T2's rules, the email functions, UB5's endpoint.

## Order

UB1 → UB2 → UB3 (the reviews can be sent), UB4 (the phone pass), then UB5–UB7
(measurement ready before the cohort), then UB8–UB12. Tracks 1 and 2 are about a
week together; Tracks 3 and 4 a few days more.
