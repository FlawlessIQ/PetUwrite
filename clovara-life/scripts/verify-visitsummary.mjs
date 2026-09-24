/**
 * C0 — the vet-visit summary (SPEC-COMPANION §9), on the screen.
 *
 * Most of what is checked is what it must NOT say. This is the one surface that
 * will be read by somebody qualified, standing next to the animal, and the
 * failure mode is not a bad experience — it is a clinician acting on something
 * we implied and could not support.
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
const ctx = await browser.newContext({
  viewport: { width: 390, height: 844 },
  permissions: ['clipboard-read', 'clipboard-write'],
})
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
      id: 'pet-vs',
      name: 'Scout',
      species: 'dog',
      breedId: 'labrador-retriever',
      birthDate: '2019-04-02',
      sex: 'female',
      weightLb: 68,
      conditionIds: [],
      knownSince: new Date(Date.now() - 300 * 86400000).toISOString(),
      ...over,
    },
  )
  await page.reload({ waitUntil: 'networkidle' })
  await page.waitForTimeout(1200)
}

const panel = () => page.locator('section[aria-labelledby="visit-heading"]')

console.log('\nIt is in the health file, where records live')
await seed()
ok('the summary is there', (await panel().count()) === 1)
let t = await panel().innerText()
ok('it says what it is for', /on one page/i.test(t))
ok(
  'the caveat is above the facts, not buried',
  /None of it has been examined or verified by a vet/i.test(t),
)
ok('and it explains what a blank means', /not that the answer is no/i.test(t))

console.log('\nCopy is the primary action')
const copyBtn = panel().getByRole('button', { name: /Copy for the vet/ })
ok('copy is offered first', (await copyBtn.count()) === 1)
await copyBtn.click()
await page.waitForTimeout(600)
ok('it confirms', /Copied/.test(await panel().innerText()))
const clip = await page.evaluate(() => navigator.clipboard.readText())
ok(`something real was copied (${clip.length} chars)`, clip.length > 300)
ok('it is plain text a practice system can take', !/<[a-z]/i.test(clip))
ok('headed with the pet', /^Scout — Labrador Retriever/.test(clip), clip.slice(0, 60))
ok('and it carries the notes', /NOTES/.test(clip))

console.log('\nWhat the copied text must never contain')
ok('no healthy-years projection', !/healthy years/i.test(clip))
ok('no range that could read as a prognosis', !/\d+\.\d\s*–\s*\d+\.\d/.test(clip))
ok(
  'no interpretation',
  !/\b(consistent with|suggests|likely|probably|recommend|rule out|differential)\b/i.test(clip),
)
ok('no dose or drug shorthand', !/\b(\d+\s*(mg|ml)|BID|SID)\b/i.test(clip))
ok('it says the projection is deliberately absent', /not a prognosis for this animal/i.test(clip))

console.log('\nUnanswered questions are shown as unanswered')
ok('"Not asked" appears rather than a blank', /Not asked/.test(clip))
ok(
  'and an empty condition list is not a negative history',
  /not a negative history/i.test(clip),
  clip.slice(0, 200),
)

console.log('\nWith a real history')
await seed({
  conditionIds: ['hip-dysplasia'],
  conditionsReviewed: true,
  bodyConditionScore: 4,
  activity: 'low',
  dental: 'rarely',
  neutered: true,
  vaccineRecords: [
    { doseId: 'dog-dhp-1', givenOn: '2019-06-01' },
    { doseId: 'dog-dhp-2', givenOn: '2019-07-01' },
  ],
  careNotes: { meds: 'Half a tablet with breakfast' },
})
await panel().getByRole('button', { name: /Copy for the vet/ }).click()
await page.waitForTimeout(600)
const full = await page.evaluate(() => navigator.clipboard.readText())
ok('the declared condition is named', /hip dysplasia/i.test(full))
ok('vaccinations appear with dates, oldest first', full.indexOf('1 June 2019') < full.indexOf('1 July 2019'))
ok('medication carries over from the sitter card', /Half a tablet with breakfast/.test(full))
ok('body condition is flagged as not a clinical BCS', /not a clinical BCS/i.test(full))
ok(
  'the condition is filed under "Already on file", not loose in the text',
  /ALREADY ON FILE[\s\S]{0,120}Hip dysplasia/i.test(full),
  full.slice(full.search(/ALREADY ON FILE/i), full.search(/ALREADY ON FILE/i) + 80),
)
ok('provenance is on the lines', /\(owner said\)/.test(full))

console.log('\nThe route must open the right animal, however you arrive')
// A bookmark, an in-app tap, and a URL pasted into an already-open tab all
// have to land on the same pet. The third used to land on a demo pet —
// somebody else's animal — because it changed the hash without a reload.
for (const [how, nav] of [
  ['cold load', async () => { await page.goto(`${BASE}#/health/pet-vs`, { waitUntil: 'networkidle' }) }],
  ['reload with the hash set', async () => { await page.evaluate(() => { window.location.hash = '#/health/pet-vs' }); await page.reload({ waitUntil: 'networkidle' }) }],
  ['hash change with no reload', async () => {
      await page.evaluate(() => { window.location.hash = '#/pet/demo-max/life' })
      await page.waitForTimeout(700)
      await page.goto(`${BASE}#/health/pet-vs`, { waitUntil: 'networkidle' })
  }],
]) {
  await nav()
  await page.waitForTimeout(1400)
  const heading = await page.locator('h1').first().innerText().catch(() => '')
  ok(`${how}: opens Scout, not a demo pet`, /Scout/.test(heading), heading)
}

console.log('\nReading it before sending it')
await seed({ conditionIds: ['hip-dysplasia'], conditionsReviewed: true })
await panel().getByRole('button', { name: /Read it first/ }).click()
await page.waitForTimeout(400)
t = await panel().innerText()
ok('the whole thing can be read on screen', /Who they are/i.test(t) && /Day to day/i.test(t))
ok('provenance is visible per line', /owner said/i.test(t))

const overflow = await page.evaluate(
  () => document.documentElement.scrollWidth > window.innerWidth + 1,
)
ok('no sideways scroll at 390px', !overflow)
ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'visit summary verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
