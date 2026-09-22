/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        cream: '#F6F3EB',
        ink: '#1B1E1B',
        forest: '#1A5C38',
        deep: '#0F3D26',
        sage: '#E4EAE0',
        accent: '#D98A26',
        muted: '#6B716C',
        line: '#E6E1D6',
      },
      fontFamily: {
        display: ['"Playfair Display"', 'Georgia', 'serif'],
        sans: ['Poppins', 'system-ui', '-apple-system', 'sans-serif'],
      },
      borderRadius: {
        card: '22px',
        soft: '18px',
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
