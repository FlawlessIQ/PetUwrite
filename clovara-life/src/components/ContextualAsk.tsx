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
        <h2 id={`ask-${ask.field}`} className="font-display text-heading-sm leading-tight text-ink">
          {ask.question}
        </h2>
        {onDismiss && (
          <button
            type="button"
            onClick={onDismiss}
            className="text-body text-ink-2 transition hover:text-ink text-action"
          >
            Not now
          </button>
        )}
      </div>
      <p className="mt-1 text-body-lg leading-snug text-ink-2">{ask.benefit}</p>
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
              className={`rounded-inner border-2 px-3 py-2.5 text-left transition ${
                on
                  ? 'border-forest bg-sage text-deep'
                  : 'border-line bg-cream text-ink hover:border-forest/50'
              }`}
            >
              <span className="block text-body-lg font-medium leading-tight">{o.label}</span>
              {o.hint && (
                <span className={`mt-0.5 block text-body-sm ${on ? 'text-deep/80' : 'text-ink-2'}`}>
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
