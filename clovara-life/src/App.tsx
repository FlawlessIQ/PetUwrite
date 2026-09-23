import { Suspense, lazy, useEffect, useMemo, useRef, useState } from 'react'
import type { PetProfile } from './data/types'
import { DEMO_PETS } from './data/demoPets'
import { findBreed } from './data/engine'
import { project } from './engine/project'
import { Journey } from './components/Journey'
import { Onboarding } from './components/Onboarding'
import { Home } from './components/Home'
import { Companion } from './components/Companion'
import { Rewards } from './components/Rewards'
import { Shop } from './components/Shop'
import { Coverage } from './components/Coverage'
import { TabBar, TopNav, SURFACES, type Surface } from './components/Nav'
import { CloverMark, Wordmark } from './components/CloverMark'
import { AccountSheet } from './components/AccountSheet'
import { useAuth } from './auth/AuthProvider'
import { displayNameFor } from './auth/session'
import { track } from './analytics/track'

// Lazy: an internal page must not cost the demo path a byte.
const MetricsDashboard = lazy(() =>
  import('./components/MetricsDashboard').then((m) => ({ default: m.MetricsDashboard })),
)

const STORAGE_KEY = 'clovara-life.pets.v1'
const SURFACE_IDS = new Set<string>(SURFACES.map((s) => s.id))

/**
 * Anything coming out of localStorage is untrusted input. A pet saved by an
 * earlier build — or hand-edited, or half-written — must not be able to throw
 * during render, because `project()` throws on an unknown breed and there is no
 * way to recover from that mid-demo without devtools.
 */
const OUTDOOR_VALUES = new Set(['indoor', 'indoor-outdoor', 'outdoor'])
const NEUTER_BANDS = new Set(['under-6m', '6-11m', '12-23m', '24m-plus', 'unsure'])

/** Optional field: absent is fine, present and wrong is not. */
const optionalOneOf = (v: unknown, allowed: Set<string>) =>
  v === undefined || (typeof v === 'string' && allowed.has(v))

function isValidPet(p: unknown): p is PetProfile {
  if (!p || typeof p !== 'object') return false
  const x = p as Record<string, unknown>
  return (
    optionalOneOf(x.outdoorAccess, OUTDOOR_VALUES) &&
    optionalOneOf(x.neuterAgeBand, NEUTER_BANDS) &&
    typeof x.id === 'string' &&
    typeof x.name === 'string' &&
    x.name.trim().length > 0 &&
    (x.species === 'dog' || x.species === 'cat') &&
    typeof x.breedId === 'string' &&
    !!findBreed(x.breedId) &&
    typeof x.birthDate === 'string' &&
    !Number.isNaN(new Date(x.birthDate).getTime()) &&
    Array.isArray(x.conditionIds) &&
    typeof x.weightLb === 'number' &&
    Number.isFinite(x.weightLb) &&
    (x.dental === 'daily' || x.dental === 'weekly' || x.dental === 'rarely') &&
    (x.activity === 'low' || x.activity === 'moderate' || x.activity === 'high') &&
    (x.diet === 'measured' || x.diet === 'free-fed' || x.diet === 'unsure')
  )
}

function loadPets(): PetProfile[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw)
    // Drop anything malformed rather than letting it reach the engine.
    return Array.isArray(parsed) ? parsed.filter(isValidPet) : []
  } catch {
    return []
  }
}

function savePets(pets: PetProfile[]) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(pets))
  } catch {
    /* storage unavailable — the demo still works, it just won't persist */
  }
}

function clearPets() {
  try {
    localStorage.removeItem(STORAGE_KEY)
  } catch {
    /* nothing to do */
  }
}

/** `?reset` wipes stored pets and bounces to a clean URL. Bookmark it. */
function handleResetParam(): boolean {
  if (typeof window === 'undefined') return false
  if (!new URLSearchParams(window.location.search).has('reset')) return false
  clearPets()
  window.location.replace(window.location.pathname)
  return true
}

/** `#/pet/:id/:surface` — deep links, and a reload that lands where you were. */
function parseHash(): { petId: string; surface: Surface } | null {
  const m = /^#\/pet\/([^/]+)\/([^/]+)$/.exec(window.location.hash)
  if (!m) return null
  const surface = m[2]
  if (!SURFACE_IDS.has(surface)) return null
  return { petId: decodeURIComponent(m[1]), surface: surface as Surface }
}

/** `#/admin/metrics` — internal only, and gated again by the Firestore rules. */
function isAdminRoute(): boolean {
  return window.location.hash === '#/admin/metrics'
}

