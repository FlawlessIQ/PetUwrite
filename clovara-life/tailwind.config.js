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
