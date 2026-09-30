/**
 * The whole verify suite, reporting every failure rather than stopping at the
 * first (BACKLOG UB9). Run after a build: `npm run verify:all` does both.
 *
 * It serves `dist/` on its own port (4178, strict) and points every script at
 * it with BASE, so a preview left running from an older build can never be
 * the thing under test. `node scripts/verify-all.mjs verify-demo verify-copy`
 * runs a subset.
 */
import { spawn, spawnSync } from 'node:child_process'
import { existsSync } from 'node:fs'
import { chromium } from 'playwright'

const SCRIPTS = [
  'verify-demo', 'verify-onboarding', 'verify-metrics', 'verify-review', 'verify-share',
  'verify-firstnight', 'verify-passport', 'verify-vaccines', 'verify-toxins', 'verify-attach',
  'verify-length', 'verify-a11y', 'verify-visitsummary', 'verify-safety', 'verify-companion',
  'verify-lumps', 'verify-remember', 'verify-c1c2', 'verify-briefing', 'verify-senior',
  'verify-journey', 'verify-copy', 'verify-bundle', 'verify-routing', 'verify-brand',
  'verify-moments-bundle', 'verify-review-packs', 'verify-errors', 'verify-headers',
]
const PORT = 4178
const BASE = `http://127.0.0.1:${PORT}`

// ── Preflight ───────────────────────────────────────────────────────────────
if (!existsSync(chromium.executablePath())) {
  console.error(
    '\nPlaywright has no Chromium on this machine, so every browser check would fail.\n' +
      'Run this once, then try again:\n\n    npx playwright install chromium\n',
  )
  process.exit(1)
}
if (!existsSync('dist/index.html')) {
  console.error('\nNo build to test. Run `npm run build` first (or `npm run verify:all`).\n')
  process.exit(1)
}

const wanted = process.argv.slice(2)
const run = wanted.length ? SCRIPTS.filter((s) => wanted.includes(s)) : SCRIPTS
const unknown = wanted.filter((s) => !SCRIPTS.includes(s))
if (unknown.length) console.warn(`Not in the suite, ignored: ${unknown.join(', ')}`)

// ── Serve the build ─────────────────────────────────────────────────────────
const preview = spawn('npx', ['vite', 'preview', '--port', String(PORT), '--strictPort', '--host', '127.0.0.1'], {
  stdio: ['ignore', 'ignore', 'pipe'],
  detached: true,
})
let previewErr = ''
preview.stderr.on('data', (d) => (previewErr += d))
const stopPreview = () => {
  try {
    process.kill(-preview.pid)
  } catch {
    /* already gone */
  }
}
process.on('exit', stopPreview)
process.on('SIGINT', () => process.exit(130))

const deadline = Date.now() + 20_000
let up = false
while (Date.now() < deadline && preview.exitCode === null) {
  try {
    up = (await fetch(`${BASE}/`)).ok
    if (up) break
  } catch {
    /* not listening yet */
  }
  await new Promise((r) => setTimeout(r, 200))
}
if (!up) {
  console.error(`\nThe preview did not start on ${PORT}.${previewErr ? '\n' + previewErr.trim() : ''}\n`)
  process.exit(1)
}

// ── Run everything ──────────────────────────────────────────────────────────
const results = []
for (const name of run) {
  console.log(`\n— ${name}`)
  const started = Date.now()
  const r = spawnSync('node', [`scripts/${name}.mjs`], { stdio: 'inherit', env: { ...process.env, BASE } })
  results.push({ name, ok: r.status === 0, seconds: (Date.now() - started) / 1000 })
}

const failed = results.filter((r) => !r.ok)
const total = results.reduce((n, r) => n + r.seconds, 0)
console.log('\n══════════════════════════════════════════')
console.log(`${results.length - failed.length} of ${results.length} passed in ${total.toFixed(0)}s`)
if (failed.length) {
  console.log(`\nFailed:\n${failed.map((r) => `  ✗ ${r.name}`).join('\n')}`)
  console.log(`\nRerun just those:\n  node scripts/verify-all.mjs ${failed.map((r) => r.name).join(' ')}`)
}
process.exit(failed.length ? 1 : 0)
