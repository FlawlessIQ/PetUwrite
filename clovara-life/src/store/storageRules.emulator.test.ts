import { beforeAll, describe, expect, it } from 'vitest'
import { loadAuth } from '../auth/firebase'
import { loadStore } from './db'
import { installBrowserShims, signInFreshViaLink } from '../test-utils/emulatorAuth'

/**
 * The real `storage.rules`, against the real Storage emulator, as real users.
 *
 * `verify-photo.mjs` drives the uploader in a browser and proves the happy
 * path works and that one stranger is refused. This file is the other half:
 * the refusals, which are the reason the rules exist and the part a browser
 * run cannot enumerate. Every check below that matters is negative.
 *
 * The load-bearing one is `records/`. Storage grants access if ANY matching
 * rule allows, so an explicit deny cannot override an allow — the vet-record
 * path is safe only because `{fileName}` is a single-segment wildcard and
 * `records/x.pdf` is two segments. That is a subtlety one careless edit turns
 * into a leak of someone's medical history, so it is asserted rather than
 * reasoned about.
 *
 * Skipped unless VITE_RUN_EMULATOR_TESTS=1. Needs the storage emulator, which
 * `npm run test:emulator` starts.
 */
const ENABLED = import.meta.env.VITE_RUN_EMULATOR_TESTS === '1'

const NOW = new Date('2026-09-23T12:00:00Z')

type StorageMod = typeof import('firebase/storage')

let S: StorageMod
let storage: ReturnType<StorageMod['getStorage']>
let auth: Awaited<ReturnType<typeof loadAuth>>
let store: Awaited<ReturnType<typeof loadStore>>

/** A tiny but genuine JPEG — rules check contentType, not bytes. */
const jpeg = (bytes = 64) => new Blob([new Uint8Array(bytes).fill(7)], { type: 'image/jpeg' })

/** True when the rules refused, rather than something else breaking. */
async function refused(op: Promise<unknown>): Promise<boolean> {
  try {
    await op
    return false
  } catch (e) {
    const code = (e as { code?: string }).code ?? String(e)
    // storage/unauthorized is the rules saying no. Anything else is a bug in
    // the test, and should fail loudly rather than count as a pass — a test
    // that treats every error as "denied" passes when the emulator is down.
    if (/unauthorized|storage\/unauthenticated/.test(code)) return true
    throw e
  }
}

beforeAll(async () => {
  if (!ENABLED) return
  installBrowserShims()
  const [appMod, storageMod] = await Promise.all([import('firebase/app'), import('firebase/storage')])
  S = storageMod
  const { FIREBASE_CONFIG } = await import('../auth/config')
  const app = appMod.getApps().length ? appMod.getApp() : appMod.initializeApp(FIREBASE_CONFIG)
  storage = S.getStorage(app)
  try {
    S.connectStorageEmulator(storage, '127.0.0.1', 9199)
  } catch {
    /* already connected */
  }
  auth = await loadAuth()
  store = await loadStore()
}, 60_000)

const petPath = (hh: string, pet: string, file = 'photo-1-avatar.jpg') =>
  `life/households/${hh}/pets/${pet}/${file}`

