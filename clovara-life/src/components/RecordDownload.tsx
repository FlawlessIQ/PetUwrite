import { useState } from 'react'
import type { PetProfile } from '../data/types'
import { recordExport } from '../engine/recordExport'
import { track } from '../analytics/track'

/**
 * "Download everything about Bruno" (BACKLOG UB12) — the Data Covenant's
 * "ask us for everything we hold on your pet", for the pet record, without
 * having to ask. Made on this device and handed to the browser; nothing is
 * sent. Shown for remembered pets too: a record of an animal who has died is
 * exactly the thing somebody may want to keep.
 */
export function RecordDownload({ pet, now = new Date() }: { pet: PetProfile; now?: Date }) {
  const [saved, setSaved] = useState<string | null>(null)

  const save = (kind: 'html' | 'json') => {
    const files = recordExport(pet, now)
    const file = `${files.baseName}.${kind}`
    const blob =
      kind === 'html'
        ? new Blob([files.html], { type: 'text/html;charset=utf-8' })
        : new Blob([files.json], { type: 'application/json;charset=utf-8' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = file
    document.body.appendChild(a)
    a.click()
    a.remove()
    setTimeout(() => URL.revokeObjectURL(url), 10_000)
    track('record_downloaded', { format: kind, pet_is_demo: !!pet.demo, species: pet.species })
    setSaved(file)
  }

  return (
    <section className="card px-5 py-5 sm:px-6" aria-labelledby="record-heading">
      <p className="label">Your copy</p>
      <h2 id="record-heading" className="mt-1.5 font-display text-heading leading-tight text-ink">
        Download everything about {pet.name}
      </h2>
      <p className="mt-1.5 text-body-lg leading-relaxed text-ink-2">
        Every answer, record and note in {pet.name}&rsquo;s file, as a page you can read and keep.
        Made on this device and sent nowhere.
      </p>
      <div className="mt-3.5 flex flex-wrap items-center gap-3">
        <button type="button" className="pill-primary" onClick={() => save('html')}>
          Download {pet.name}&rsquo;s record
        </button>
        <button type="button" className="pill-ghost px-4 py-2 text-body" onClick={() => save('json')}>
          As data (.json)
        </button>
      </div>
      {saved && (
        <p className="mt-2 text-body-sm leading-relaxed text-ink-2" role="status">
          If nothing opened, look in your downloads for {saved}.
        </p>
      )}
    </section>
  )
}
