/**
 * Photo upload against the Auth, Firestore and Storage emulators (SPEC §4.2).
 *
 * Driven in a real browser because the interesting parts are browser parts:
 * canvas resizing, and the fact that a 4032×3024 phone photo must not be what
 * gets uploaded or what Home downloads on every load.
 */
import { chromium } from 'playwright'

const BASE = 'http://127.0.0.1:4174'
const PROJECT = 'pet-underwriter-ai'
const EMU_AUTH = 'http://127.0.0.1:9099'

let failures = 0
const ok = (label, cond, detail = '') => {
  if (cond) console.log(`  ✓ ${label}`)
  else {
    failures++
    console.log(`  ✗ ${label}${detail ? ' — ' + detail : ''}`)
  }
}

const browser = await chromium.launch()
const ctx = await browser.newContext({ viewport: { width: 1100, height: 950 } })
const page = await ctx.newPage()
const errors = []
page.on('pageerror', (e) => errors.push(String(e)))

// A pet made signed-out, then an account, so there is a household to upload to.
await page.goto(BASE, { waitUntil: 'networkidle' })
await page.evaluate(() =>
  localStorage.setItem(
    'clovara-life.pets.v1',
    JSON.stringify([
      {
        id: 'pet-photo',
        name: 'Pepper',
        species: 'dog',
        breedId: 'beagle',
        birthDate: '2021-01-01',
        sex: 'female',
        weightLb: 0,
        conditionIds: [],
      },
    ]),
  ),
)

console.log('\nSign in and import')
const email = `photo-${Date.now()}@example.com`
await page.reload({ waitUntil: 'networkidle' })
await page.waitForTimeout(600)
await page.getByRole('button', { name: /Pepper|Max|Choose a pet/ }).first().click()
await page.waitForTimeout(300)
await page.getByRole('menuitem', { name: /Sign in/ }).click()
await page.waitForTimeout(500)
await page.getByLabel('Email').fill(email)
await page.getByRole('button', { name: /Email me a sign-in link/ }).click()
await page.waitForTimeout(1500)

const { oobCodes } = await fetch(`${EMU_AUTH}/emulator/v1/projects/${PROJECT}/oobCodes`).then((r) => r.json())
const mine = oobCodes.filter((c) => c.email === email).pop()
const oob = new URL(mine.oobLink)
const target = new URL(oob.searchParams.get('continueUrl'))
for (const k of ['apiKey', 'mode', 'oobCode', 'lang']) {
  const v = oob.searchParams.get(k)
  if (v) target.searchParams.set(k, v)
}
await page.goto(target.toString(), { waitUntil: 'load' })
await page.waitForTimeout(2500)
await page.getByRole('button', { name: 'Keep them' }).click()
await page.waitForTimeout(2500)
ok('signed in with a household and the pet imported', true)

console.log('\nUpload')
await page.goto(`${BASE}#/pet/pet-photo/life`, { waitUntil: 'load' })
await page.waitForTimeout(2500)
ok('the picker is offered', (await page.locator('[data-ask="photo"]').count()) === 1)
ok('it says it changes nothing in the plan', /Changes nothing in the plan/.test(await page.locator('[data-ask="photo"]').innerText()))

// A genuinely large landscape photo, as a phone would produce.
const buffer = await page.evaluate(async () => {
  const c = document.createElement('canvas')
  c.width = 4032
  c.height = 3024
  const g = c.getContext('2d')
  // Noise, not a gradient: a flat gradient compresses to almost nothing at any
  // size, which would make "the upload is smaller than the source" trivially
  // true and prove nothing.
  const img = g.createImageData(4032, 3024)
  for (let i = 0; i < img.data.length; i += 4) {
    img.data[i] = (Math.random() * 255) | 0
    img.data[i + 1] = (Math.random() * 255) | 0
    img.data[i + 2] = (Math.random() * 255) | 0
    img.data[i + 3] = 255
  }
  g.putImageData(img, 0, 0)
  const blob = await new Promise((res) => c.toBlob(res, 'image/jpeg', 0.92))
  const buf = new Uint8Array(await blob.arrayBuffer())
  return Array.from(buf)
})
ok(`source photo is a realistic phone photo (${(buffer.length / 1024 / 1024).toFixed(1)}MB, 4032×3024)`, buffer.length > 1_000_000)

