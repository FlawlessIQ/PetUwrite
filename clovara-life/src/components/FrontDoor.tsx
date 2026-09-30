import { FRONT_DOOR } from '../data/frontDoor'
import { CloverMark } from './CloverMark'

/**
 * What a stranger sees first (ACQUISITION-ONBOARDING-PLAN, AO1).
 *
 * The site used to open on "Max's day" — somebody else's dog, with nothing to
 * say it was an example. Now a first visit to the bare site says what this is
 * and offers one thing: add your own. The demo is one tap away and at its own
 * link (#/demo) for investors; every existing link bypasses this entirely.
 * Shown once — either button marks it seen.
 */
export function FrontDoor({ onStart, onExample }: { onStart: () => void; onExample: () => void }) {
  return (
    <section className="mx-auto flex w-full max-w-[640px] flex-col px-5 pb-16 pt-10 sm:pt-16" aria-labelledby="front-door-heading">
      <CloverMark size={44} />
      <p className="label mt-6">{FRONT_DOOR.eyebrow}</p>
      <h1 id="front-door-heading" className="mt-2 font-display text-display-lg leading-[1.08] text-ink sm:text-display-xl">
        {FRONT_DOOR.headline}
      </h1>
      <p className="mt-4 max-w-[52ch] text-lead leading-relaxed text-ink-2">{FRONT_DOOR.body}</p>
      <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:items-center">
        <button type="button" className="pill-primary" onClick={onStart}>
          {FRONT_DOOR.primary}
        </button>
        <button type="button" className="pill-ghost" onClick={onExample}>
          {FRONT_DOOR.secondary}
        </button>
      </div>
      <p className="mt-4 text-body-sm leading-relaxed text-ink-2">{FRONT_DOOR.exampleNote}</p>
      <a href="#/covenant" className="mt-10 text-body text-forest text-action">
        What we do, and never do, with what you tell us
      </a>
    </section>
  )
}
