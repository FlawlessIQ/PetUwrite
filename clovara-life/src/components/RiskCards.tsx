import type { Projection, RiskCard } from '../data/types'

const MODE_COPY: Record<RiskCard['mode'], { label: string; className: string }> = {
  manage: { label: 'Managing', className: 'bg-forest text-white' },
  active: { label: 'In the window', className: 'bg-accent/15 text-[#8A5510]' },
  watch: { label: 'Watching', className: 'bg-sage text-deep' },
}

export function RiskCards({ projection, name }: { projection: Projection; name: string }) {
  return (
    <section className="card overflow-hidden" aria-labelledby="risks-heading">
      <div className="border-b border-line bg-cream/50 px-5 py-4 sm:px-6">
        <h2 id="risks-heading" className="font-display text-[22px] leading-tight text-ink">
          What matters for a {projection.breed.name}
        </h2>
        <p className="mt-1 text-[14px] leading-snug text-ink-2">
          The conditions most worth knowing about for this breed, and when they typically show up.
        </p>
      </div>

      <ul className="divide-y divide-line">
        {projection.riskCards.map((card) => {
          const mode = MODE_COPY[card.mode]
          return (
            <li key={card.id} className="px-5 py-4 sm:px-6">
              <div className="flex flex-wrap items-start justify-between gap-x-3 gap-y-1.5">
                <h3 className="text-[15.5px] font-medium leading-snug text-ink">{card.name}</h3>
                <span
                  className={`shrink-0 rounded-full px-2.5 py-0.5 text-[11px] font-medium uppercase tracking-[0.07em] ${mode.className}`}
                >
                  {mode.label}
                </span>
              </div>

              <p className="mt-1 text-[13px] font-medium text-forest">{card.window}</p>

              <p className="mt-2 text-[14px] leading-relaxed text-ink/80">
                <span className="text-ink-2">What you might notice — </span>
                {card.watch}
              </p>
              <p className="mt-1.5 text-[14px] leading-relaxed text-ink/80">
                <span className="text-ink-2">What to do — </span>
                {card.action}
              </p>

              {card.context && (
                <p className="mt-2.5 rounded-soft border border-line bg-cream/60 px-3 py-2.5 text-[13.5px] leading-relaxed text-ink/80">
                  <span className="mb-1 block text-[11px] uppercase tracking-[0.09em] text-ink-2">
                    About {name} specifically
                  </span>
                  {card.context.text}
                  <span className="mt-1.5 block text-[12.5px] text-ink-2">
                    {card.context.source.label}
                  </span>
                </p>
              )}

              {card.tier === 'high' && (
                <p className="mt-2 text-[12px] uppercase tracking-[0.09em] text-accent">
                  {projection.breed.isMixed
                    ? 'Common, and worth staying ahead of'
                    : 'Higher relative risk in this breed'}
                </p>
              )}
            </li>
          )
        })}
      </ul>

      <p className="border-t border-line bg-cream/50 px-5 py-3.5 text-[13px] leading-relaxed text-ink-2 sm:px-6">
        These are breed-average patterns, not findings about {name}. Your vet is the one who decides
        what any of it means for your pet.
      </p>
    </section>
  )
}
