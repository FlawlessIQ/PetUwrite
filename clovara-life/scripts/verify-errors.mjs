/**
 * Client errors reach the queue, scrubbed (BACKLOG UB7).
 *
 * `errors.test.ts` proves the scrubbing. This proves the wiring: a crash
 * outside React and an unawaited rejection each become one `client_error`
 * event, with no email, link or stack in it, and a flood is capped.
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
const page = await browser.newPage()
const errors = () =>
  page.evaluate(() =>
    JSON.parse(localStorage.getItem('clovara-life.events.v1') || '[]').filter(
      (e) => e.name === 'client_error',
    ),
  )

console.log('\nClient errors')
await page.goto(`${BASE}/#/demo`, { waitUntil: 'networkidle' })
await page.evaluate(() => localStorage.clear())
await page.goto(`${BASE}/#/pet/demo-max/life`, { waitUntil: 'networkidle' })
ok('a normal visit records none', (await errors()).length === 0)

await page.evaluate(() => {
  setTimeout(() => {
    throw new Error('Could not save for jo@example.com at https://x.test/a 98511200445566')
  })
  Promise.reject(new Error('Nobody awaited this'))
})
await page.waitForFunction(
  () =>
    JSON.parse(localStorage.getItem('clovara-life.events.v1') || '[]').filter(
      (e) => e.name === 'client_error',
    ).length >= 2,
  null,
  { timeout: 5000 },
).catch(() => {})
const got = await errors()
const thrown = got.find((e) => e.props.kind === 'window')
const rejected = got.find((e) => e.props.kind === 'promise')
ok('a thrown error is recorded', !!thrown, JSON.stringify(got.map((e) => e.props)))
ok('an unawaited rejection is recorded', !!rejected)
ok(
  'the message is scrubbed of the email, the link and the number',
  thrown?.props.message === 'Could not save for [email] at [url] [number]',
  thrown?.props.message,
)
ok(
  'the route is a shape, not a pet',
  /^pet\/[a-z-]+$/.test(thrown?.props.route ?? '') && !thrown.props.route.includes('max'),
  thrown?.props.route,
)
ok(
  'nothing else rides along — no stack, no file',
  got.every((e) => Object.keys(e.props).sort().join() === 'component,kind,message,route'),
  JSON.stringify(got.map((e) => Object.keys(e.props))),
)

await page.evaluate(() => {
  for (let i = 0; i < 20; i++) setTimeout(() => { throw new Error(`flood ${i}`) })
})
await page.waitForTimeout(500)
ok('a flood is capped per session', (await errors()).length <= 5, String((await errors()).length))

await browser.close()
console.log(failures ? `\n${failures} failed` : '\nclient errors verified')
process.exit(failures ? 1 : 0)
