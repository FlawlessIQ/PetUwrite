/**
 * Anonymous visits reach lifeIngest (BACKLOG UB5 / AO13) — and checks don't.
 *
 * Always: an automated browser (navigator.webdriver) sends nothing, so the
 * verify suite and the phone book never count as visitors.
 *
 * With INGEST_LIVE=1 and BASE=https://clovara-life.web.app: a browser that is
 * not flagged as automated, signed out, has its events accepted (202) and its
 * queue drained. That writes one real visit to life_events, under a visitor id
 * starting `verify-` — which the dashboard leaves out.
 */
import { chromium } from 'playwright'

const BASE = process.env.BASE || 'http://127.0.0.1:4173'
const LIVE = process.env.INGEST_LIVE === '1'
let failures = 0
const ok = (label, cond, detail = '') => {
  if (cond) console.log(`  ✓ ${label}`)
  else {
    failures++
    console.log(`  ✗ ${label}${detail ? ' — ' + detail : ''}`)
  }
}
const isIngest = (url) => url.includes('/lifeIngest')
const browser = await chromium.launch()

console.log('\nAn automated browser is never counted')
{
  const page = await browser.newPage()
  const sent = []
  page.on('request', (r) => isIngest(r.url()) && sent.push(r.url()))
  await page.goto(`${BASE}/#/demo`, { waitUntil: 'networkidle' })
  await page.evaluate(() => localStorage.clear())
  await page.goto(`${BASE}/#/pet/demo-max/life`, { waitUntil: 'networkidle' })
  await page.waitForTimeout(6000)
  const queued = await page.evaluate(() => JSON.parse(localStorage.getItem('clovara-life.events.v1') || '[]').length)
  ok('it records events on the device as usual', queued > 0, String(queued))
  ok('and sends none of them', sent.length === 0, sent.join(' '))
  await page.close()
}

if (LIVE) {
  console.log(`\nA person, signed out — ${BASE}`)
  const ctx = await browser.newContext()
  const visitor = `verify-ingest-${new Date().toISOString().slice(0, 10)}`
  await ctx.addInitScript((id) => {
    Object.defineProperty(Navigator.prototype, 'webdriver', { get: () => false })
    if (!localStorage.getItem('clovara-life.visitor.v1')) localStorage.setItem('clovara-life.visitor.v1', id)
  }, visitor)
  const page = await ctx.newPage()
  const response = page.waitForResponse((r) => isIngest(r.url()) && r.request().method() === 'POST', { timeout: 15000 }).catch(() => null)
  await page.goto(`${BASE}/#/demo`, { waitUntil: 'networkidle' })
  const res = await response
  let body = null
  try {
    body = await res?.json()
  } catch {}
  ok('its events are sent to lifeIngest', !!res, 'no request within 15s — is the build flag on?')
  ok('and accepted', res?.status() === 202 && body?.stored > 0 && body?.refused === 0, `${res?.status()} ${JSON.stringify(body)}`)
  await page.waitForTimeout(500)
  const left = await page.evaluate(() => JSON.parse(localStorage.getItem('clovara-life.events.v1') || '[]'))
  ok('what landed leaves the queue', left.length < (body?.stored ?? 1) || left.length === 0, `${left.length} still queued`)
  ok('no Firebase SDK was loaded to do it', !(await page.evaluate(() => performance.getEntriesByType('resource').some((e) => /firestore|firebase/i.test(e.name) && !/cloudfunctions/.test(e.name)))))
  await ctx.close()
}

await browser.close()
console.log(failures ? `\n${failures} failed` : '\nanonymous ingest verified')
process.exit(failures ? 1 : 0)
