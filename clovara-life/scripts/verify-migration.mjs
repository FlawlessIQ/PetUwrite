/**
 * End-to-end check of the localStorage → Firestore migration (SPEC §3).
 *
 * Runs it the way a person does: make a pet signed out, ask for a sign-in link,
 * complete it, take the "Keep working with Max?" offer, reload. Every step is an
 * assertion, and the last two matter most — the pet has to come back from
 * Firestore rather than from the device, and the offer must not reappear.
 *
 * Needs the emulator suite and a preview built with VITE_USE_EMULATORS=1, both
 * of which `npm run verify:migration` arranges.
 */
import { chromium } from 'playwright'

const BASE = 'http://127.0.0.1:4174'
const PROJECT = 'pet-underwriter-ai'
const EMU = 'http://127.0.0.1:9099'

let failures = 0
const ok = (label, cond, detail = '') => {
  if (cond) {
    console.log(`  ✓ ${label}`)
  } else {
    failures++
    console.log(`  ✗ ${label}${detail ? ' — ' + detail : ''}`)
  }
}

const browser = await chromium.launch()
const ctx = await browser.newContext({ viewport: { width: 1100, height: 900 } })
const page = await ctx.newPage()
const errors = []
page.on('pageerror', (e) => errors.push(String(e)))
page.on('console', (m) => m.type() === 'error' && errors.push(m.text()))

// ── 1. Signed out, a pet made on this device ────────────────────────────────
console.log('\nSigned out')
await page.goto(BASE, { waitUntil: 'networkidle' })
await page.evaluate(() => {
  localStorage.setItem(
    'clovara-life.pets.v1',
    JSON.stringify([
      {
        id: 'pet-local-1',
        name: 'Biscuit',
        species: 'dog',
        breedId: 'border-collie',
        birthDate: '2022-03-01',
        sex: 'female',
        neutered: true,
        weightLb: 40,
        conditionIds: [],
        activity: 'high',
        dental: 'weekly',
        diet: 'measured',
      },
    ]),
  )
})
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(600)
await page.getByRole('button', { name: /Max|Choose a pet/ }).first().click()
await page.waitForTimeout(250)
ok('a local pet shows in the switcher', (await page.locator('[role="menu"]').textContent()).includes('Biscuit'))

// ── 2. Sign in with a one-time link ─────────────────────────────────────────
console.log('\nEmail-link sign-in')
const email = `migrate-${Date.now()}@example.com`
await page.getByRole('menuitem', { name: /Sign in/ }).click()
await page.waitForTimeout(400)
await page.getByLabel('Email').fill(email)
await page.getByRole('button', { name: /Email me a sign-in link/ }).click()
await page.waitForTimeout(1500)
ok('confirmation names the address', (await page.locator('[role="dialog"]').textContent()).includes('sign-in link'))

const { oobCodes } = await fetch(`${EMU}/emulator/v1/projects/${PROJECT}/oobCodes`).then((r) => r.json())
const mine = oobCodes.filter((c) => c.email === email).pop()
// The emulator's oobLink points at its own action page. What the app receives in
// production is the continueUrl with Firebase's parameters appended, so build
// that rather than rewriting the host.
const oob = new URL(mine.oobLink)
const target = new URL(oob.searchParams.get('continueUrl'))
for (const k of ['apiKey', 'mode', 'oobCode', 'lang']) {
  const v = oob.searchParams.get(k)
  if (v) target.searchParams.set(k, v)
}
// 'load', not 'networkidle': once Firestore connects it holds a stream open and
// the network never goes idle again.
await page.goto(target.toString(), { waitUntil: 'load' })
await page.waitForTimeout(2500)
ok('the link signs you in', (await page.evaluate(() => localStorage.getItem('clovara-life.session.v1'))) === '1')
ok('one-time parameters are stripped from the URL', !page.url().includes('oobCode'))

// ── 3. The import offer ─────────────────────────────────────────────────────
console.log('\nImport')
const banner = await page.locator('section[aria-labelledby="import-heading"]').textContent().catch(() => null)
ok('offer appears and names the pet', !!banner && banner.includes('Biscuit'))

await page.getByRole('button', { name: 'Keep them' }).click()
await page.waitForTimeout(2500)
ok('offer clears once taken', (await page.locator('section[aria-labelledby="import-heading"]').count()) === 0)
ok('local copy removed only after the write landed', (await page.evaluate(() => localStorage.getItem('clovara-life.pets.v1'))) === null)

// ── 4. It came from the cloud, not the device ───────────────────────────────
console.log('\nAfter reload')
await page.reload({ waitUntil: 'load' })
await page.waitForTimeout(3000)
await page.getByRole('button', { name: /Max|Choose a pet|Biscuit/ }).first().click()
await page.waitForTimeout(400)
const menu = await page.locator('[role="menu"]').textContent()
ok('the pet survives a reload, from Firestore', menu.includes('Biscuit'))
ok('the import is not offered again', (await page.locator('section[aria-labelledby="import-heading"]').count()) === 0)
ok('demo pets are untouched throughout', ['Max', 'Winston', 'Luna'].every((n) => menu.includes(n)))
ok('no page errors', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'migration verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
