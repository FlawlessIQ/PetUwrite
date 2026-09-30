# Deploying Clovara

**Last updated: 2026-09-25.** Verified against `firebase.json`, `.firebaserc`
and the build scripts on that date. This replaces `HOSTING_SETUP.md`, which
described a single-target Flutter deployment and no longer matches the project
(it is in `archive/` for history).

---

## There are two hosting targets and they are both live

| Target | Site | Serves | Built from |
|---|---|---|---|
| `main` | `pet-underwriter-ai.web.app` | the marketing site, and the Flutter app at `/app` | `out/` |
| `life` | `clovara-life.web.app` | Clovara Life | `clovara-life/dist/` |

**Never run `firebase deploy` or `firebase deploy --only hosting`.** With two
targets configured, both of those push **both live sites** — including whichever
one you have not built, from whatever is sitting in its output directory. Always
name the target.

## Clovara Life

```bash
cd clovara-life && npm run build && cd .. && firebase deploy --only hosting:life
```

`clovara-life/dist/` is a Vite build. Two things about it catch people out:

- **Editing `clovara-life/public/` changes nothing until you rebuild.** Vite
  copies `public/` into `dist/` at build time, and the deploy reads `dist/`. The
  journey map (`public/partners/journey-data.js`) is the usual victim.
- `journey-data.js` gets Firebase Hosting's default `max-age=3600`, not a
  configured header — `firebase.json` only sets Cache-Control for `/assets/**`
  (immutable, because Vite fingerprints those filenames) and `/index.html`
  (no-cache). So anyone who loaded the partner map in the last hour keeps the old
  copy until it expires. Cache-bust with a query string when verifying a change,
  and do not read a stale response as a failed deploy.

Before deploying, `npm run verify:all` builds and runs every browser and static
suite (30 as of UB12), reporting every failure rather than stopping at the first.
`npm run test:emulator` needs the Firebase emulators and is separate.

**Security headers** (UB8) are set on the life target in `firebase.json` under
`"source": "**"` — Referrer-Policy, nosniff, X-Frame-Options/`frame-ancestors`,
Permissions-Policy — and the local preview reads the same block. After a deploy,
check them on the live site:

```bash
cd clovara-life && BASE=https://clovara-life.web.app node scripts/verify-headers.mjs
```

## The marketing site

```bash
npm run build && firebase deploy --only hosting:main
```

`npm run build` is `next build` (static export, `output: "export"`) followed by
`scripts/copy-legacy-app.mjs` and `next-sitemap`. The copy step takes the
Flutter web build from `build/web/` and places it at `out/app/`, which is how the
Flutter app is still served — as a sub-path of the marketing site rather than as
a hosting target of its own. If you have not run `flutter build web`, that step
copies whatever was there last.

`build:next-only` skips the copy step.

## Cloud Functions

Two codebases, and they deploy independently:

```bash
firebase deploy --only functions:default   # functions/
firebase deploy --only functions:life      # clovara-life/functions/
```

## Counting visitors who never sign up (UB5 / AO13)

**Live since 2026-09-30.** How it was switched on, and how to redo or undo it:

1. **Deploy the one function**, not the whole codebase — a full `functions:life`
   deploy would also put the (still silent) email functions live:
   `firebase deploy --only functions:life:lifeIngest`. It is public by design,
   accepts only known event names from three origins, and is rate-limited.
2. **Switch the client on**: `clovara-life/.env.production` sets
   `VITE_ANON_INGEST=1`, so every production build has it; deploy `hosting:life`.

To switch it off, remove that line, rebuild and deploy `hosting:life`; the
endpoint can stay. Automated browsers never send, so production checks are not
counted. To prove it end to end (writes one visit under a `verify-` id, which the
dashboard leaves out):

```bash
cd clovara-life && INGEST_LIVE=1 BASE=https://clovara-life.web.app node scripts/verify-ingest.mjs
```

## Switching email on

Everything is built and tested; nothing sends. The Life functions use a console
sender that only logs, and the account-panel opt-in is compiled out of the
production bundle. In order — each step is Conor's or needs his word:

1. **A sending domain**, authenticated in SendGrid (the SPF/DKIM CNAME records it
   gives you) with a DMARC record. Sending from a Gmail or FlawlessIQ address is
   not an option: the first is rejected under DMARC, the second makes the wrong
   company the sender (the same problem as A3).
2. **The key**: `firebase functions:secrets:set SENDGRID_API_KEY --project pet-underwriter-ai`
   (a restricted key with *Mail Send* only).
3. **Counsel's postal address** replaces the `LEGAL-REVIEW` line in
   `clovara-life/functions/email.js` (`moment`); the unsubscribe wording beside
   it is counsel's to approve too (A2).
4. **Bind and configure** in `clovara-life/functions/index.js`: add
   `SENDGRID_API_KEY` (a `defineSecret`) to the `secrets` of `stripeWebhook`,
   `sendMoments` and `lifePlanSaved`, and set `EMAIL_PROVIDER=sendgrid` and
   `EMAIL_FROM="Clovara <hello@DOMAIN>"` as parameters. Not before step 2 — binding
   a secret that does not exist fails the deploy.
5. **Deploy the functions**: `firebase deploy --only functions:life`. Then send
   yourself one of each template before anyone else gets one.
6. **Show the opt-in**: build with `VITE_EMAIL_MOMENTS=1` and deploy `hosting:life`.

The sender refuses to run half-configured (no key or no from address → an
error, never a silent drop), and open and click tracking are off per message —
click tracking would rewrite the unsubscribe link and tell SendGrid who opened
what, which the Data Covenant does not allow.

## Rules

```bash
firebase deploy --only firestore:rules
firebase deploy --only storage
```

`firestore.rules` holds both products: the underwriting collections, then the
Clovara Life block (from the `// CLOVARA LIFE` banner to the end of
`match /households/{householdId}`). A rules deploy applies all of it, so run
`cd clovara-life && npm run test:emulator` first — 110 tests, 16 of them
adversarial. See `FIRESTORE-REVIEW-BRIEF.md`.

## Preview channels, rollback and history

These commands are unchanged and still worth knowing. They also take a target:

```bash
firebase hosting:channel:deploy preview-name --only life
firebase hosting:channel:list
firebase hosting:releases:list --site clovara-life
firebase hosting:rollback --site clovara-life
```

## Project

One Firebase project, `pet-underwriter-ai`, for everything. `.firebaserc` maps
the two targets onto their sites; there is no separate staging project.
