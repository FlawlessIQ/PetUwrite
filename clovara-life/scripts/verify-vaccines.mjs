/**
 * Vaccine Autopilot (SPEC §6.4), on the screen.
 *
 * This is the most clinically adjacent surface in the product, so most of what
 * is checked here is what it must NOT say: never that a pet is overdue, never
 * that a pet is protected, and never a schedule presented as ours rather than
 * their vet's.
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

const weeksOld = (w) => new Date(Date.now() - w * 7 * 86400000).toISOString().slice(0, 10)
const seed = async (over) => {
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await page.evaluate(
    (pet) => {
      localStorage.clear()
      localStorage.setItem('clovara-life.pets.v1', JSON.stringify([pet]))
      // Lives in the Health File since the Life surface was slimmed — it is a
      // record you go and look at, not something that should meet you.
      window.location.hash = `#/health/${pet.id}`
    },
    {
      id: 'pet-vx',
      name: 'Scout',
      species: 'dog',
      breedId: 'labrador-retriever',
      birthDate: weeksOld(8),
      sex: 'female',
      weightLb: 0,
      conditionIds: [],
      ...over,
    },
  )
  await page.reload({ waitUntil: 'networkidle' })
  await page.waitForTimeout(900)
}
const panel = () => page.locator('section[aria-labelledby="vaccines-heading"]')
const stored = () =>
  page.evaluate(() => JSON.parse(localStorage.getItem('clovara-life.pets.v1') || '[]')[0])

console.log('\nAn eight-week-old puppy')
await seed({})
ok('the schedule is shown', (await panel().count()) === 1)
let t = await panel().innerText()
ok('it says the first dose is usually around now', /usually given/i.test(t), t.slice(0, 120))
ok('it names the core dog vaccine', /DHP|DAPP/.test(t))
ok('it does not schedule a lifestyle vaccine', !/Leptospirosis.*(Usually now|Later)/s.test(t))

console.log('\nWhose decision this is')
ok('the disclaimer is above the schedule, not buried', /your vet sets the schedule/i.test(t))
ok('it explains why — brands, disease pressure, law', /brands differ/i.test(t))
ok('rabies is flagged as depending on local law', /depends on local law/i.test(t))
ok('non-core vaccines appear only as questions to ask', /worth asking your vet/i.test(t))
ok('and leptospirosis is one of them', /Leptospirosis/.test(t))

console.log('\nWhat it must never say')
ok('never "overdue"', !/overdue/i.test(t))
ok('never that the pet is protected or immune', !/\b(protected|immune|fully covered)\b/i.test(t))
ok('never a dose, a volume or a route', !/\b(\d+\s*(ml|mg)|subcutaneous|intranasal)\b/i.test(t))

console.log('\nRecording what actually happened')
await panel().getByRole('button', { name: 'Record' }).first().click()
await page.waitForTimeout(300)
const input = panel().locator('input[type="date"]').first()
ok('it asks for a date', (await input.count()) === 1)
const max = await input.getAttribute('max')
ok('and refuses a date in the future', max === new Date().toISOString().slice(0, 10), String(max))
await input.fill('2026-09-01')
await panel().getByRole('button', { name: 'Save' }).click()
await page.waitForTimeout(600)
t = await panel().innerText()
ok('it records as given', /Recorded/.test(t))
ok('and shows the date back in plain words', /1 September 2026/.test(t), t.slice(0, 300))

const after = await stored()
ok(
  'it is stored against the dose id',
  Array.isArray(after.vaccineRecords) && after.vaccineRecords[0].doseId.startsWith('dog-'),
  JSON.stringify(after.vaccineRecords),
)
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(900)
ok('it survives a reload', /Recorded/.test(await panel().innerText()))

console.log('\nCorrecting a mistake')
await panel().getByRole('button', { name: 'Change' }).first().click()
await page.waitForTimeout(300)
await panel().getByRole('button', { name: 'Remove' }).click()
await page.waitForTimeout(600)
ok('a record can be taken back', !/Recorded/.test(await panel().innerText()))

console.log('\nA puppy past the usual window')
await seed({ birthDate: weeksOld(22) })
t = await panel().innerText()
ok('it says the window has passed', /window/i.test(t))
ok(
  'and asks rather than accuses',
  /if Scout has already had these, record them/i.test(t),
  t.slice(0, 200),
)
ok('still never the word overdue', !/overdue/i.test(t))

console.log('\nA kitten gets the cat course')
await seed({ species: 'cat', breedId: 'domestic-shorthair', name: 'Pip' })
t = await panel().innerText()
ok('FVRCP, not DHP', /FVRCP/.test(t) && !/DHP/.test(t))
ok('and feline leukaemia is a question, not a schedule', /leukaemia/i.test(t))

console.log('\nAn adult with nothing recorded')
await seed({ birthDate: weeksOld(300) })
ok('the primary course is not shown forever', (await panel().count()) === 0)

const overflow = await page.evaluate(
  () => document.documentElement.scrollWidth > window.innerWidth + 1,
)
ok('no sideways scroll at 390px', !overflow)
ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'vaccines verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