describe.skipIf(!ENABLED)('storage.rules — Life photos', () => {
  it('lets a member write and read a photo of their own pet', async () => {
    const me = await signInFreshViaLink(auth, 'sr-owner')
    const hh = await store.ensureHousehold(me.uid, NOW)
    const path = petPath(hh.id, 'pet-a')

    await S.uploadBytes(S.ref(storage, path), jpeg(), { contentType: 'image/jpeg' })
    const url = await S.getDownloadURL(S.ref(storage, path))
    expect(url).toContain(encodeURIComponent(`life/households/${hh.id}`))
  })

  it('refuses a stranger both read and write on someone else\'s pet', async () => {
    const me = await signInFreshViaLink(auth, 'sr-a')
    const mine = await store.ensureHousehold(me.uid, NOW)
    const path = petPath(mine.id, 'pet-b')
    await S.uploadBytes(S.ref(storage, path), jpeg(), { contentType: 'image/jpeg' })

    // Become somebody else entirely, knowing the exact path.
    await signInFreshViaLink(auth, 'sr-b')
    expect(await refused(S.getDownloadURL(S.ref(storage, path)))).toBe(true)
    expect(
      await refused(S.uploadBytes(S.ref(storage, path), jpeg(), { contentType: 'image/jpeg' })),
      'a stranger overwrote a photo',
    ).toBe(true)
    expect(await refused(S.deleteObject(S.ref(storage, path))), 'a stranger deleted a photo').toBe(
      true,
    )
  })

  it('refuses a household that does not exist, so a made-up id is not a way in', async () => {
    await signInFreshViaLink(auth, 'sr-ghost')
    const path = petPath('household-that-was-never-created', 'pet-c')
    expect(await refused(S.uploadBytes(S.ref(storage, path), jpeg()))).toBe(true)
  })

  it('refuses everyone who is not signed in', async () => {
    const me = await signInFreshViaLink(auth, 'sr-signed-in')
    const hh = await store.ensureHousehold(me.uid, NOW)
    const path = petPath(hh.id, 'pet-d')
    await S.uploadBytes(S.ref(storage, path), jpeg(), { contentType: 'image/jpeg' })

    await auth.signOut()
    expect(await refused(S.getDownloadURL(S.ref(storage, path)))).toBe(true)
    expect(await refused(S.uploadBytes(S.ref(storage, path), jpeg()))).toBe(true)
  })

  it('refuses vet records outright, even to the household that owns them', async () => {
    // P1.7 is blocked on the Firestore security review SPEC §7 requires. Until
    // that happens nothing may be written here, and the nested path must not
    // fall through the single-segment photo rule above it.
    const me = await signInFreshViaLink(auth, 'sr-records')
    const hh = await store.ensureHousehold(me.uid, NOW)
    const pdf = new Blob([new Uint8Array(32)], { type: 'application/pdf' })

    for (const p of [
      `life/households/${hh.id}/pets/pet-e/records/bloods.pdf`,
      `life/households/${hh.id}/pets/pet-e/records/2024/bloods.pdf`,
    ]) {
      expect(await refused(S.uploadBytes(S.ref(storage, p), pdf)), p).toBe(true)
      expect(await refused(S.getDownloadURL(S.ref(storage, p))), p).toBe(true)
    }
  })

  it('refuses anything that is not an image, however it is named', async () => {
    const me = await signInFreshViaLink(auth, 'sr-type')
    const hh = await store.ensureHousehold(me.uid, NOW)
    // A .jpg name with a PDF inside is the interesting case: the rule checks
    // the declared content type, so the extension must not be what saves us.
    const path = petPath(hh.id, 'pet-f', 'photo-1-avatar.jpg')
    const notAnImage = new Blob([new Uint8Array(32)], { type: 'application/pdf' })
    expect(await refused(S.uploadBytes(S.ref(storage, path), notAnImage))).toBe(true)
  })

  it('refuses a file larger than the uploader could ever produce', async () => {
    const me = await signInFreshViaLink(auth, 'sr-size')
    const hh = await store.ensureHousehold(me.uid, NOW)
    const path = petPath(hh.id, 'pet-g', 'photo-1-full.jpg')
    const huge = new Blob([new Uint8Array(13 * 1024 * 1024)], { type: 'image/jpeg' })
    expect(await refused(S.uploadBytes(S.ref(storage, path), huge))).toBe(true)
  }, 60_000)

  it('leaves the underwriting paths alone', async () => {
    // The Life block is additive; the catch-all deny above it still applies to
    // everything outside `life/`. If this ever passes, a glob has widened.
    const me = await signInFreshViaLink(auth, 'sr-scope')
    await store.ensureHousehold(me.uid, NOW)
    expect(await refused(S.uploadBytes(S.ref(storage, 'life-ish/anything.jpg'), jpeg()))).toBe(true)
    expect(await refused(S.uploadBytes(S.ref(storage, 'anything.jpg'), jpeg()))).toBe(true)
  })
})
