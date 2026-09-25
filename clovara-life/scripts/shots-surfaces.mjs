/**
 * Every surface, at the two widths DESIGN.md §8 checks: 390px and 1280px.
 *
 *   SET=before node scripts/shots-surfaces.mjs     → shots/before/*.png
 *   SET=after  node scripts/shots-surfaces.mjs     → shots/after/*.png
 *
 * Deliberately separate from the older `shots.mjs`, which predates most of these
 * surfaces and shoots at 1440. Full-page captures, demo pets only, signed out.
 */
import { chromium } from 'playwright'
import { mkdirSync } from 'node:fs'

const BASE = process.env.BASE || 'http://127.0.0.1:4173'
const SET = process.env.SET || 'before'
const OUT = `shots/${SET}`
mkdirSync(OUT, { recursive: true })

const WIDTHS = [
  ['390', { width: 390, height: 844, deviceScaleFactor: 2, isMobile: true, hasTouch: true }],
  ['1280', { width: 1280, height: 900, deviceScaleFactor: 1 }],
]

/** [name, hash, optional action before capture] */
const SURFACES = [
  ['home-max', '#/pet/demo-max/home'],
  ['home-winston', '#/pet/demo-winston/home'],
  ['home-luna', '#/pet/demo-luna/home'],
  ['care-max', '#/pet/demo-max/care'],
  ['rewards-max', '#/pet/demo-max/rewards'],
  ['shop-max', '#/pet/demo-max/shop'],
  ['coverage-max', '#/pet/demo-max/coverage'],
  ['life-max', '#/pet/demo-max/life'],
  ['health-max', '#/health/demo-max'],
  ['health-luna', '#/health/demo-luna'],
  ['wrong', '#/wrong'],
  ['ate', '#/ate'],
  ['protect', '#/protect'],
  ['covenant', '#/covenant'],
  [
    'onboarding',
    '#/pet/demo-max/home',
    async (p) => {
      // "Add a pet" is a header button on wide screens and a switcher menu item
      // on narrow ones; the first version of this only tried the button.
      const b = p.locator('header button:visible', { hasText: /^Add a pet$/ })
      if (await b.count()) await b.first().click()
      else {
        await p.locator('button[aria-haspopup="menu"]').first().click()
        await p.waitForTimeout(250)
        await p.locator('[role="menuitem"]', { hasText: /Add a pet/ }).first().click()
      }
      await p.waitForTimeout(500)
    },
  ],
  ['partners-walkthrough', 'partners/walkthrough.html', null, true],
  ['partners-journey', 'partners/journey.html', null, true],
  ['partners-index', 'partners/index.html', null, true],
]

const browser = await chromium.launch()
let n = 0
for (const [w, viewport] of WIDTHS) {
  for (const [name, target, action, isPage] of SURFACES) {
    const ctx = await browser.newContext({ viewport, ...viewport })
    const page = await ctx.newPage()
    const url = isPage ? `${BASE}/${target}` : `${BASE}/${target}`
    await page.goto(url, { waitUntil: 'networkidle' })
    await page.evaluate(() => document.fonts.ready)
    await page.waitForTimeout(900)
    if (action) await action(page)
    // Settle any entrance motion so before/after compare like for like.
    await page.emulateMedia({ reducedMotion: 'reduce' })
    await page.waitForTimeout(250)
    await page.screenshot({ path: `${OUT}/${name}-${w}.png`, fullPage: true })
    n++
    await ctx.close()
  }
}
await browser.close()
console.log(`${n} shots → ${OUT}/`)
