/**
 * The companion conversation kit — the renderer (docs/DESIGN.md §5b).
 *
 * One component per block kind, and a registry that maps kind → component.
 * There is no component for a diagnosis, a likelihood, a condition name or a
 * verdict, because there is no block for one: the component set IS the
 * compliance boundary. A test holds the registry to the seven kinds in §5b.
 */
import type { ReactElement } from 'react'
import { inlineSegments, URGENCY_CLOSING, type BlockKind, type CompanionBlock } from '../../companion/blocks'
import { POISON_LINES } from '../../data/poisonLines'

export interface BlockContext {
  petName: string
  /** Called when an action pill is tapped. Absent → the pills are shown but inert. */
  onAction?: (item: { label: string; action: string }) => void
  /** The action already chosen in this reply, if any. Locks the row. */
  chosen?: string | null
  /**
   * How a product_ref finds its product. Supplied by whoever renders product
   * blocks, so the kit — which every Care visit downloads — does not carry the
   * whole shop catalogue (BACKLOG T4). Absent → a product_ref renders nothing,
   * the same as a reference to a product that does not exist.
   */
  product?: (id: string) => { name: string; emoji: string; memberPrice: number } | undefined
}

type Of<K extends BlockKind> = Extract<CompanionBlock, { kind: K }>

// ── text ────────────────────────────────────────────────────────────────────
function TextBlock({ block }: { block: Of<'text'> }) {
  return (
    <p>
      {inlineSegments(block.md).map((s, i) =>
        s.bold ? (
          <strong key={i} className="font-semibold text-ink">
            {s.text}
          </strong>
        ) : (
          <span key={i}>{s.text}</span>
        ),
      )}
    </p>
  )
}

