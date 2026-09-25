# Clovara Website

This repository now contains a production-grade Next.js marketing site for Clovara, built with the App Router, TypeScript, Tailwind CSS, Framer Motion, and Lucide React.

## Three things live in this repository

| | Where | Deployed as |
|---|---|---|
| **The marketing site** (this project) | `app/`, `components/`, `hooks/` | `hosting:main` → pet-underwriter-ai.web.app |
| **Clovara Life** — the pet wellness membership product | `clovara-life/` | `hosting:life` → clovara-life.web.app |
| **The Flutter app** — underwriting, quotes, the admin console | `lib/` | `/app` under `hosting:main` |

The Flutter app is **not** dormant reference code: `npm run build` runs
`scripts/copy-legacy-app.mjs`, which copies its `build/web/` output into `out/app/`,
so it ships with every deploy of this site. Do not delete `lib/` on the assumption
that nothing uses it.

Clovara Life has its own README, spec, changelog and test suites in
`clovara-life/`, and is worked on independently of this project.

## Where the documentation lives

- **[`CLAUDE.md`](CLAUDE.md)** — repo instructions, the invariants, and the living-documents protocol. Read first.
- **[`docs/README.md`](docs/README.md)** — an index of all 203 documents, saying which are maintained and which are history.
- **[`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md)** — the two hosting targets and how to deploy either without touching the other.
- **[`docs/ROADMAP.md`](docs/ROADMAP.md)** — the living build state. Not the `ROADMAP.md` in this directory, which is a January 2026 snapshot.
- **`clovara-life/SPEC.md`** — the build contract for Clovara Life and its nine invariants.

Other `.md` files in this directory are older notes on the underwriting product
and the Flutter app. They were true when written; nothing keeps them true.

## Quick Start

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

## Scripts

- `npm run dev` starts the Next.js development server.
- `npm run build` creates a production build and generates `sitemap.xml` / `robots.txt` via `next-sitemap`.
- `npm run lint` runs Next.js linting.
- `npm run typecheck` runs TypeScript in strict mode.
- `npm run format` formats the project with Prettier.

## Routes

- `/` marketing homepage
- `/about` company and mission page
- `/how-it-works` full explainer and FAQ
- `/quote` four-step quote funnel
- `/privacy` placeholder privacy page
- `/terms` placeholder terms page

## Launch TODOs

- Replace the Segment placeholder write key in `app/layout.tsx`.
- Replace placeholder testimonials with approved real testimonials.
- Add state license numbers in `components/Footer.tsx`.
- Replace placeholder privacy policy and terms pages with approved legal copy.
- Confirm final product copy, coverage descriptions, and regulatory disclaimers.
- Replace `/public/og-image.svg` with final branded Open Graph art if desired.

## Deployment

The project is configured for Firebase Hosting. `next.config.mjs` uses static export mode, so `npm run build` writes the deployable site to `out`.

```bash
npm run build
firebase deploy --only hosting:main
```

**Name the target.** There are two hosting sites on this project — `main`
(this site) and `life` (clovara-life.web.app) — so plain
`firebase deploy --only hosting` pushes both, including whichever one you have
not built. `docs/DEPLOYMENT.md` has the full picture.

Live Firebase Hosting URL: `https://pet-underwriter-ai.web.app`.
