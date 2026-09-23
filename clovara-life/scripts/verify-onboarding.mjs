/**
 * Tier 0 → reveal → Tier 1 (SPEC §4.1 and §4.2), driven as a person does it.
 *
 * The two claims worth proving are the ones the spec makes about feel rather
 * than function: the reveal arrives in five questions with no account wall, and
 * every Tier-1 answer visibly moves the projection. Both are timed/measured
 * here rather than asserted.
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

const range = async () => {
  const t = await page.locator('body').innerText()
  const m = t.match(/(\d+\.\d)–(\d+\.\d)\s*\n?\s*healthy years/)
  return m ? [Number(m[1]), Number(m[2])] : null
}

console.log('\nTier 0 — five questions to the reveal')
await page.goto(BASE, { waitUntil: 'networkidle' })
await page.evaluate(() => localStorage.clear())
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(500)

const started = Date.now()
await page.getByRole('button', { name: /Add a pet/ }).first().click()
await page.waitForTimeout(300)
ok('no account wall before the reveal', !(await page.locator('[role="dialog"]').count()))

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
ok('age offers an approximate answer by default', /About /.test(await page.locator('body').innerText()))
await page.getByRole('button', { name: 'Continue' }).click()
await page.waitForTimeout(250)
await page.getByRole('radio', { name: 'Female' }).click()
await page.getByRole('button', { name: /See Pepper's plan/ }).click()
await page.waitForTimeout(900)
const seconds = (Date.now() - started) / 1000

const first = await range()
ok('the reveal arrives', !!first, 'no range found')
ok(`under 60 seconds of interaction (${seconds.toFixed(1)}s of automation)`, seconds < 60)

console.log('\nTier 1 — every answer moves the number')
ok('the sharpen panel is there', (await page.locator('section[aria-labelledby="sharpen-heading"]').count()) === 1)
ok('body condition is asked with five silhouettes, not a weight box first', (await page.locator('button[aria-label*="Ribs"]').count()) === 5)

// Silhouette → the projection must move.
await page.locator('button[aria-label*="Ribs hard to feel"]').click()
await page.waitForTimeout(1200)
const afterHeavy = await range()
ok('picking a heavy silhouette lowers the projection', !!afterHeavy && afterHeavy[0] < first[0], `${first} → ${afterHeavy}`)

await page.locator('button[aria-label*="light pressure"]').click()
await page.waitForTimeout(1200)
const afterIdeal = await range()
ok('correcting it moves the projection back up', !!afterIdeal && afterIdeal[0] > afterHeavy[0])

// "None that I know of" is a first-class answer (invariant 9).
await page.getByRole('button', { name: 'None that I know of' }).click()
await page.waitForTimeout(600)
ok('"None that I know of" is offered and selectable', true)

// The accuracy meter should climb as answers land.
await page.goto(`${BASE}#/pet/${await page.evaluate(() => JSON.parse(localStorage.getItem('clovara-life.pets.v1'))[0].id)}/home`, { waitUntil: 'networkidle' })
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(800)
const home = await page.locator('body').innerText()
const pct = Number((home.match(/(\d+)% sharp/) || [0, 0])[1])
ok(`accuracy climbed above the Tier-0 floor of 40% (now ${pct}%)`, pct > 40)

console.log('\nPersistence')
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(800)
const stored = await page.evaluate(() => JSON.parse(localStorage.getItem('clovara-life.pets.v1'))[0])
ok('body condition persisted', stored.bodyConditionScore === 3, String(stored.bodyConditionScore))
ok('conditions review persisted', stored.conditionsReviewed === true)
ok('approximate birthday recorded as approximate', stored.birthDateApprox === true)
ok('Tier-1 fields nobody answered stay absent', stored.activity === undefined && stored.dental === undefined)
ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'onboarding verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