function PetSwitcher({
  pets,
  activeId,
  onSelect,
  onAdd,
  onReset,
  onAccount,
  hasUserPets,
  accountLabel,
}: {
  pets: PetProfile[]
  activeId: string | null
  onSelect: (id: string) => void
  onAdd: () => void
  onReset: () => void
  onAccount: () => void
  hasUserPets: boolean
  /** Null when signed out — the menu item says "Sign in" instead. */
  accountLabel: string | null
}) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)
  const active = pets.find((p) => p.id === activeId)

  useEffect(() => {
    if (!open) return
    const onDoc = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false)
    }
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setOpen(false)
    document.addEventListener('mousedown', onDoc)
    document.addEventListener('keydown', onKey)
    return () => {
      document.removeEventListener('mousedown', onDoc)
      document.removeEventListener('keydown', onKey)
    }
  }, [open])

  return (
    <div className="relative flex items-center gap-2" ref={ref}>
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
        aria-haspopup="menu"
        className="flex items-center gap-2 rounded-full border border-line bg-white px-3.5 py-2 text-[14.5px] font-medium text-ink transition hover:border-forest/50"
      >
        <span className="max-w-[8rem] truncate">{active ? active.name : 'Choose a pet'}</span>
        <span aria-hidden="true" className="text-[11px] text-muted">
          ▾
        </span>
      </button>

      {open && (
        <div
          role="menu"
          className="absolute right-0 top-[calc(100%+8px)] z-40 flex max-h-[min(60vh,26rem)] w-[248px] flex-col overflow-y-auto overscroll-contain rounded-soft border border-line bg-white shadow-lift"
        >
          {pets.map((p) => (
            <button
              key={p.id}
              role="menuitem"
              type="button"
              onClick={() => {
                onSelect(p.id)
                setOpen(false)
              }}
              className={`flex w-full shrink-0 items-center justify-between gap-2 border-b border-line px-4 py-2.5 text-left text-[14.5px] transition ${
                p.id === activeId ? 'bg-sage text-deep' : 'hover:bg-cream'
              }`}
            >
              <span className="truncate">{p.name}</span>
              <span className="shrink-0 text-[12px] text-muted">{p.demo ? 'Demo' : 'Yours'}</span>
            </button>
          ))}
          <button
            role="menuitem"
            type="button"
            onClick={() => {
              onAdd()
              setOpen(false)
            }}
            className="w-full shrink-0 bg-cream/60 px-4 py-2.5 text-left text-[14.5px] font-medium text-forest transition hover:bg-cream"
          >
            + Add a pet
          </button>
          <button
            role="menuitem"
            type="button"
            onClick={() => {
              onAccount()
              setOpen(false)
            }}
            className="w-full shrink-0 border-t border-line px-4 py-2.5 text-left text-[14px] text-ink transition hover:bg-cream"
          >
            {accountLabel ? (
              <>
                <span className="block truncate font-medium">{accountLabel}</span>
                <span className="block text-[12.5px] text-muted">Signed in · manage account</span>
              </>
            ) : (
              'Sign in'
            )}
          </button>
          {hasUserPets && (
            <button
              role="menuitem"
              type="button"
              onClick={() => {
                onReset()
                setOpen(false)
              }}
              className="w-full shrink-0 border-t border-line px-4 py-2.5 text-left text-[13.5px] text-muted transition hover:bg-cream hover:text-ink"
            >
              Reset demo data
            </button>
          )}
        </div>
      )}
    </div>
  )
}

