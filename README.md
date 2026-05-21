# Clovara Website

This repository now contains a production-grade Next.js marketing site for Clovara, built with the App Router, TypeScript, Tailwind CSS, Framer Motion, and Lucide React.

The legacy Flutter app source remains in the repo for reference, but the root web project is the Next.js site intended for Vercel deployment.

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
- `/about` founder and mission page
- `/how-it-works` full explainer and FAQ
- `/quote` four-step quote funnel
- `/privacy` placeholder privacy page
- `/terms` placeholder terms page

## Launch TODOs

- Replace the Segment placeholder write key in `app/layout.tsx`.
- Replace placeholder partner logos in the social proof bar.
- Replace placeholder investor logos on `/about`.
- Replace founder bio and portrait placeholder on `/about`.
- Replace placeholder testimonials with approved real testimonials.
- Add state license numbers in `components/Footer.tsx`.
- Replace placeholder privacy policy and terms pages with approved legal copy.
- Confirm final product copy, coverage descriptions, and regulatory disclaimers.
- Replace `/public/og-image.svg` with final branded Open Graph art if desired.

## Deployment

The project includes `vercel.json` and is configured for Vercel's Next.js runtime.

```bash
npm run build
```

The previous Firebase Hosting deployment scripts are still present for the legacy Flutter workflow, but the new production target is Vercel.
