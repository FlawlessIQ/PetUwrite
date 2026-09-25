import { useMemo, useState } from 'react'
import type { PetProfile } from '../data/types'
import { vaccineState, vaccineHeadline, type DoseState } from '../engine/vaccines'
import { NON_CORE_TO_ASK, VACCINE_DISCLAIMER, VACCINE_RECORD_NOTE } from '../data/vaccines'
import { longDate } from '../share/cardLayout'
import { track } from '../analytics/track'

/**
 * Vaccine Autopilot (SPEC §6.4).
 *
 * A record with a reminder attached, never a prescription. The disclaimer is at
 * the top rather than the bottom, because whose decision this is needs saying
 * before somebody reads a schedule, not after.
 */
const STATUS_STYLE: Record<DoseState['status'], string> = {
  recorded: 'bg-sage text-deep',
  due: 'bg-[#F6E8D2] text-amber',
  'past-window': 'bg-cream text-ink-2',
  upcoming: 'bg-white text-ink-2',
}

const STATUS_WORD: Record<DoseState['status'], string> = {
  recorded: 'Recorded',
  due: 'Usually now',
  'past-window': 'Window passed',
  upcoming: 'Later',
}

export function Vaccines({
  pet,
  onUpdate,
  now = new Date(),
}: {
  pet: PetProfile
  onUpdate?: (patch: Partial<PetProfile>) => void
  now?: Date
}) {
  const state = useMemo(() => vaccineState(pet, now), [pet, now])
  const [editing, setEditing] = useState<string | null>(null)
  const [date, setDate] = useState('')

  if (!state.visible) return null

  const record = (doseId: string, givenOn: string) => {
    if (!onUpdate || !givenOn) return
    const rest = (pet.vaccineRecords ?? []).filter((r) => r.doseId !== doseId)
    track('vaccine_recorded', { dose: doseId, pet_is_demo: !!pet.demo, species: pet.species })
    onUpdate({ vaccineRecords: [...rest, { doseId, givenOn }] })
    setEditing(null)
    setDate('')
  }

  const clear = (doseId: string) => {
    if (!onUpdate) return
    onUpdate({ vaccineRecords: (pet.vaccineRecords ?? []).filter((r) => r.doseId !== doseId) })
    setEditing(null)
  }

  const byVaccine = new Map<string, DoseState[]>()
  for (const d of state.doses) {
    byVaccine.set(d.vaccine.id, [...(byVaccine.get(d.vaccine.id) ?? []), d])
  }

  return (
    <section className="card overflow-hidden" aria-labelledby="vaccines-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <p className="label">Vaccinations</p>
        <h2 id="vaccines-heading" className="mt-1 font-display text-heading text-ink">
          {vaccineHeadline(pet, state)}
        </h2>
        {/* Before the schedule, not after it. */}
        <p className="mt-2 text-body-sm leading-relaxed text-ink-2">{VACCINE_DISCLAIMER}</p>
      </div>

      <ul className="divide-y divide-line">
        {[...byVaccine.entries()].map(([vaccineId, doses]) => {
          const vaccine = doses[0].vaccine
          return (
            <li key={vaccineId} className="px-5 py-4">
              <div className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
                <p className="text-lead font-medium text-ink">{vaccine.label}</p>
                {vaccine.lawDependent && (
                  <span className="rounded-full bg-cream px-2.5 py-1 text-caption text-ink-2">
                    Depends on local law
                  </span>
                )}
              </div>
              <p className="mt-1 text-body-sm leading-relaxed text-ink-2">{vaccine.protects}</p>

              <ul className="mt-3 space-y-2">
                {doses.map((d) => (
                  <li key={d.dose.id}>
                    <div className="flex flex-wrap items-center justify-between gap-x-3 gap-y-2">
                      <span className="text-body-lg text-ink">
                        {d.dose.label}
                        <span className="ml-2 text-body-sm text-ink-2">
                          {d.givenOn
                            ? longDate(d.givenOn)
                            : `usually ${longDate(d.windowOpens)} – ${longDate(d.windowCloses)}`}
                        </span>
                      </span>
                      <span className="flex items-center gap-2">
                        <span
                          className={`rounded-full px-2.5 py-1 text-caption ${STATUS_STYLE[d.status]}`}
                        >
                          {STATUS_WORD[d.status]}
                        </span>
                        {onUpdate && (
                          <button
                            type="button"
                            className="text-body-sm text-forest text-action"
                            onClick={() => {
                              setEditing(editing === d.dose.id ? null : d.dose.id)
                              setDate(d.givenOn ?? '')
                            }}
                          >
                            {d.givenOn ? 'Change' : 'Record'}
                          </button>
                        )}
                      </span>
                    </div>

                    {editing === d.dose.id && (
                      <div className="mt-2 flex flex-wrap items-center gap-2">
                        <label className="sr-only" htmlFor={`given-${d.dose.id}`}>
                          Date {d.dose.label.toLowerCase()} of {vaccine.label} was given
                        </label>
                        <input
                          id={`given-${d.dose.id}`}
                          type="date"
                          value={date}
                          max={new Date().toISOString().slice(0, 10)}
                          onChange={(e) => setDate(e.target.value)}
                          className="field max-w-[190px]"
                        />
                        <button
                          type="button"
                          className="pill-primary px-4 py-2 text-body"
                          onClick={() => record(d.dose.id, date)}
                          disabled={!date}
                        >
                          Save
                        </button>
                        {d.givenOn && (
                          <button
                            type="button"
                            className="pill-ghost px-4 py-2 text-body"
                            onClick={() => clear(d.dose.id)}
                          >
                            Remove
                          </button>
                        )}
                      </div>
                    )}
                  </li>
                ))}
              </ul>
            </li>
          )
        })}
      </ul>

      <div className="border-t border-line bg-cream/40 px-5 py-4">
        <p className="label">Worth asking your vet about</p>
        <ul className="mt-2 space-y-1.5">
          {NON_CORE_TO_ASK[pet.species].map((q) => (
            <li key={q} className="text-body leading-relaxed text-ink">
              {q}
            </li>
          ))}
        </ul>
        <p className="mt-3 text-body-sm leading-relaxed text-ink-2">{VACCINE_RECORD_NOTE}</p>
      </div>
    </section>
  )
}
