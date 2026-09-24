/**
 * What is on the critical path, and what must stay off it.
 *
 * Twice now a data table has arrived in the main bundle through a single
 * innocuous import, and both times it was found by hand:
 *
 *  - the Health File summary imported `passportState` and `vaccineState`, which
 *    brought 103 socialisation stamps and the vaccination schedule with them;
 *  - `vaccines.ts` imported one constant, `WEEKS_PER_YEAR`, from `passport.ts`,
 *    which brought the socialisation table back the moment the morning briefing
 *    put the vaccination schedule on the home screen.
 *
 * Nothing rendered any of it. That is what makes this class of regression
 * invisible: it costs every visitor bytes and costs no test a failure.
 *
 * Run after `npm run build`. No browser: it reads dist.
 */
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { gzipSync } from 'node:zlib'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const DIST = resolve(dirname(fileURLToPath(import.meta.url)), '../dist/assets')

let failures = 0
const ok = (label, cond, detail = '') => {
  if (cond) console.log(`  ✓ ${label}`)
  else {
    failures++
    console.log(`  ✗ ${label}${detail ? ' — ' + detail : ''}`)
  }
}

const assets = readdirSync(DIST)
const entry = assets.filter((f) => /^index-[^.]+\.js$/.test(f))
if (entry.length !== 1) {
  console.log(`\n  ✗ expected exactly one entry chunk, found ${entry.length}: ${entry.join(', ')}`)
  console.log('\n    (run `npm run build` first — a stale dist has chunks from several builds)\n')
  process.exit(1)
}
const main = readFileSync(join(DIST, entry[0]), 'utf8')
const raw = statSync(join(DIST, entry[0])).size
const gz = gzipSync(main).length
const kb = (n) => `${(n / 1024).toFixed(1)}kB`

/**
 * Budgets sit a little above today's figures. They exist to catch a step change
 * — a table, a date library, an icon set — not to force a fight over a kilobyte.
 * Raising one is a decision to record, not a formality.
 */
const RAW_BUDGET = 560 * 1024
const GZIP_BUDGET = 165 * 1024

console.log('\nThe entry chunk')
console.log(`  ${entry[0]} — ${kb(raw)} raw, ${kb(gz)} gzipped`)
ok(`raw under ${kb(RAW_BUDGET)}`, raw <= RAW_BUDGET, kb(raw))
ok(`gzipped under ${kb(GZIP_BUDGET)}`, gz <= GZIP_BUDGET, kb(gz))

console.log('\nData tables that must not be on the critical path')
/**
 * Each is matched by a string only that table contains, because an import graph
 * can be reorganised without moving the bytes. What is being asserted is where
 * the content ended up.
 */
const MUST_BE_LAZY = [
  ['the socialisation stamps', 'An umbrella opening', 'src/data/socialization.ts — the Health File'],
  ['the toxin table', 'Xylitol', 'src/data/toxins.ts — the "ate something" flow'],
  ['the senior adaptations', 'Rugs or runners', 'src/data/senior.ts — the Health File'],
]
for (const [what, marker, where] of MUST_BE_LAZY) {
  const leaked = main.includes(marker)
  ok(`${what} are not in the entry chunk`, !leaked, leaked ? `expected in ${where}` : '')
  // A marker that matches nothing anywhere means the copy changed and this check
  // has quietly stopped checking.
  const anywhere = assets.some(
    (f) => f.endsWith('.js') && f !== entry[0] && readFileSync(join(DIST, f), 'utf8').includes(marker),
  )
  ok(`  …and still exist somewhere (${what} marker is current)`, anywhere)
}

console.log('\nKnown and accepted, so a change here is deliberate')
/**
 * The breed tables are 130kB of source and the largest thing in the bundle. They
 * are also what the plan renders from, so splitting them would put a loading
 * state on the first screen: measured at 1.3s to a fully rendered plan on 4G
 * with 4x CPU throttling, the split would make the number worse, not better.
 * The shop catalogue rides along because `platform.ts` holds both the home
 * screen's builders and `recommendProducts`; worth ~4kB gzipped to separate,
 * which measurement did not justify either.
 */
ok('the breed tables are still in the entry chunk, as decided', main.includes('Zinc-responsive'))
// The morning briefing reads the vaccination schedule on the home screen, so
// this one is earning its place rather than riding along. It is asserted rather
// than assumed, so that removing the briefing's use of it would show up here.
ok('the vaccination schedule is in the entry chunk, which the briefing needs', main.includes('DHP / DAPP'))
ok('the shop catalogue is still in the entry chunk, as decided', main.includes('Facial Fold Wipes'))

console.log('\nThe lazy routes are still lazy')
for (const name of ['HealthFile', 'SomethingWrong', 'AteSomething', 'Attach', 'DataCovenant', 'MetricsDashboard', 'SitterCard']) {
  ok(`${name} has its own chunk`, assets.some((f) => f.startsWith(`${name}-`) && f.endsWith('.js')))
}

console.log(`\n${failures === 0 ? 'bundle verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
