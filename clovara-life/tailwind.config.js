/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      // docs/DESIGN.md §2 — exactly this set. Changing a value here is a
      // design decision and gets a DECISIONS.md entry.
      colors: {
        cream: '#F6F3EB', // page ground
        'cream-2': '#EFEBE0', // hover on ground, inset wells
        card: '#FFFFFF', // card surfaces
        line: '#E5E1D5', // borders, dividers (was #E6E1D6)
        ink: '#1B1E1B', // primary text, dark buttons
        'ink-2': '#5C635C', // secondary text (was `muted` #6B716C)
        'ink-3': '#8A918A', // captions, placeholders — see DECISIONS: fails AA for small text
        forest: '#1A5C38', // primary actions, links, data marks, focus rings
        deep: '#0F3D26', // hero bands, text on sage
        sage: '#E4EAE0', // positive chips, soft fills, icon wells
        'sage-2': '#D5DFD0', // borders on sage, inactive timeline dots
        accent: '#D98A26', // attention only
        amber: '#B27117', // accent-toned text — see DECISIONS: fails AA for small text
        'nudge-fill': '#FBF4E7', // "worth watching" card fill
        track: '#EDEAE0', // ring and chart tracks, grids
      },
      fontFamily: {
        display: ['"Playfair Display"', 'Georgia', 'serif'],
        sans: ['Poppins', 'system-ui', '-apple-system', 'sans-serif'],
      },
      /*
       * The type scale (BACKLOG D-UI2). Every step is a DESIGN.md §3 role or is
       * named as not being one, and nothing else may set a font size:
       * scripts/verify-brand.mjs fails on an arbitrary text-[Npx]. Sizes only —
       * line height stays with the element.
       *
       * Adopted by snapping each of the 35 hand-set sizes to the nearest step,
       * ties rounding DOWN, so text never grew into a layout sized for it. The
       * first attempt rounded up and pushed the new-puppy Home over its length
       * budget and a poison-line number onto a second line; this one does not.
       *
       * Not §3 roles, and open questions for Conor: `lead` holds 15px prose
       * (ledes), above §3's 14.5px body maximum; and the three heading steps sit
       * in the gap between §3's title (≤16px) and display (≥26px), where the app
       * sets its Playfair card headings.
       */
      fontSize: {
        micro: '8px', // §5 score-ring micro-label (7–8px)
        'caption-sm': '9.5px', // §3 caption, lower bound — the six-tab bottom nav
        caption: '11px', // §3 caption and eyebrow, upper bound
        'body-sm': '12.5px', // §3 body, lower bound
        body: '13.5px', // §3 body
        'body-lg': '14px', // §3 body
        lead: '15px', // §3 title range; ledes and button labels — not a §3 body size
        title: '16px', // §3 title, upper bound — and the iOS minimum for inputs
        'heading-sm': '18px', // not in §3 — card headings
        heading: '20px', // not in §3 — card headings
        'heading-lg': '22px', // not in §3 — card headings
        stat: '24px', // §3 stat, lower bound
        'display-sm': '26px', // §3 display
        display: '30px', // §3 display
        'display-lg': '34px', // §3 display
        'display-xl': '40px', // §3 display-xl
        'display-2xl': '46px', // §3 display-xl
        hero: '54px', // §3 display-xl — the projection range
        'hero-xl': '62px', // §3 display-xl, upper bound
      },
      borderRadius: {
        card: '22px', // cards
        soft: '18px', // inner cards
        inner: '12px', // wells and inputs
      },
      boxShadow: {
        soft: '0 1px 2px rgba(27,30,27,0.04), 0 12px 32px -18px rgba(27,30,27,0.22)',
        lift: '0 2px 6px rgba(27,30,27,0.06), 0 24px 48px -24px rgba(27,30,27,0.28)',
      },
      backgroundImage: {
        clover: 'linear-gradient(140deg, #D98A26, #8FA83E 48%, #1E7A46)',
      },
      maxWidth: {
        shell: '1180px',
      },
    },
  },
  plugins: [],
}
