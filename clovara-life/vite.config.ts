import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'
import { readFileSync } from 'node:fs'

/**
 * The security headers `hosting:life` sends (UB8), read from firebase.json so
 * the preview the verify suite runs against behaves like production. One
 * source: change them there.
 */
function lifeSecurityHeaders(): Record<string, string> {
  try {
    const config = JSON.parse(readFileSync(new URL('../firebase.json', import.meta.url), 'utf8'))
    const life = config.hosting.find((h: { target: string }) => h.target === 'life')
    const all = life.headers.find((h: { source: string }) => h.source === '**')
    return Object.fromEntries(all.headers.map((h: { key: string; value: string }) => [h.key, h.value]))
  } catch {
    return {}
  }
}

export default defineConfig({
  plugins: [react()],
  // The canonical mark lives at the repo root (docs/DESIGN.md §1) and the app
  // imports it rather than keeping a copy. Build resolves it anywhere; the dev
  // server needs telling. Only that one directory, not the whole repo.
  server: { fs: { allow: ['.', '../assets/images'] } },
  preview: { headers: lifeSecurityHeaders() },
  test: {
    // `functions/` is a separate CommonJS codebase tested with node:test
    // (`npm test --prefix functions`). Vitest must not try to collect it.
    exclude: ['**/node_modules/**', '**/dist/**', 'functions/**'],
  },
})
