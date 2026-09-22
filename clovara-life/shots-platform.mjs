import { chromium } from 'playwright'
import { mkdirSync } from 'node:fs'

const BASE = process.env.BASE || 'http://localhost:4173'
const OUT = 'shots'
const EXE = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'
mkdirSync(OUT, { recursive: true })

const DESKTOP = { width: 1440, height: 980 }
const PHONE = { width: 390, height: 844 }

const SURFACES = ['Home', 'Care', 'Rewards', 'Shop', 'Coverage', 'Life']

async function open(viewport, mobile = false) {
  const browser = await chromium.launch({ executablePath: EXE })
  const ctx = await browser.newContext(
    mobile ? { viewport, deviceScaleFactor: 2, isMobile: true, hasTouch: true } : { viewport },
  )
  const page = await ctx.newPage()
  const errors = []
  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()))
  page.on('pageerror', (e) => errors.push(String(e)))
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await page.waitForTimeout(500)
  return { browser, page, errors }
}

async function pickPet(page, name) {
  await page.getByRole('button', { name: /Choose a pet|^Max|^Winston|^Luna|^Poppy/ }).first().click()
  await page.getByRole('menuitem', { name: new RegExp(`^${name}`) }).click()
  await page.waitForTimeout(400)
}

async function goto(page, label, mobile) {
  const nav = page.getByRole('navigation', { name: 'Sections' })
  await nav.getByRole('button', { name: label, exact: true }).first().click()
  await page.waitForTimeout(mobile ? 450 : 350)
}

// ── Desktop: all six surfaces for Max ───────────────────────────────────────
{
  const { browser, page, errors } = await open(DESKTOP)
  for (const s of SURFACES) {
    await goto(page, s)
    await page.screenshot({ path: `${OUT}/p-desktop-max-${s.toLowerCase()}.png`, fullPage: true })
  }
  if (errors.length) console.log('[desktop max]', errors.slice(0, 4))
  await browser.close()
}

// ── Desktop: Luna, to prove the surfaces differ by species ──────────────────
{
  const { browser, page, errors } = await open(DESKTOP)
  await pickPet(page, 'Luna')
  for (const s of ['Shop', 'Coverage', 'Care']) {
    await goto(page, s)
    await page.screenshot({ path: `${OUT}/p-desktop-luna-${s.toLowerCase()}.png`, fullPage: true })
  }
  if (errors.length) console.log('[desktop luna]', errors.slice(0, 4))
  await browser.close()
}

// ── Desktop: Winston coverage, and the expanded pricing math ────────────────
{
  const { browser, page, errors } = await open(DESKTOP)
  await pickPet(page, 'Winston')
  await goto(page, 'Coverage')
  await page.getByRole('button', { name: /Why this price/i }).click()
  await page.waitForTimeout(350)
  await page.screenshot({ path: `${OUT}/p-desktop-winston-pricing.png`, fullPage: true })
  await goto(page, 'Shop')
  await page.getByRole('button', { name: /What the evidence says/i }).first().click()
  await page.waitForTimeout(350)
  await page.screenshot({ path: `${OUT}/p-desktop-winston-shop-evidence.png`, fullPage: true })
  if (errors.length) console.log('[desktop winston]', errors.slice(0, 4))
  await browser.close()
}

// ── Desktop: score breakdown open ───────────────────────────────────────────
{
  const { browser, page, errors } = await open(DESKTOP)
  await page.getByRole('button', { name: /What makes up the score/i }).click()
  await page.waitForTimeout(350)
  await page.screenshot({ path: `${OUT}/p-desktop-max-score-open.png`, fullPage: true })
  if (errors.length) console.log('[desktop score]', errors.slice(0, 4))
  await browser.close()
}

// ── Mobile: viewport-sized shots of every surface ───────────────────────────
{
  const { browser, page, errors } = await open(PHONE, true)
  for (const s of SURFACES) {
    await goto(page, s, true)
    await page.screenshot({ path: `${OUT}/p-mobile-${s.toLowerCase()}.png` })
  }
  // Full-page mobile for the two densest screens
  for (const s of ['Shop', 'Coverage']) {
    await goto(page, s, true)
    await page.screenshot({ path: `${OUT}/p-mobile-${s.toLowerCase()}-full.png`, fullPage: true })
  }
  if (errors.length) console.log('[mobile]', errors.slice(0, 4))
  await browser.close()
}

console.log('done')
