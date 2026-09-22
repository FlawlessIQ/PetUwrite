import { chromium } from 'playwright'

/**
 * End-to-end checks for the things that would ruin a live demo. Run against a
 * preview server (or the deployed URL) with:  BASE=https://... node scripts/verify-demo.mjs
 */

const BASE = process.env.BASE || 'http://127.0.0.1:4173'
/**
 * Browser to launch. Defaults to whatever Playwright resolved for this
 * platform, so the script runs on a developer Mac as well as in CI. Set
 * PW_EXECUTABLE to pin a specific binary.
 */
const LAUNCH = process.env.PW_EXECUTABLE ? { executablePath: process.env.PW_EXECUTABLE } : {}
const KEY = 'clovara-life.pets.v1'

let pass = 0
let fail = 0
const ok = (name, cond, detail = '') => {
  if (cond) {
    pass++
    console.log(`  ✓ ${name}`)
  } else {
    fail++
    console.log(`  ✗ ${name}${detail ? ' — ' + detail : ''}`)
  }
}

const browser = await chromium.launch(LAUNCH)

async function page(opts = {}) {
  const ctx = await browser.newContext(opts)
  const p = await ctx.newPage()
  const errors = []
  p.on('pageerror', (e) => errors.push(String(e)))
  p.on('console', (m) => m.type() === 'error' && errors.push(m.text()))
  p.errors = errors
  return p
}

// ── 1. Corrupt storage must not white-screen ────────────────────────────────
console.log('\nCorrupt localStorage recovery')
{
  const p = await page()
  await p.goto(BASE, { waitUntil: 'networkidle' })

  // A pet referencing a breed that no longer exists — the realistic failure.
  await p.evaluate(
    ([k]) =>
      localStorage.setItem(
        k,
        JSON.stringify([
          { id: 'ghost', name: 'Ghost', species: 'dog', breedId: 'breed-that-was-renamed',
            birthDate: '2020-01-01', sex: 'male', neutered: true, weightLb: 40,
            conditionIds: [], activity: 'moderate', dental: 'weekly', diet: 'measured' },
        ]),
      ),
    [KEY],
  )
  await p.reload({ waitUntil: 'networkidle' })
  await p.waitForTimeout(400)

  const bodyText = await p.textContent('body')
  ok('app still renders (bad pet dropped, not crashed)', bodyText.includes("Max's day"))
  ok('the invalid pet is not in the switcher', !bodyText.includes('Ghost'))
  ok('no page errors', p.errors.length === 0, p.errors[0])

  // Half-written entries, wrong types, and outright junk.
  await p.evaluate(
    ([k]) =>
      localStorage.setItem(
        k,
        JSON.stringify([
          { id: 'x', name: 'NoBreed' },
          { id: 'y', name: 'BadDate', species: 'cat', breedId: 'domestic-shorthair',
            birthDate: 'not-a-date', conditionIds: [], weightLb: 9, sex: 'female',
            neutered: true, activity: 'low', dental: 'daily', diet: 'measured' },
          'a string',
          null,
        ]),
      ),
    [KEY],
  )
  await p.reload({ waitUntil: 'networkidle' })
  await p.waitForTimeout(400)
  ok('junk entries are all dropped', (await p.textContent('body')).includes("Max's day"))
  await p.context().close()
}

// ── 2. The error boundary catches a real throw ──────────────────────────────
console.log('\nError boundary')
{
  const p = await page()
  await p.goto(BASE, { waitUntil: 'networkidle' })
  // Force a render throw the validator cannot pre-empt.
  await p.evaluate(() => {
    const orig = Array.prototype.map
    // eslint-disable-next-line no-extend-native
    Array.prototype.map = function () {
      throw new Error('Simulated render failure')
    }
    setTimeout(() => (Array.prototype.map = orig), 4000)
  })
  await p.getByRole('navigation', { name: 'Sections' }).getByRole('button', { name: 'Shop', exact: true }).first().click().catch(() => {})
  await p.waitForTimeout(600)
  const text = (await p.textContent('body')) || ''
  ok('boundary shows a branded recovery screen', text.includes('Something went wrong'))
  ok('offers a Start over button', text.includes('Start over'))
  await p.context().close()
}

// ── 3. ?reset clears stored pets ────────────────────────────────────────────
console.log('\nReset paths')
{
  const p = await page()
  await p.goto(BASE, { waitUntil: 'networkidle' })
  await p.evaluate(
    ([k]) =>
      localStorage.setItem(
        k,
        JSON.stringify([
          { id: 'mine', name: 'Rehearsal', species: 'dog', breedId: 'beagle',
            birthDate: '2021-01-01', sex: 'male', neutered: true, weightLb: 25,
            conditionIds: [], activity: 'moderate', dental: 'weekly', diet: 'measured' },
        ]),
      ),
    [KEY],
  )
  await p.goto(`${BASE}/?reset`, { waitUntil: 'networkidle' })
  await p.waitForTimeout(400)
  const stored = await p.evaluate(([k]) => localStorage.getItem(k), [KEY])
  ok('?reset clears stored pets', stored === null)
  ok('?reset lands on a clean URL', !p.url().includes('reset'))
  await p.context().close()
}

