import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{ts,tsx}",
    "./components/**/*.{ts,tsx}",
    "./hooks/**/*.{ts,tsx}"
  ],
  theme: {
    extend: {
      colors: {
        clv: {
          white: "#FAFAF7",
          paper: "#F2EFE8",
          "sage-light": "#EEF7F2",
          green: "#2D6A4F",
          "green-dark": "#1B4332",
          "green-mid": "#52B788",
          "green-muted": "#74B49B",
          charcoal: "#1A1A1A",
          gray: "#888888",
          "gray-light": "#D5D0C8",
          "gray-border": "#E8E3DA",
          amber: "#B45309",
          "amber-light": "#FFF8E7"
        }
      },
      fontFamily: {
        display: ["var(--font-playfair)"],
        sans: ["var(--font-dm-sans)"]
      },
      letterSpacing: {
        label: "0.1em"
      },
      lineHeight: {
        body: "1.7"
      }
    }
  },
  plugins: []
};

export default config;
