import { useCallback, useEffect, useRef, useState } from 'react'
import type { PetProfile } from '../data/types'
import type { User } from '../auth/firebase'
import { profileFromFirestore, storedFromProfile } from '../data/fromFirestore'
import { loadStore } from './db'
import { track } from '../analytics/track'
import { clearLocalPets, loadLocalPets, saveLocalPets } from './localPets'

/**
 * Where a household's pets come from, and how the ones made before there was an
 * account get in.
 *
 * Two sources, never both at once:
 *   signed out → localStorage, exactly as the app has always worked. No network,
 *                no SDK, and the investor demo lives here.
 *   signed in  → Firestore, which becomes the single source of truth.
 *
 * On first sign-in with local pets, SPEC §3's "Keep working with Max?" offers a
 * one-tap import. Nothing is imported without being asked, and nothing local is
 * cleared until the write has actually landed.
 */
export interface PetsState {
  /** What the app should render. Demo pets are added by the caller. */
  pets: PetProfile[]
  /** True while the first Firestore read is in flight. */
  loading: boolean
  /** Local pets not yet in the account — the import offer. Empty when there is nothing to offer. */
  importable: PetProfile[]
  importing: boolean
  /** Null until signed in and the household is known. */
  householdId: string | null
  addPet: (pet: PetProfile) => Promise<void>
  /** Tier-1 sharpening. Writes through immediately — there is no save button. */
  updatePet: (petId: string, patch: Partial<PetProfile>) => Promise<void>
  runImport: () => Promise<void>
  dismissImport: () => void
  resetLocal: () => void
}

export function usePets(user: User | null): PetsState {
  const [localPets, setLocalPets] = useState<PetProfile[]>([])
  const [cloudPets, setCloudPets] = useState<PetProfile[] | null>(null)
  const [householdId, setHouseholdId] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [importable, setImportable] = useState<PetProfile[]>([])
  const [importing, setImporting] = useState(false)
  const [dismissed, setDismissed] = useState(false)
  const mounted = useRef(true)

  useEffect(() => {
    mounted.current = true
    setLocalPets(loadLocalPets())
    return () => {
      mounted.current = false
    }
  }, [])

  // Signing in: find the household, read its pets, and work out what is still
  // only on this device. Signing out: forget the cloud and fall back to local.
  useEffect(() => {
    if (!user) {
      setCloudPets(null)
      setHouseholdId(null)
      setImportable([])
      setDismissed(false)
      return
    }
    let cancelled = false
    setLoading(true)
    ;(async () => {
      try {
        const store = await loadStore()
        const household = await store.ensureHousehold(user.uid, new Date())
        const docs = await store.listPets(household.id)
        // Anything unusable is dropped here rather than allowed to reach
        // project(), which throws on an unknown breed.
        const mapped = docs.map(profileFromFirestore).filter((m) => m !== null)
        if (cancelled || !mounted.current) return
        setHouseholdId(household.id)
        setCloudPets(mapped.map((m) => m!.profile))
      } catch {
        if (!cancelled && mounted.current) {
          // Offline or denied. Showing the local pets is better than showing
          // none — the account simply has not loaded yet.
          setCloudPets(null)
          setHouseholdId(null)
        }
      } finally {
        if (!cancelled && mounted.current) setLoading(false)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [user])

  // The import offer: local pets whose id is not already in the account.
  // Matching on id means importing twice is a no-op rather than a duplicate.
  useEffect(() => {
    if (!user || cloudPets === null || dismissed) {
      setImportable([])
      return
    }
    const known = new Set(cloudPets.map((p) => p.id))
    setImportable(localPets.filter((p) => !known.has(p.id)))
  }, [user, cloudPets, localPets, dismissed])

  const runImport = useCallback(async () => {
    if (!user || !householdId || !importable.length) return
    setImporting(true)
    try {
      const store = await loadStore()
      const now = new Date()
      await store.savePets(
        householdId,
        importable.map((p) =>
          storedFromProfile(p, {
            householdId,
            uid: user.uid,
            now,
            importedFrom: 'localStorage',
          }),
        ),
      )
      if (!mounted.current) return
      setCloudPets((prev) => [...(prev ?? []), ...importable])
      // Only now, after the write has landed. The local copy is the only copy
      // until this point, and a failed import must not lose it.
      clearLocalPets()
      setLocalPets([])
      track('pets_imported', { count: importable.length })
    } catch {
      /* Left alone: local pets intact, the offer stays up, they can retry. */
    } finally {
      if (mounted.current) setImporting(false)
    }
  }, [user, householdId, importable])

  const addPet = useCallback(
    async (pet: PetProfile) => {
      if (user && householdId) {
        setCloudPets((prev) => [...(prev ?? []), pet])
        try {
          const store = await loadStore()
          await store.savePet(
            householdId,
            storedFromProfile(pet, { householdId, uid: user.uid, now: new Date() }),
          )
        } catch {
          /* The pet stays on screen. A retry queue is P1 work, not P0. */
        }
        return
      }
      const next = [...localPets, pet]
      setLocalPets(next)
      saveLocalPets(next)
    },
    [user, householdId, localPets],
  )

  const updatePet = useCallback(
    async (petId: string, patch: Partial<PetProfile>) => {
      // Optimistic in both backends: the whole mechanic is that the projection
      // moves as you answer, so waiting on a round trip would break it.
      if (user && householdId) {
        let next: PetProfile | undefined
        setCloudPets((prev) => {
          const updated = (prev ?? []).map((p) => {
            if (p.id !== petId) return p
            next = { ...p, ...patch }
            return next
          })
          return updated
        })
        if (!next) return
        try {
          const store = await loadStore()
          await store.savePet(
            householdId,
            storedFromProfile(next, { householdId, uid: user.uid, now: new Date() }),
          )
        } catch {
          /* Stays on screen. A retry queue is later work, not this. */
        }
        return
      }
      setLocalPets((prev) => {
        const updated = prev.map((p) => (p.id === petId ? { ...p, ...patch } : p))
        saveLocalPets(updated)
        return updated
      })
    },
    [user, householdId],
  )

  const resetLocal = useCallback(() => {
    clearLocalPets()
    setLocalPets([])
  }, [])

  return {
    pets: user && cloudPets !== null ? cloudPets : localPets,
    loading,
    importable,
    importing,
    householdId,
    addPet,
    updatePet,
    runImport,
    dismissImport: () => setDismissed(true),
    resetLocal,
  }
}
