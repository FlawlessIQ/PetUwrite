import { useMemo, useState } from 'react'
import type { PetProfile } from '../data/types'
import { forEmergency, NO_PLACES_COPY, NULL_PLACES_PROVIDER, placesFromEnv, type EmergencyVet } from '../engine/places'
import { track } from '../analytics/track'

/**
 * "Find the nearest vet open now" — shared by both urgent screens.
 *
 * It lived only on "ate something" until the UAT (run 1, D17) found the
 * collapse screen — "Stop and ring a vet now" — offering nothing but poison
 * lines. The screen that most needs a vet had the weaker way to find one.
 *
 * Sits under the phone numbers on both, so "a line above" is true on both.
 */
export function FindVet({ pet }: { pet: PetProfile }) {
  const places = useMemo(() => placesFromEnv() ?? NULL_PLACES_PROVIDER, [])
  const [vets, setVets] = useState<EmergencyVet[] | null>(null)
  const [vetState, setVetState] = useState<'idle' | 'asking' | 'done' | 'refused' | 'failed'>('idle')

  /**
   * Location is asked for only when somebody taps, never on load.
   *
   * A permission prompt that appears by itself is one people dismiss without
   * reading, and this screen must not spend its one chance at their attention
   * on a dialogue they did not ask for.
   */
  const findVets = () => {
    if (!navigator.geolocation) {
      setVetState('failed')
      return
    }
    setVetState('asking')
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        try {
          const found = await places.findEmergencyVets({
            lat: pos.coords.latitude,
            lng: pos.coords.longitude,
          })
          setVets(forEmergency(found))
          setVetState('done')
          track('emergency_vets_found', { count: found.length, pet_is_demo: !!pet.demo })
        } catch {
          setVetState('failed')
        }
      },
      () => setVetState('refused'),
      { timeout: 10000, maximumAge: 60000 },
    )
  }

  return (
    <>
      {places.available ? (
        <div className="mt-4">
          {vetState === 'idle' && (
            <button
              type="button"
              className="pill-ghost w-full px-4 py-2.5 text-body-lg"
              onClick={findVets}
            >
              Find the nearest vet open now
            </button>
          )}
          {vetState === 'asking' && (
            <p className="text-body text-ink-2">Looking…</p>
          )}
          {vetState === 'refused' && (
            <p className="text-body leading-relaxed text-ink-2">
              Without your location we cannot look. Search for &ldquo;emergency vet near
              me&rdquo;, or ring a line above — they will tell you where to go.
            </p>
          )}
          {vetState === 'failed' && (
            <p className="text-body leading-relaxed text-ink-2">{NO_PLACES_COPY}</p>
          )}
          {vetState === 'done' && vets && (
            <>
              {vets.length === 0 ? (
                <p className="text-body leading-relaxed text-ink-2">{NO_PLACES_COPY}</p>
              ) : (
                <ul className="space-y-2">
                  {vets.map((v) => (
                    <li
                      key={`${v.name}-${v.address}`}
                      className="rounded-soft border border-line bg-white px-4 py-3"
                    >
                      <div className="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
                        <span className="text-body-lg font-medium text-ink">{v.name}</span>
                        <span className="text-body-sm text-ink-2">
                          {v.openNow === true
                            ? 'Open now'
                            : v.openNow === false
                              ? 'Hours say closed'
                              : 'Hours unknown'}
                          {v.distanceKm !== undefined && ` · ${v.distanceKm}km`}
                        </span>
                      </div>
                      <p className="mt-0.5 text-body-sm leading-relaxed text-ink-2">{v.address}</p>
                      {v.tel && (
                        <a
                          href={`tel:${v.tel.replace(/\s+/g, '')}`}
                          onClick={() => track('emergency_vet_called', { pet_is_demo: !!pet.demo })}
                          className="mt-1 inline-block text-lead font-medium text-forest"
                        >
                          {v.tel}
                        </a>
                      )}
                    </li>
                  ))}
                </ul>
              )}
              <p className="mt-2 text-body-sm leading-relaxed text-ink-2">
                Opening hours come from Google and can be wrong at three in the morning. Ring
                before you drive.
              </p>
            </>
              )}
            </div>
          ) : (
            <p className="mt-3 text-body-sm leading-relaxed text-ink-2">{NO_PLACES_COPY}</p>
          )}
    </>
  )
}