// ── 4. Hash routing: deep link, persistence across reload, back button ──────
console.log('\nHash routing')
{
  const p = await page()
  await p.goto(BASE, { waitUntil: 'networkidle' })
  const nav = p.getByRole('navigation', { name: 'Sections' })
  await nav.getByRole('button', { name: 'Coverage', exact: true }).first().click()
  await p.waitForTimeout(300)
  ok('surface is reflected in the URL', p.url().includes('/coverage'), p.url())

  await p.reload({ waitUntil: 'networkidle' })
  await p.waitForTimeout(500)
  ok('reload returns to the same surface', ((await p.textContent('h1')) || '').includes('covered'))

  // Deep link straight to Luna's shop, as you would paste to someone.
  await p.goto(`${BASE}/#/pet/demo-luna/shop`, { waitUntil: 'networkidle' })
  await p.waitForTimeout(600)
  const h1 = (await p.textContent('h1')) || ''
  ok('deep link opens the right pet and surface', h1.includes('Luna'), h1)
  ok('no page errors during routing', p.errors.length === 0, p.errors[0])
  await p.context().close()
}

// ── 5. iOS zoom trap: every input must be >= 16px ───────────────────────────
console.log('\niOS input zoom')
{
  const p = await page({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true })
  await p.goto(BASE, { waitUntil: 'networkidle' })
  await p.getByRole('button', { name: /Choose a pet|^Max/ }).first().click()
  await p.getByRole('menuitem', { name: /Add a pet/ }).click()
  await p.waitForTimeout(400)
  const sizes = await p.$$eval('input', (els) =>
    els.map((e) => parseFloat(getComputedStyle(e).fontSize)),
  )
  ok(`all ${sizes.length} inputs are >= 16px`, sizes.every((s) => s >= 16), sizes.join(','))
  await p.context().close()
}

// ── 6. No horizontal overflow at 320px on any surface ───────────────────────
console.log('\nNarrow-viewport overflow (320px)')
{
  const p = await page({ viewport: { width: 320, height: 700 }, isMobile: true, hasTouch: true })
  await p.goto(BASE, { waitUntil: 'networkidle' })
  for (const s of ['Home', 'Care', 'Rewards', 'Shop', 'Coverage', 'Life']) {
    await p.getByRole('navigation', { name: 'Sections' }).getByRole('button', { name: s, exact: true }).first().click()
    await p.waitForTimeout(350)
    const over = await p.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    )
    ok(`${s} has no horizontal overflow`, over <= 1, `${over}px`)
  }
  await p.context().close()
}

// ── 7. Branded first paint before JS lands ──────────────────────────────────
console.log('\nFirst paint')
{
  const p = await page()
  await p.route('**/*.js', async (r) => {
    await new Promise((res) => setTimeout(res, 1200))
    await r.continue()
  })
  // 'commit', not 'load' or 'domcontentloaded' — module scripts are deferred,
  // so DOMContentLoaded fires only after React has already mounted and replaced
  // the fallback.
  await p.goto(BASE, { waitUntil: 'commit' })
  ok(
    'shows a branded fallback, not a blank page',
    await p.locator('#boot').waitFor({ state: 'visible', timeout: 3000 }).then(() => true).catch(() => false),
  )
  ok('fallback is replaced once the app mounts', await p
    .locator('text=Max\'s day')
    .first()
    .waitFor({ timeout: 8000 })
    .then(() => true)
    .catch(() => false))
  await p.unroute('**/*.js')
  await p.context().close()
}

// ── 8. Share metadata ───────────────────────────────────────────────────────
console.log('\nShare card')
{
  const p = await page()
  await p.goto(BASE, { waitUntil: 'networkidle' })
  const meta = await p.evaluate(() => ({
    ogImage: document.querySelector('meta[property="og:image"]')?.content,
    ogTitle: document.querySelector('meta[property="og:title"]')?.content,
    twitter: document.querySelector('meta[name="twitter:card"]')?.content,
    touch: document.querySelector('link[rel="apple-touch-icon"]')?.href,
  }))
  ok('og:image present', !!meta.ogImage)
  ok('og:title present', !!meta.ogTitle)
  ok('twitter:card is summary_large_image', meta.twitter === 'summary_large_image')
  ok('apple-touch-icon linked', !!meta.touch)

  const img = await p.request.get(`${BASE}/og.png`)
  ok('og.png is served', img.ok(), String(img.status()))
  const icon = await p.request.get(`${BASE}/apple-touch-icon.png`)
  ok('apple-touch-icon.png is served', icon.ok(), String(icon.status()))
  await p.context().close()
}

// ── 9. Auth stays off the demo path ─────────────────────────────────────────
// The Firebase SDK is ~46KB gzipped across three chunks. A signed-out visitor —
// which is what an investor demo is — must not fetch any of it. This is the
// check that keeps `src/auth/firebase.ts` honest: the moment someone turns one
// of those dynamic imports into a static one, this fails.
console.log('\nAuth is lazy')
{
  const p = await page()
  const scripts = []
  p.on('request', (r) => {
    if (r.resourceType() === 'script') scripts.push(r.url().split('/').pop())
  })
  await p.goto(BASE, { waitUntil: 'networkidle' })
  // Sweep every surface, not just the landing one, so a stray import anywhere
  // in the app is caught too.
  for (const s of ['home', 'care', 'rewards', 'shop', 'coverage', 'life']) {
    await p.goto(`${BASE}#/pet/demo-max/${s}`, { waitUntil: 'networkidle' })
  }
  await p.waitForTimeout(400)
  const sdk = scripts.filter((u) => /index\.esm|firebase/i.test(u))
  ok('signed-out demo fetches no Firebase chunks', sdk.length === 0, sdk.join(', '))
  ok('no page errors while signed out', p.errors.length === 0, p.errors.slice(0, 2).join(' | '))
  await p.context().close()
}

await browser.close()

console.log(`\n${pass} passed, ${fail} failed\n`)
process.exit(fail === 0 ? 0 : 1)
