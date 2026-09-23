import { beforeAll, beforeEach, describe, expect, it } from 'vitest'

/**
 * End-to-end analytics against the emulator, with the real rules loaded.
 *
 * `track()` writes to localStorage, which does not exist in node — without the
 * shim below it silently no-ops and every assertion here would pass while
 * testing nothing. So the shim goes in before any module that touches storage
 * is imported.
 */
const ENABLED = process.env.RUN_EMULATOR_TESTS === '1'

if (ENABLED && typeof globalThis.localStorage === 'undefined') {
  const mem = new Map<string, string>()
  Object.defineProperty(globalThis, 'localStorage', {
    configurable: true,
    value: {
      getItem: (k: string) => mem.get(k) ?? null,
      setItem: (k: string, v: string) => void mem.set(k, String(v)),
      removeItem: (k: string) => void mem.delete(k),
      clear: () => mem.clear(),
      key: (i: number) => [...mem.keys()][i] ?? null,
      get length() {
        return mem.size
      },
    },
  })
}

const { track, flush, queuedCount } = await import('./track')
const { loadAuth } = await import('../auth/firebase')

describe.skipIf(!ENABLED)('analytics flush (emulator)', () => {
  let auth: Awaited<ReturnType<typeof loadAuth>>

  const signInFresh = async (): Promise<string> => {
    const email = `ev-${Math.random().toString(36).slice(2, 10)}@example.com`
    const cred = await auth.createAccount(email, 'emulator-password')
    return cred.user.uid
  }

  beforeAll(async () => {
    auth = await loadAuth()
  })

  beforeEach(() => localStorage.clear())

  it('buffers while signed out and writes the backlog once there is an identity', async () => {
    // This is the whole point of the queue: the reveal happens before anyone
    // has an account, and it still has to be countable afterwards.
    track('reveal_viewed', { pet_is_demo: true })
    track('pet_created', { species: 'dog' })
    expect(queuedCount()).toBe(2)

    const uid = await signInFresh()
    const written = await flush(uid)
    expect(written).toBe(2)
    expect(queuedCount()).toBe(0)
  })

  it('does not lose events logged while a flush is in flight', async () => {
    track('reveal_viewed', {})
    const uid = await signInFresh()
    const inFlight = flush(uid)
    track('pet_created', { species: 'cat' })
    await inFlight
    // The second event was queued after the flush read its batch, so it must
    // still be waiting rather than have been silently dropped.
    expect(queuedCount()).toBe(1)
  })

  it('is safe to call twice at once', async () => {
    track('reveal_viewed', {})
    const uid = await signInFresh()
    // Reference equality is the precise claim: overlapping calls get the SAME
    // promise, so only one write path ever runs. Comparing the resolved numbers
    // cannot distinguish a shared flight from a double write — both would
    // report 1 each.
    const first = flush(uid)
    const second = flush(uid)
    expect(second).toBe(first)
    expect(await first).toBe(1)
    expect(queuedCount()).toBe(0)
  })

  it('survives a flush with nothing queued', async () => {
    const uid = await signInFresh()
    expect(await flush(uid)).toBe(0)
  })
})

describe.skipIf(!ENABLED)('analytics rules — append-only (emulator)', () => {
  let auth: Awaited<ReturnType<typeof loadAuth>>

  beforeAll(async () => {
    auth = await loadAuth()
  })

  const fs = async () => {
    const [{ getApps, getApp, initializeApp }, mod] = await Promise.all([
      import('firebase/app'),
      import('firebase/firestore'),
    ])
    const { FIREBASE_CONFIG } = await import('../auth/config')
    const app = getApps().length ? getApp() : initializeApp(FIREBASE_CONFIG)
    const db = mod.getFirestore(app)
    try {
      mod.connectFirestoreEmulator(db, '127.0.0.1', 8080)
    } catch {
      /* already connected */
    }
    return { db, ...mod }
  }

  const code = async (op: Promise<unknown>): Promise<unknown> => {
    try {
      await op
      return '(allowed)'
    } catch (err) {
      return (err as { code?: unknown })?.code ?? String(err)
    }
  }

  const signInFresh = async (): Promise<string> => {
    const email = `rules-ev-${Math.random().toString(36).slice(2, 10)}@example.com`
    return (await auth.createAccount(email, 'emulator-password')).user.uid
  }

  it('refuses an event stamped with somebody else\'s uid', async () => {
    // Without this, any signed-in user could forge another account's funnel.
    const me = await signInFresh()
    const { db, collection, doc, setDoc } = await fs()
    const ref = doc(collection(db, 'life_events'))
    expect(
      await code(setDoc(ref, { name: 'trial_started', uid: 'someone-else', at: new Date().toISOString(), props: {}, visitorId: 'v', sessionId: 's', build: 't' })),
    ).toBe('permission-denied')
    expect(me).toBeTruthy()
  })

  it('refuses edits and deletes — the log is append-only by construction', async () => {
    const uid = await signInFresh()
    const { db, collection, doc, setDoc, updateDoc, deleteDoc } = await fs()
    const ref = doc(collection(db, 'life_events'))
    const base = { name: 'reveal_viewed', uid, at: new Date().toISOString(), props: {}, visitorId: 'v', sessionId: 's', build: 't' }
    expect(await code(setDoc(ref, base))).toBe('(allowed)')
    expect(await code(updateDoc(ref, { name: 'attach_bound' }))).toBe('permission-denied')
    expect(await code(deleteDoc(ref))).toBe('permission-denied')
  })

  it('refuses reads to a non-admin, so the dashboard is genuinely gated', async () => {
    // The route guard in the client is UX. This is the control.
    const uid = await signInFresh()
    const { db, collection, doc, setDoc, getDocs, query, limit } = await fs()
    await setDoc(doc(collection(db, 'life_events')), {
      name: 'reveal_viewed', uid, at: new Date().toISOString(), props: {}, visitorId: 'v', sessionId: 's', build: 't',
    })
    expect(await code(getDocs(query(collection(db, 'life_events'), limit(1))))).toBe(
      'permission-denied',
    )
  })

  it('refuses a signed-out write', async () => {
    await signInFresh()
    await auth.signOut()
    const { db, collection, doc, setDoc } = await fs()
    expect(
      await code(setDoc(doc(collection(db, 'life_events')), { name: 'reveal_viewed', uid: 'x', at: new Date().toISOString(), props: {}, visitorId: 'v', sessionId: 's', build: 't' })),
    ).toBe('permission-denied')
  })
})
