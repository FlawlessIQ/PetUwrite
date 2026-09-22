import type { PetProfile, Projection } from '../data/types'
import { buildCompanion } from '../engine/platform'

export function Companion({ pet, projection }: { pet: PetProfile; projection: Projection }) {
  const thread = buildCompanion(pet, projection)
  const knownSince = new Date(pet.birthDate).getFullYear()

  return (
    <div className="mx-auto w-full max-w-[760px] px-5 pb-24 pt-8 sm:pt-10">
      <header className="mb-6">
        <p className="label">Companion</p>
        <h1 className="mt-1.5 font-display text-[34px] leading-[1.1] text-ink sm:text-[40px]">
          It remembers {pet.name}
        </h1>
        <p className="mt-2 max-w-[62ch] text-[15.5px] leading-relaxed text-muted">
          Knows {pet.name} since {knownSince}. This conversation is built from {pet.name}'s own
          record — the condition on file, the risk window {pet.sex === 'female' ? 'she' : 'he'} is in
          right now, and the signs that actually matter for a {projection.breed.name}. Switch pets
          and it changes, because the memory changes.
        </p>
      </header>

      <div className="card px-4 py-5 sm:px-6 sm:py-6">
        <ol className="flex flex-col gap-3.5">
          {thread.map((m, i) => (
            <li
              key={i}
              className={`flex ${m.from === 'user' ? 'justify-end' : 'justify-start'}`}
            >
              <div
                className={`max-w-[88%] rounded-[18px] px-4 py-3 text-[14.5px] leading-relaxed sm:max-w-[78%] ${
                  m.from === 'user'
                    ? 'rounded-br-[6px] bg-forest text-white'
                    : 'rounded-bl-[6px] border border-line bg-cream/50 text-ink'
                }`}
              >
                <p>{m.text}</p>

                {m.recall && (
                  <div className="mt-3 flex gap-2.5 rounded-soft bg-sage px-3 py-2.5 text-[13.5px] leading-relaxed text-deep">
                    <svg
                      aria-hidden="true"
                      viewBox="0 0 24 24"
                      className="mt-[3px] h-[15px] w-[15px] shrink-0 stroke-current"
                      fill="none"
                      strokeWidth={2}
                    >
                      <circle cx="12" cy="12" r="9" />
                      <path d="M12 8v4l2.5 2.5" strokeLinecap="round" />
                    </svg>
                    <span>
                      <strong className="font-semibold">{m.recall.label}:</strong> {m.recall.text}
                    </span>
                  </div>
                )}

                {m.actions && (
                  <div className="mt-3 flex flex-wrap gap-2">
                    {m.actions.map((a, j) => (
                      <span
                        key={a}
                        className={`rounded-full px-3.5 py-1.5 text-[13px] font-medium ${
                          j === 0
                            ? 'bg-forest text-white'
                            : 'border border-line bg-white text-ink'
                        }`}
                      >
                        {a}
                      </span>
                    ))}
                  </div>
                )}
              </div>
            </li>
          ))}
        </ol>

        <div className="mt-5 flex items-center gap-2 rounded-full border border-line bg-white py-2 pl-5 pr-2 text-[14px] text-muted">
          <span className="flex-1">Ask about {pet.name}…</span>
          <span
            aria-hidden="true"
            className="grid h-9 w-9 shrink-0 place-items-center rounded-full bg-forest"
          >
            <svg viewBox="0 0 24 24" className="h-4 w-4 stroke-white" fill="none" strokeWidth={2.2} strokeLinecap="round">
              <path d="M5 12h14M13 6l6 6-6 6" />
            </svg>
          </span>
        </div>
      </div>

      <div className="mt-5 grid gap-3 sm:grid-cols-2">
        <p className="rounded-soft border border-line bg-white px-4 py-3.5 text-[13.5px] leading-relaxed text-muted">
          The companion shares information and routes you to a licensed vet. It does not diagnose —
          that is the legal line and the trust line, and they happen to be the same line.
        </p>
        <p className="rounded-soft border border-line bg-white px-4 py-3.5 text-[13.5px] leading-relaxed text-muted">
          Conversations here are firewalled from underwriting and claims. What you tell the
          assistant does not price your policy.
        </p>
      </div>

      <p className="mt-4 text-[13px] leading-relaxed text-muted">
        This thread is scripted for the preview, but every specific in it is pulled from {pet.name}'s
        record rather than written by hand.
      </p>
    </div>
  )
}
