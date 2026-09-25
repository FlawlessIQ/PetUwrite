/**
 * The companion conversation — bubbles, chrome and the scripted player
 * (docs/DESIGN.md §5b).
 *
 * The chrome is not content. The header, the disclaimer and the typebar are
 * rendered here unconditionally and take no text from the reply, so no reply —
 * scripted today, model-written later — can omit or reword them.
 */
import { useEffect, useRef, useState } from 'react'
import type { CompanionBlock } from '../../companion/blocks'
import { continuationFor, splitAtFirstChoice, type Turn } from '../../companion/script'
import { RenderBlock, type BlockContext } from './Blocks'

/** §5b motion: 120ms between blocks, a 300ms rise each. */
export const STAGGER_MS = 120
const TYPING_MS = 700

const reducedMotion = () =>
  typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches

// ── Bubbles ─────────────────────────────────────────────────────────────────
/** User: forest, white, right, radius 18/18/6/18. */
export function UserBubble({ text, delay = 0 }: { text: string; delay?: number }) {
  return (
    <li className="flex justify-end">
      <p
        className="stream-in max-w-[82%] rounded-[18px] rounded-br-[6px] bg-forest px-4 py-3 text-[14.5px] leading-[1.5] text-white"
        style={{ animationDelay: `${delay}ms` }}
      >
        {text}
      </p>
    </li>
  )
}

/** AI: card, 1px line, left, radius 18/18/18/6. Actions sit under it, outside the bubble. */
export function AiReply({ blocks, ctx, delay = 0 }: { blocks: CompanionBlock[]; ctx: BlockContext; delay?: number }) {
  const inBubble = blocks.filter((b) => b.kind !== 'actions')
  const actions = blocks.filter((b) => b.kind === 'actions')
  return (
    <li className="flex flex-col items-start gap-2">
      {inBubble.length > 0 && (
        <div className="max-w-[82%] space-y-2.5 rounded-[18px] rounded-bl-[6px] border border-line bg-card px-4 py-3 text-[14.5px] leading-[1.5] text-ink">
          {inBubble.map((b, i) => (
            <div key={i} className="stream-in" style={{ animationDelay: `${delay + i * STAGGER_MS}ms` }}>
              <RenderBlock block={b} ctx={ctx} />
            </div>
          ))}
        </div>
      )}
      {actions.map((b, i) => (
        <div key={`a${i}`} className="stream-in" style={{ animationDelay: `${delay + (inBubble.length + i) * STAGGER_MS}ms` }}>
          <RenderBlock block={b} ctx={ctx} />
        </div>
      ))}
    </li>
  )
}

/** §5b: three sage dots in an AI bubble. */
export function TypingDots() {
  return (
    <li className="flex justify-start" aria-live="polite">
      <span className="flex gap-1.5 rounded-[18px] rounded-bl-[6px] border border-line bg-card px-4 py-3.5">
        <span className="sr-only">The companion is replying</span>
        {[0, 1, 2].map((i) => (
          <span key={i} aria-hidden="true" className="typing-dot h-[7px] w-[7px] rounded-full bg-sage-2" style={{ animationDelay: `${i * 150}ms` }} />
        ))}
      </span>
    </li>
  )
}

// ── Chrome ──────────────────────────────────────────────────────────────────
/** The fixed disclaimer. Exact words from §5b; not content, cannot be omitted. */
export const DISCLAIMER =
  'Companion shares information and routes you to licensed vets — it doesn’t diagnose. Your conversations here are never used in underwriting or claims.'

export function ChromeHeader({ petName, since }: { petName: string; since: number }) {
  return (
    <p className="mb-4 text-center text-[13px] font-semibold tracking-[0.02em] text-ink-2">
      Knows {petName} since <span className="tabular-nums">{since}</span>
    </p>
  )
}

