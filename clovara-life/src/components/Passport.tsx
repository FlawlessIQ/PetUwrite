import { useMemo, useState } from 'react'
import type { PetProfile } from '../data/types'
import { passportState, windowCopy } from '../engine/passport'
import { PASSPORT_PRINCIPLE, PASSPORT_VET_LINE } from '../data/socialization'
import { track } from '../analytics/track'

/**
 * The Socialization Passport (SPEC §6.3).
 *
 * Gamified in the one way that is safe: progress you can see, and nothing that
 * rewards speed. There is no streak to break and no daily target, because the
 * failure mode of a checklist like this is somebody pushing a frightened animal
 * through the last few stamps to finish the page.
 */
export function Passport({
  pet,
  onUpdate,
  now = new Date(),
}: {
  pet: PetProfile
  onUpdate?: (patch: Partial<PetProfile>) => void
  now?: Date
}) {
  const state = useMemo(() => passportState(pet, now), [pet, now])
  const [openGroup, setOpenGroup] = useState<string | null>(null)

  if (!state.visible) return null
  const copy = windowCopy(pet, state)
  const collected = new Set(state.collected)
  const pct = Math.round(state.progress * 100)

  const toggle = (id: string) => {
    if (!onUpdate) return
    const next = collected.has(id)
      ? state.collected.filter((x) => x !== id)
      : [...state.collected, id]
    track('passport_stamp', {
      added: !collected.has(id),
      total: next.length,
      pet_is_demo: !!pet.demo,
      species: pet.species,
    })
    onUpdate({ socialStamps: next })
  }

  return (
    <section className="card overflow-hidden" aria-labelledby="passport-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <p className="label">Passport</p>
        <h2 id="passport-heading" className="mt-1 font-display text-[20px] text-ink">
          {copy.title}
        </h2>
        <p className="mt-1 text-[13.5px] leading-relaxed text-ink-2">{copy.body}</p>

        <div className="mt-4 flex items-center gap-3">
          <span className="h-2 flex-1 overflow-hidden rounded-full bg-white">
            <span
              className="block h-full rounded-full bg-forest transition-[width] duration-500"
              style={{ width: `${pct}%` }}
            />
          </span>
          <span className="shrink-0 text-[13px] text-ink-2">
            {state.collected.length} of {state.stamps.length}
          </span>
        </div>
      </div>

      <ul className="divide-y divide-line">
        {state.byGroup.map(({ group, total, done }) => {
          const open = openGroup === group
          return (
            <li key={group}>
              <button
                type="button"
                aria-expanded={open}
                onClick={() => setOpenGroup(open ? null : group)}
                className="flex w-full items-center justify-between gap-4 px-5 py-3.5 text-left"
              >
                <span className="text-[15px] text-ink">{group}</span>
                <span className="flex items-center gap-3">
                  <span className="text-[13px] text-ink-2">
                    {done}/{total}
                  </span>
                  <span
                    aria-hidden="true"
                    className={`text-[18px] leading-none text-ink-2 transition-transform ${open ? 'rotate-45' : ''}`}
                  >
                    +
                  </span>
                </span>
              </button>

              {open && (
                <ul className="px-5 pb-4">
                  {state.stamps
                    .filter((st) => st.group === group)
                    .map((st) => {
                      const has = collected.has(st.id)
                      return (
                        <li key={st.id}>
                          <button
                            type="button"
                            role="checkbox"
                            aria-checked={has}
                            disabled={!onUpdate}
                            onClick={() => toggle(st.id)}
                            className="flex w-full items-center gap-3 py-2 text-left disabled:opacity-60"
                          >
                            <span
                              aria-hidden="true"
                              className={`grid h-5 w-5 shrink-0 place-items-center rounded-full border text-[12px] leading-none transition ${
                                has
                                  ? 'border-forest bg-forest text-white'
                                  : 'border-line bg-white text-transparent'
                              }`}
                            >
                              ✓
                            </span>
                            <span className={`text-[14.5px] ${has ? 'text-ink-2 line-through' : 'text-ink'}`}>
                              {st.label}
                            </span>
                          </button>
                        </li>
                      )
                    })}
                </ul>
              )}
            </li>
          )
        })}
      </ul>

      <div className="border-t border-line bg-cream/40 px-5 py-4">
        <p className="text-[13px] leading-relaxed text-deep">{PASSPORT_PRINCIPLE}</p>
        {pet.species === 'dog' && (
          <p className="mt-2 text-[12.5px] leading-relaxed text-ink-2">{PASSPORT_VET_LINE}</p>
        )}
      </div>
    </section>
  )
}