// ── history_ref: the memory moment ─────────────────────────────────────────
function ClockIcon() {
  return (
    <svg aria-hidden="true" viewBox="0 0 24 24" className="mt-[2px] h-[14px] w-[14px] shrink-0 stroke-current" fill="none" strokeWidth={1.8}>
      <circle cx="12" cy="12" r="9" />
      <path d="M12 7.5v4.5l2.8 2.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}
function HistoryRef({ block }: { block: Of<'history_ref'> }) {
  return (
    <div className="flex gap-2 rounded-[10px] bg-sage px-3 py-2.5 text-body-sm leading-relaxed text-deep">
      <ClockIcon />
      <p>
        <strong className="font-semibold">{block.lead}:</strong> {block.note}
        {block.date && <span className="tabular-nums"> {block.date}</span>}
      </p>
    </div>
  )
}

// ── watch_signs ────────────────────────────────────────────────────────────
function WatchSigns({ block }: { block: Of<'watch_signs'> }) {
  const closing = URGENCY_CLOSING[block.urgency]
  return (
    <div>
      <p>{block.intro}</p>
      {block.signs.length > 0 && (
        <ul className="mt-2 space-y-1.5">
          {block.signs.map((s) => (
            <li key={s} className="flex gap-2.5">
              <span aria-hidden="true" className="mt-[9px] h-[6px] w-[6px] shrink-0 rounded-full bg-forest" />
              <span>{s}</span>
            </li>
          ))}
        </ul>
      )}
      {closing && <p className="mt-2 font-semibold text-deep">{closing}</p>}
    </div>
  )
}

// ── actions: max three, one primary, verbs ─────────────────────────────────
function Actions({ block, ctx }: { block: Of<'actions'>; ctx: BlockContext }) {
  const locked = !!ctx.chosen || !ctx.onAction
  return (
    <div className="flex flex-wrap gap-2" role="group" aria-label="Choose what happens next">
      {block.items.map((it) =>
        // An action that is a route is navigation, and navigation is a link: it
        // can open in a new tab and is announced as one. Everything else
        // continues the conversation, so it is a button.
        it.action.startsWith('#/') ? (
          <a
            key={it.action}
            href={it.action}
            className={`${it.style === 'primary' ? 'pill-primary' : 'pill-ghost'} pill-sm`}
          >
            {it.label}
          </a>
        ) : (
        <button
          key={it.action}
          type="button"
          // aria-disabled rather than disabled: `disabled` repaints the primary in
          // the disabled grey, which made the option you chose look like the one
          // you did not. The chosen pill keeps its colour; the rest fade.
          aria-disabled={locked || undefined}
          aria-pressed={ctx.chosen ? ctx.chosen === it.action : undefined}
          onClick={() => !locked && ctx.onAction?.(it)}
          className={`${it.style === 'primary' ? 'pill-primary' : 'pill-ghost'} pill-sm ${
            ctx.chosen && ctx.chosen !== it.action ? 'opacity-50' : ''
          } ${locked ? 'cursor-default' : ''}`}
        >
          {it.label}
        </button>
        ),
      )}
    </div>
  )
}

// ── booking_confirm ────────────────────────────────────────────────────────
function BookingConfirm({ block }: { block: Of<'booking_confirm'> }) {
  return (
    <div>
      {/* Generic over the kind of appointment: the schema carries who and when,
          not whether it is video, so the component does not claim either. */}
      <p>
        Done — booked with <strong className="font-semibold text-ink">{block.vet}</strong>,{' '}
        <strong className="font-semibold tabular-nums text-ink">{block.when}</strong>.
      </p>
      <p className="mt-1.5">{block.prepared}</p>
    </div>
  )
}

// ── product_ref: one mini product card ─────────────────────────────────────
function ProductRef({ block, ctx }: { block: Of<'product_ref'>; ctx: BlockContext }) {
  const p = ctx.product?.(block.productId)
  // A reference to a product that does not exist renders nothing rather than an
  // empty card or a "why" line with nothing to be about.
  if (!p) return null
  return (
    <div className="flex gap-3 rounded-soft border border-line bg-cream px-3 py-3">
      {/* §5: emoji only as a content-image placeholder until real imagery lands. */}
      <span aria-hidden="true" className="grid h-12 w-12 shrink-0 place-items-center rounded-inner bg-card text-heading-lg">
        {p.emoji}
      </span>
      <div className="min-w-0">
        <p className="text-body-lg font-semibold leading-snug text-ink">{p.name}</p>
        <p className="mt-0.5 text-body-sm leading-snug text-ink-2">{block.why}</p>
        <p className="mt-1 text-body-sm font-semibold tabular-nums text-forest">${p.memberPrice} for members</p>
      </div>
    </div>
  )
}

// ── escalate: nudge-pattern, amber not red ─────────────────────────────────
function Escalate({ block }: { block: Of<'escalate'> }) {
  return (
    <div className="nudge">
      <p className="font-semibold text-ink">{block.reason}</p>
      <a href="#/wrong" className="pill-primary pill-sm mt-2.5">
        What to do now
      </a>
      <ul className="mt-3 space-y-1.5">
        {POISON_LINES.map((l) => (
          <li key={l.id} className="text-body-sm leading-snug text-ink-2">
            <a href={`tel:${l.tel}`} className="text-action font-semibold tabular-nums text-forest">
              {l.display}
            </a>{' '}
            · {l.name}
          </li>
        ))}
      </ul>
    </div>
  )
}

// ── fact: a grounded claim and where it came from (D-UI8) ──────────────────
function Fact({ block }: { block: Of<'fact'> }) {
  return (
    <div className="rounded-inner border border-line bg-cream px-3 py-2.5">
      <p className="text-body-lg leading-relaxed text-ink">{block.claim}</p>
      <p className="mt-1 text-body-sm text-ink-2">
        {block.source}
        {block.citation && ` · ${block.citation}`}
      </p>
    </div>
  )
}

/**
 * kind → component. Exactly §5b's eight; the test fails if this grows a key
 * the schema does not have — which is where a "likely_condition" would appear.
 */
export const BLOCK_RENDERERS: { [K in BlockKind]: (p: { block: Of<K>; ctx: BlockContext }) => ReactElement | null } = {
  text: ({ block }) => <TextBlock block={block} />,
  history_ref: ({ block }) => <HistoryRef block={block} />,
  watch_signs: ({ block }) => <WatchSigns block={block} />,
  actions: ({ block, ctx }) => <Actions block={block} ctx={ctx} />,
  booking_confirm: ({ block }) => <BookingConfirm block={block} />,
  product_ref: ({ block, ctx }) => <ProductRef block={block} ctx={ctx} />,
  escalate: ({ block }) => <Escalate block={block} />,
  fact: ({ block }) => <Fact block={block} />,
}

/** One block. Anything the registry does not know renders as text — never as nothing. */
export function RenderBlock({ block, ctx }: { block: CompanionBlock; ctx: BlockContext }) {
  const render = (BLOCK_RENDERERS as Record<string, (p: { block: CompanionBlock; ctx: BlockContext }) => ReactElement | null>)[
    block.kind
  ]
  if (!render) {
    const loose = block as unknown as Record<string, unknown>
    const md = typeof loose.md === 'string' ? loose.md : typeof loose.text === 'string' ? loose.text : ''
    return <TextBlock block={{ kind: 'text', md }} />
  }
  return render({ block, ctx })
}
