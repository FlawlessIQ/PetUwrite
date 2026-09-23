import { beforeAll, describe, expect, it } from 'vitest'
import { loadStore } from './db'
import { loadAuth } from '../auth/firebase'
import { profileFromFirestore, storedFromProfile } from '../data/fromFirestore'
import { project } from '../engine/project'
import type { PetProfile } from '../data/types'
import { installBrowserShims, signInFreshViaLink } from '../test-utils/emulatorAuth'

/**
 * Round-trips the real repository against the real Firestore emulator, signed
 * in as real emulator users, with the real `firestore.rules` loaded.
 *
 * Signing in matters: unauthenticated writes are rejected by the rules, so a
 * test that skipped auth would prove nothing about either the repository or the
 * rules. Several assertions below are negative — they prove the rules DENY
 * something — and those are the reason this file exists at all.
 *
 * Skipped unless VITE_RUN_EMULATOR_TESTS=1, so `npm test` stays a fast pure-unit run
 * needing nothing installed. Run with `npm run test:emulator`, which starts the
 * suite from the repo-root firebase.json and tears it down afterwards.
 */
const ENABLED = import.meta.env.VITE_RUN_EMULATOR_TESTS === '1'

const NOW = new Date('2026-09-23T12:00:00Z')

const profile = (over: Partial<PetProfile> = {}): PetProfile => ({
  id: `pet-${Math.random().toString(36).slice(2, 10)}`,
  name: 'Scout',
  species: 'dog',
  breedId: 'labrador-retriever',
  birthDate: '2021-04-02',
  sex: 'female',
  neutered: true,
  weightLb: 68,
  conditionIds: [],
  activity: 'moderate',
  dental: 'weekly',
  diet: 'measured',
  ...over,
})

describe.skipIf(!ENABLED)('firestore repository (emulator)', () => {
  let store: Awaited<ReturnType<typeof loadStore>>
  let auth: Awaited<ReturnType<typeof loadAuth>>

  /** A brand-new user, signed in through the real email-link flow. */
  const asNewUser = async (): Promise<string> => (await signInFreshViaLink(auth, 'store')).uid

  beforeAll(async () => {
    installBrowserShims()
    ;[store, auth] = await Promise.all([loadStore(), loadAuth()])
  })

  it('creates exactly one household on first sign-in, and finds it on the second', async () => {
    const me = await asNewUser()
    const first = await store.ensureHousehold(me, NOW)
    expect(first.id).toBeTruthy()
    expect(first.members[me].role).toBe('owner')
    expect(first.memberIds).toEqual([me])

    // The point of the lookup: signing in again must not create a second one.
    const second = await store.ensureHousehold(me, NOW)
    expect(second.id).toBe(first.id)
  })

  it('keeps memberIds in step with the members map', async () => {
    // These duplicate each other because Firestore cannot query map keys. If
    // they drift, the rules and the lookup disagree about who is in the
    // household — so it is asserted, not trusted.
    const me = await asNewUser()
    const hh = await store.ensureHousehold(me, NOW)
    expect(hh.memberIds.slice().sort()).toEqual(Object.keys(hh.members).sort())
  })

  it('round-trips a pet through a real write and read', async () => {
    const me = await asNewUser()
    const hh = await store.ensureHousehold(me, NOW)
    const before = profile()
    await store.savePet(hh.id, storedFromProfile(before, { householdId: hh.id, uid: me, now: NOW }))

    const pets = await store.listPets(hh.id)
    expect(pets).toHaveLength(1)
    const mapped = profileFromFirestore(pets[0])
    expect(mapped).not.toBeNull()
    expect(mapped!.profile).toEqual(before)
    expect(mapped!.assumed).toEqual([])
    expect(project(mapped!.profile, { now: NOW })).toEqual(project(before, { now: NOW }))
  })

  it('writes an import as one batch, so a household never holds half a migration', async () => {
    const me = await asNewUser()
    const hh = await store.ensureHousehold(me, NOW)
    const batch = [profile({ name: 'Rex' }), profile({ name: 'Nell' }), profile({ name: 'Pip' })]
    await store.savePets(
      hh.id,
      batch.map((p) =>
        storedFromProfile(p, { householdId: hh.id, uid: me, now: NOW, importedFrom: 'localStorage' }),
      ),
    )
    const pets = await store.listPets(hh.id)
    expect(pets.map((p) => p.name.value).sort()).toEqual(['Nell', 'Pip', 'Rex'])
    expect(pets.every((p) => p.importedFrom === 'localStorage')).toBe(true)
  })

  it('stores a Tier-0-only pet and still projects it', async () => {
    const me = await asNewUser()
    const hh = await store.ensureHousehold(me, NOW)
    const sparse = profile({ weightLb: 0 })
    await store.savePet(hh.id, storedFromProfile(sparse, { householdId: hh.id, uid: me, now: NOW }))

    const [read] = await store.listPets(hh.id)
    expect(read.weightLb).toBeUndefined()
    const mapped = profileFromFirestore(read)!
    expect(mapped.assumed.some((a) => a.field === 'weightLb')).toBe(true)
    expect(project(mapped.profile, { now: NOW }).widened).toBe(true)
  })

  it('deletes a pet without touching the household', async () => {
    const me = await asNewUser()
    const hh = await store.ensureHousehold(me, NOW)
    const p = profile()
    await store.savePet(hh.id, storedFromProfile(p, { householdId: hh.id, uid: me, now: NOW }))
    expect(await store.listPets(hh.id)).toHaveLength(1)
    await store.deletePet(hh.id, p.id)
    expect(await store.listPets(hh.id)).toHaveLength(0)
    expect((await store.ensureHousehold(me, NOW)).id).toBe(hh.id)
  })
})