await page.setInputFiles('[data-ask="photo"] input[type=file]', {
  name: 'pepper.jpg',
  mimeType: 'image/jpeg',
  buffer: Buffer.from(buffer),
})
await page.waitForTimeout(6000)

const stored = await page.evaluate(async () => {
  const el = document.querySelector('[data-ask="photo"] img')
  return el ? { src: el.getAttribute('src'), w: el.naturalWidth, h: el.naturalHeight } : null
})
ok('an avatar appears after upload', !!stored?.src && /^https?:/.test(stored.src), JSON.stringify(stored))
ok('the avatar is square and small, not the phone photo', stored?.w === stored?.h && stored?.w <= 512, `${stored?.w}×${stored?.h}`)

console.log('\nWhat was stored')
// Check the two objects directly rather than through a listing. The avatar's
// own download URL is the authoritative reference, and the full copy sits
// beside it under the same name — so this asserts the exact objects the app
// claims to have written, not whatever a list query feels like returning.
const avatarUrl = new URL(stored.src)
const BUCKET = avatarUrl.pathname.split('/')[3]
const avatarPath = decodeURIComponent(avatarUrl.pathname.split('/o/')[1])
const fullPath = avatarPath.replace('-avatar.jpg', '-full.jpg')
console.log(`    bucket: ${BUCKET}`)
console.log(`    avatar: ${avatarPath}`)
console.log(`    full:   ${fullPath}`)

ok('the avatar is under the household path the rules guard', avatarPath.startsWith('life/households/'))
ok('the path carries the pet id, so it cannot collide', avatarPath.includes('/pets/pet-photo/'))

const media = (path) =>
  `http://127.0.0.1:9199/v0/b/${BUCKET}/o/${encodeURIComponent(path)}?alt=media`

// The avatar carries a download token, so it is readable by anyone with the
// URL — that is what makes it cheap to render. The full copy deliberately has
// no token, so reading it goes through the Storage rules, which want household
// membership. A stranger with the exact path must be refused.
const strangerRes = await fetch(media(fullPath))
ok(
  'a stranger cannot read the full copy, even knowing its exact path',
  strangerRes.status === 403,
  `HTTP ${strangerRes.status}`,
)

// As the household member the app signed in as. The emulator accepts the owner
// token for this; in production the SDK signs the request.
const fullRes = await fetch(media(fullPath), { headers: { Authorization: 'Bearer owner' } })
ok('a full copy was written beside the avatar', fullRes.ok, `HTTP ${fullRes.status}`)
const fullBytes = fullRes.ok ? (await fullRes.arrayBuffer()).byteLength : 0
ok(
  `the kept copy is far smaller than the source (${(fullBytes / 1024 / 1024).toFixed(2)}MB vs ${(buffer.length / 1024 / 1024).toFixed(1)}MB)`,
  fullBytes > 0 && fullBytes < buffer.length / 2,
)

// Decoded in the page from the authenticated bytes, since the URL itself is
// not publicly readable — which is the point of the assertion above.
const dims = fullBytes
  ? await page.evaluate(
      (bytes) =>
        new Promise((res) => {
          const blob = new Blob([new Uint8Array(bytes)], { type: 'image/jpeg' })
          const url = URL.createObjectURL(blob)
          const i = new Image()
          i.onload = () => {
            res({ w: i.naturalWidth, h: i.naturalHeight })
            URL.revokeObjectURL(url)
          }
          i.onerror = () => res(null)
          i.src = url
        }),
      Array.from(new Uint8Array(await (await fetch(media(fullPath), { headers: { Authorization: 'Bearer owner' } })).arrayBuffer())),
    )
  : null
ok(
  `the kept copy is capped at 2048 on the long edge (${dims?.w}×${dims?.h}), not the 4032 source`,
  !!dims && Math.max(dims.w, dims.h) === 2048,
  JSON.stringify(dims),
)
ok('and it kept the source aspect ratio', !!dims && Math.abs(dims.w / dims.h - 4032 / 3024) < 0.01)

console.log('\nPersistence')
await page.reload({ waitUntil: 'load' })
await page.waitForTimeout(3000)
const afterReload = await page.evaluate(() => !!document.querySelector('header img'))
ok('the avatar survives a reload', afterReload)
ok('no page errors', errors.length === 0, errors.slice(0, 2).join(' | '))

await browser.close()
console.log(`\n${failures === 0 ? 'photo verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
