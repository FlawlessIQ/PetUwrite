/**
 * First-Night Mode (SPEC §6.2), on the screen.
 *
 * The engine tests prove which block applies. This proves the thing that
 * matters at 2am: that somebody frightened does not have to expand anything to
 * find out whether to ring a vet.
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

const seed = async (over) => {
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await page.evaluate(
    (pet) => {
      localStorage.clear()
      localStorage.setItem('clovara-life.pets.v1', JSON.stringify([pet]))
      window.location.hash = `#/pet/${pet.id}/life`
    },
    {
      id: 'pet-fn',
      name: 'Scout',
      species: 'dog',
      breedId: 'labrador-retriever',
      birthDate: new Date(Date.now() - 9 * 7 * 86400000).toISOString().slice(0, 10),
      sex: 'female',
      weightLb: 0,
      conditionIds: [],
      ...over,
    },
  )
  await page.reload({ waitUntil: 'networkidle' })
  await page.waitForTimeout(900)
}

const panel = () => page.locator('section[aria-labelledby="first-night-heading"]')
const hoursAgo = (h) => new Date(Date.now() - h * 3600000).toISOString()

console.log('\nA nine-week-old, home two hours')
await seed({ knownSince: hoursAgo(2) })
ok('First-Night Mode is on', (await panel().count()) === 1)
let t = await panel().innerText()
ok('it says which hour they are in', /home about 2 hours/.test(t), t.slice(0, 120))
ok('it is the arrival block', /The first few hours/.test(t))
ok('it says what is normal, so nobody panics at normal', /Normal right now/.test(t))

console.log('\nThe part that matters at 2am')
ok('the escalation list is visible without expanding anything', /Call a vet now/.test(t))
ok(
  'it names the signs that are not settling problems',
  /vomiting/i.test(t) && /breathing/i.test(t) && /collapse/i.test(t) && /seizure/i.test(t),
)
ok('and says so in those words', /none of these are settling problems/i.test(t))
ok(
  'it never claims to replace a vet',
  /never replaces your own vet/i.test(t) && /information, not veterinary advice/i.test(t),
)
ok(
  'it does not diagnose or dose',
  !/\b(diagnos|prescrib|dosage|mg\b|antibiotic)\b/i.test(t),
)

console.log('\nReading ahead at 3am')
ok('later blocks are listed', /what comes next/i.test(t))
const firstNext = panel().locator('button[aria-expanded]').first()
ok('and collapsed to start', (await firstNext.getAttribute('aria-expanded')) === 'false')
await firstNext.click()
await page.waitForTimeout(300)
ok('one opens', (await firstNext.getAttribute('aria-expanded')) === 'true')

console.log('\nThe night block')
await seed({ knownSince: hoursAgo(10) })
t = await panel().innerText()
ok('at hour ten it is the first night', /The first night/.test(t))
ok(
  'it treats crying as an animal that lost its litter, not a behaviour problem',
  /not a behaviour problem/i.test(t),
)

console.log('\nA kitten gets cat guidance')
await seed({
  species: 'cat',
  breedId: 'domestic-shorthair',
  knownSince: hoursAgo(5),
  name: 'Pip',
})
t = await panel().innerText()
ok('cat copy, not dog copy', /litter tray|tray/i.test(t) && !/on the lead/i.test(t), t.slice(0, 160))

console.log('\nWhen it should be off')
await seed({ knownSince: hoursAgo(100) })
ok('gone after seventy-two hours', (await panel().count()) === 0)
await seed({
  knownSince: hoursAgo(2),
  birthDate: new Date(Date.now() - 200 * 7 * 86400000).toISOString().slice(0, 10),
})
ok('never shown for an adult, however recently they arrived', (await panel().count()) === 0)

console.log('\nAt phone width')
await seed({ knownSince: hoursAgo(2) })
const overflow = await page.evaluate(
  () => document.documentElement.scrollWidth > window.innerWidth + 1,
)
ok('no sideways scroll on a 390px phone', !overflow)

ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'first-night verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
