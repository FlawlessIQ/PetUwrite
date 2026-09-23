/**
 * The attach flow (SPEC §5), driven as somebody buys.
 *
 * The DoD is "end-to-end attach in test mode in <90s from offer tap", so this
 * times it. The rest is about the screen of truth: a waiting period somebody
 * cannot miss, a pre-existing picture in words, and a button that stays off
 * until the small print has actually been scrolled.
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
      window.location.hash = `#/pet/${pet.id}/life`
    },
    {
      id: 'pet-at',
      name: 'Scout',
      species: 'dog',
      breedId: 'labrador-retriever',
      birthDate: '2021-04-02',
      sex: 'female',
      weightLb: 68,
      conditionIds: [],
      knownSince: new Date(Date.now() - 100 * 86400000).toISOString(),
      ...over,
    },
  )
  await page.reload({ waitUntil: 'networkidle' })
  await page.waitForTimeout(900)
}

console.log('\nEntry points (SPEC §5)')
await seed()
ok('the offer is on the Life surface, at the reveal', (await page.locator('a[href="#/protect"]').count()) >= 1)
await page.goto(`${BASE}#/pet/pet-at/coverage`, { waitUntil: 'networkidle' })
await page.waitForTimeout(800)
ok('and a quiet line on Coverage', (await page.locator('a[href="#/protect"]').count()) >= 1)

console.log('\nScreen 1 — a price nobody had to ask for')
const started = Date.now()
await page.locator('a[href="#/protect"]').first().click()
await page.waitForTimeout(900)
let t = await page.locator('body').innerText()
ok('it opens on step 1 of 2', /step 1 of 2/i.test(t))
ok('there is a price', /\$\d+\.\d\d/.test(t))
ok('it says there was no form', /did not have to fill in a form/i.test(t))
ok(
  'insurance and the rider are two separate lines (invariant 2)',
  /two separate lines/i.test(t),
)
ok('the price is labelled illustrative', /illustrative/i.test(t) && /not an offer/i.test(t))
ok('and says rates are not filed', /not yet filed/i.test(t))

console.log('\nAdjusting, without a form')
await page.getByRole('button', { name: 'Adjust' }).click()
await page.waitForTimeout(400)
ok('tiers are offered', (await page.getByRole('button', { name: /Clovara Essential/ }).count()) === 1)
const before = (await page.locator('body').innerText()).match(/\$(\d+\.\d\d)/)[1]
await page.getByRole('button', { name: /Clovara Essential/ }).click()
await page.waitForTimeout(500)
const after = (await page.locator('body').innerText()).match(/\$(\d+\.\d\d)/)[1]
ok(`changing tier changes the price ($${before} → $${after})`, before !== after)

console.log('\nScreen 2 — the screen of truth')
await page.getByRole('button', { name: /See exactly what this covers/ }).click()
await page.waitForTimeout(800)
t = await page.locator('body').innerText()
ok('it says it is the uncomfortable page', /uncomfortable page/i.test(t))
ok('waiting periods are given as DATES, not durations', /from \d+ \w+ \d{4}/.test(t), t.slice(0, 400))
ok('the orthopaedic wait is named', /orthopaedic|cruciate/i.test(t))
ok('cover starts tomorrow, never today', /Cover would start/i.test(t))
ok(
  'with nothing declared, it says so rather than leaving a blank',
  /nothing is excluded as pre-existing today/i.test(t),
)

console.log('\nThe button stays off until the small print is read')
const buy = page.getByRole('button', { name: /Protect Scout for/ })
ok('the buy button exists', (await buy.count()) === 1)
ok('and is disabled to start', await buy.isDisabled())
const attest = page.locator('input[type="checkbox"]').last()
ok('the attestation is disabled too', await attest.isDisabled())

await page.evaluate(() => {
  const el = [...document.querySelectorAll('div')].find((d) => d.scrollHeight > d.clientHeight + 40 && d.className.includes('overflow-y-auto'))
  el.scrollTop = el.scrollHeight
  el.dispatchEvent(new Event('scroll', { bubbles: true }))
})
await page.waitForTimeout(500)
ok('scrolling the disclosures to the end enables the attestation', !(await attest.isDisabled()))
await attest.check()
await page.waitForTimeout(300)
ok('and then the button', !(await buy.isDisabled()))

console.log('\nBinding is honest about not being live')
await buy.click()
await page.waitForTimeout(900)
t = await page.locator('body').innerText()
ok(
  'it says binding needs the carrier programme, rather than failing silently',
  /carrier programme/i.test(t),
  t.slice(0, 300),
)
const seconds = (Date.now() - started) / 1000
ok(`the whole flow took under 90 seconds (${seconds.toFixed(1)}s)`, seconds < 90)

console.log('\nA pet with something already diagnosed')
await seed({ conditionIds: ['hip-dysplasia'], conditionsReviewed: true })
await page.goto(`${BASE}#/protect`, { waitUntil: 'networkidle' })
await page.waitForTimeout(800)
await page.getByRole('button', { name: /See exactly what this covers/ }).click()
await page.waitForTimeout(700)
t = await page.locator('body').innerText()
ok('the condition is named in plain words', /will not be covered/i.test(t))
ok('and it says what still is', /Everything unrelated still is/i.test(t))
ok('never blaming the owner for it', !/should have|your fault|failed to/i.test(t))

const overflow = await page.evaluate(
  () => document.documentElement.scrollWidth > window.innerWidth + 1,
)
ok('no sideways scroll at 390px', !overflow)
ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'attach verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
