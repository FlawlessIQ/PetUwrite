/**
 * "Download everything about Bruno" (BACKLOG UB12), in a browser.
 *
 * `recordExport.test.ts` proves what the files say. This proves the Health
 * File hands them over: both downloads arrive, they are the pet's own record,
 * nothing leaves the device to make them, and a pet who has died keeps it.
 */
import { readFile } from 'node:fs/promises'
import { chromium } from 'playwright'
import { waitForText } from './lib/wait.mjs'

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
const ctx = await browser.newContext({ viewport: { width: 390, height: 844 }, acceptDownloads: true })
const page = await ctx.newPage()
const errors = []
page.on('pageerror', (e) => errors.push(String(e)))

const pet = {
  id: 'pet-rec',
  name: 'Bruno',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2016-03-14',
  sex: 'male',
  weightLb: 74,
  conditionIds: ['hip-dysplasia'],
  conditionsReviewed: true,
  careNotes: { feeding: 'Two scoops <am>' },
  knownSince: '2016-05-20T00:00:00.000Z',
}
const seed = async (over = {}) => {
  await page.goto(`${BASE}/#/demo`, { waitUntil: 'networkidle' })
  await page.evaluate((p) => {
    localStorage.clear()
    localStorage.setItem('clovara-life.pets.v1', JSON.stringify([p]))
  }, { ...pet, ...over })
  await page.goto(`${BASE}/#/health/pet-rec`, { waitUntil: 'networkidle' })
  await page.reload({ waitUntil: 'networkidle' })
  await waitForText(page, /Download everything about Bruno/)
}
const download = async (name) => {
  const [d] = await Promise.all([
    page.waitForEvent('download', { timeout: 8000 }),
    page.getByRole('button', { name }).click(),
  ])
  return { file: d.suggestedFilename(), text: await readFile(await d.path(), 'utf8') }
}

console.log('\nThe Health File hands over the record')
await seed()
ok('the card is on the Health File', (await page.getByRole('heading', { name: 'Download everything about Bruno' }).count()) === 1)

const requests = []
page.on('request', (r) => !r.url().startsWith('blob:') && !r.url().startsWith('data:') && requests.push(r.url()))
const html = await download(/Download Bruno.s record/)
ok('the readable copy arrives as bruno-clovara-record.html', html.file === 'bruno-clovara-record.html', html.file)
ok('it is Bruno’s record', html.text.includes('Everything on record for Bruno') && html.text.includes('Hip dysplasia'))
ok('what the owner typed is escaped', html.text.includes('Two scoops &lt;am&gt;') && !html.text.includes('<am>'))
const json = await download(/As data/)
let data = null
try {
  data = JSON.parse(json.text)
} catch {}
ok('the data copy arrives as .json', json.file === 'bruno-clovara-record.json', json.file)
ok('and holds the pet as stored', data?.pet?.id === 'pet-rec' && data?.pet?.careNotes?.feeding === 'Two scoops <am>')
ok('nothing went over the network to make either', requests.length === 0, requests.slice(0, 3).join(' '))
ok('it says where to look if nothing opened', /look in your downloads for bruno-clovara-record\.json/.test(await page.locator('body').innerText()))

const queue = await page.evaluate(() => JSON.parse(localStorage.getItem('clovara-life.events.v1') || '[]'))
const tracked = queue.filter((e) => e.name === 'record_downloaded')
ok('each download is counted, with no name in it', tracked.length === 2 && tracked.every((e) => !JSON.stringify(e.props).includes('Bruno')))

console.log('\nA pet who has died keeps it')
await seed({ diedOn: '2026-09-01' })
ok('the card is still there', (await page.getByRole('heading', { name: 'Download everything about Bruno' }).count()) === 1)
const after = await download(/Download Bruno.s record/)
ok('and the record says when', /Died/.test(after.text) && /1 September 2026/.test(after.text))

ok('no page errors', errors.length === 0, errors.slice(0, 2).join(' | '))
await browser.close()
console.log(failures ? `\n${failures} failed` : '\nrecord download verified')
process.exit(failures ? 1 : 0)
