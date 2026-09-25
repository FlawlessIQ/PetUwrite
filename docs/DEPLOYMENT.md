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
suite. `npm run test:emulator` needs the Firebase emulators and is separate.

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