/**
 * §5b typebar: a card pill, a ghost placeholder, a 32px forest send disc.
 * It is a button that takes you to the real question box above rather than a
 * text field that does nothing — a field you can type into and cannot send is
 * worse than no field.
 */
export function ChromeTypebar({ petName, target = 'ask' }: { petName: string; target?: string }) {
  return (
    <button
      type="button"
      onClick={() => {
        const el = document.getElementById(target)
        el?.scrollIntoView({ behavior: reducedMotion() ? 'auto' : 'smooth', block: 'center' })
        el?.focus({ preventScroll: true })
      }}
      className="mt-5 flex w-full items-center gap-2 rounded-full border border-line bg-card py-1.5 pl-5 pr-1.5 text-left text-[14px] text-ink-2 transition hover:border-forest/50"
    >
      <span className="flex-1">Ask about {petName}…</span>
      <span aria-hidden="true" className="grid h-8 w-8 shrink-0 place-items-center rounded-full bg-forest">
        <svg viewBox="0 0 24 24" className="h-4 w-4 stroke-white" fill="none" strokeWidth={2.1} strokeLinecap="round" strokeLinejoin="round">
          <path d="M5 12h14M13 6l6 6-6 6" />
        </svg>
      </span>
    </button>
  )
}

export function ChromeDisclaimer() {
  return <p className="mt-3 text-center text-[11px] leading-relaxed text-ink-2">{DISCLAIMER}</p>
}

// ── The scripted player ─────────────────────────────────────────────────────
/**
 * Streams the scripted thread in, stops at the first choice, and continues when
 * the owner taps one — their choice appearing as their own bubble (§5b). Under
 * reduced motion everything renders at once and the typing pause is skipped.
 */
export function ScriptedConversation({ turns, petName, since }: { turns: Turn[]; petName: string; since: number }) {
  const { before, after } = splitAtFirstChoice(turns)
  const [chosen, setChosen] = useState<{ label: string; action: string } | null>(null)
  const [typing, setTyping] = useState(false)
  const [shown, setShown] = useState<Turn[]>([])
  const timer = useRef<number | null>(null)

  // A different pet is a different conversation: the caller keys this component
  // by pet, so switching remounts it rather than resetting state here — `turns`
  // is a fresh array every render and would wipe a tap the moment it happened.
  useEffect(() => () => {
    if (timer.current) window.clearTimeout(timer.current)
  }, [])

  const choose = (item: { label: string; action: string }) => {
    if (chosen) return
    setChosen(item)
    const next = continuationFor(item.action, after)
    if (reducedMotion()) {
      setShown(next)
      return
    }
    setTyping(true)
    timer.current = window.setTimeout(() => {
      setTyping(false)
      setShown(next)
    }, TYPING_MS)
  }

  let delay = 0
  const step = (n: number) => {
    const d = delay
    delay += n * STAGGER_MS
    return d
  }

  return (
    <div>
      <ChromeHeader petName={petName} since={since} />
      <ol className="flex flex-col gap-3.5" aria-label={`Conversation about ${petName}`}>
        {before.map((t, i) =>
          t.from === 'user' ? (
            <UserBubble key={`b${i}`} text={t.text} delay={step(1)} />
          ) : (
            <AiReply
              key={`b${i}`}
              blocks={t.blocks}
              delay={step(t.blocks.length)}
              ctx={{ petName, onAction: choose, chosen: chosen?.action ?? null }}
            />
          ),
        )}
        {chosen && <UserBubble key="choice" text={chosen.label} />}
        {typing && <TypingDots />}
        {shown.map((t, i) =>
          t.from === 'user' ? (
            <UserBubble key={`s${i}`} text={t.text} />
          ) : (
            <AiReply key={`s${i}`} blocks={t.blocks} delay={i * STAGGER_MS} ctx={{ petName }} />
          ),
        )}
      </ol>
      <ChromeTypebar petName={petName} />
      <ChromeDisclaimer />
    </div>
  )
}
