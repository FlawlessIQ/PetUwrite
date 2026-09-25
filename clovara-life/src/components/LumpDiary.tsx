import { useMemo, useRef, useState } from 'react'
import type { PetProfile } from '../data/types'
import {
  inOrder,
  lumpBlockedCopy,
  lumpState,
  NEW_LUMP_WARNING,
  NO_JUDGEMENT,
  SIZE_REFERENCES,
  SIZE_REFERENCE_WHY,
  type Lump,
} from '../engine/lumps'
import { uploadPetPhoto } from '../store/photos'
import { isRemembered } from '../engine/remember'
import { describeRejection } from '../store/imageMath'
import { longDate } from '../share/cardLayout'
import { track } from '../analytics/track'

/**
 * The lump diary (SPEC-HORIZON §1.1).
 *
 * TWO DIVERGENCES FROM MY OWN SPEC, BOTH FORCED AND BOTH RECORDED IN ROADMAP:
 *
 *  1. The spec called for the previous photo as a faint overlay during capture.
 *     Capture hands off to the operating system's camera (`capture=
 *     "environment"`), so there is no preview to overlay onto. The achievable
 *     version is the previous photo shown large, immediately before the camera
 *     opens, to be matched from memory. Worse, and honest about being worse.
 *
 *  2. The spec put lumps in a subcollection. Every `{sub=**}` under a pet is
 *     denied pending the Firestore security review, so they live on the pet
 *     document instead.
 *
 * THE SIZE REFERENCE IS ASKED FOR BEFORE THE CAMERA OPENS, not after. Asked
 * afterwards it is a question about a photograph already taken, and the honest
 * answer is usually no.
 */