export default function App() {
  const [userPets, setUserPets] = useState<PetProfile[]>([])
  const [activeId, setActiveId] = useState<string>(() => parseHash()?.petId ?? DEMO_PETS[0].id)
  const [adding, setAdding] = useState(false)
  const [accountOpen, setAccountOpen] = useState(false)
  const [adminRoute, setAdminRoute] = useState(isAdminRoute)
  const { user } = useAuth()
  const [surface, setSurface] = useState<Surface>(() => parseHash()?.surface ?? 'home')

  useEffect(() => {
    if (handleResetParam()) return
    setUserPets(loadPets())
    track('session_start', { demo_only: true })
  }, [])

  const pets = [...DEMO_PETS, ...userPets]
  const active = pets.find((p) => p.id === activeId) ?? pets[0]

  // One projection, shared by every surface. No screen holds its own truth.
  const projection = useMemo(() => project(active), [active])

  // ── URL sync ─────────────────────────────────────────────────────────────
  // Write state → hash. Guarded so it never fights the hashchange listener.
  useEffect(() => {
    if (!active || adminRoute) return
    const next = `#/pet/${encodeURIComponent(active.id)}/${surface}`
    if (window.location.hash !== next) window.history.replaceState(null, '', next)
  }, [active, surface, adminRoute])

  // Read hash → state, for back/forward and pasted links.
  useEffect(() => {
    const onHash = () => {
      const parsed = parseHash()
      if (!parsed) return
      setSurface(parsed.surface)
      setActiveId((cur) => (parsed.petId !== cur ? parsed.petId : cur))
    }
    const onAdmin = () => setAdminRoute(isAdminRoute())
    window.addEventListener('hashchange', onHash)
    window.addEventListener('hashchange', onAdmin)
    return () => {
      window.removeEventListener('hashchange', onHash)
      window.removeEventListener('hashchange', onAdmin)
    }
  }, [])

  // The Life surface is the Plan reveal (SPEC §4.1). Fired once per pet per
  // session so a user flicking between tabs does not inflate the top of the
  // funnel — the dashboard's rates are computed against it.
  const revealed = useRef(new Set<string>())
  useEffect(() => {
    if (surface !== 'life' || !active) return
    if (revealed.current.has(active.id)) return
    revealed.current.add(active.id)
    track('reveal_viewed', { pet_is_demo: !!active.demo, species: active.species })
  }, [surface, active])

  const go = (s: Surface) => {
    setSurface(s)
    window.scrollTo({ top: 0 })
  }

  const selectPet = (id: string) => {
    setActiveId(id)
    window.scrollTo({ top: 0 })
  }

  const addPet = (pet: PetProfile) => {
    const next = [...userPets, pet]
    setUserPets(next)
    savePets(next)
    setActiveId(pet.id)
    setAdding(false)
    setSurface('life')
    track('pet_created', { species: pet.species, has_weight: pet.weightLb > 0 })
    window.scrollTo({ top: 0 })
  }

  const resetDemo = () => {
    clearPets()
    setUserPets([])
    setActiveId(DEMO_PETS[0].id)
    setSurface('home')
    window.scrollTo({ top: 0 })
  }

  return (
    <div className="flex min-h-screen flex-col">
      <a
        href="#main"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-4 focus:z-50 focus:rounded-soft focus:bg-ink focus:px-4 focus:py-2 focus:text-cream"
      >
        Skip to content
      </a>

      <header className="sticky top-0 z-20 border-b border-line/80 bg-cream/85 backdrop-blur-md">
        <div className="mx-auto flex max-w-shell items-center justify-between gap-4 px-5 py-3">
          <button
            type="button"
            onClick={() => {
              setAdding(false)
              go('home')
            }}
            className="flex shrink-0 items-center"
            aria-label="Clovara Life home"
          >
            <Wordmark size={28} />
          </button>

          {!adding && (
            <>
              <TopNav active={surface} onChange={go} />
              <div className="flex shrink-0 items-center gap-2">
                <PetSwitcher
                  pets={pets}
                  activeId={active?.id ?? null}
                  onSelect={selectPet}
                  onAdd={() => setAdding(true)}
                  onReset={resetDemo}
                  onAccount={() => setAccountOpen(true)}
                  hasUserPets={userPets.length > 0}
                  accountLabel={user ? displayNameFor(user) : null}
                />
                <button
                  type="button"
                  onClick={() => setAdding(true)}
                  className="hidden rounded-full bg-forest px-4 py-2 text-[14.5px] font-medium text-white transition hover:bg-deep lg:inline-flex"
                >
                  Add a pet
                </button>
              </div>
            </>
          )}
        </div>
      </header>

      {accountOpen && <AccountSheet onClose={() => setAccountOpen(false)} />}

      <main id="main" className="flex-1">
        {adminRoute ? (
          <Suspense fallback={<div className="mx-auto max-w-shell px-5 py-10 text-muted">Loading…</div>}>
            <MetricsDashboard
              onClose={() => {
                window.location.hash = `#/pet/${encodeURIComponent(active?.id ?? DEMO_PETS[0].id)}/home`
                setAdminRoute(false)
              }}
            />
          </Suspense>
        ) : adding ? (
          <Onboarding onComplete={addPet} onCancel={() => setAdding(false)} />
        ) : active ? (
          <div key={`${active.id}-${surface}`} className="reveal">
            {surface === 'home' && <Home pet={active} projection={projection} onNavigate={go} />}
            {surface === 'care' && <Companion pet={active} projection={projection} />}
            {surface === 'rewards' && <Rewards pet={active} projection={projection} />}
            {surface === 'shop' && <Shop pet={active} projection={projection} />}
            {surface === 'coverage' && <Coverage pet={active} projection={projection} />}
            {surface === 'life' && <Journey pet={active} />}
          </div>
        ) : null}
      </main>

      <footer className="border-t border-line bg-white/60 pb-[76px] md:pb-0">
        <div className="mx-auto max-w-shell px-5 py-8">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div className="flex items-center gap-2.5">
              <CloverMark size={22} id="footer" />
              <span className="font-display text-[16px] text-ink">Clovara Life</span>
            </div>
            <p className="max-w-[62ch] text-[13.5px] leading-relaxed text-muted">
              Clovara Life shares information to support care decisions. It is not veterinary advice;
              your veterinarian decides care. Pricing, products and activity data in this preview are
              illustrative.
            </p>
          </div>
        </div>
      </footer>

      {!adding && <TabBar active={surface} onChange={go} />}
    </div>
  )
}
