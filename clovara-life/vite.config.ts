import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    // `functions/` is a separate CommonJS codebase tested with node:test
    // (`npm test --prefix functions`). Vitest must not try to collect it.
    exclude: ['**/node_modules/**', '**/dist/**', 'functions/**'],
  },
})
