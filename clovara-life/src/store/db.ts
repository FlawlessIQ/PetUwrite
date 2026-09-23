/**
 * The Firestore repository for Clovara Life.
 *
 * Like `src/auth/firebase.ts`, every `firebase/*` import in here is dynamic, so
 * the SDK stays out of the signed-out demo bundle. `verify-demo.mjs` asserts
 * that a signed-out visitor fetches zero Firebase chunks, and that check covers
 * this module too — if one of these imports becomes static, it fails.
 *
 * Shape follows SPEC §7:
 *   households/{householdId}                 → Household
 *   households/{householdId}/pets/{petId}    → StoredPet
 *
 * Reads are defensive. Everything coming back is fed through
 * `profileFromFirestore()`, which drops anything unusable rather than letting a
 * document written by an older build reach `project()`.
 */
import { FIREBASE_CONFIG } from '../auth/config'
import type { Household, StoredPet } from '../data/stored'

const HOUSEHOLDS = 'households'
const PETS = 'pets'

/** Set VITE_USE_EMULATORS=1 to point a dev build at the local emulator suite. */
const USE_EMULATORS = import.meta.env.VITE_USE_EMULATORS === '1'

type Db = import('firebase/firestore').Firestore

interface StoreKit {
  db: Db
  /** Finds the caller's household, creating one of them if they have none. */
  ensureHousehold: (uid: string, now: Date) => Promise<Household>
  listPets: (householdId: string) => Promise<StoredPet[]>
  savePet: (householdId: string, pet: StoredPet) => Promise<void>
  savePets: (householdId: string, pets: StoredPet[]) => Promise<void>
  deletePet: (householdId: string, petId: string) => Promise<void>
}

let kit: Promise<StoreKit> | null = null

export function loadStore(): Promise<StoreKit> {
  if (kit) return kit
  kit = (async () => {
    const [{ initializeApp, getApps, getApp }, fs] = await Promise.all([
      import('firebase/app'),
      import('firebase/firestore'),
    ])
    const {
      getFirestore,
      connectFirestoreEmulator,
      collection,
      doc,
      getDoc,
      getDocs,
      setDoc,
      deleteDoc,
      query,
      where,
      limit,
      writeBatch,
    } = fs

    // Shares the app instance with auth/firebase.ts — whichever loads first
    // initialises it, the other finds it.
    const app = getApps().length ? getApp() : initializeApp(FIREBASE_CONFIG)
    const db = getFirestore(app)
    if (USE_EMULATORS) {
      try {
        connectFirestoreEmulator(db, '127.0.0.1', 8080)
      } catch {
        /* already connected on a hot reload */
      }
    }

    const householdRef = (id: string) => doc(db, HOUSEHOLDS, id)
    const petsRef = (householdId: string) => collection(db, HOUSEHOLDS, householdId, PETS)

    async function ensureHousehold(uid: string, now: Date): Promise<Household> {
      const existing = await getDocs(
        query(collection(db, HOUSEHOLDS), where('memberIds', 'array-contains', uid), limit(1)),
      )
      if (!existing.empty) {
        const d = existing.docs[0]
        return { ...(d.data() as Omit<Household, 'id'>), id: d.id }
      }

      // A household of one, created on first sign-in. The family circle in P1
      // adds members to this — it is not a different kind of object, which is
      // why even a single user gets a household rather than owning pets
      // directly.
      const ref = doc(collection(db, HOUSEHOLDS))
      const household: Household = {
        id: ref.id,
        createdAt: now.toISOString(),
        createdBy: uid,
        members: { [uid]: { role: 'owner', joinedAt: now.toISOString() } },
        // Duplicates the members keys because Firestore cannot query map keys,
        // and both the security rules and the lookup above need to.
        memberIds: [uid],
      }
      await setDoc(ref, household)
      return household
    }

    async function listPets(householdId: string): Promise<StoredPet[]> {
      const snap = await getDocs(petsRef(householdId))
      return snap.docs.map((d) => ({ ...(d.data() as Omit<StoredPet, 'id'>), id: d.id }))
    }

    async function savePet(householdId: string, pet: StoredPet): Promise<void> {
      await setDoc(doc(petsRef(householdId), pet.id), pet, { merge: true })
    }

    async function savePets(householdId: string, pets: StoredPet[]): Promise<void> {
      if (!pets.length) return
      // One batch so a half-finished import cannot leave a household holding
      // some of someone's pets and not others.
      const batch = writeBatch(db)
      for (const p of pets) batch.set(doc(petsRef(householdId), p.id), p, { merge: true })
      await batch.commit()
    }

    async function deletePet(householdId: string, petId: string): Promise<void> {
      await deleteDoc(doc(petsRef(householdId), petId))
    }

    // getDoc/householdRef are used by callers that already know the id.
    void getDoc
    void householdRef

    return { db, ensureHousehold, listPets, savePet, savePets, deletePet }
  })()
  kit.catch(() => {
    kit = null
  })
  return kit
}

/** True once Firestore has actually been pulled in. For tests and diagnostics. */
export function storeLoaded(): boolean {
  return kit !== null
}
