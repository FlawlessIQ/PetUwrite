/**
 * The live companion's replies, as conversation-kit blocks (DESIGN.md §5b).
 *
 * The grounded companion (C2), the safety escalation (C1) and the ask-for-a-vet
 * route (C4) used to render their own markup. Each is restated here as blocks,
 * so the companion renders no free text on any path — the architecture rule
 * §5b is built on — and invents no words doing it: every string comes from the
 * engine that already produced it.
 */
import { RED_FLAG_BODY, RED_FLAG_HEADLINE } from '../data/redFlags'
import type { Recall } from '../engine/grounding'
import type { VetRouting } from '../engine/telehealth'
import { normalise, type CompanionBlock } from './blocks'

/** Where each kind of fact came from, in the owner's words. */
export const SOURCE_LABEL: Record<string, string> = {
  'pet-record': 'from what you told us',
  'breed-table': 'from the breed research',
  projection: 'from the plan',
  vaccination: 'from your vaccination notes',
  'care-note': 'from your notes',
}

/** C2: what is on the record, each fact with its source; then the route. */
export function recallBlocks(r: Recall): CompanionBlock[] {
  const out: CompanionBlock[] = []
  if (r.opening) out.push({ kind: 'text', md: r.opening })
  for (const f of r.facts) {
    out.push({
      kind: 'fact',
      claim: f.claim,
      source: SOURCE_LABEL[f.source.kind] ?? f.source.kind,
      ...(f.source.kind === 'breed-table' ? { citation: `${f.source.citation} evidence` } : {}),
    })
  }
  // The route used to be a colour change alone; bold carries it in words' weight.
  out.push({ kind: 'text', md: r.route === 'vet-soon' ? `**${r.closing}**` : r.closing })
  return normalise(out)
}

/** C1: the escalation, then why — the safety classifier's own words. */
export function escalationBlocks(): CompanionBlock[] {
  return normalise([
    { kind: 'escalate', reason: RED_FLAG_HEADLINE },
    { kind: 'text', md: RED_FLAG_BODY },
  ])
}

/** The route to a pet's one-page summary — an action the kit renders as a link. */
export const summaryRoute = (petId: string) => `#/health/${encodeURIComponent(petId)}`

/** C4: the honest answer to "can I talk to a vet", and the one thing to do. */
export function vetBlocks(v: VetRouting, petName: string, petId: string): CompanionBlock[] {
  return normalise([
    { kind: 'text', md: `**${v.headline}**` },
    { kind: 'text', md: v.body },
    ...v.steps.map((step): CompanionBlock => ({ kind: 'text', md: step })),
    { kind: 'actions', items: [{ label: `Open ${petName}'s summary`, style: 'primary', action: summaryRoute(petId) }] },
  ])
}
