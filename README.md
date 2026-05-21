# Clovara Website

This repository now contains a production-grade Next.js marketing site for Clovara, built with the App Router, TypeScript, Tailwind CSS, Framer Motion, and Lucide React.

The legacy Flutter app source remains in the repo for reference, but the root web project is the Next.js site deployed to Firebase Hosting as a static export.

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
firebase deploy --only hosting
```

Live Firebase Hosting URL: `https://pet-underwriter-ai.web.app`.
