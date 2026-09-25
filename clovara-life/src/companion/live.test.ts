import { describe, expect, it } from 'vitest'
import { RED_FLAG_HEADLINE } from '../data/redFlags'
import { DEMO_PETS } from '../data/demoPets'
import { buildGroundingSet, composeRecall } from '../engine/grounding'
import { project } from '../engine/project'
import { routeToVet } from '../engine/telehealth'
import { BLOCK_KINDS } from './blocks'
import { escalationBlocks, recallBlocks, SOURCE_LABEL, vetBlocks } from './live'

const NOW = new Date('2026-09-25T12:00:00Z')
const max = DEMO_PETS.find((p) => p.id === 'demo-max')!
const recallFor = (q: string) => recallBlocks(composeRecall(max, buildGroundingSet(max, project(max), q, NOW), q))

describe('the live companion, as blocks (D-UI8)', () => {
  it('puts every retrieved fact on screen as a fact block — with its source, always', () => {
    const blocks = recallFor('is he getting stiff after walks')
    const facts = blocks.filter((b) => b.kind === 'fact')
    expect(facts.length).toBeGreaterThan(0)
    for (const f of facts) {
      if (f.kind !== 'fact') continue
      expect(f.source.trim()).not.toBe('')
      expect(Object.values(SOURCE_LABEL)).toContain(f.source)
    }
  })

  it('names the research and its strength on every breed-table fact', () => {
    const facts = recallFor('is he getting stiff after walks').filter((b) => b.kind === 'fact')
    const breed = facts.filter((f) => f.kind === 'fact' && f.source === SOURCE_LABEL['breed-table'])
    for (const f of breed) if (f.kind === 'fact') expect(f.citation).toMatch(/evidence$/)
  })

  it('carries the vet route in the closing line’s weight, not its colour', () => {
    const r = composeRecall(max, buildGroundingSet(max, project(max), 'limping', NOW), 'limping')
    const last = recallBlocks(r).at(-1)!
    if (r.route === 'vet-soon') expect(last).toEqual({ kind: 'text', md: `**${r.closing}**` })
    else expect(last).toEqual({ kind: 'text', md: r.closing })
  })

  it('says plainly when it knows nothing — no opening, and no fact dressed up as one', () => {
    const r = composeRecall(max, buildGroundingSet(max, project(max), 'xylophone sonnet quartz', NOW), 'xylophone sonnet quartz')
    const blocks = recallBlocks(r)
    if (r.opening === null) expect(blocks.some((b) => b.kind === 'fact')).toBe(r.facts.length > 0)
    expect(blocks.at(-1)?.kind).toBe('text')
  })

  it('escalates first, in the safety classifier’s own words', () => {
    const [first, second] = escalationBlocks()
    expect(first).toEqual({ kind: 'escalate', reason: RED_FLAG_HEADLINE })
    expect(second?.kind).toBe('text')
  })

  it('answers "can I talk to a vet" with the honest route and one action: the real summary', () => {
    const blocks = vetBlocks(routeToVet('Max'), 'Max', 'demo-max')
    const actions = blocks.filter((b) => b.kind === 'actions')
    expect(actions).toHaveLength(1)
    // A route, so the kit renders it as a link rather than a button.
    if (actions[0].kind === 'actions') expect(actions[0].items).toEqual([{ label: "Open Max's summary", style: 'primary', action: '#/health/demo-max' }])
    expect(JSON.stringify(blocks)).not.toMatch(/Dr\. |booked|video slot/i)
  })

  it('uses only kinds the renderer has — every path', () => {
    const all = [...recallFor('stiff'), ...escalationBlocks(), ...vetBlocks(routeToVet('Max'), 'Max', 'demo-max')]
    for (const b of all) expect(BLOCK_KINDS).toContain(b.kind)
  })
})
