import type { Ask } from '../data/askRegistry'

/**
 * A single contextual ask, rendered on the screen the registry places it on.
 *
 * Deliberately small and quiet. A contextual ask interrupts someone doing
 * something else, so it earns its place by being one question with a visible
 * reason, dismissible, and gone once answered.
 */
export function ContextualAsk<T extends string>({
  ask,
  options,
  value,
  onAnswer,
  onDismiss,
}: {
  ask: Ask
  options: { value: T; label: string; hint?: string }[]
  value: T | undefined
  onAnswer: (v: T) => void
  onDismiss?: () => void
}) {
  return (
    <section
      aria-labelledby={`ask-${ask.field}`}
      className="card mb-5 overflow-hidden border-forest/25 bg-sage/30 px-5 py-4 sm:px-6"
    >
      <div className="flex flex-wrap items-start justify-between gap-x-4 gap-y-1">
        <h2 id={`ask-${ask.field}`} className="font-display text-[19px] leading-tight text-ink">
          {ask.question}
        </h2>
        {onDismiss && (
          <button
            type="button"
            onClick={onDismiss}
            className="text-[13.5px] text-muted transition hover:text-ink text-action"
          >
            Not now
          </button>
        )}
      </div>
      <p className="mt-1 text-[14px] leading-snug text-muted">{ask.benefit}</p>
      <div role="radiogroup" aria-label={ask.question} className="mt-3.5 grid gap-2 sm:grid-cols-3">
        {options.map((o) => {
          const on = value === o.value
          return (
            <button
              key={o.value}
              type="button"
              role="radio"
              aria-checked={on}
              onClick={() => onAnswer(o.value)}
              className={`rounded-soft border px-3 py-2.5 text-left transition ${
                on
                  ? 'border-forest bg-forest text-white shadow-soft'
                  : 'border-line bg-white text-ink hover:border-forest/50'
              }`}
            >
              <span className="block text-[14.5px] font-medium leading-tight">{o.label}</span>
              {o.hint && (
                <span className={`mt-0.5 block text-[12px] ${on ? 'text-white/70' : 'text-muted'}`}>
                  {o.hint}
                </span>
              )}
            </button>
          )
        })}
      </div>
    </section>
  )
}
