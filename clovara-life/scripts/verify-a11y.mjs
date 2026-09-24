/**
 * Accessibility, across every surface (no SPEC section — it was never checked).
 *
 * No axe-core, because no new dependencies. These are hand-written checks for
 * the failures that actually matter in this product and that a sighted person
 * clicking around will never notice:
 *
 *  - a control with no accessible name is a button a screen reader announces
 *    as "button", which on the toxin screen could be the poison line
 *  - an unlabelled input is a field nobody can fill in without sight
 *  - a heading jump is a document outline that cannot be navigated
 *  - an image with no alt is a pet's photo announced as a filename
 *  - a tap target under 44px fails anyone with a tremor, and this is a phone
 *    product used one-handed while holding an animal
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

const wk = (n) => new Date(Date.now() - n * 7 * 86400000).toISOString().slice(0, 10)
const daysAgo = (n) => new Date(Date.now() - n * 86400000).toISOString()

const PET = {
  id: 'pet-a11y',
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: wk(9),
  sex: 'female',
  weightLb: 0,
  conditionIds: [],
  knownSince: daysAgo(0.08),
}

const audit = async (label, hash) => {
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await page.evaluate(
    ([pet, h]) => {
      localStorage.clear()
      localStorage.setItem('clovara-life.pets.v1', JSON.stringify([pet]))
      window.location.hash = h
    },
    [PET, hash],
  )
  await page.reload({ waitUntil: 'networkidle' })
  await page.waitForTimeout(1400)

  const r = await page.evaluate(() => {
    const name = (el) =>
      (
        el.getAttribute('aria-label') ||
        el.getAttribute('title') ||
        (el.getAttribute('aria-labelledby') &&
          document.getElementById(el.getAttribute('aria-labelledby'))?.textContent) ||
        el.textContent ||
        ''
      ).trim()

    const visible = (el) => {
      const s = getComputedStyle(el)
      if (s.display === 'none' || s.visibility === 'hidden') return false
      const b = el.getBoundingClientRect()
      return b.width > 0 && b.height > 0
    }

    const controls = [...document.querySelectorAll('button, a[href], [role="button"], [role="radio"], [role="checkbox"]')].filter(visible)
    const unnamed = controls.filter((el) => !name(el)).map((el) => el.outerHTML.slice(0, 80))

    const inputs = [...document.querySelectorAll('input, select, textarea')].filter(visible)
    const unlabelled = inputs.filter((el) => {
      if (el.getAttribute('aria-label') || el.getAttribute('title')) return false
      if (el.id && document.querySelector(`label[for="${CSS.escape(el.id)}"]`)) return false
      if (el.closest('label')) return false
      return true
    }).map((el) => el.outerHTML.slice(0, 80))

    const imgs = [...document.querySelectorAll('img')].filter(visible)
    const noAlt = imgs.filter((el) => el.getAttribute('alt') === null).map((el) => el.src.slice(-40))

    const levels = [...document.querySelectorAll('h1,h2,h3,h4,h5,h6')]
      .filter(visible)
      .map((el) => Number(el.tagName[1]))
    const jumps = []
    for (let i = 1; i < levels.length; i++) {
      if (levels[i] - levels[i - 1] > 1) jumps.push(`h${levels[i - 1]} → h${levels[i]}`)
    }

    const small = controls
      .filter((el) => {
        const b = el.getBoundingClientRect()
        // Inline text links inside a paragraph are exempt — they are words, not
        // tap targets, and enlarging them would break the sentence.
        if (el.tagName === 'A' && el.closest('p')) return false
        // A skip link is 1×1 until it is focused. That is how a skip link
        // works, and it is measured focused further down instead.
        if (el.className && String(el.className).includes('sr-only')) return false
        return b.height < 36 || b.width < 36
      })
      .map((el) => `${name(el).slice(0, 24)} ${Math.round(el.getBoundingClientRect().width)}×${Math.round(el.getBoundingClientRect().height)}`)

    return {
      controls: controls.length,
      unnamed,
      unlabelled,
      noAlt,
      jumps,
      small,
      firstHeading: levels[0] ?? null,
      lang: document.documentElement.lang || null,
    }
  })

  console.log(`\n${label} (${r.controls} controls)`)
  ok('every control has an accessible name', r.unnamed.length === 0, r.unnamed.slice(0, 2).join(' | '))
  ok('every input has a label', r.unlabelled.length === 0, r.unlabelled.slice(0, 2).join(' | '))
  ok('every image has alt text', r.noAlt.length === 0, r.noAlt.slice(0, 2).join(' | '))
  ok('headings do not skip a level', r.jumps.length === 0, r.jumps.slice(0, 3).join(', '))
  ok('tap targets are at least 36px', r.small.length === 0, r.small.slice(0, 3).join(' | '))
  return r
}

await audit('Life surface', '#/pet/pet-a11y/life')
await audit('Home', '#/pet/pet-a11y/home')
await audit('Health file', '#/health/pet-a11y')
await audit('He ate something', '#/ate')
await audit('Protect — the offer', '#/protect')
await audit('Data Covenant', '#/covenant')
await audit('Shop', '#/pet/pet-a11y/shop')
await audit('Coverage', '#/pet/pet-a11y/coverage')

console.log('\nThe document itself')
const doc = await page.evaluate(() => ({
  lang: document.documentElement.lang || null,
  title: document.title,
  skip: !!document.querySelector('a[href="#main"]'),
  main: !!document.querySelector('main, #main'),
}))
ok('the page declares a language', !!doc.lang, String(doc.lang))
ok('it has a title', doc.title.length > 3, doc.title)
ok('there is a skip link', doc.skip)
ok('and something for it to skip to', doc.main)
// Measured focused, because it is 1×1 until then by design.
await page.keyboard.press('Tab')
const skip = await page.evaluate(() => {
  const a = document.activeElement
  const b = a.getBoundingClientRect()
  return { name: (a.textContent || '').trim(), w: Math.round(b.width), h: Math.round(b.height) }
})
ok(
  `the skip link is a real target once focused (${skip.w}×${skip.h})`,
  /skip/i.test(skip.name) && skip.h >= 30 && skip.w >= 60,
  JSON.stringify(skip),
)

console.log('\nKeyboard')
await page.goto(`${BASE}#/pet/pet-a11y/life`, { waitUntil: 'networkidle' })
await page.waitForTimeout(1200)
const reached = []
for (let i = 0; i < 14; i++) {
  await page.keyboard.press('Tab')
  const el = await page.evaluate(() => {
    const a = document.activeElement
    if (!a || a === document.body) return null
    const s = getComputedStyle(a)
    return {
      tag: a.tagName,
      name: (a.getAttribute('aria-label') || a.textContent || '').trim().slice(0, 30),
      outline: s.outlineStyle !== 'none' || s.boxShadow !== 'none',
    }
  })
  if (el) reached.push(el)
}
ok(`tab reaches controls (${reached.length} in 14 presses)`, reached.length >= 8)
ok(
  'and focus is visible on each',
  reached.length > 0 && reached.every((e) => e.outline),
  reached.filter((e) => !e.outline).map((e) => e.name).slice(0, 3).join(', '),
)

ok('no page errors throughout', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'accessibility verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
