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

ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'routing verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
