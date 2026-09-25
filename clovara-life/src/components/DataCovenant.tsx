import { COVENANT, COVENANT_INTRO, COVENANT_TITLE } from '../data/covenant'
import { CloverMark } from './CloverMark'
import { Icon } from './Icon'

/**
 * The Data Covenant page (invariant 5). Reached at `#/covenant`.
 *
 * Deliberately plain: one column, no cards competing for attention, no
 * illustration. It is a promise, and a promise that has been art-directed reads
 * like marketing.
 *
 * The content lives in `data/covenant.ts` so it is reviewable and tested in one
 * place — see the LEGAL-REVIEW block at the top of that file.
 */
export function DataCovenant({ onClose }: { onClose: () => void }) {
  return (
    <div className="mx-auto w-full max-w-[680px] px-5 pb-24 pt-8 sm:pt-12">
      <div className="mb-8 flex items-center justify-between gap-4">
        <div className="flex items-center gap-2.5">
          <CloverMark size={26} />
          <span className="label">Clovara</span>
        </div>
        <button
          type="button"
          onClick={onClose}
          className="text-[14px] text-ink-2 transition hover:text-ink text-action"
        >
          Back to the app
        </button>
      </div>

      <h1 className="font-display text-[36px] leading-[1.08] text-ink sm:text-[44px]">
        {COVENANT_TITLE}
      </h1>
      <p className="mt-4 max-w-[58ch] text-[17px] leading-relaxed text-ink/85">{COVENANT_INTRO}</p>

      <div className="mt-10 space-y-9">
        {COVENANT.map((section) => (
          <section key={section.id} id={section.id} aria-labelledby={`${section.id}-h`}>
            <h2
              id={`${section.id}-h`}
              className="font-display text-[23px] leading-tight text-ink sm:text-[26px]"
            >
              {section.heading}
            </h2>
            {section.body.map((p, i) => (
              <p key={i} className="mt-3 max-w-[62ch] text-[15.5px] leading-relaxed text-ink/80">
                {p}
              </p>
            ))}
            {section.promises && (
              <ul className="mt-4 space-y-3">
                {section.promises.map((p, i) => (
                  <li
                    key={i}
                    className="flex gap-3 rounded-soft border border-forest/25 bg-sage/30 px-4 py-3"
                  >
                    <Icon name="check" size={17} className="mt-1 text-forest" active />
                    <span className="text-[15.5px] leading-relaxed text-ink/85">{p}</span>
                  </li>
                ))}
              </ul>
            )}
          </section>
        ))}
      </div>

      <div className="mt-12 border-t border-line pt-6">
        <button type="button" onClick={onClose} className="pill-primary">
          Back to the app
        </button>
      </div>
    </div>
  )
}
