/**
 * The Arrival Certificate (SPEC §6.1), drawn in a real browser.
 *
 * Canvas is the one thing unit tests cannot reach: `cardLayout` proves the
 * arithmetic, but a card that renders blank, or in the wrong font, or with the
 * name off the edge, passes every pure test there is. This opens the real card
 * and looks at the pixels.
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
const ctx = await browser.newContext({ viewport: { width: 1100, height: 1000 } })
const page = await ctx.newPage()
const errors = []
page.on('pageerror', (e) => errors.push(String(e)))
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()))

console.log('\nA new pet reaches the certificate')
await page.goto(BASE, { waitUntil: 'networkidle' })
await page.evaluate(() => localStorage.clear())
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(400)

await page.getByRole('button', { name: /Add a pet/ }).first().click()
await page.waitForTimeout(300)
await page.getByRole('radio', { name: 'A dog' }).click()
await page.getByRole('button', { name: 'Continue' }).click()
await page.waitForTimeout(250)
await page.getByLabel('Search breeds').fill('Beagle')
await page.waitForTimeout(300)
await page.getByRole('button', { name: /^Beagle/ }).first().click()
await page.getByRole('button', { name: 'Continue' }).click()
await page.waitForTimeout(250)
await page.getByLabel('Their name').fill("O'Malley")
await page.getByRole('button', { name: 'Continue' }).click()
await page.waitForTimeout(250)
await page.getByRole('button', { name: 'Continue' }).click()
await page.waitForTimeout(250)
await page.getByRole('radio', { name: 'Male', exact: true }).click()
await page.getByRole('button', { name: /See O'Malley's plan/ }).click()
await page.waitForTimeout(1500)

const card = page.locator('section[aria-labelledby="share-card-heading"]')
ok('the certificate is offered at creation', (await card.count()) === 1)
const img = card.locator('img')
await img.waitFor({ state: 'visible', timeout: 15000 }).catch(() => {})
ok('a card image was actually produced', (await img.count()) === 1)

const dims = await img.evaluate((el) => ({ w: el.naturalWidth, h: el.naturalHeight }))
ok(`it is a real 1080 square (${dims.w}×${dims.h})`, dims.w === 1080 && dims.h === 1080)

// The blank-canvas trap: a card can be the right size and entirely empty.
const ink = await page.evaluate(async () => {
  const el = document.querySelector('section[aria-labelledby="share-card-heading"] img')
  const c = document.createElement('canvas')
  c.width = el.naturalWidth
  c.height = el.naturalHeight
  c.getContext('2d').drawImage(el, 0, 0)
  const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data
  const seen = new Set()
  let dark = 0
  for (let i = 0; i < d.length; i += 4 * 97) {
    seen.add(`${d[i] >> 4},${d[i + 1] >> 4},${d[i + 2] >> 4}`)
    if (d[i] < 120 && d[i + 1] < 120 && d[i + 2] < 120) dark++
  }
  return { colours: seen.size, dark, sampled: Math.floor(d.length / (4 * 97)) }
})
ok(`the card is not blank — ${ink.colours} distinct tones`, ink.colours >= 4, JSON.stringify(ink))
ok(
  `there is real text on it (${ink.dark} dark samples)`,
  ink.dark > 20,
  'a card of the right size and no ink is the failure a pure test cannot see',
)

console.log('\nWhat it says')
ok('it offers to save or share', (await card.getByRole('button', { name: /Save or share/ }).count()) === 1)
ok(
  'it says the card stays on the device',
  /never leaves it unless you share/.test(await card.innerText()),
)
const alt = await img.getAttribute('alt')
ok('the image has a real alt description', /O'Malley/.test(alt || ''), String(alt))

console.log('\nWithout a photo')
ok(
  'a pet with no photo still gets a card, not an error',
  (await img.count()) === 1 && !/could not make the card/.test(await card.innerText()),
)

console.log('\nIt is offered once, not forever')
await card.getByRole('button', { name: 'Not now' }).click()
await page.waitForTimeout(400)
ok('dismissing it puts it away', (await card.count()) === 0)
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(1200)
ok('and it does not return on every load', (await card.count()) === 0)

ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'share card verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
