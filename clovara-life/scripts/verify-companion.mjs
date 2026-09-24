/**
 * C2 — the grounded companion (SPEC-COMPANION §3.2), on the screen.
 *
 * The rule under test is that it can only say what it already knows. So the
 * checks are: does it cite everything, does it refuse to guess, does safety
 * still come first, and does it admit ignorance without softening it into
 * something that sounds like an answer.
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
      window.location.hash = `#/pet/${pet.id}/care`
    },
    {
      id: 'pet-ac',
      name: 'Scout',
      species: 'dog',
      breedId: 'labrador-retriever',
      birthDate: '2019-04-02',
      sex: 'female',
      weightLb: 68,
      conditionIds: ['hip-dysplasia'],
      conditionsReviewed: true,
      activity: 'low',
      dental: 'rarely',
      careNotes: { meds: 'Half a joint tablet with breakfast' },
      knownSince: new Date(Date.now() - 400 * 86400000).toISOString(),
      ...over,
    },
  )
  await page.reload({ waitUntil: 'networkidle' })
  await page.waitForTimeout(1200)
}

const panel = () => page.locator('section[aria-labelledby="ask-heading"]')
const ask = async (q) => {
  await panel().getByLabel(/What would you like to know/i).fill(q)
  await panel().getByRole('button', { name: 'Ask' }).click()
  await page.waitForTimeout(500)
  return panel().innerText()
}

console.log('\nIt says what it is before you use it')
await seed()
ok('the grounded companion is on the Care surface', (await panel().count()) === 1)
let t = await panel().innerText()
ok('it says it can only tell you what it knows', /only tell you what it already knows/i.test(t))
ok('it says it shows its sources', /shows you which/i.test(t))
ok('and that it cannot examine the pet', /cannot examine Scout/i.test(t))

console.log('\nRecall, with sources on every line')
t = await ask('Her hip seems sore after walks')
ok('it opens by naming the record', /already on Scout's record/i.test(t))
ok('it recalls the declared condition', /hip dysplasia/i.test(t))
ok('every claim shows where it came from', /from what you told us/i.test(t))
ok('and breed claims name the research and its strength', /from the breed research/i.test(t) && /evidence/i.test(t))
ok('it says plainly it is recall, not an opinion', /recall, not an opinion/i.test(t))
ok('and that it has not examined the pet', /have not examined Scout/i.test(t))
ok('it routes to a vet when the record has something to say', /worth a vet's eyes/i.test(t))

console.log('\nWhat it must never do')
ok(
  'never diagnoses or speculates',
  !/\b(sounds like|probably|likely|it could be|I think|diagnos|suggests|consistent with)\b/i.test(t),
  t.slice(0, 200),
)
ok('never claims a longer life', !/live longer|longer life|extra years/i.test(t))

console.log('\nIt finds other things it actually holds')
t = await ask('Is she still on her tablets?')
ok('the medication note is recalled', /Half a joint tablet with breakfast/.test(t))
t = await ask('Her breath smells')
ok('the dental routine is recalled', /Teeth are cleaned/i.test(t))

console.log('\nWhen it knows nothing, it says so — and does not soften it')
t = await ask('What is the weather going to be like tomorrow?')
ok('it admits the gap', /none of them speak to what you have described/i.test(t))
ok('it says how much it does hold', /We hold \d+ things about Scout/i.test(t))
ok('it calls it a gap in what we know, not a judgement', /not a judgement about Scout/i.test(t))
ok(
  'and it never reassures on the way out',
  !/\b(fine|nothing to worry|not serious|probably ok|no need)\b/i.test(t),
  t.slice(0, 200),
)

console.log('\nSafety still runs first')
t = await ask('He collapsed and his gums look pale')
ok('an emergency overrides recall entirely', /Stop and ring a vet now/i.test(t))
ok('and it does NOT answer with hip dysplasia instead', !/already on Scout's record/i.test(t))
ok('it offers the way through', (await panel().locator('a[href="#/wrong"]').count()) === 1)

console.log('\nAsking for a vet gets an answer, not a recital of the record')
t = await ask('Can I speak to a vet about this?')
ok('it answers the ask', /cannot put you through to a vet/i.test(t))
ok('and does not recite the record instead', !/already on Scout's record/i.test(t))
ok('it is honest that there is no partner', /no video vet behind Clovara yet/i.test(t))
ok(
  'it does not promise the feature is coming',
  !/\b(soon|coming|shortly|we are working on)\b/i.test(t),
  t.slice(0, 200),
)
ok('it leads with the summary', /Copy Scout's summary/i.test(t))
ok('it says how to reach somebody out of hours', /out of hours/i.test(t))
ok(
  'and links straight to the summary',
  (await panel().locator('a[href^="#/health/"]').count()) === 1,
)

console.log('\nThe scripted preview is still there and still labelled')
const body = await page.locator('body').innerText()
ok('the demo thread survives', /scripted for the preview/i.test(body))

const overflow = await page.evaluate(
  () => document.documentElement.scrollWidth > window.innerWidth + 1,
)
ok('no sideways scroll at 390px', !overflow)
ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'companion verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
