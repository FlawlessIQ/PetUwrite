/**
 * C1 — the safety check (SPEC-COMPANION §3.1), on the screen.
 *
 * Two answers matter and one of them is dangerous. "Ring now" has to be
 * unmissable; "nothing matched" has to be impossible to read as reassurance.
 * Most of what is asserted below is the second one.
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
      window.location.hash = `#/pet/${pet.id}/home`
    },
    {
      id: 'pet-sw',
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
  await page.waitForTimeout(1000)
}

const ask = async (what) => {
  await page.goto(`${BASE}#/wrong`, { waitUntil: 'networkidle' })
  await page.waitForTimeout(700)
  await page.getByLabel(/What are you seeing/i).fill(what)
  await page.getByRole('button', { name: 'Check it' }).click()
  await page.waitForTimeout(500)
  return page.locator('body').innerText()
}

console.log('\nGetting there')
await seed()
ok('one tap from home', (await page.locator('a[href="#/wrong"]').count()) === 1)
await page.locator('a[href="#/wrong"]').click()
await page.waitForTimeout(800)
let t = await page.locator('body').innerText()
ok('it opens', /Something is wrong with Scout/.test(t))
ok('it asks in plain words', /how you would say it/i.test(t))
ok('it says up front it cannot examine the pet', /cannot examine Scout/i.test(t))

console.log('\nA red flag must be unmissable')
t = await ask('He collapsed in the garden and his gums look pale')
ok('it says ring now', /Stop and ring a vet now/i.test(t))
ok('it names what it matched', /Collapsed, or will not get up/i.test(t) && /gums/i.test(t))
ok('it explains why, without diagnosing', /cannot stand needs to be seen now/i.test(t))
ok('and offers phone numbers', (await page.locator('a[href^="tel:"]').count()) >= 3)
ok('it mentions out of hours', /out of hours/i.test(t))
ok('and says to ring even if unsure', /nobody minds the call/i.test(t))

console.log('\nThe dangerous answer — nothing matched')
t = await ask('He seems a bit quiet today and is sleeping more than usual')
ok('it does NOT say ring now', !/Stop and ring a vet now/i.test(t))
ok(
  'it NEVER reassures',
  !/\b(sounds fine|seems fine|probably fine|nothing to worry|not serious|no need)\b/i.test(t),
  t.slice(0, 200),
)
ok(
  'it says this is about our list, not the pet',
  /statement about our list, not about your pet/i.test(t),
)
ok('it admits serious things are missing from the list', /plenty of serious things are not on it/i.test(t))
ok('and points at their own practice', /you know them and we do not/i.test(t))

console.log('\nIt shows what it checks for, so "nothing matched" means something')
const showBtn = page.getByRole('button', { name: /See all \d+ things we check for/ })
ok('the list can be opened', (await showBtn.count()) === 1)
await showBtn.click()
await page.waitForTimeout(400)
t = await page.locator('body').innerText()
ok('and it is the real list', /Struggling to breathe/i.test(t) && /A seizure, or fitting/i.test(t))

console.log('\nSpecies distinctions that change the answer')
t = await ask('She is panting a lot')
ok('a panting dog is not escalated', !/Stop and ring a vet now/i.test(t))
await seed({ species: 'cat', breedId: 'domestic-shorthair', name: 'Pip' })
t = await ask('She is panting a lot')
ok('a panting CAT is escalated', /Stop and ring a vet now/i.test(t))
ok('and it says why cats are different', /cats almost never pant/i.test(t))
t = await ask('He keeps going to the litter tray and nothing is coming out')
ok('straining in the tray escalates for a cat', /Stop and ring a vet now/i.test(t))
ok('and flags it as the most time-critical', /hours rather than days/i.test(t))

console.log('\nHonesty about the list itself')
t = await page.locator('body').innerText()
ok('the page carries its VET-REVIEW status', /VET-REVIEW/.test(t))
ok(
  'and says it errs towards sending you to a vet',
  /more often than strictly necessary/i.test(t),
)

const overflow = await page.evaluate(
  () => document.documentElement.scrollWidth > window.innerWidth + 1,
)
ok('no sideways scroll at 390px', !overflow)
ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'safety check verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
