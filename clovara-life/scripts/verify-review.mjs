/**
 * The annual re-projection (SPEC §4.3), driven as someone meets it.
 *
 * The engine tests prove when a review is due and what it contains. This proves
 * the thing a pure test cannot: that it appears for a pet who is due one, that
 * "this changed" lands you on the question rather than a dead end, and that
 * finishing it actually stops it coming back — a yearly prompt that reappears
 * on every load is worse than no yearly prompt.
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

const ago = (days) => new Date(Date.now() - days * 86_400_000).toISOString()
const PET_ID = 'pet-review-test'

const seed = async (extra) => {
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await page.evaluate(
    ([id, pet]) => {
      localStorage.clear()
      localStorage.setItem('clovara-life.pets.v1', JSON.stringify([pet]))
      window.location.hash = `#/pet/${id}/life`
    },
    [
      PET_ID,
      {
        id: PET_ID,
        name: 'Rosie',
        species: 'dog',
        breedId: 'labrador-retriever',
        birthDate: '2019-05-01',
        sex: 'female',
        weightLb: 70,
        bodyConditionScore: 3,
        conditionIds: [],
        conditionsReviewed: true,
        activity: 'moderate',
        dental: 'weekly',
        neutered: true,
        ...extra,
      },
    ],
  )
  await page.reload({ waitUntil: 'networkidle' })
  await page.waitForTimeout(900)
}

const review = () => page.locator('section[aria-labelledby="review-heading"]')
const stored = () =>
  page.evaluate(() => JSON.parse(localStorage.getItem('clovara-life.pets.v1') || '[]')[0])

console.log('\nA pet who is not due one')
await seed({ knownSince: ago(200) })
ok('no review is shown', (await review().count()) === 0)

console.log('\nA pet who is')
await seed({ knownSince: ago(400), lastReviewedRange: { low: 10.4, high: 13.2 } })
ok('the review appears', (await review().count()) === 1)
const text = await review().innerText()
ok('it is headed with the pet, not with us', /A year with Rosie/.test(text), text.slice(0, 80))
ok('it says what we said last year', /10\.4–13\.2/.test(text), text.slice(0, 300))
ok(
  'it explains the change by age rather than blaming the owner',
  /a year older/.test(text) && !/should have|you did not|failed/i.test(text),
)
ok('body condition is asked first', /Has their shape changed\?/.test(text))
ok(
  'a neutered pet is not asked again about neutering',
  !/Neutered or spayed since\?/.test(text),
)
ok('a dog is not asked the cat question', !/get out as much/.test(text))
ok(
  'every item says why, about the animal',
  /moves the projection more than anything else/.test(text) &&
    !/up to date|our records/i.test(text),
)

console.log('\nStill true')
const before = await review().getByRole('button', { name: 'Still true' }).count()
ok(`every item offers "still true" (${before} of them)`, before >= 4)
await review().getByRole('button', { name: 'Still true' }).first().click()
await page.waitForTimeout(400)
ok(
  'confirming one leaves the rest',
  (await review().getByRole('button', { name: 'Still true' }).count()) === before - 1,
)
ok('and says so', /Thank you — noted/.test(await review().innerText()))

console.log('\nThis changed')
await review().getByRole('button', { name: 'This changed' }).first().click()
await page.waitForTimeout(600)
const sharpen = page.locator('section[aria-labelledby="sharpen-heading"]')
ok(
  '"this changed" opens the real question instead of a dead end',
  (await sharpen.locator('button[aria-label*="Ribs"]').count()) === 5 ||
    /Anything already diagnosed/.test(await sharpen.innerText()),
  (await sharpen.innerText()).slice(0, 160),
)

console.log('\nFinishing')
// UAT run 1, D8: "none of them required" sat under a Done that stayed
// disabled until every item was answered. Done now works at any point.
ok(
  'Done works before every item is handled — none of them are required',
  !(await review().getByRole('button', { name: /^Done$/ }).isDisabled()),
)
for (let i = 0; i < 10; i++) {
  const b = review().getByRole('button', { name: 'Still true' })
  if ((await b.count()) === 0) break
  await b.first().click()
  await page.waitForTimeout(250)
}
const doneBtn = review().getByRole('button', { name: /^Done$/ })
await doneBtn.click()
await page.waitForTimeout(700)

ok('the review goes away', (await review().count()) === 0)
const after = await stored()
ok('the review date was written', !!after.lastReviewedAt, JSON.stringify(after.lastReviewedAt))
ok(
  'and the range, so next year has something to compare against',
  !!after.lastReviewedRange && Number.isFinite(after.lastReviewedRange.low),
  JSON.stringify(after.lastReviewedRange),
)

await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(900)
ok('it does not come back on reload', (await review().count()) === 0)

console.log('\nNot now')
await seed({ knownSince: ago(400) })
await review().getByRole('button', { name: 'Not now' }).click()
await page.waitForTimeout(400)
ok('"Not now" dismisses it', (await review().count()) === 0)
ok('without writing a review date', !(await stored()).lastReviewedAt)
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(900)
ok(
  'and it is offered again next visit, rather than never again',
  (await review().count()) === 1,
)

// UAT run 1, D7: "Still true" was offered for questions nobody had put.
// JSON drops undefined, so this Rosie has never been asked about her teeth.
console.log('\nA question never asked')
await seed({ knownSince: ago(400), dental: undefined })
let r = await review().innerText()
ok('it says so, and asks it as a first question (UAT run 2, N2)', /Are their teeth cleaned at home\?[\s\S]*we have never asked/.test(r) && !/Has the teeth routine changed/.test(r))
ok('and offers "Answer it", not "Still true"', (await review().getByRole('button', { name: 'Answer it' }).count()) === 1)
ok('with every other item still confirmable', (await review().getByRole('button', { name: 'Still true' }).count()) >= 3)
await review().getByRole('button', { name: 'Skip' }).click()
await page.waitForTimeout(300)
ok('skipping says "Skipped", not "noted"', /Skipped\./.test(await review().innerText()))
ok('and records nothing', (await stored()).dental === undefined)

ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'annual review verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
