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

// ACQUISITION-ONBOARDING-PLAN, AO1: a first visit to the bare site meets a
// front door — what this is, and one thing to do — not somebody else's dog.
console.log('\nThe front door')
await page.goto(BASE, { waitUntil: 'networkidle' })
await page.evaluate(() => localStorage.clear())
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(500)
let door = await page.locator('body').innerText()
ok('a first visit says what this is', /Your pet’s plan for life/.test(door) && /do not need an account/.test(door))
ok('and is not somebody else\'s dog', !/Max's day/.test(door))
ok('with one primary action', (await page.getByRole('button', { name: 'Add your dog or cat' }).count()) === 1)
ok('sign-in is in the header', (await page.locator('header').getByRole('button', { name: 'Sign in' }).count()) === 1)
await page.getByRole('button', { name: 'See an example first' }).click()
await page.waitForTimeout(700)
ok('"see an example" opens the demo', /Max's day/.test(await page.locator('body').innerText()))
await page.goto(BASE, { waitUntil: 'networkidle' })
await page.waitForTimeout(600)
ok('and it is shown once — a return visit goes where you were', /Max's day/.test(await page.locator('body').innerText()))
await page.evaluate(() => localStorage.clear())
await page.goto(`${BASE}/#/demo`, { waitUntil: 'networkidle' })
await page.waitForTimeout(600)
ok('the investor link, #/demo, skips it and opens Max', /Max's day/.test(await page.locator('body').innerText()))

console.log('\nTier 0 — five questions to the reveal')
await page.evaluate(() => localStorage.clear())
await page.goto(BASE, { waitUntil: 'networkidle' })
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(500)

const started = Date.now()
await page.getByRole('button', { name: 'Add your dog or cat' }).click()
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

// AO2: the plan exists only in this browser, and now it says so.
console.log('\nThe save moment')
const save = page.locator('section', { has: page.locator('#save-life') })
ok('after the reveal, it asks to keep the plan', (await save.count()) === 1)
ok('and says why — it lives only in this browser', /only in this browser/.test(await save.innerText()))
ok('and that no card is needed', /No card needed/.test(await save.innerText()))
await save.getByRole('button', { name: /Keep Pepper/ }).click()
await page.waitForTimeout(400)
ok('"keep" opens sign-in', /Sign in to Clovara/.test(await page.locator('[role="dialog"]').innerText().catch(() => '')))
await page.keyboard.press('Escape')
await page.locator('[role="dialog"]').getByRole('button', { name: 'Not now' }).click().catch(() => {})
await page.waitForTimeout(300)
await save.getByRole('button', { name: 'Not now' }).click()
await page.waitForTimeout(300)
ok('"not now" puts it away', (await page.locator('#save-life').count()) === 0)

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