// ───────────────────────────────────────────────────────────────────────────
// The rules themselves. Every assertion here is a denial — what someone else
// must NOT be able to do with your pets.
// ───────────────────────────────────────────────────────────────────────────
describe.skipIf(!ENABLED)('firestore rules — household isolation (emulator)', () => {
  let store: Awaited<ReturnType<typeof loadStore>>
  let auth: Awaited<ReturnType<typeof loadAuth>>

  beforeAll(async () => {
    installBrowserShims()
    ;[store, auth] = await Promise.all([loadStore(), loadAuth()])
  })

  /**
   * Asserts Firestore refused the operation.
   *
   * Checks the error CODE, not its message: the emulator reports a denial that
   * came from a rule expression erroring ("evaluation error at L605") and one
   * that came from a rule returning false with different text, and both are
   * denials. `permission-denied` is the stable contract across the emulator and
   * production.
   */
  const expectDenied = async (op: Promise<unknown>, what: string) => {
    let code: unknown = '(resolved without error)'
    try {
      await op
    } catch (err) {
      code = (err as { code?: unknown })?.code ?? String(err)
    }
    expect(code, what).toBe('permission-denied')
  }

  const signInFresh = async (): Promise<string> => (await signInFreshViaLink(auth, 'rules')).uid

  it("a stranger cannot read another household's pets", async () => {
    const a = await signInFresh()
    const ha = await store.ensureHousehold(a, NOW)
    await store.savePet(
      ha.id,
      storedFromProfile(profile({ name: 'Private' }), { householdId: ha.id, uid: a, now: NOW }),
    )

    // Completing a link signs the SDK in as B, so every call below is B's.
    const b = await signInFresh()
    expect(b).not.toBe(a)
    await expectDenied(store.listPets(ha.id), "stranger listing another household's pets")
  })

  it("a stranger cannot write into another household", async () => {
    const a = await signInFresh()
    const ha = await store.ensureHousehold(a, NOW)

    await signInFresh()
    await expectDenied(
      store.savePet(
        ha.id,
        storedFromProfile(profile({ name: 'Injected' }), { householdId: ha.id, uid: 'whoever', now: NOW }),
      ),
      'stranger writing into another household',
    )
  })

  it('a signed-out client cannot read or write anything', async () => {
    const a = await signInFresh()
    const ha = await store.ensureHousehold(a, NOW)
    await auth.signOut()
    await expectDenied(store.listPets(ha.id), 'signed-out read')
    await expectDenied(store.ensureHousehold('anyone', NOW), 'signed-out household lookup')
  })

  it('each new user gets their own household, never a shared one', async () => {
    const a = await signInFresh()
    const ha = await store.ensureHousehold(a, NOW)
    const b = await signInFresh()
    const hb = await store.ensureHousehold(b, NOW)
    expect(ha.id).not.toBe(hb.id)
    expect(hb.memberIds).toEqual([b])
  })
})
