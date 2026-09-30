/**
 * The security headers `hosting:life` promises (BACKLOG UB8).
 *
 * Statically: firebase.json's life target declares them (the `main` target is
 * not this script's business and is not read). Live: the page, an asset and a
 * partner page all carry them — against the preview (vite.config.ts serves the
 * same block) or, with BASE=https://clovara-life.web.app, production. And the
 * app loads under them without the browser complaining about the policy.
 */
import { readFileSync } from 'node:fs'
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

const EXPECTED = {
  'referrer-policy': 'strict-origin-when-cross-origin',
  'x-content-type-options': 'nosniff',
  'x-frame-options': 'DENY',
  'content-security-policy': "frame-ancestors 'none'",
}

console.log('\nfirebase.json — the life target')
const config = JSON.parse(readFileSync(new URL('../../firebase.json', import.meta.url), 'utf8'))
const life = config.hosting.find((h) => h.target === 'life')
const block = life?.headers?.find((h) => h.source === '**')
const declared = Object.fromEntries((block?.headers ?? []).map((h) => [h.key.toLowerCase(), h.value]))
for (const [k, v] of Object.entries(EXPECTED)) ok(`declares ${k}: ${v}`, declared[k] === v, declared[k])
const pp = declared['permissions-policy'] ?? ''
ok('Permissions-Policy lets the vet finder ask for location', /geolocation=\(self\)/.test(pp), pp)
ok('and turns off what the app never uses', ['microphone=()', 'payment=()', 'usb=()'].every((x) => pp.includes(x)), pp)

console.log(`\nServed — ${BASE}`)
const home = await fetch(`${BASE}/`)
const html = await home.text()
const asset = html.match(/\/assets\/[^"']+\.js/)?.[0]
for (const [label, url] of [
  ['the app', `${BASE}/`],
  ['a script asset', asset ? `${BASE}${asset}` : null],
  ['a partner page', `${BASE}/partners/journey.html`],
]) {
  if (!url) {
    ok(`${label} found`, false)
    continue
  }
  const res = url === `${BASE}/` ? home : await fetch(url)
  const missing = Object.entries(EXPECTED).filter(([k, v]) => res.headers.get(k) !== v)
  ok(
    `${label} carries all five`,
    res.ok && missing.length === 0 && !!res.headers.get('permissions-policy'),
    `${res.status} ${missing.map(([k]) => k).join(', ')}`,
  )
}

console.log('\nThe app under the policy')
const browser = await chromium.launch()
const page = await browser.newPage()
const complaints = []
page.on('console', (m) => /Permissions-Policy|Content Security Policy|X-Frame-Options/i.test(m.text()) && complaints.push(m.text()))
await page.goto(`${BASE}/#/demo`, { waitUntil: 'networkidle' })
await page.goto(`${BASE}/#/pet/demo-max/life`, { waitUntil: 'networkidle' })
ok('loads with no policy complaints in the console', complaints.length === 0, complaints.join(' | '))
ok('the demo still renders', (await page.locator('main, #root').first().innerText()).includes('Max'))
await browser.close()

console.log(failures ? `\n${failures} failed` : '\nsecurity headers verified')
process.exit(failures ? 1 : 0)
