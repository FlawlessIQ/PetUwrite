/**
 * Second opinion (SPEC-HORIZON §1.3) and meds autopilot (§1.4), on the screen.
 *
 * Both are features defined by a line they will not cross: one never suggests a
 * vet's recommendation is wrong, the other never says what to give.
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
      window.location.hash = `#/health/${pet.id}`
    },
    {
      id: 'pet-c',
      name: 'Scout',
      species: 'dog',
      breedId: 'labrador-retriever',
      birthDate: '2015-04-02',
      sex: 'female',
      weightLb: 68,
      conditionIds: ['hip-dysplasia'],
      knownSince: new Date(Date.now() - 400 * 86400000).toISOString(),
      careNotes: { meds: 'Half a joint tablet with breakfast' },
      ...over,
    },
  )
  await page.reload({ waitUntil: 'networkidle' })
  await page.waitForTimeout(1300)
}

const so = () => page.locator('section[aria-labelledby="opinion-heading"]')
const md = () => page.locator('section[aria-labelledby="meds-heading"]')

console.log('\nSECOND OPINION — questions, never doubts')
await seed()
ok('it is in the health file', (await so().count()) === 1)
let t = await so().innerText()
ok('nothing is stored or sent', /Nothing is stored and nothing is sent anywhere/i.test(t))

await so().getByLabel(/What were you told about Scout/i).fill(
  'They have recommended surgery on her cruciate, about £4,800. My insurance should cover it.',
)
await so().getByRole('button', { name: /What should I ask/ }).click()
await page.waitForTimeout(500)
t = await so().innerText()
ok('it leads with "what if we do nothing"', /What happens if we do nothing/i.test(t))
ok('it asks about the anaesthetic, because surgery was mentioned', /anaesthetic risks at their age/i.test(t))
ok('and about pre-authorisation, because insurance was', /pre-authorise this with my insurer/i.test(t))
ok('it asks what is included in the price', /included in that price/i.test(t))
ok('it raises the condition already on record', /hip dysplasia/i.test(t))
ok('and the medication they are on', /Half a joint tablet/i.test(t))
ok('and their age, for an older dog', /worth saying out loud/i.test(t))

console.log('\n  the line it will not cross')
ok('it says these are questions, not doubts', /questions, not doubts/i.test(t))
ok(
  'it never suggests the recommendation is wrong',
  !/\b(unnecessary|not needed|do not need|overpriced|too expensive|avoid|push back)\b/i.test(t),
  t.slice(0, 200),
)
ok('it refuses to judge the price, and says why', /do not tell you whether the price is fair/i.test(t))
ok(
  'and it offers no clinical view of its own',
  !/\b(we think|we would say|in our view|it is probably|sounds like)\b/i.test(t),
)

console.log('\nMEDS — a record, never advice')
t = await md().innerText()
ok('it is there', (await md().count()) === 1)
ok('it says we do not check the prescription', /we do not check it/i.test(t))
ok('and will never tell you to change it', /never tell you to change it/i.test(t))
ok('a missed dose goes to the vet', /ask your vet what to do about it/i.test(t))
ok('with no general answer offered', /no general answer/i.test(t))

await md().getByRole('button', { name: /Add a medication/ }).click()
await page.waitForTimeout(300)
await md().getByLabel(/What is it called/i).fill('Metacam')
await md().getByLabel(/What were you told to give/i).fill('Half a tablet with food')
// UAT run 1, D18: "Twice a day" was preselected and saved unnoticed.
ok('no frequency is chosen for you', (await md().locator('button[aria-pressed="true"]').count()) === 0)
ok('and it will not save without one', await md().getByRole('button', { name: 'Save' }).isDisabled())
await md().getByRole('button', { name: 'Twice a day' }).click()
await md().getByLabel(/How many were dispensed/i).fill('8')
await md().getByRole('button', { name: 'Save' }).click()
await page.waitForTimeout(700)
t = await md().innerText()
ok('it records what was typed, verbatim', /Half a tablet with food/.test(t))
ok('and counts what is left', /4 days left, by your count/i.test(t))
ok('attributing the count to the owner', /by your count/i.test(t))

await md().getByRole('button', { name: /Given just now/ }).click()
await page.waitForTimeout(600)
t = await md().innerText()
ok('a dose can be logged', /1 of 2 today/.test(t))
const stored = await page.evaluate(
  () => JSON.parse(localStorage.getItem('clovara-life.pets.v1'))[0].medications[0],
)
ok('it persists', Array.isArray(stored.given) && stored.given.length === 1)
ok(
  'and records WHEN but never WHO',
  !JSON.stringify(stored).match(/uid|loggedBy|givenBy/i),
  JSON.stringify(stored).slice(0, 140),
)
await md().getByRole('button', { name: /Undo the last one/ }).click()
await page.waitForTimeout(600)
ok('a mis-tap can be undone', /0 of 2 today/.test(await md().innerText()))

console.log('\n  running out')
await seed({
  medications: [
    { id: 'm1', name: 'Metacam', amount: 'Half a tablet', frequency: 'twice', startedOn: new Date().toISOString(), quantity: 6, given: [] },
  ],
})
t = await md().innerText()
ok('it warns when a course is nearly done', /3 days left/i.test(t))
ok('and says repeat prescriptions are not always same-day', /not always same-day/i.test(t))
ok('never telling anybody what to give', !/\b(give \d|take \d|\d+\s*(mg|ml)|dose of)\b/i.test(t))

console.log('\nBoth go quiet when a pet has died')
await seed({ diedOn: new Date(Date.now() - 10 * 86400000).toISOString() })
ok('the medication list is gone', (await md().count()) === 0)
ok('and so is second opinion', (await so().count()) === 0)

const overflow = await page.evaluate(
  () => document.documentElement.scrollWidth > window.innerWidth + 1,
)
ok('no sideways scroll at 390px', !overflow)
ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'C1 + C2 verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
