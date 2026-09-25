/**
 * The defensive Remember pass (SPEC-HORIZON §2.5), on the screen.
 *
 * Every check is a silence. The four failures this prevents all ship in real
 * products today: a renewal notice, a reminder something is due, a suggestion
 * to buy, and a cheerful note about how they are doing — each arriving weeks
 * later from a system nobody told to stop.
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

const daysAgo = (n) => new Date(Date.now() - n * 86400000).toISOString()
const base = {
  id: 'pet-rem',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2018-09-24',
  sex: 'female',
  weightLb: 0,
  conditionIds: [],
  knownSince: daysAgo(1100),
}

const seed = async (over, hash = '#/pet/pet-rem/life') => {
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await page.evaluate(
    ([pet, h]) => {
      localStorage.clear()
      localStorage.setItem('clovara-life.pets.v1', JSON.stringify([pet]))
      window.location.hash = h
    },
    [{ ...base, ...over }, hash],
  )
  await page.reload({ waitUntil: 'networkidle' })
  // Wait for the pet's page to have actually rendered, not for a fixed time.
  // A flat 1.3s passed alone and failed under the full suite's load, reading
  // the page before the plan had drawn — a flake in this harness, not the app.
  await page
    .waitForFunction((name) => document.body.innerText.includes(name) && document.querySelectorAll('section').length > 1, [base.name], {
      timeout: 15000,
    })
    .catch(() => {})
  await page.waitForTimeout(400)
  return page.locator('body').innerText()
}

console.log('\nControl — everything is shouting while they are alive')
let t = await seed({})
ok('the plan is asking questions', /Sharpen|shape are they in/i.test(t))
ok('the annual review is due', /A year with Scout/i.test(t))
ok('the Protect offer is on the page', (await page.locator('a[href="#/protect"]').count()) >= 1)

console.log('\nAfter telling us')
t = await seed({ diedOn: daysAgo(20) })
ok('the record is still here, and it says so', /record is still here/i.test(t))
ok('it says nothing was deleted', /Nothing has been deleted, and nothing will be/i.test(t))
ok('and asks for nothing', /Nothing else is needed from you/i.test(t))

console.log('\nThe four failures')
ok('no question about how they are doing', !/Sharpen|shape are they in|how much do they move/i.test(t))
ok('no reminder that anything is due', !/\b(due|overdue|reminder|book|renew)\b/i.test(t), t.slice(0, 200))
ok('nothing is offered for sale', (await page.locator('a[href="#/protect"]').count()) === 0)
ok('no anniversary or arrival card', !/Gotcha Day|plan begins today/i.test(t))
// "Puppy" and "Senior" are life-stage labels on the arc — the record, not a
// suggestion. The test is about being sold a replacement.
ok(
  'and nothing suggests another animal',
  !/\b(another pet|new pet|second pet|adopt a|get a (puppy|kitten)|ready for another)\b/i.test(t),
)

console.log('\nThe home surface goes quiet too')
t = await seed({ diedOn: daysAgo(20) }, '#/pet/pet-rem/home')
ok('the nudge stops talking in the present', /record is still here/i.test(t))
ok('no activity story', !/activity is down|steps today|is down \d+%/i.test(t))
ok('and no present-tense framing of their week', !/\bthis week\b/i.test(t), t.slice(0, 160))

console.log('\nThe shop stops recommending')
t = await seed({ diedOn: daysAgo(20) }, '#/pet/pet-rem/shop')
ok(
  'nothing is recommended',
  !/Hip & Joint|chews|supplement|free bag/i.test(t),
  t.slice(0, 200),
)

console.log('\nThe record stays reachable')
t = await seed({ diedOn: daysAgo(20), lumps: [{ id: 'l1', location: 'Left shoulder', firstSeen: daysAgo(200), photos: [] }] }, '#/health/pet-rem')
ok('the health file opens', /Everything on record for Scout/i.test(t))
ok('the vet summary is still there', /on one page/i.test(t))
ok('the lump diary is still readable', /Left shoulder/i.test(t))
ok('but it no longer asks for photographs', !/Track something new|Open the camera/i.test(t))
ok('and no sitter link is offered', !/A link for whoever has Scout/i.test(t))

console.log('\nTelling us, and undoing it')
t = await seed({}, '#/health/pet-rem')
const tell = page.getByRole('button', { name: /Scout has died/ })
ok('the way to tell us is there, quietly', (await tell.count()) === 1)
await tell.click()
await page.waitForTimeout(300)
t = await page.locator('body').innerText()
ok('it explains what happens', /stops everything/i.test(t) && /Nothing is deleted/i.test(t))
ok('it asks only for a date', (await page.locator('#died-on').count()) === 1)
ok(
  'and nothing else — no cause, no reflection, no rating',
  // /cause/ alone matches "because", which is everywhere.
  // \brate\b, because "separately" contains "rate".
  !/cause of death|what happened|tell us more|how are you feeling|\brate\b|feedback|survey/i.test(t),
)
await page.locator('#died-on').fill(new Date(Date.now() - 86400000).toISOString().slice(0, 10))
await page.getByRole('button', { name: 'Save' }).click()
await page.waitForTimeout(700)
t = await page.locator('body').innerText()
ok('it takes effect', /record is still here/i.test(t))
ok('and it can be undone in one tap', (await page.getByRole('button', { name: /this was a mistake/i }).count()) === 1)
await page.getByRole('button', { name: /this was a mistake/i }).click()
await page.waitForTimeout(700)
ok('undo restores everything', !/record is still here/i.test(await page.locator('body').innerText()))

ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'remember pass verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
