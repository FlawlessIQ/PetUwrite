/**
 * How long the Life surface actually is (no SPEC section — this is a scar).
 *
 * Every P3 moment was built onto the Life page one at a time and verified
 * alone. Together they made it fifteen phone screens for a new puppy: somebody
 * reached the reveal in under sixty seconds and then hit a wall, and not one of
 * the fourteen other verification scripts could see it, because each checks a
 * single card.
 *
 * So this one checks the whole page, in the states that stack the most, with a
 * ceiling. The number is a budget, not a measurement — if a new surface pushes
 * past it, the question is what comes off, not what the limit should be.
 */
import { chromium } from 'playwright'

const BASE = process.env.BASE || 'http://127.0.0.1:4173'
const PHONE = 844

/**
 * A ceiling and a convergence target, rather than a budget per state — four
 * budgets would just be a curve fitted to today's numbers.
 *
 * The floor is 7.5–8.0 screens: the projection content alone, measured on the
 * demo pets, which render none of the P3 moments. That predates this work.
 *
 * Above it, length tracks how much is PENDING. A pet with six unanswered
 * questions is longer than one with none because there are six questions, and
 * it shrinks as they are answered — that is the incentive mechanic, not bloat.
 * First-Night Mode and the annual review are the same: large, and gone in days.
 *
 * So: nothing is ever over CEILING in any state, and once somebody has answered
 * the questions it must come back under SETTLED. The first number stops a new
 * surface being stacked on; the second stops the page being permanently long.
 */
const CEILING = 12
const SETTLED = 9.5

let failures = 0
const ok = (label, cond, detail = '') => {
  if (cond) console.log(`  ✓ ${label}`)
  else {
    failures++
    console.log(`  ✗ ${label}${detail ? ' — ' + detail : ''}`)
  }
}

const browser = await chromium.launch()
const ctx = await browser.newContext({ viewport: { width: 390, height: PHONE } })
const page = await ctx.newPage()
const errors = []
page.on('pageerror', (e) => errors.push(String(e)))

const wk = (n) => new Date(Date.now() - n * 7 * 86400000).toISOString().slice(0, 10)
const daysAgo = (n) => new Date(Date.now() - n * 86400000).toISOString()

const measure = async (label, pet, budget = CEILING, surface = 'life') => {
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await page.evaluate(
    ([p, s]) => {
      localStorage.clear()
      localStorage.setItem('clovara-life.pets.v1', JSON.stringify([p]))
      window.location.hash = s === 'life' ? `#/pet/${p.id}/life` : `#/${s}`
    },
    [pet, surface],
  )
  await page.reload({ waitUntil: 'networkidle' })
  await page.waitForTimeout(1600)
  const h = await page.evaluate(() => document.documentElement.scrollHeight)
  const screens = h / PHONE
  ok(
    `${label.padEnd(30)} ${screens.toFixed(1)} screens (budget ${budget})`,
    screens <= budget,
    `${Math.round(h)}px is over budget — the question is what comes off, not what the limit should be`,
  )
  return screens
}

const base = {
  id: 'pet-len',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  sex: 'female',
  weightLb: 0,
  conditionIds: [],
}

console.log('\nThe Life surface, in the states that stack the most')
// Worst case by construction: First-Night, the arrival window, a puppy with
// every Tier-1 question still unanswered.
await measure(
  'new puppy, hours old',
  { ...base, birthDate: wk(9), knownSince: daysAgo(0.08) },
  CEILING,
)
// Everything still unanswered: six open questions are six questions, and the
// page shrinks as they are answered.
await measure('puppy, nothing answered yet', { ...base, birthDate: wk(11), knownSince: daysAgo(20) })
// Once a year, for about a week.
await measure('adult, annual review due', {
  ...base,
  birthDate: '2019-04-02',
  weightLb: 68,
  knownSince: daysAgo(800),
})
// The one that must converge: nothing pending, nothing transient.
await measure(
  'adult, everything answered',
  {
    ...base,
    birthDate: '2019-04-02',
    weightLb: 68,
    bodyConditionScore: 3,
    conditionsReviewed: true,
    activity: 'moderate',
    dental: 'weekly',
    neutered: true,
    knownSince: daysAgo(100),
    lastReviewedAt: new Date().toISOString(),
  },
  SETTLED,
)

console.log('\nThe demo pets, which are the floor and predate all of this')
for (const id of ['demo-max', 'demo-luna']) {
  await page.goto(`${BASE}#/pet/${id}/life`, { waitUntil: 'networkidle' })
  await page.waitForTimeout(1300)
  const h = await page.evaluate(() => document.documentElement.scrollHeight)
  ok(`${id.padEnd(30)} ${(h / PHONE).toFixed(1)} screens`, h / PHONE <= SETTLED)
}

console.log('\nWhat moved off it is reachable in one tap')
await page.goto(BASE, { waitUntil: 'networkidle' })
await page.evaluate((p) => {
  localStorage.clear()
  localStorage.setItem('clovara-life.pets.v1', JSON.stringify([p]))
  window.location.hash = `#/pet/${p.id}/life`
}, { ...base, birthDate: wk(11), knownSince: daysAgo(20) })
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(1200)
const link = page.locator('a[href^="#/health/"]')
ok('the Life surface links to the health file, naming the pet', (await link.count()) === 1)
const summary = await link.innerText()
ok(
  'and the line says what is in it, so it is worth tapping',
  /vaccination|firsts|sitter/i.test(summary),
  summary,
)
await link.click()
await page.waitForTimeout(1200)
const file = await page.locator('body').innerText()
ok('vaccinations moved there', /Vaccinations/i.test(file))
ok('the passport moved there', /Passport/i.test(file))
ok('sitter mode moved there', /Sitter mode/i.test(file))
ok('and it says the projection does not use any of it', /does not use anything from this page/i.test(file))

console.log('\nWhat stayed on Life, because it is only true for a few days')
await page.goto(BASE, { waitUntil: 'networkidle' })
await page.evaluate((p) => {
  localStorage.clear()
  localStorage.setItem('clovara-life.pets.v1', JSON.stringify([p]))
  window.location.hash = `#/pet/${p.id}/life`
}, { ...base, birthDate: wk(9), knownSince: daysAgo(0.08) })
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(1400)
const life = await page.locator('body').innerText()
ok('First-Night Mode is still on Life', /first night|first few hours/i.test(life))
ok('the sharpening questions are still on Life', /Sharpen|shape are they in/i.test(life))
ok('the Protect offer is still on Life', (await page.locator('a[href="#/protect"]').count()) >= 1)
ok('but the health file is a link, not three cards', !/Socialization|scratching post/i.test(life))

ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'length verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
