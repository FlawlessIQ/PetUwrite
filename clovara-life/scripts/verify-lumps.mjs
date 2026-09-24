/**
 * The lump diary (SPEC-HORIZON §1.1), on the screen.
 *
 * Almost everything here is about what it refuses to do. The feature's whole
 * risk is that it tells somebody a lump has not changed and they wait.
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
const img = 'data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=='

const seed = async (lumps) => {
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await page.evaluate(
    ([pet]) => {
      localStorage.clear()
      localStorage.setItem('clovara-life.pets.v1', JSON.stringify([pet]))
      window.location.hash = `#/health/${pet.id}`
    },
    [
      {
        id: 'pet-lump',
        name: 'Scout',
        species: 'dog',
        breedId: 'labrador-retriever',
        birthDate: '2019-04-02',
        sex: 'female',
        weightLb: 68,
        conditionIds: [],
        knownSince: daysAgo(400),
        lumps,
      },
    ],
  )
  await page.reload({ waitUntil: 'networkidle' })
  await page.waitForTimeout(1200)
}

const panel = () => page.locator('section[aria-labelledby="lumps-heading"]')

/**
 * The verdict text, with the explanatory copy removed.
 *
 * "A photo taken closer looks bigger" is the sentence explaining why a size
 * reference is needed — it is the prohibition, not a claim about this lump, and
 * a bare /bigger/ flags it. Same shape as the toxin file's "do not try to make
 * them sick".
 */
const verdictText = (s) =>
  s
    .replace(/Put something of known size[^.]*\.[^.]*\./g, '')
    .replace(/Without one, a photo taken closer looks bigger[^.]*\./g, '')


console.log('\nIt leads with the thing that matters')
await seed([])
ok('the diary is in the health file', (await panel().count()) === 1)
let t = await panel().innerText()
ok(
  'it says a new lump is a vet visit, not a diary entry',
  /reason to see a vet, not a reason to start a diary/i.test(t),
)
ok('and that this is for something already looked at', /already looked at/i.test(t))

console.log('\nThe size reference is compulsory, and asked BEFORE the camera')
await seed([{ id: 'l1', location: 'Left shoulder', firstSeen: daysAgo(60), photos: [] }])
await panel().getByRole('button', { name: /Left shoulder/ }).click()
await page.waitForTimeout(400)
t = await panel().innerText()
ok('it explains why scale matters', /taken closer looks bigger/i.test(t))
ok('references are offered', (await panel().getByRole('button', { name: 'A coin' }).count()) === 1)
const cam = panel().getByRole('button', { name: /Open the camera/ })
ok('the camera is disabled until one is chosen', await cam.isDisabled())
ok('and it says so', /Choose what you will put beside it first/i.test(t))
await panel().getByRole('button', { name: 'A coin' }).click()
await page.waitForTimeout(300)
ok('choosing one enables the camera', !(await cam.isDisabled()))

console.log('\nTwo comparable photos')
await seed([
  {
    id: 'l1',
    location: 'Left shoulder',
    firstSeen: daysAgo(90),
    photos: [
      { url: img, fullPath: 'a', takenAt: daysAgo(90), sizeReference: 'A coin' },
      { url: img, fullPath: 'b', takenAt: daysAgo(30), sizeReference: 'A coin' },
      { url: img, fullPath: 'c', takenAt: daysAgo(1), sizeReference: 'A coin' },
    ],
  },
])
await panel().getByRole('button', { name: /Left shoulder/ }).click()
await page.waitForTimeout(500)
t = await panel().innerText()
ok('it shows a first and a most recent', /First/.test(t) && /Most recent/.test(t))
ok('it names the scale used in each', /with a coin/i.test(t))

console.log('\nWhat it must NEVER say')
ok(
  'it never says whether it changed',
  !/\b(bigger|smaller|grown|growing|larger|no change|unchanged|stable|increased|decreased)\b/i.test(
    verdictText(t),
  ),
  verdictText(t).slice(0, 260),
)
ok('it says out loud that it will not judge', /do not tell you whether it has changed/i.test(t))
ok('and why that refusal matters', /makes somebody wait/i.test(t))
ok('it never categorises the lump', !/\b(benign|malignant|suspicious|harmless|worrying|tumour|tumor|cyst)\b/i.test(t))
ok('no measurement, percentage or trend anywhere', !/\d+\s*(mm|cm|%)/.test(t))

console.log('\nA photo with no scale is kept, and marked')
await seed([
  {
    id: 'l1',
    location: 'Left shoulder',
    firstSeen: daysAgo(60),
    photos: [
      { url: img, fullPath: 'a', takenAt: daysAgo(60), sizeReference: 'A coin' },
      { url: img, fullPath: 'b', takenAt: daysAgo(2), sizeReference: null },
    ],
  },
])
await panel().getByRole('button', { name: /Left shoulder/ }).click()
await page.waitForTimeout(500)
t = await panel().innerText()
ok('it refuses to compare them', /cannot be compared/i.test(t))
ok('it explains how to fix it next time', /coin or a fingertip beside it will fix that/i.test(t))
ok('but keeps the photo', /no scale/i.test(t))
ok(
  'and still does not guess',
  !/\b(bigger|smaller|grown|no change)\b/i.test(verdictText(t)),
  verdictText(t).slice(0, 200),
)

console.log('\nOne photo only')
await seed([
  {
    id: 'l1',
    location: 'Left shoulder',
    firstSeen: daysAgo(10),
    photos: [{ url: img, fullPath: 'a', takenAt: daysAgo(10), sizeReference: 'A coin' }],
  },
])
await panel().getByRole('button', { name: /Left shoulder/ }).click()
await page.waitForTimeout(500)
t = await panel().innerText()
ok('it says there is nothing to set it against yet', /nothing to set it against/i.test(t))
ok('and shows the last photo to match for the next one', /Match this framing/i.test(t))

console.log('\nStarting one')
await seed([])
await panel().getByRole('button', { name: /Track something new/ }).click()
await page.waitForTimeout(300)
await panel().getByLabel(/Where on Scout/i).fill('Under the collar')
await panel().getByRole('button', { name: 'Start' }).click()
await page.waitForTimeout(600)
ok('it appears', /Under the collar/.test(await panel().innerText()))
const stored = await page.evaluate(
  () => JSON.parse(localStorage.getItem('clovara-life.pets.v1'))[0].lumps,
)
ok('and persists to the pet', Array.isArray(stored) && stored[0].location === 'Under the collar')

const overflow = await page.evaluate(
  () => document.documentElement.scrollWidth > window.innerWidth + 1,
)
ok('no sideways scroll at 390px', !overflow)
ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'lump diary verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
