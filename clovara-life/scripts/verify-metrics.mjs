/**
 * The four numbers SPEC §4.3 names, proven to actually be measured.
 *
 * `phaseMetrics.test.ts` proves the arithmetic given events. This proves the
 * events exist — which is the half that rots silently, because a funnel that
 * stopped emitting looks exactly like a funnel nobody converted on.
 *
 * It reads the analytics queue out of localStorage rather than Firestore: the
 * queue is what `flush()` later writes verbatim, and reading it needs no
 * emulator, no sign-in and no admin.
 */
import { chromium } from 'playwright'

const BASE = process.env.BASE || 'http://127.0.0.1:4173'
let failures = 0
const ok = (label, cond, detail = '') => {
  if (cond) console.log(`  ✓ ${label}`)
  else {
    failures++
    console.log(`  ✗ ${label}${detail ? ' — ' + detail : ''}`)
  }
}

const browser = await chromium.launch()
const ctx = await browser.newContext({ viewport: { width: 1100, height: 950 } })
const page = await ctx.newPage()
const errors = []
page.on('pageerror', (e) => errors.push(String(e)))
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()))

const queue = () =>
  page.evaluate(() => JSON.parse(localStorage.getItem('clovara-life.events.v1') || '[]'))
const named = async (name) => (await queue()).filter((e) => e.name === name)

console.log('\nA real onboarding, instrumented')
await page.goto(BASE, { waitUntil: 'networkidle' })
await page.evaluate(() => localStorage.clear())
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(500)

// Max's Life surface, looked at before anybody onboards — an investor demo.
// Its reveal must be recorded but NOT timed.
await page.goto(`${BASE}#/pet/demo-max/life`, { waitUntil: 'networkidle' })
await page.waitForTimeout(900)
const demoReveals = (await named('reveal_viewed')).filter((e) => e.props.pet_is_demo === true)
ok(
  'a demo pet reveal is recorded',
  demoReveals.length > 0,
  'no demo reveal seen; the switcher or routing may have changed',
)
ok(
  'but it is NOT timed — investors are not an onboarding',
  // Guarded: `every` on an empty array is true, and a check that passes
  // because nothing happened is worse than no check.
  demoReveals.length > 0 && demoReveals.every((e) => e.props.ms_to_reveal === undefined),
  JSON.stringify(demoReveals.map((e) => e.props.ms_to_reveal)),
)
const demoScores = (await named('accuracy_score')).filter((e) => e.props.pet_is_demo === true)
ok(
  'the demo pet is scored too, and flagged so the metrics can drop it',
  demoScores.length > 0 && demoScores.every((e) => e.props.pet_is_demo === true),
)

await page.goto(BASE, { waitUntil: 'networkidle' })
await page.waitForTimeout(400)

const startedAt = Date.now()
await page.getByRole('button', { name: /Add a pet/ }).first().click()
await page.waitForTimeout(300)
await page.getByRole('radio', { name: 'A dog' }).click()
await page.getByRole('button', { name: 'Continue' }).click()
await page.waitForTimeout(250)
await page.getByLabel('Search breeds').fill('Beagle')
await page.waitForTimeout(300)
await page.getByRole('button', { name: /^Beagle/ }).first().click()
await page.getByRole('button', { name: 'Continue' }).click()
await page.waitForTimeout(250)
await page.getByLabel('Their name').fill('Pepper')
await page.getByRole('button', { name: 'Continue' }).click()
await page.waitForTimeout(250)
await page.getByRole('button', { name: 'Continue' }).click()
await page.waitForTimeout(250)
await page.getByRole('radio', { name: 'Female' }).click()
await page.getByRole('button', { name: /See Pepper's plan/ }).click()
await page.waitForTimeout(1000)
const wallClock = Date.now() - startedAt

console.log('\nTime to reveal')
const timed = (await named('reveal_viewed')).filter((e) => typeof e.props.ms_to_reveal === 'number')
ok('the reveal that followed onboarding is timed', timed.length === 1, `${timed.length} timed reveals`)
const ms = timed[0]?.props.ms_to_reveal
ok(
  `it measures the onboarding, not the page load (${(ms / 1000).toFixed(1)}s vs ${(wallClock / 1000).toFixed(1)}s of automation)`,
  ms > 500 && ms <= wallClock + 500,
  String(ms),
)

console.log('\nTier-1 answers')
await page.locator('button[aria-label*="light pressure"]').click()
await page.waitForTimeout(700)
await page.getByRole('button', { name: 'None that I know of' }).click()
await page.waitForTimeout(700)

const t1 = await named('tier1_field_added')
const fields = t1.map((e) => e.props.field)
ok('answering a silhouette records the field', fields.includes('weightLb'), fields.join(','))
ok('answering conditions records the field', fields.includes('conditionIds'), fields.join(','))
ok('the events are marked as a real pet, not a demo', t1.every((e) => e.props.pet_is_demo === false))
ok(
  'every Tier-1 event carries a field name, so the metric can count distinct ones',
  t1.length > 0 && t1.every((e) => typeof e.props.field === 'string' && e.props.field.length > 0),
)

console.log('\nAccuracy score')
const scores = (await named('accuracy_score')).filter((e) => e.props.pet_is_demo === false)
ok('a score is recorded for the new pet', scores.length > 0)
ok(
  'scores are numbers in range',
  scores.every((e) => typeof e.props.score === 'number' && e.props.score >= 0 && e.props.score <= 100),
  JSON.stringify(scores.map((e) => e.props.score)),
)
ok(
  `it is banded, not one per tap (${scores.length} scores for ${t1.length} answers)`,
  scores.length <= t1.length + 1,
)
const rising = scores.map((e) => e.props.score)
ok(
  'and it climbs as answers land',
  rising.length < 2 || rising[rising.length - 1] > rising[0],
  JSON.stringify(rising),
)

console.log('\nThe Data Covenant, on the analytics path')
const all = await queue()
const blob = JSON.stringify(all.map((e) => e.props))
ok('no pet name is in any event', !/Pepper|Max|Winston|Luna/i.test(blob), blob.slice(0, 200))
ok('no email address is in any event', !/@/.test(blob))
ok(
  'no free text at all — every prop is a scalar we chose',
  all.length > 0 &&
    all.every((e) =>
    Object.values(e.props).every(
        (v) => v === null || ['string', 'number', 'boolean'].includes(typeof v),
      ),
    ),
)
ok(
  'every event carries a visitor and a session, or none of the four metrics can be computed',
  all.length > 0 && all.every((e) => !!e.visitorId && !!e.sessionId && !!e.at),
)

ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'metrics verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
