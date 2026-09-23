/**
 * "He ate a grape" (SPEC §6.5) — the highest-stakes screen in the product.
 *
 * Almost everything below is about ORDER and about what must never appear.
 * Somebody arriving here is frightened, will read the first thing, and will act
 * on it. The phone numbers and "do not make them sick" must come before the
 * lookup, and nothing must ever read as a clearance.
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
const ctx = await browser.newContext({ viewport: { width: 390, height: 844 } })
const page = await ctx.newPage()
const errors = []
page.on('pageerror', (e) => errors.push(String(e)))
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()))

const seed = async (over = {}) => {
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await page.evaluate(
    (pet) => {
      localStorage.clear()
      localStorage.setItem('clovara-life.pets.v1', JSON.stringify([pet]))
      window.location.hash = `#/pet/${pet.id}/home`
    },
    {
      id: 'pet-tx',
      name: 'Scout',
      species: 'dog',
      breedId: 'labrador-retriever',
      birthDate: '2021-04-02',
      sex: 'female',
      weightLb: 66,
      conditionIds: [],
      knownSince: new Date(Date.now() - 400 * 86400000).toISOString(),
      ...over,
    },
  )
  await page.reload({ waitUntil: 'networkidle' })
  await page.waitForTimeout(900)
}

console.log('\nGetting there fast')
await seed()
const entry = page.locator('a[href="#/ate"]')
ok('there is one tap from the home screen', (await entry.count()) === 1)
await entry.click()
await page.waitForTimeout(900)
let t = await page.locator('body').innerText()
ok('it opens', /ate something/i.test(t))

console.log('\nThe order of the page — what somebody reads first')
const body = await page.locator('body').innerText()
const iRing = body.search(/Ring your vet or a poison line now/i)
const iDiy = body.search(/Do not try to make them sick/i)
const iLookup = body.search(/What did they eat\?/i)
ok('"ring now" appears', iRing >= 0)
ok('"do not make them sick" appears', iDiy >= 0)
ok('both come BEFORE the lookup', iRing < iLookup && iDiy < iLookup, `${iRing}/${iDiy}/${iLookup}`)
ok('it says not to wait for signs', /do not wait for signs/i.test(body))
ok('it says to take the packet', /packet|wrapper|photograph/i.test(body))

console.log('\nThe phone numbers')
const tels = page.locator('a[href^="tel:"]')
ok(`poison lines are tap-to-call (${await tels.count()} of them)`, (await tels.count()) >= 3)
ok('each says a fee applies, rather than surprising somebody', (body.match(/fee/gi) || []).length >= 3)
ok(
  'the emergency-vet lookup is honest that it cannot search',
  /cannot look up/i.test(body) && !/no results|nothing nearby/i.test(body),
)

console.log('\nWhat it must never say')
ok('never tells anybody to induce vomiting', !/induce vomiting|hydrogen peroxide|salt water/i.test(body))
ok('never a milligram figure', !/\d+\s*mg/i.test(body))

console.log('\nA grape — no safe dose')
await page.getByPlaceholder(/grapes, chocolate/i).fill('raisin')
await page.waitForTimeout(400)
await page.getByRole('button', { name: /Grapes, raisins/ }).click()
await page.waitForTimeout(400)
t = await page.locator('body').innerText()
ok('it says ring now', /Ring now/.test(t))
ok('and explains there is no safe amount', /no amount of this treated as safe/i.test(t))
ok('it never asks how many, because it does not matter', !/how many grams/i.test(t))

console.log('\nChocolate — banded by kind and by size')
await page.getByRole('button', { name: 'Something else' }).click()
await page.waitForTimeout(300)
await page.getByPlaceholder(/grapes, chocolate/i).fill('chocolate')
await page.waitForTimeout(400)
await page.getByRole('button', { name: /^Chocolate/ }).click()
await page.waitForTimeout(400)
ok('it asks what kind', (await page.getByRole('button', { name: 'Baking or cocoa powder' }).count()) === 1)
t = await page.locator('body').innerText()
ok('with no amount given, it escalates rather than reassures', /Ring now/.test(t), t.slice(0, 400))

await page.getByRole('button', { name: 'White chocolate' }).click()
await page.getByLabel(/how many grams/i).fill('5')
await page.waitForTimeout(500)
t = await page.locator('body').innerText()
ok('a scrap of white chocolate for a 30kg dog is "watch closely"', /Watch closely/.test(t), t.slice(0, 300))
ok('and even then it is explicitly not a clearance', /not a clearance/i.test(t))
// Scoped to the verdict box: the page elsewhere legitimately says "a guess is
// fine" (the grams placeholder) and "that does not mean it is safe".
const verdict = await page
  .locator('div')
  .filter({ hasText: /^Watch closely/ })
  .last()
  .innerText()
ok(
  'the verdict itself never calls it safe or fine',
  !/\b(safe|fine|no need|nothing to worry|harmless)\b/i.test(verdict),
  verdict,
)

await page.getByRole('button', { name: 'Baking or cocoa powder' }).click()
await page.getByLabel(/how many grams/i).fill('120')
await page.waitForTimeout(500)
t = await page.locator('body').innerText()
ok('120g of baking chocolate for the same dog is "ring now"', /Ring now/.test(t))

console.log('\nSomething not on the list')
await page.getByRole('button', { name: 'Something else' }).click()
await page.waitForTimeout(300)
await page.getByPlaceholder(/grapes, chocolate/i).fill('zzzqqq')
await page.waitForTimeout(400)
t = await page.locator('body').innerText()
ok(
  'it does not say "no results" and stop',
  /does not mean it is safe/i.test(t),
  t.slice(0, 200),
)

console.log('\nA cat gets the lily')
await seed({ species: 'cat', breedId: 'domestic-shorthair', name: 'Pip', weightLb: 10 })
await page.locator('a[href="#/ate"]').click()
await page.waitForTimeout(800)
await page.getByPlaceholder(/grapes, chocolate/i).fill('lily')
await page.waitForTimeout(400)
ok('lilies are offered to a cat', (await page.getByRole('button', { name: /^Lily/ }).count()) === 1)
await page.getByRole('button', { name: /^Lily/ }).click()
await page.waitForTimeout(400)
t = await page.locator('body').innerText()
ok('and it is a ring-now, including pollen', /Ring now/.test(t) && /pollen/i.test(t))

const overflow = await page.evaluate(
  () => document.documentElement.scrollWidth > window.innerWidth + 1,
)
ok('no sideways scroll at 390px', !overflow)
ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'toxins verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
