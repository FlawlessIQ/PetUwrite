/**
 * The scripted companion thread, as conversation-kit turns (DESIGN.md §5b).
 *
 * `buildCompanion` stays the source of the content — it is pure, tested, and
 * built from the pet's own record. This only restates each message as blocks,
 * preferring its structured fields to its prose, so nothing reaches the screen
 * as free text. It invents nothing: every string below comes from the engine.
 */
import type { CompanionMessage } from '../engine/platform'
import { normalise, type CompanionBlock } from './blocks'

export type Turn = { from: 'user'; text: string } | { from: 'ai'; blocks: CompanionBlock[] }

export function scriptedTurns(messages: CompanionMessage[]): Turn[] {
  return messages.map((m): Turn => {
    if (m.from === 'user') return { from: 'user', text: m.text }

    const raw: CompanionBlock[] = []
    if (m.booking) {
      raw.push({ kind: 'booking_confirm', ...m.booking })
    } else if (m.watch) {
      raw.push({ kind: 'watch_signs', ...m.watch })
    } else {
      raw.push({ kind: 'text', md: m.text })
    }
    if (m.recall) {
      // No date is invented: the scripted record does not carry one.
      raw.push({ kind: 'history_ref', lead: m.recall.label, note: m.recall.text, date: '' })
    }
    if (m.actions?.length) {
      raw.push({
        kind: 'actions',
        items: m.actions.map((label, i) => ({
          label,
          style: i === 0 ? 'primary' : 'ghost',
          action: m.actionIds?.[i] ?? `action-${i}`,
        })),
      })
    }
    return { from: 'ai', blocks: normalise(raw) }
  })
}

/**
 * Where the thread waits for a tap: just after the first reply that offers
 * actions. §5b: tapping renders the owner's choice as their own bubble, so the
 * scripted owner line that follows is replaced by what they actually chose.
 */
export function splitAtFirstChoice(turns: Turn[]): { before: Turn[]; after: Turn[] } {
  const at = turns.findIndex((t) => t.from === 'ai' && t.blocks.some((b) => b.kind === 'actions'))
  if (at === -1) return { before: turns, after: [] }
  const rest = turns.slice(at + 1)
  // Drop the scripted owner reply; the tap is the reply.
  const after = rest[0]?.from === 'user' ? rest.slice(1) : rest
  return { before: turns.slice(0, at + 1), after }
}

/**
 * What the thread says after a tap. Booking gets the booking; asking only for
 * the summary gets only the summary — the same scripted sentence, not a
 * confirmation of an appointment nobody asked for.
 */
export function continuationFor(action: string, after: Turn[]): Turn[] {
  if (action !== 'send-summary') return after
  return after.map((t) =>
    t.from === 'ai'
      ? {
          from: 'ai' as const,
          blocks: t.blocks.map((b): CompanionBlock => (b.kind === 'booking_confirm' ? { kind: 'text', md: b.prepared } : b)),
        }
      : t,
  )
}
