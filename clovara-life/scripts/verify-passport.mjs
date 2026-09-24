/**
 * The Socialization Passport (SPEC §6.3), on the screen.
 *
 * The engine tests prove the window arithmetic. This proves stamps survive a
 * reload, that a kitten is told the truth about a window that closed before
 * they were adopted, and that nothing here rewards rushing a frightened animal.
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
      id: 'pet-pp',
      name: 'Scout',
      species: 'dog',
      breedId: 'labrador-retriever',
      birthDate: weeksOld(9),
      sex: 'female',
      weightLb: 0,
      conditionIds: [],
      knownSince: new Date(Date.now() - 200 * 3600000).toISOString(),
      ...over,
    },
  )
  await page.reload({ waitUntil: 'networkidle' })
  await page.waitForTimeout(900)
}

const panel = () => page.locator('section[aria-labelledby="passport-heading"]')
const stored = () =>
  page.evaluate(() => JSON.parse(localStorage.getItem('clovara-life.pets.v1') || '[]')[0])

console.log('\nA nine-week-old puppy')
await seed({})
ok('the passport is shown', (await panel().count()) === 1)
let t = await panel().innerText()
ok('it says how long the easy part lasts', /week/i.test(t) && /easy part/i.test(t), t.slice(0, 120))
ok('it starts at zero of about a hundred', /0 of 9[0-9]|0 of 1[0-9][0-9]/.test(t), t.slice(0, 200))
ok(
  'it says a frightened animal has not been socialised',
  /frightened/i.test(t) && /does not count/i.test(t),
)
ok(
  'it sends the vaccination question to a vet rather than answering it',
  /question for your vet/i.test(t),
)
ok('there is no streak to break and no daily target', !/streak|today|daily/i.test(t), t.slice(0, 400))

console.log('\nCollecting a stamp')
await panel().getByRole('button', { name: 'People' }).click()
await page.waitForTimeout(350)
const boxes = panel().locator('[role="checkbox"]')
ok('the page opens to its stamps', (await boxes.count()) > 8)
ok('and they start unchecked', (await boxes.first().getAttribute('aria-checked')) === 'false')
await boxes.first().click()
await page.waitForTimeout(500)
ok('ticking one marks it', (await boxes.first().getAttribute('aria-checked')) === 'true')
ok('progress moves', /1 of /.test(await panel().innerText()))

const after = await stored()
ok('it is written to the pet', Array.isArray(after.socialStamps) && after.socialStamps.length === 1)
ok('as an id, not a label', /^[a-z]-[a-z-]+$/.test(after.socialStamps[0]), String(after.socialStamps[0]))

await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(900)
ok('and it survives a reload', /1 of /.test(await panel().innerText()))

console.log('\nUnticking, because people mis-tap')
await panel().getByRole('button', { name: 'People' }).click()
await page.waitForTimeout(350)
await panel().locator('[role="checkbox"]').first().click()
await page.waitForTimeout(500)
ok('a stamp can be taken back', /0 of /.test(await panel().innerText()))

console.log('\nA nine-week-old kitten is told the truth')
await seed({ species: 'cat', breedId: 'domestic-shorthair', name: 'Pip' })
t = await panel().innerText()
ok('its window is described as already closed', /already closed/i.test(t), t.slice(0, 160))
ok(
  'and it says that part was not theirs to do',
  /before most kittens come home/i.test(t) && /not to you/i.test(t),
)
ok('without telling them they failed', !/too late|missed|should have/i.test(t))
await panel().getByRole('button', { name: 'Being a pet' }).click()
await page.waitForTimeout(350)
const catPage = await panel().innerText()
ok(
  'the stamps are a cat\'s, not a dog\'s',
  /scratching post/i.test(catPage) && /litter tray/i.test(catPage),
  catPage.slice(0, 200),
)
ok('and no crate or chew anywhere in them', !/crate|to chew/i.test(catPage))

console.log('\nWhen it should be gone')
await seed({ birthDate: weeksOld(40) })
ok('not shown for a grown dog', (await panel().count()) === 0)

console.log('\nDemo pets')
await page.goto(`${BASE}#/pet/demo-max/life`, { waitUntil: 'networkidle' })
await page.waitForTimeout(900)
ok('an adult demo pet is unaffected', (await panel().count()) === 0)

const overflow = await page.evaluate(
  () => document.documentElement.scrollWidth > window.innerWidth + 1,
)
ok('no sideways scroll at 390px', !overflow)
ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'passport verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
