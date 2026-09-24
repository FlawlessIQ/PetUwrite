/**
 * The morning briefing (SPEC-HORIZON §1.2), on the screen.
 *
 * The rule under test is that it never invents a reason. The empty state is the
 * feature, not a fallback: a briefing that finds something to say every day is
 * one people stop reading, and they stop before the day it matters.
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
const settled = {
  id: 'pet-b',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2019-04-02',
  sex: 'female',
  weightLb: 68,
  conditionIds: [],
  conditionsReviewed: true,
  bodyConditionScore: 3,
  activity: 'moderate',
  dental: 'weekly',
  neutered: true,
  knownSince: daysAgo(200),
  lastReviewedAt: daysAgo(10),
}

const seed = async (over = {}) => {
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await page.evaluate(
    (pet) => {
      localStorage.clear()
      localStorage.setItem('clovara-life.pets.v1', JSON.stringify([pet]))
      window.location.hash = `#/pet/${pet.id}/home`
    },
    { ...settled, ...over },
  )
  await page.reload({ waitUntil: 'networkidle' })
  await page.waitForTimeout(1200)
}

const panel = () => page.locator('section[aria-labelledby="briefing-heading"]')

console.log('\nA quiet morning — the empty state is the feature')
await seed()
ok('the briefing is on Home', (await panel().count()) === 1)
let t = await panel().innerText()
ok('it says there is nothing to do', /Nothing needs doing for Scout today/i.test(t))
ok('and says so as the headline, not as an apology', /Scout is all set/i.test(t))
ok(
  'it invents nothing to fill the space',
  !/\b(remember to|make sure you|did you know|top tip|why not|consider|it is important)\b/i.test(t),
  t.slice(0, 200),
)
ok('and is honest that there is no weather provider', /no provider connected/i.test(t))
ok('saying it would rather say less than guess', /one fewer thing than guess/i.test(t))

console.log('\nA morning with something in it')
await seed({
  medications: [
    { id: 'm1', name: 'Metacam', amount: 'Half a tablet', frequency: 'twice', startedOn: daysAgo(3), quantity: 4, given: [] },
  ],
})
t = await panel().innerText()
ok('the headline changes when something needs doing', /Scout today/i.test(t))
ok('medication leads, because it is the only thing that is genuinely today', /Half a tablet, 2 today/i.test(t))
ok('and it says the course is running out', /runs out in about 2 days/i.test(t))
ok('attributed to the owner, not to us', /by your count/i.test(t))
ok('the "nothing to do" line is gone', !/Nothing needs doing/i.test(t))

console.log('\nIt stops talking once the doses are logged')
await seed({
  medications: [
    { id: 'm1', name: 'Metacam', amount: 'Half a tablet', frequency: 'twice', startedOn: daysAgo(3), given: [new Date().toISOString(), new Date().toISOString()] },
  ],
})
t = await panel().innerText()
ok('no medication line once the day is done', !/Half a tablet/i.test(t))
ok('and it goes back to saying there is nothing', /Nothing needs doing/i.test(t))

console.log('\nOther things it knows about')
await seed({ knownSince: daysAgo(1000), lastReviewedAt: daysAgo(400) })
ok('the annual review appears when due', /five questions when you have a minute/i.test(await panel().innerText()))

await seed({
  lumps: [{ id: 'l', location: 'Left shoulder', firstSeen: daysAgo(90), photos: [{ url: 'u', fullPath: 'f', takenAt: daysAgo(40), sizeReference: 'A coin' }] }],
})
t = await panel().innerText()
ok('a stale lump photo is mentioned', /Left shoulder: last photographed 40 days ago/i.test(t))

await seed({
  lumps: [{ id: 'l', location: 'Left shoulder', firstSeen: daysAgo(90), photos: [] }],
})
ok(
  'but a lump nobody has photographed is never nagged about',
  !/Left shoulder/i.test(await panel().innerText()),
)

console.log('\nWhen a pet has died')
await seed({ diedOn: daysAgo(10) })
ok('there is no briefing at all', (await panel().count()) === 0)
ok(
  'not even "nothing to do today"',
  !/Nothing needs doing/i.test(await page.locator('body').innerText()),
)

const overflow = await page.evaluate(
  () => document.documentElement.scrollWidth > window.innerWidth + 1,
)
ok('no sideways scroll at 390px', !overflow)
ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'briefing verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
