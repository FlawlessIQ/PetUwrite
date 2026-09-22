import { chromium } from 'playwright'
import { mkdirSync } from 'node:fs'

/**
 * Browser to launch. Defaults to whatever Playwright resolved for this
 * platform, so the script runs on a developer Mac as well as in CI. Set
 * PW_EXECUTABLE to pin a specific binary.
 */
const LAUNCH = process.env.PW_EXECUTABLE ? { executablePath: process.env.PW_EXECUTABLE } : {}

const BASE = process.env.BASE || 'http://localhost:4173'
const OUT = 'shots'
mkdirSync(OUT, { recursive: true })

const DESKTOP = { width: 1440, height: 980 }
const MOBILE = { width: 390, height: 844, deviceScaleFactor: 2, isMobile: true, hasTouch: true }

async function pickPet(page, name) {
  await page.getByRole('button', { name: /Choose a pet|Max|Winston|Luna/ }).first().click()
  await page.getByRole('menuitem', { name: new RegExp(`^${name}`) }).click()
  await page.waitForTimeout(350)
}

async function run(label, viewport, fn) {
  const browser = await chromium.launch(LAUNCH)
  const ctx = await browser.newContext({ viewport, ...(viewport.isMobile ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) })
  const page = await ctx.newPage()
  const errors = []
  page.on('console', (m) => m.type() === 'error' && errors.push(m.text()))
  page.on('pageerror', (e) => errors.push(String(e)))
  await page.goto(BASE, { waitUntil: 'networkidle' })
  await page.waitForTimeout(500)
  await fn(page, label)
  if (errors.length) console.log(`[${label}] console errors:`, errors.slice(0, 5))
  await browser.close()
}

const full = (page, name) => page.screenshot({ path: `${OUT}/${name}.png`, fullPage: true })

// Desktop: each demo pet
for (const pet of ['Max', 'Winston', 'Luna']) {
  await run(`desktop-${pet}`, DESKTOP, async (page, label) => {
    if (pet !== 'Max') await pickPet(page, pet)
    await full(page, label)
  })
}

// Desktop: levers toggled + methodology open
await run('desktop-levers', DESKTOP, async (page, label) => {
  const levers = page.getByRole('region', { name: /What you can change/i })
  await levers.getByRole('radio', { name: 'Overweight' }).click()
  await page.waitForTimeout(200)
  await levers.getByRole('radio', { name: 'Rarely' }).click()
  await page.waitForTimeout(200)
  await levers.getByRole('radio', { name: 'Low' }).click()
  await page.waitForTimeout(350)
  await full(page, label)
  // Hero close-up so the number is legible
  await page.locator('section').first().screenshot({ path: `${OUT}/${label}-hero.png` })
})

await run('desktop-methodology', DESKTOP, async (page, label) => {
  await page.getByRole('button', { name: /How we work this out/i }).click()
  await page.waitForTimeout(350)
  await full(page, label)
})

// Desktop: onboarding, every step
await run('desktop-onboarding', DESKTOP, async (page) => {
  await page.getByRole('button', { name: 'Add a pet', exact: true }).click()
  await page.waitForTimeout(300)
  await full(page, 'desktop-onboarding-1')
  await page.getByLabel('Their name').fill('Poppy')
  await page.getByRole('radio', { name: 'Dog' }).click()
  await page.getByRole('button', { name: 'Continue' }).click()
  await page.waitForTimeout(250)
  await page.getByLabel('Search breeds').fill('bern')
  await page.waitForTimeout(250)
  await full(page, 'desktop-onboarding-2')
  await page.getByRole('button', { name: /Bernese/ }).click()
  await page.getByRole('button', { name: 'Continue' }).click()
  await page.waitForTimeout(250)
  await page.getByLabel('Date of birth').fill('2022-04-02')
  await page.getByRole('radio', { name: 'Female' }).click()
  await page.getByRole('radio', { name: 'Yes' }).click()
  await full(page, 'desktop-onboarding-3')
  await page.getByRole('button', { name: 'Continue' }).click()
  await page.waitForTimeout(250)
  await page.getByLabel('Current weight (lb)').fill('112')
  await page.waitForTimeout(250)
  await full(page, 'desktop-onboarding-4')
  await page.getByRole('button', { name: 'Continue' }).click()
  await page.waitForTimeout(250)
  await full(page, 'desktop-onboarding-5')
  await page.getByRole('button', { name: 'Continue' }).click()
  await page.waitForTimeout(250)
  await full(page, 'desktop-onboarding-6')
  await page.getByRole('button', { name: 'See the journey' }).click()
  await page.waitForTimeout(600)
  await full(page, 'desktop-onboarding-result')
})

// Mobile
for (const pet of ['Max', 'Luna']) {
  await run(`mobile-${pet}`, MOBILE, async (page, label) => {
    if (pet !== 'Max') await pickPet(page, pet)
    await full(page, label)
  })
}

await run('mobile-onboarding', MOBILE, async (page, label) => {
  await page.getByRole('button', { name: /Choose a pet|Max/ }).first().click()
  await page.getByRole('menuitem', { name: /Add a pet/ }).click()
  await page.waitForTimeout(300)
  await full(page, label)
})

console.log('done')
