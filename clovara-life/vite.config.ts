import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  // The canonical mark lives at the repo root (docs/DESIGN.md §1) and the app
  // imports it rather than keeping a copy. Build resolves it anywhere; the dev
  // server needs telling. Only that one directory, not the whole repo.
  server: { fs: { allow: ['.', '../assets/images'] } },
  test: {
    // `functions/` is a separate CommonJS codebase tested with node:test
    // (`npm test --prefix functions`). Vitest must not try to collect it.
    exclude: ['**/node_modules/**', '**/dist/**', 'functions/**'],
  },
})
