/**
 * Which pet is on the screen, and does the URL agree.
 *
 * This is the third bug of one shape. `#/health` with no pet id opened a demo
 * pet; then `#/health/<id>` reached by hash-only navigation showed the wrong
 * pet; and then leaving the Health File for a *different* pet rewrote the URL
 * back to the previous one — so a link to Luna, followed from Max's Health
 * File, opened Max under Luna's link.
 *
 * In a health product, one animal's record under another animal's name is the
 * worst display bug available, so the routes get their own suite rather than a
 * line in somebody else's.
 *
 * The cause each time was the same: `activeId` is state duplicated from the
 * URL, and several places wrote to both. The tests below pin every entry and
 * exit rather than the particular sequence that broke.
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

/** Who the page is actually showing, and what the URL claims. */
const shown = () =>
  page.evaluate(() => {
    const m = document.body.innerText.match(/^(.*?)'s day/ms)
    return {
      pet: m ? m[1].split('\n').pop().trim() : null,
      hash: location.hash,
    }
  })

const go = async (hash) => {
  await page.goto(`${BASE}/${hash}`, { waitUntil: 'networkidle' })
  await page.waitForTimeout(900)
}
/** A same-document hash change, which is what a tapped link does. */
const follow = async (hash) => {
  await page.evaluate((h) => {
    window.location.hash = h
  }, hash)
  await page.waitForTimeout(900)
}

console.log('\nCold loads land on the pet in the URL')
for (const [id, name] of [
  ['demo-max', 'Max'],
  ['demo-luna', 'Luna'],
  ['demo-winston', 'Winston'],
]) {
  await ctx.clearCookies()
  await go(`#/pet/${id}/home`)
  const s = await shown()
  ok(`${name} from a cold ${id} link`, s.pet === name, JSON.stringify(s))
  ok(`  …and the URL is left alone`, s.hash === `#/pet/${id}/home`, s.hash)
}

console.log('\nFollowing a link from one pet to another')
await go('#/pet/demo-max/home')
await follow('#/pet/demo-luna/home')
let s = await shown()
ok('Max → Luna shows Luna', s.pet === 'Luna', JSON.stringify(s))
ok('  …and the URL still says Luna', s.hash === '#/pet/demo-luna/home', s.hash)

console.log('\nFollowing a link OUT of the Health File to another pet')
// The regression. The Health File used to push its own pet back into the shared
// state on the way out, and the URL writer then overwrote the incoming link.
await go('#/pet/demo-max/home')
await go('#/health/demo-max')
await follow('#/pet/demo-luna/home')
s = await shown()
ok("Max's Health File → Luna shows LUNA, not Max", s.pet === 'Luna', JSON.stringify(s))
ok('  …and the URL was not rewritten to Max', s.hash === '#/pet/demo-luna/home', s.hash)

console.log('\nThe Health File itself')
await go('#/health/demo-luna')
ok(
  'a direct link opens the pet in the link',
  /Luna/.test(await page.evaluate(() => document.body.innerText)),
)
await go('#/pet/demo-max/home')
await follow('#/health/demo-luna')
ok(
  'and so does the same link followed while looking at Max',
  /Luna/.test(await page.evaluate(() => document.body.innerText)),
)

console.log('\nThe switcher names the pet on the screen')
// Found in the UI-pass screenshots: after the Health File stopped pushing its pet
// into shared state, a cold link to Luna's file showed Luna's record under a
// switcher that said Max.
const switcherLabel = () =>
  page.locator('button[aria-haspopup="menu"]').first().innerText().then((t) => t.trim())
await ctx.clearCookies()
await go('#/health/demo-luna')
ok("a cold link to Luna's Health File says Luna in the switcher", /Luna/.test(await switcherLabel()), await switcherLabel())
await page.locator('button[aria-haspopup="menu"]').first().click()
await page.waitForTimeout(300)
await page.locator('[role="menuitem"]', { hasText: 'Winston' }).first().click()
await page.waitForTimeout(900)
ok(
  "choosing Winston there opens Winston's Health File",
  (await page.evaluate(() => location.hash)) === '#/health/demo-winston' &&
    /Winston/.test(await page.evaluate(() => document.body.innerText)),
  await page.evaluate(() => location.hash),
)
ok('  …and the switcher follows', /Winston/.test(await switcherLabel()), await switcherLabel())

console.log('\nThe pet switcher still owns the URL')
await go('#/pet/demo-max/home')
await page.locator('button[aria-haspopup="menu"]').first().click()
await page.waitForTimeout(300)
const luna = page.locator('[role="menuitem"]', { hasText: 'Luna' }).first()
if ((await luna.count()) > 0) {
  await luna.click()
  await page.waitForTimeout(900)
  s = await shown()
  ok('switching pets updates the URL', s.hash === '#/pet/demo-luna/home', JSON.stringify(s))
} else {
  ok('switching pets updates the URL', false, 'could not open the switcher')
}

console.log('\nBack and forward')
await go('#/pet/demo-max/home')
await follow('#/pet/demo-luna/home')
await page.goBack()
await page.waitForTimeout(900)
s = await shown()
ok('back returns to Max', s.pet === 'Max', JSON.stringify(s))
await page.goForward()
await page.waitForTimeout(900)
s = await shown()
ok('forward returns to Luna', s.pet === 'Luna', JSON.stringify(s))

// UAT run 1, D6: the tab bar kept highlighting whichever tab was last open —
// Rewards on "something is wrong", Home on the Health File.
console.log('\nThe tab bar names the section you are in, or none')
const current = () =>
  page.evaluate(() => [...new Set([...document.querySelectorAll('nav [aria-current="page"]')].map((e) => e.textContent.trim()))])
await go('#/pet/demo-max/rewards')
ok('control: Rewards is current on Rewards', (await current()).join() === 'Rewards', JSON.stringify(await current()))
await follow('#/wrong')
ok('"something is wrong" belongs to no tab', (await current()).length === 0, JSON.stringify(await current()))
await follow('#/ate')
ok('nor does "ate something"', (await current()).length === 0, JSON.stringify(await current()))
await go('#/pet/demo-max/home')
await follow('#/health/demo-max')
ok('the Health File belongs to Life', (await current()).join() === 'Life', JSON.stringify(await current()))
await go('#/pet/demo-max/coverage')
await follow('#/protect')
ok('Protect belongs to Coverage', (await current()).join() === 'Coverage', JSON.stringify(await current()))

// T7: the URL is the one source of truth. The screens outside the tabs act on
// the pet you came from, a tab from there goes there, and a blank URL is filled.
console.log('\nThe URL is where you are')
await go('#/pet/demo-luna/rewards')
await follow('#/wrong')
ok('"something is wrong" is about the pet you came from', /Something is wrong with Luna/.test(await page.evaluate(() => document.body.innerText)))
await page.locator('button[aria-haspopup="menu"]').first().click()
await page.waitForTimeout(300)
await page.locator('[role="menuitem"]', { hasText: 'Winston' }).first().click()
await page.waitForTimeout(700)
ok('choosing Winston there makes it about Winston', /Something is wrong with Winston/.test(await page.evaluate(() => document.body.innerText)))
ok('  …without leaving the screen', (await page.evaluate(() => location.hash)) === '#/wrong')
await page.setViewportSize({ width: 1280, height: 844 })
await page.locator('nav[aria-label="Sections"] button', { hasText: 'Care' }).first().click()
await page.waitForTimeout(800)
ok("a tab from there goes to that tab, for that pet", (await page.evaluate(() => location.hash)) === '#/pet/demo-winston/care', await page.evaluate(() => location.hash))
await page.goBack()
await page.waitForTimeout(800)
ok('and back returns to the screen you left', (await page.evaluate(() => location.hash)) === '#/wrong', await page.evaluate(() => location.hash))
await page.setViewportSize({ width: 390, height: 844 })
await go('#/nowhere-at-all')
s = await shown()
// The last pet and tab — here Winston's Care, which is where we just were.
ok('a URL that says nowhere lands where you last were', s.hash === '#/pet/demo-winston/care', JSON.stringify(s))

// UAT run 1, D4: "Add body condition" opened Life at the top, leaving the
// question it named several screens down.
console.log('\n"Add …" on Home lands on the question')
await page.goto(BASE, { waitUntil: 'networkidle' })
await page.evaluate(() => {
  localStorage.setItem(
    'clovara-life.pets.v1',
    JSON.stringify([{ id: 'route-pup', name: 'Pip', species: 'dog', breedId: 'labrador-retriever', birthDate: '2026-07-20', sex: 'male', weightLb: 0, conditionIds: [], knownSince: new Date(Date.now() - 30 * 864e5).toISOString() }]),
  )
  window.location.hash = '#/pet/route-pup/home'
})
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(900)
await page.getByRole('button', { name: 'Add body condition' }).click()
await page.waitForTimeout(1200)
const top = await page.evaluate(() => document.getElementById('sharpen-weightLb')?.getBoundingClientRect().top ?? null)
ok('the question is on screen, near the top', top !== null && top >= 0 && top < 300, `top=${top}`)
ok('and we are on Life', /\/life$/.test(await page.evaluate(() => location.hash)))
await page.evaluate(() => localStorage.removeItem('clovara-life.pets.v1'))

ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'routing verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
