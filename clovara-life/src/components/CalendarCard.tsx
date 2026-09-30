import { useMemo, useState } from 'react'
import type { PetProfile } from '../data/types'
import { calendarEvents, toIcs } from '../engine/calendar'
import { track } from '../analytics/track'

/**
 * "Put Bruno's dates in your calendar" (ACQUISITION-ONBOARDING-PLAN, Phase B).
 *
 * The return channel that needs no email domain: the owner's own calendar does
 * the reminding. The file is written on this device and handed to the browser
 * as a download — on a phone that opens the calendar's own "add" sheet. Nothing
 * is sent anywhere, so nothing here needs consent beyond the tap.
 */
export function CalendarCard({ pet, now = new Date() }: { pet: PetProfile; now?: Date }) {
  const events = useMemo(() => calendarEvents(pet, now), [pet, now])
  const [done, setDone] = useState(false)
  if (events.length === 0) return null
  const file = `${pet.name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'pet'}-clovara.ics`

  const add = () => {
    const ics = toIcs(pet, events, now)
    const url = URL.createObjectURL(new Blob([ics], { type: 'text/calendar;charset=utf-8' }))
    const a = document.createElement('a')
    a.href = url
    a.download = file
    document.body.appendChild(a)
    a.click()
    a.remove()
    setTimeout(() => URL.revokeObjectURL(url), 10_000)
    track('calendar_exported', { events: events.length, pet_is_demo: !!pet.demo, species: pet.species })
    setDone(true)
  }

  const next = events[0]
  return (
    <section className="card px-5 py-5 sm:px-6" aria-labelledby="calendar-heading">
      <p className="label">Reminders</p>
      <h2 id="calendar-heading" className="mt-1.5 font-display text-heading leading-tight text-ink">
        Put {pet.name}&rsquo;s dates in your calendar
      </h2>
      <p className="mt-1.5 text-body-lg leading-relaxed text-ink-2">
        {events.length === 1 ? 'One date' : `${events.length} dates`}, starting with{' '}
        <span className="text-ink">{next.title.replace(`${pet.name}: `, '')}</span> on{' '}
        {new Date(`${next.date}T12:00:00Z`).toLocaleDateString('en-GB', { day: 'numeric', month: 'long', timeZone: 'UTC' })}
        . Made on this device and sent nowhere; add it again after you record something, to keep it
        current.
      </p>
      <button type="button" className="pill-primary mt-3.5" onClick={add}>
        Add to my calendar
      </button>
      {done && (
        <p className="mt-2 text-body-sm leading-relaxed text-ink-2" role="status">
          If nothing opened, look in your downloads for {file} and open it.
        </p>
      )}
    </section>
  )
}
