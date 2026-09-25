import { useState } from 'react'
import type { PetProfile } from '../data/types'
import {
  FREQUENCIES,
  medLine,
  medState,
  MISSED_DOSE,
  NOT_A_PRESCRIPTION,
  RUNNING_OUT_NOTE,
  type FrequencyId,
  type Medication,
} from '../engine/meds'
import { track } from '../analytics/track'

/**
 * Meds autopilot (SPEC-HORIZON §1.4).
 *
 * A record and a count. The amount is free text exactly as the label reads, and
 * nothing here ever says what to give or what to do about a missed dose.
 */
export function Meds({
  pet,
  onUpdate,
  now = new Date(),
}: {
  pet: PetProfile
  onUpdate?: (patch: Partial<PetProfile>) => void
  now?: Date
}) {
  const meds = (pet.medications as Medication[] | undefined) ?? []
  const [adding, setAdding] = useState(false)
  const [name, setName] = useState('')
  const [amount, setAmount] = useState('')
  const [frequency, setFrequency] = useState<FrequencyId>('twice')
  const [quantity, setQuantity] = useState('')

  const save = (next: Medication[]) => onUpdate?.({ medications: next })

  const add = () => {
    if (!name.trim() || !amount.trim()) return
    save([
      ...meds,
      {
        id: `med-${Date.now()}`,
        name: name.trim(),
        amount: amount.trim(),
        frequency,
        startedOn: now.toISOString(),
        quantity: quantity ? Number(quantity) : undefined,
        given: [],
      },
    ])
    track('med_added', { pet_is_demo: !!pet.demo })
    setName('')
    setAmount('')
    setQuantity('')
    setAdding(false)
  }

  const logDose = (id: string) => {
    save(
      meds.map((m) =>
        m.id === id ? { ...m, given: [...(m.given ?? []), new Date().toISOString()] } : m,
      ),
    )
    track('med_dose_logged', { pet_is_demo: !!pet.demo })
  }

  const undoLast = (id: string) => {
    save(meds.map((m) => (m.id === id ? { ...m, given: (m.given ?? []).slice(0, -1) } : m)))
  }

  return (
    <section className="card overflow-hidden" aria-labelledby="meds-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <p className="label">Medication</p>
        <h2 id="meds-heading" className="mt-1 font-display text-[20px] text-ink">
          What {pet.name} is taking
        </h2>
        <p className="mt-1 text-[13px] leading-relaxed text-ink-2">{NOT_A_PRESCRIPTION}</p>
      </div>

      <ul className="divide-y divide-line">
        {meds.map((med) => {
          const state = medState(med, now)
          return (
            <li key={med.id} className="px-5 py-4">
              <div className="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
                <p className="text-[15px] font-medium text-ink">{med.name}</p>
                <p className={`text-[12.5px] ${state.runningOut ? 'text-[#8A5510]' : 'text-ink-2'}`}>
                  {medLine(med, state)}
                </p>
              </div>
              <p className="mt-0.5 text-[13.5px] leading-relaxed text-ink-2">
                {med.amount} · {FREQUENCIES.find((f) => f.id === med.frequency)?.label.toLowerCase()}
              </p>

              {state.runningOut && (
                <p className="mt-2 rounded-soft border border-accent/30 bg-accent/10 px-3.5 py-2.5 text-[12.5px] leading-relaxed text-[#8A5510]">
                  {RUNNING_OUT_NOTE}
                </p>
              )}

              {onUpdate && (
                <div className="mt-3 flex flex-wrap items-center gap-2">
                  <button
                    type="button"
                    className="pill-ghost px-4 py-2 text-[13.5px]"
                    onClick={() => logDose(med.id)}
                  >
                    {state.doneToday ? 'Log another anyway' : 'Given just now'}
                  </button>
                  {(med.given?.length ?? 0) > 0 && (
                    <button
                      type="button"
                      className="text-action text-[13px] text-ink-2"
                      onClick={() => undoLast(med.id)}
                    >
                      Undo the last one
                    </button>
                  )}
                  {state.perDay > 0 && (
                    <span className="text-[12.5px] text-ink-2">
                      {state.givenToday} of {state.perDay} today
                    </span>
                  )}
                </div>
              )}
            </li>
          )
        })}
      </ul>

      <div className="border-t border-line bg-cream/40 px-5 py-4">
        <p className="text-[12.5px] leading-relaxed text-ink-2">{MISSED_DOSE}</p>
      </div>

      {onUpdate && (
        <div className="border-t border-line px-5 py-4">
          {adding ? (
            <div className="space-y-3">
              <div>
                <label htmlFor="med-name" className="label">
                  What is it called?
                </label>
                <input
                  id="med-name"
                  className="field mt-1.5"
                  placeholder="Exactly as it reads on the label"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </div>
              <div>
                <label htmlFor="med-amount" className="label">
                  What were you told to give?
                </label>
                <input
                  id="med-amount"
                  className="field mt-1.5"
                  placeholder="Half a tablet with food"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                />
              </div>
              <div className="flex flex-wrap gap-2">
                {FREQUENCIES.map((f) => (
                  <button
                    key={f.id}
                    type="button"
                    aria-pressed={frequency === f.id}
                    onClick={() => setFrequency(f.id)}
                    className={`rounded-full border-[1.5px] px-3.5 py-2 text-[13.5px] transition ${
                      frequency === f.id
                        ? 'border-forest bg-sage text-deep'
                        : 'border-line bg-white text-ink'
                    }`}
                  >
                    {f.label}
                  </button>
                ))}
              </div>
              <div>
                <label htmlFor="med-qty" className="label">
                  How many were dispensed? (optional)
                </label>
                <input
                  id="med-qty"
                  type="number"
                  min="0"
                  inputMode="numeric"
                  className="field mt-1.5 max-w-[160px]"
                  value={quantity}
                  onChange={(e) => setQuantity(e.target.value)}
                />
              </div>
              <div className="flex gap-2">
                <button
                  type="button"
                  className="pill-primary px-5 py-2.5 text-[14px]"
                  onClick={add}
                  disabled={!name.trim() || !amount.trim()}
                >
                  Save
                </button>
                <button
                  type="button"
                  className="pill-ghost px-5 py-2.5 text-[14px]"
                  onClick={() => setAdding(false)}
                >
                  Cancel
                </button>
              </div>
            </div>
          ) : (
            <button
              type="button"
              className="pill-ghost px-5 py-2.5 text-[14px]"
              onClick={() => setAdding(true)}
            >
              Add a medication
            </button>
          )}
        </div>
      )}
    </section>
  )
}