export function LumpDiary({
  pet,
  householdId,
  onUpdate,
  now = new Date(),
}: {
  pet: PetProfile
  householdId: string | null
  onUpdate?: (patch: Partial<PetProfile>) => void
  now?: Date
}) {
  const lumps = useMemo<Lump[]>(() => (pet.lumps as Lump[] | undefined) ?? [], [pet.lumps])
  const [adding, setAdding] = useState(false)
  const [location, setLocation] = useState('')
  const [openId, setOpenId] = useState<string | null>(null)
  const [reference, setReference] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const fileInput = useRef<HTMLInputElement>(null)
  const pendingRef = useRef<{ lumpId: string; reference: string | null } | null>(null)

  // The diary stays readable; it stops asking for more (SPEC-HORIZON §2.5).
  const quiet = isRemembered(pet)
  const save = (next: Lump[]) => onUpdate?.({ lumps: next })

  const addLump = () => {
    const name = location.trim()
    if (!name) return
    const lump: Lump = {
      id: `lump-${Date.now()}`,
      location: name,
      firstSeen: now.toISOString(),
      photos: [],
    }
    save([...lumps, lump])
    track('lump_started', { pet_is_demo: !!pet.demo })
    setLocation('')
    setAdding(false)
    setOpenId(lump.id)
  }

  const openCamera = (lumpId: string) => {
    pendingRef.current = { lumpId, reference }
    fileInput.current?.click()
  }

  const onFile = async (file: File | undefined) => {
    const pending = pendingRef.current
    if (!file || !pending || !householdId) return
    const rejection = describeRejection(file)
    if (rejection) {
      setError(rejection)
      return
    }
    setBusy(true)
    setError(null)
    try {
      const photo = await uploadPetPhoto(file, { householdId, petId: pet.id })
      save(
        lumps.map((l) =>
          l.id === pending.lumpId
            ? {
                ...l,
                photos: [
                  ...l.photos,
                  {
                    url: photo.avatarUrl,
                    fullPath: photo.fullPath,
                    takenAt: new Date().toISOString(),
                    sizeReference: pending.reference,
                  },
                ],
              }
            : l,
        ),
      )
      track('lump_photo_added', { has_reference: !!pending.reference, pet_is_demo: !!pet.demo })
    } catch {
      setError('That photo did not upload. Try again, or a different one.')
    } finally {
      setBusy(false)
      setReference(null)
      if (fileInput.current) fileInput.current.value = ''
    }
  }

  return (
    <section className="card overflow-hidden" aria-labelledby="lumps-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4">
        <p className="label">Lump diary</p>
        <h2 id="lumps-heading" className="mt-1 font-display text-[20px] text-ink">
          The same thing, month after month
        </h2>
        {!quiet && (
          <p className="mt-2 rounded-soft border border-accent/30 bg-accent/10 px-4 py-3 text-[13px] leading-relaxed text-[#8A5510]">
            {NEW_LUMP_WARNING}
          </p>
        )}
      </div>

      <input
        ref={fileInput}
        type="file"
        aria-label={`Photograph a lump on ${pet.name}`}
        accept="image/jpeg,image/png,image/webp,image/heic,image/heif"
        capture="environment"
        className="sr-only"
        onChange={(e) => void onFile(e.target.files?.[0])}
      />

      <ul className="divide-y divide-line">
        {lumps.map((lump) => {
          const state = lumpState(lump, now)
          const open = openId === lump.id
          const ordered = inOrder(lump.photos)
          const last = ordered[ordered.length - 1]
          return (
            <li key={lump.id} className="px-5 py-4">
              <button
                type="button"
                aria-expanded={open}
                onClick={() => setOpenId(open ? null : lump.id)}
                className="flex w-full items-baseline justify-between gap-4 text-left"
              >
                <span className="text-[15px] font-medium text-ink">{lump.location}</span>
                <span className="text-[12.5px] text-ink-2">
                  {state.photoCount} photo{state.photoCount === 1 ? '' : 's'}
                  {state.daysTracked > 0 && ` · ${state.daysTracked} days`}
                </span>
              </button>

              {open && (
                <div className="mt-4">
                  {/* The comparison, or why there is not one. */}
                  {state.pair ? (
                    <>
                      <div className="grid grid-cols-2 gap-3">
                        {state.pair.map((p, i) => (
                          <figure key={p.takenAt}>
                            <img
                              src={p.url}
                              alt={`${lump.location}, ${longDate(p.takenAt)}`}
                              className="w-full rounded-soft border border-line"
                            />
                            <figcaption className="mt-1 text-[12px] text-ink-2">
                              {i === 0 ? 'First' : 'Most recent'} · {longDate(p.takenAt)}
                              <span className="block">with {p.sizeReference?.toLowerCase()}</span>
                            </figcaption>
                          </figure>
                        ))}
                      </div>
                      <p className="mt-3 rounded-soft bg-sage/50 px-4 py-3 text-[13px] leading-relaxed text-deep">
                        {NO_JUDGEMENT}
                      </p>
                    </>
                  ) : (
                    <p className="text-[13.5px] leading-relaxed text-ink-2">
                      {lumpBlockedCopy(state)}
                    </p>
                  )}

                  {ordered.length > 0 && (
                    <div className="mt-4">
                      <p className="label">Every photo</p>
                      <ul className="mt-2 flex gap-2 overflow-x-auto pb-1">
                        {ordered.map((p) => (
                          <li key={p.takenAt} className="shrink-0">
                            <img
                              src={p.url}
                              alt={`${lump.location}, ${longDate(p.takenAt)}`}
                              className="h-20 w-20 rounded-soft border border-line object-cover"
                            />
                            <p className="mt-0.5 w-20 text-[11px] leading-tight text-ink-2">
                              {longDate(p.takenAt).replace(/ \d{4}$/, '')}
                              {!p.sizeReference && <span className="block">no scale</span>}
                            </p>
                          </li>
                        ))}
                      </ul>
                    </div>
                  )}

                  {/* Capture: the reference is chosen BEFORE the camera opens. */}
                  {onUpdate && !quiet && (
                    <div className="mt-5 rounded-soft border border-line bg-cream/40 px-4 py-4">
                      <p className="text-[14px] font-medium text-ink">Take the next one</p>
                      <p className="mt-1 text-[13px] leading-relaxed text-ink-2">
                        {SIZE_REFERENCE_WHY}
                      </p>
                      <div className="mt-3 flex flex-wrap gap-2">
                        {SIZE_REFERENCES.map((r) => (
                          <button
                            key={r}
                            type="button"
                            aria-pressed={reference === r}
                            onClick={() => setReference(r)}
                            className={`rounded-full border px-3.5 py-2 text-[13.5px] transition ${
                              reference === r
                                ? 'border-forest bg-forest text-white'
                                : 'border-line bg-white text-ink'
                            }`}
                          >
                            {r}
                          </button>
                        ))}
                      </div>

                      {last && (
                        <div className="mt-4">
                          <p className="text-[13px] leading-relaxed text-ink-2">
                            Match this framing as closely as you can — same distance, same angle.
                          </p>
                          <img
                            src={last.url}
                            alt={`The last photo of ${lump.location}, to match`}
                            className="mt-2 w-full max-w-[220px] rounded-soft border border-line"
                          />
                        </div>
                      )}

                      <button
                        type="button"
                        className="pill-primary mt-4 px-5 py-2.5 text-[14px]"
                        disabled={!reference || busy}
                        onClick={() => openCamera(lump.id)}
                      >
                        {busy ? 'One moment…' : 'Open the camera'}
                      </button>
                      {!reference && (
                        <p className="mt-2 text-[12.5px] text-ink-2">
                          Choose what you will put beside it first.
                        </p>
                      )}
                      {error && <p className="mt-2 text-[13px] text-[#8A5510]">{error}</p>}
                    </div>
                  )}
                </div>
              )}
            </li>
          )
        })}
      </ul>

      {onUpdate && !quiet && (
        <div className="border-t border-line px-5 py-4">
          {adding ? (
            <div className="flex flex-wrap items-end gap-2">
              <div className="min-w-[180px] flex-1">
                <label htmlFor="lump-where" className="label">
                  Where on {pet.name}?
                </label>
                <input
                  id="lump-where"
                  type="text"
                  className="field mt-1.5"
                  placeholder="Left shoulder, under the collar…"
                  value={location}
                  onChange={(e) => setLocation(e.target.value)}
                />
              </div>
              <button
                type="button"
                className="pill-primary px-5 py-2.5 text-[14px]"
                onClick={addLump}
                disabled={!location.trim()}
              >
                Start
              </button>
            </div>
          ) : (
            <button
              type="button"
              className="pill-ghost px-5 py-2.5 text-[14px]"
              onClick={() => setAdding(true)}
            >
              Track something new
            </button>
          )}
        </div>
      )}
    </section>
  )
}
