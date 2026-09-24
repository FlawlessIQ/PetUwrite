/**
 * The senior suite (SPEC-HORIZON §1.5), on the screen.
 *
 * Two rules under test, and the second is the harder one: never estimate
 * remaining time, and never frame ageing as decline to be fought. There is also
 * deliberately no quality-of-life score anywhere, and the page says why.
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
const seed = async (over = {}) => {
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await page.evaluate(
    (pet) => {
      localStorage.clear()
      localStorage.setItem('clovara-life.pets.v1', JSON.stringify([pet]))
      window.location.hash = `#/health/${pet.id}`
    },
    {
      id: 'pet-s',
      name: 'Scout',
      species: 'dog',
      breedId: 'labrador-retriever',
      birthDate: '2014-04-02',
      sex: 'female',
      weightLb: 68,
      conditionIds: [],
      knownSince: daysAgo(2000),
      ...over,
    },
  )
  await page.reload({ waitUntil: 'networkidle' })
  await page.waitForTimeout(1300)
}

const panel = () => page.locator('section[aria-labelledby="senior-heading"]')

/**
 * Both negative checks below are scoped rather than run over the whole panel,
 * and the reason matters:
 *
 *  - "score" and "out of six" appear once, in the note explaining that we do
 *    NOT score a life. The sentence that refuses the thing cannot be evidence
 *    of the thing.
 *  - "arthritis" appears once, under "What the plan already says" — that block
 *    is the existing per-stage care actions from `data/engine.ts`, written for
 *    a vet's standing advice ("treat stiffness as treatable pain"). The rule
 *    being tested is about the senior suite's OWN observations, which must
 *    never be told what they might mean.
 */
const upTo = (text, marker) => {
  const i = text.toUpperCase().indexOf(marker)
  return i < 0 ? text : text.slice(0, i)
}
const section = (text, from, to) => {
  const i = text.toUpperCase().indexOf(from)
  if (i < 0) return ''
  const j = text.toUpperCase().indexOf(to, i + from.length)
  return text.slice(i, j < 0 ? text.length : j)
}

console.log('\nFor an older dog')
await seed()
ok('the suite appears', (await panel().count()) === 1)
let t = await panel().innerText()
ok('it is about the house, not the animal', /Making the house easier for Scout/i.test(t))
ok('and says so up front', /nothing here is about slowing anything down/i.test(t))

console.log('\nWhat it must never do')
ok(
  'it NEVER estimates remaining time',
  !/\b(years left|time left|remaining|how long|final years|last years|end of life|not long)\b/i.test(t),
  t.slice(0, 220),
)
ok('no healthy-years range anywhere', !/\d+\.\d\s*–\s*\d+\.\d/.test(t) && !/healthy years/i.test(t))
ok(
  'it never frames ageing as a fight',
  !/\b(fight|battle|combat|reverse|defy|slow the ageing|still young)\b/i.test(t),
)
ok('no promise of a longer life', !/live longer|longer life|extra years|add years/i.test(t))

console.log('\nThe quality-of-life scale that is deliberately absent')
ok(
  'there is no score of any kind outside the note refusing one',
  !/\b(score|scored|rating|rated|out of (five|six|ten|\d))\b/i.test(upTo(t, 'WE DO NOT SCORE')),
  upTo(t, 'WE DO NOT SCORE').slice(0, 200),
)
ok('and the page says why', /we do not score/i.test(t))
ok('naming where that belongs', /belong with a vet/i.test(t))
ok('and what it refuses to be', /six tick boxes/i.test(t))

console.log('\nWhat it actually offers')
ok('rugs on hard floors', /Rugs or runners on hard floors/i.test(t))
ok('a ramp, for a dog', /ramp or steps/i.test(t))
ok('things worth mentioning at the next visit', /Worth mentioning at the next visit/i.test(t))
ok('phrased as observations, not symptoms', /Slower to get up/i.test(t))
const mentions = () => section(t, 'WORTH MENTIONING AT THE NEXT VISIT', 'WHAT THE PLAN')
ok('and it refuses to say what they might mean', /not going to tell you what they might be/i.test(t))
ok(
  'and names no condition among the observations',
  !/\b(sign of|indicates|suggests|arthritis|kidney|dementia|cognitive|cancer|diabetes)\b/i.test(
    mentions(),
  ),
  mentions().slice(0, 200),
)

console.log('\nThe reasons are about the animal')
await panel().getByRole('button', { name: /Rugs or runners/ }).click()
await page.waitForTimeout(350)
t = await panel().innerText()
ok('opening one explains why', /hardest thing in most houses/i.test(t))
ok('without mentioning us', !/\bour\b|we recommend|Clovara/i.test(t))

console.log('\nA cat gets a cat house')
await seed({ species: 'cat', breedId: 'domestic-shorthair', name: 'Pip', birthDate: '2013-04-02' })
t = await panel().innerText()
ok('a litter tray with a low side', /litter tray with one low side/i.test(t))
ok('and no ramp for the car', !/ramp or steps for the car/i.test(t))
ok('grooming help, which cats stop doing quietly', /hand with grooming/i.test(t))
ok('and cat-specific things to mention', /Stopped jumping to somewhere/i.test(t))

console.log('\nWhen it should not appear')
await seed({ birthDate: '2024-04-02' })
ok('not for a young dog', (await panel().count()) === 0)
await seed({ diedOn: daysAgo(10) })
ok('and not once a pet has died', (await panel().count()) === 0)

const overflow = await page.evaluate(
  () => document.documentElement.scrollWidth > window.innerWidth + 1,
)
ok('no sideways scroll at 390px', !overflow)
ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'senior suite verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
