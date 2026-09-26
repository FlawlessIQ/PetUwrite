import { beforeAll, describe, expect, it } from 'vitest'
import { loadAuth } from '../auth/firebase'
import { installBrowserShims, signInFreshViaLink } from '../test-utils/emulatorAuth'

/**
 * ADVERSARIAL rules tests — written to break the rules, not to confirm them.
 *
 * The existing emulator suite checks that the rules do what I intended. This
 * file assumes my intentions were wrong somewhere and goes looking. It is not
 * a substitute for the independent review SPEC §7 budgets for — I wrote these
 * rules, so I share their blind spots — but everything it finds is real.
 *
 * Each test is named for the attack, not the feature.
 */
const ENABLED = import.meta.env.VITE_RUN_EMULATOR_TESTS === '1'

const PROJECT = 'pet-underwriter-ai'
const FS = `http://127.0.0.1:8080/v1/projects/${PROJECT}/databases/(default)/documents`

let auth: Awaited<ReturnType<typeof loadAuth>>
let fs: typeof import('firebase/firestore')
let db: ReturnType<typeof import('firebase/firestore').getFirestore>

/** Writes a document bypassing the rules, to set up a victim. */
async function seedAsAdmin(path: string, fields: Record<string, unknown>) {
  const res = await fetch(`${FS}/${path}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', Authorization: 'Bearer owner' },
    body: JSON.stringify({ fields }),
  })
  if (!res.ok) throw new Error(`seed failed ${res.status}`)
}

const strArr = (xs: string[]) => ({ arrayValue: { values: xs.map((v) => ({ stringValue: v })) } })

async function denied(op: Promise<unknown>): Promise<boolean> {
  try {
    await op
    return false
  } catch (e) {
    const code = (e as { code?: string }).code ?? String(e)
    if (/permission-denied|PERMISSION_DENIED/.test(code)) return true
    throw e
  }
}

beforeAll(async () => {
  if (!ENABLED) return
  installBrowserShims()
  const [appMod, fsMod] = await Promise.all([import('firebase/app'), import('firebase/firestore')])
  fs = fsMod
  const { FIREBASE_CONFIG } = await import('../auth/config')
  const app = appMod.getApps().length ? appMod.getApp() : appMod.initializeApp(FIREBASE_CONFIG)
  db = fs.getFirestore(app)
  try {
    fs.connectFirestoreEmulator(db, '127.0.0.1', 8080)
  } catch {
    /* already connected */
  }
  auth = await loadAuth()
}, 60_000)

describe.skipIf(!ENABLED)('attacking the Life rules', () => {
  it('ATTACK: grant myself a paid membership by creating a household with an entitlement', async () => {
    // The update rule forbids touching `entitlement`. The CREATE rule checks
    // createdBy, memberIds and members — and says nothing about entitlement.
    const me = await signInFreshViaLink(auth, 'atk-ent')
    const id = `hh-atk-${Date.now()}`
    const attempt = fs.setDoc(fs.doc(db, 'households', id), {
      createdBy: me.uid,
      memberIds: [me.uid],
      members: { [me.uid]: { role: 'owner' } },
      createdAt: new Date().toISOString(),
      // Never paid a penny.
      entitlement: { status: 'active', priceId: 'stolen', currentPeriodEnd: '2099-01-01' },
    })
    expect(
      await denied(attempt),
      'a client created a household carrying its own active entitlement',
    ).toBe(true)
  })

  it('ATTACK: evict the household owner and keep their pets', async () => {
    // The update rule requires only that the WRITER remains a member. It says
    // nothing about anybody else, so a member can remove the founder from the
    // household holding their own animals.
    const owner = await signInFreshViaLink(auth, 'atk-owner')
    const id = `hh-eviction-${Date.now()}`
    await seedAsAdmin(`households/${id}`, {
      createdBy: { stringValue: owner.uid },
      memberIds: strArr([owner.uid, 'ATTACKER_UID']),
      members: { mapValue: { fields: {} } },
    })

    // The attacker is a legitimate member — they were invited.
    const attacker = await signInFreshViaLink(auth, 'atk-evictor')
    await seedAsAdmin(`households/${id}`, {
      createdBy: { stringValue: owner.uid },
      memberIds: strArr([owner.uid, attacker.uid]),
      members: { mapValue: { fields: {} } },
    })

    const attempt = fs.updateDoc(fs.doc(db, 'households', id), {
      // Owner removed. Attacker keeps the pets.
      memberIds: [attacker.uid],
    })
    expect(
      await denied(attempt),
      'a household member evicted the founder and kept their pets',
    ).toBe(true)
  })

  it('ATTACK: add myself to a stranger\'s household', async () => {
    const victim = await signInFreshViaLink(auth, 'atk-victim')
    const id = `hh-join-${Date.now()}`
    await seedAsAdmin(`households/${id}`, {
      createdBy: { stringValue: victim.uid },
      memberIds: strArr([victim.uid]),
      members: { mapValue: { fields: {} } },
    })
    const attacker = await signInFreshViaLink(auth, 'atk-joiner')
    expect(
      await denied(
        fs.updateDoc(fs.doc(db, 'households', id), { memberIds: [victim.uid, attacker.uid] }),
      ),
    ).toBe(true)
  })

  it('ATTACK: create a household in somebody else\'s name', async () => {
    const attacker = await signInFreshViaLink(auth, 'atk-impersonate')
    expect(
      await denied(
        fs.setDoc(fs.doc(db, 'households', `hh-imp-${Date.now()}`), {
          createdBy: 'SOMEBODY_ELSE',
          memberIds: [attacker.uid],
          members: { [attacker.uid]: { role: 'owner' } },
        }),
      ),
    ).toBe(true)
  })

  it('ATTACK: read a stranger\'s pets knowing the household id', async () => {
    const victim = await signInFreshViaLink(auth, 'atk-petvictim')
    const id = `hh-pets-${Date.now()}`
    await seedAsAdmin(`households/${id}`, {
      createdBy: { stringValue: victim.uid },
      memberIds: strArr([victim.uid]),
      members: { mapValue: { fields: {} } },
    })
    await seedAsAdmin(`households/${id}/pets/p1`, { name: { stringValue: 'Secret' } })

    await signInFreshViaLink(auth, 'atk-petreader')
    expect(await denied(fs.getDoc(fs.doc(db, 'households', id, 'pets', 'p1')))).toBe(true)
    expect(await denied(fs.getDocs(fs.collection(db, 'households', id, 'pets')))).toBe(true)
  })

  it('ATTACK: reach vet records, which the review has not cleared yet', async () => {
    const me = await signInFreshViaLink(auth, 'atk-records')
    const id = `hh-rec-${Date.now()}`
    await seedAsAdmin(`households/${id}`, {
      createdBy: { stringValue: me.uid },
      memberIds: strArr([me.uid]),
      members: { mapValue: { fields: {} } },
    })
    // Even as a legitimate member of my own household.
    for (const p of [['pets', 'p1', 'records', 'r1'], ['pets', 'p1', 'events', 'e1']]) {
      expect(
        await denied(fs.setDoc(fs.doc(db, 'households', id, ...(p as [string, string, string, string])), { x: 1 })),
        p.join('/'),
      ).toBe(true)
      expect(
        await denied(fs.getDoc(fs.doc(db, 'households', id, ...(p as [string, string, string, string])))),
        p.join('/'),
      ).toBe(true)
    }
  })

  it("ATTACK: write a lump onto a stranger's pet", async () => {
    // The lump diary lives ON the pet document rather than in a subcollection
    // (SPEC-HORIZON §1.1 diverged here, because `{sub=**}` under a pet is
    // denied). That makes the pet document's write rule the only thing standing
    // between a stranger and somebody's lump photographs, so it is worth
    // attacking directly rather than assuming the read test covers it.
    const victim = await signInFreshViaLink(auth, 'atk-lumpvictim')
    const id = `hh-lump-${Date.now()}`
    await seedAsAdmin(`households/${id}`, {
      createdBy: { stringValue: victim.uid },
      memberIds: strArr([victim.uid]),
      members: { mapValue: { fields: {} } },
    })
    await seedAsAdmin(`households/${id}/pets/p1`, { name: { stringValue: 'Scout' } })

    await signInFreshViaLink(auth, 'atk-lumpwriter')
    const pet = fs.doc(db, 'households', id, 'pets', 'p1')
    expect(await denied(fs.setDoc(pet, { lumps: [] }, { merge: true }))).toBe(true)
    expect(await denied(fs.updateDoc(pet, { lumps: [] }))).toBe(true)
    expect(await denied(fs.deleteDoc(pet))).toBe(true)
  })

  it('ATTACK: hide a lump in a subcollection, where the review gate does not look', async () => {
    // The reason lumps are on the pet document is that everything under a pet is
    // denied pending the security review. If a subcollection were ever allowed
    // by accident, lump photographs would be the first thing written there and
    // nothing would notice.
    const me = await signInFreshViaLink(auth, 'atk-lumpsub')
    const id = `hh-lumpsub-${Date.now()}`
    await seedAsAdmin(`households/${id}`, {
      createdBy: { stringValue: me.uid },
      memberIds: strArr([me.uid]),
      members: { mapValue: { fields: {} } },
    })
    for (const sub of ['lumps', 'photos', 'records', 'anything']) {
      const d = fs.doc(db, 'households', id, 'pets', 'p1', sub, 'x1')
      expect(await denied(fs.setDoc(d, { note: 'hidden' })), `write ${sub}`).toBe(true)
      expect(await denied(fs.getDoc(d)), `read ${sub}`).toBe(true)
    }
  })

  /**
   * NOT AN ATTACK THAT FAILS — a boundary, asserted so it cannot move quietly.
   *
   * A pet document has no field allowlist: any member may write any field,
   * including `provenance: 'vet_verified'` and an `updatedBy` naming somebody
   * else. Today that is cosmetic. Nothing grants a privilege, a price or a claim
   * outcome on the strength of a pet field — the Data Covenant firewalls
   * underwriting from all of it and `canBind` is false — so the worst an owner
   * can do is mislabel their own data in their own app.
   *
   * It stops being cosmetic the moment anything trusts those fields: a claim, a
   * rating input, or a badge shown to a sitter who is not the person who typed
   * it. That is precisely what the Firestore security review (ROADMAP B1) gates
   * vet-record extraction on, so this test exists to hand the reviewer a
   * demonstrated fact rather than a question.
   */
  it('BOUNDARY: a member can stamp their own data "vet_verified" (known, for the review)', async () => {
    const me = await signInFreshViaLink(auth, 'atk-prov')
    const id = `hh-prov-${Date.now()}`
    await seedAsAdmin(`households/${id}`, {
      createdBy: { stringValue: me.uid },
      memberIds: strArr([me.uid]),
      members: { mapValue: { fields: {} } },
    })
    const pet = fs.doc(db, 'households', id, 'pets', 'p1')
    // Allowed today (T1, for the review). If this ever starts being denied, the
    // rules gained a provenance constraint and this should become an ATTACK.
    // `updatedBy` is the member's own uid: naming somebody else is T2's attack,
    // below, and is denied.
    expect(
      await denied(
        fs.setDoc(pet, {
          weightLb: {
            value: 3,
            provenance: 'vet_verified',
            updatedAt: new Date().toISOString(),
            updatedBy: me.uid,
          },
        }),
      ),
    ).toBe(false)
  })

  /** BACKLOG T2: `updatedBy` must be the writer, for every field a write changes. */
  it('ATTACK: write a field as if somebody else had set it', async () => {
    const me = await signInFreshViaLink(auth, 'atk-author')
    const id = `hh-author-${Date.now()}`
    await seedAsAdmin(`households/${id}`, {
      createdBy: { stringValue: me.uid },
      memberIds: strArr([me.uid]),
      members: { mapValue: { fields: {} } },
    })
    const pet = fs.doc(db, 'households', id, 'pets', 'p1')
    const field = (value: unknown, by: string) => ({ value, provenance: 'owner_declared', updatedAt: new Date().toISOString(), updatedBy: by })
    expect(await denied(fs.setDoc(pet, { weightLb: field(3, 'somebody-else') })), 'create as someone else').toBe(true)
    expect(await denied(fs.setDoc(pet, { weightLb: field(3, me.uid) })), 'control: create as me').toBe(false)
    expect(await denied(fs.updateDoc(pet, { dental: field('daily', 'somebody-else') })), 'update as someone else').toBe(true)
    expect(await denied(fs.updateDoc(pet, { dental: field('daily', me.uid) })), 'control: update as me').toBe(false)
  })

  /**
   * The other side of T2: a field a write does not change keeps whoever set it.
   * A partner updating the weight must not be refused because the owner typed
   * the name.
   */
  it('BOUNDARY: a partner may leave the fields somebody else set alone', async () => {
    const me = await signInFreshViaLink(auth, 'atk-partner')
    const id = `hh-partner-${Date.now()}`
    await seedAsAdmin(`households/${id}`, {
      createdBy: { stringValue: 'the-owner' },
      memberIds: strArr(['the-owner', me.uid]),
      members: { mapValue: { fields: {} } },
    })
    const at = new Date().toISOString()
    await seedAsAdmin(`households/${id}/pets/p1`, {
      name: { mapValue: { fields: { value: { stringValue: 'Bruno' }, provenance: { stringValue: 'owner_declared' }, updatedAt: { stringValue: at }, updatedBy: { stringValue: 'the-owner' } } } },
    })
    const pet = fs.doc(db, 'households', id, 'pets', 'p1')
    const mine = { value: 70, provenance: 'owner_declared', updatedAt: new Date().toISOString(), updatedBy: me.uid }
    expect(await denied(fs.updateDoc(pet, { weightLb: mine })), 'update one field').toBe(false)
    expect(await denied(fs.setDoc(pet, { weightLb: mine }, { merge: true })), 'merge one field').toBe(false)
  })

  it('ATTACK: reach every pet on the project with a collection-group query', async () => {
    /**
     * `docs/FIRESTORE-REVIEW-BRIEF.md` lists this as a question for the
     * reviewer. It is answerable here, so it is answered here rather than
     * bought: a collection-group query matches a collection id at any depth, so
     * `collectionGroup('pets')` asks for every pet document in the database
     * regardless of which household it sits under. Rules are evaluated against
     * the query, and `lifeIsMember()` cannot be satisfied for all of them at
     * once, so it must fail — including when I own one of the households it
     * would return, which is the version of this attack most likely to slip
     * through.
     */
    const me = await signInFreshViaLink(auth, 'atk-cgroup')
    const mine = `hh-cg-mine-${Date.now()}`
    const theirs = `hh-cg-theirs-${Date.now()}`
    await seedAsAdmin(`households/${mine}`, {
      createdBy: { stringValue: me.uid },
      memberIds: strArr([me.uid]),
      members: { mapValue: { fields: {} } },
    })
    await seedAsAdmin(`households/${mine}/pets/p1`, { name: { stringValue: 'Mine' } })
    await seedAsAdmin(`households/${theirs}`, {
      createdBy: { stringValue: 'somebody-else' },
      memberIds: strArr(['somebody-else']),
      members: { mapValue: { fields: {} } },
    })
    await seedAsAdmin(`households/${theirs}/pets/p1`, { name: { stringValue: 'Theirs' } })

    expect(await denied(fs.getDocs(fs.collectionGroup(db, 'pets')))).toBe(true)
    // And the same for the subtrees the review has not cleared.
    for (const group of ['records', 'events', 'lumps']) {
      expect(await denied(fs.getDocs(fs.collectionGroup(db, group))), group).toBe(true)
    }
    // The household collection itself is only queryable as my own membership.
    expect(await denied(fs.getDocs(fs.collection(db, 'households')))).toBe(true)
  })

  it('ATTACK: forge analytics as another user', async () => {
    const me = await signInFreshViaLink(auth, 'atk-analytics')
    expect(
      await denied(
        fs.setDoc(fs.doc(db, 'life_events', `ev-${Date.now()}`), {
          uid: 'SOMEBODY_ELSE',
          name: 'trial_started',
        }),
      ),
    ).toBe(true)
    // My own is fine — that is the design.
    await fs.setDoc(fs.doc(db, 'life_events', `ev-mine-${Date.now()}`), {
      uid: me.uid,
      name: 'session_start',
    })
  })

  it('ATTACK: read the analytics log without being an admin', async () => {
    await signInFreshViaLink(auth, 'atk-analytics-read')
    expect(await denied(fs.getDocs(fs.collection(db, 'life_events')))).toBe(true)
  })

  it('ATTACK: rewrite history in the append-only log', async () => {
    const me = await signInFreshViaLink(auth, 'atk-append')
    const ref = fs.doc(db, 'life_events', `ev-append-${Date.now()}`)
    await fs.setDoc(ref, { uid: me.uid, name: 'session_start' })
    expect(await denied(fs.updateDoc(ref, { name: 'attach_bound' }))).toBe(true)
    expect(await denied(fs.deleteDoc(ref))).toBe(true)
  })

  it('ATTACK: write my own feature flags and pricing', async () => {
    await signInFreshViaLink(auth, 'atk-config')
    expect(await denied(fs.setDoc(fs.doc(db, 'life_config', 'pricing'), { monthly: 0 }))).toBe(true)
  })

  it('ATTACK: escalate to admin by writing my own users/ document', async () => {
    // Life shares the auth pool with the underwriting app, whose isAdmin()
    // trusts users/{uid}.userRole. If a Life user could write that, they would
    // read the entire underwriting database.
    const me = await signInFreshViaLink(auth, 'atk-escalate')
    expect(
      await denied(fs.setDoc(fs.doc(db, 'users', me.uid), { userRole: 2 })),
      'a Life user made themselves an underwriting admin',
    ).toBe(true)
    expect(await denied(fs.setDoc(fs.doc(db, 'users', me.uid), { userRole: '3' }))).toBe(true)
  })

  it('ATTACK: read the underwriting product\'s data as a Life user', async () => {
    await signInFreshViaLink(auth, 'atk-cross')
    for (const coll of ['quotes', 'claims', 'policies', 'underwriting_cases']) {
      expect(await denied(fs.getDocs(fs.collection(db, coll))), coll).toBe(true)
    }
  })

  it('ATTACK: enumerate sitter links', async () => {
    await signInFreshViaLink(auth, 'atk-sitter')
    expect(await denied(fs.getDocs(fs.collection(db, 'life_sitter_links')))).toBe(true)
    expect(await denied(fs.getDocs(fs.collection(db, 'life_invites')))).toBe(true)
  })
})
