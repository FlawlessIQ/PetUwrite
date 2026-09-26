import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import { BLOCK_KINDS, type CompanionBlock } from '../../companion/blocks'
import { scriptedTurns } from '../../companion/script'
import { DEMO_PETS } from '../../data/demoPets'
import { project } from '../../engine/project'
import { buildCompanion } from '../../engine/platform'
import { BLOCK_RENDERERS, RenderBlock } from './Blocks'
import { DISCLAIMER, ScriptedConversation } from './Conversation'

const html = (b: CompanionBlock) => renderToStaticMarkup(<RenderBlock block={b} ctx={{ petName: 'Max' }} />)

describe('the renderer', () => {
  it('renders an unknown block as plain text — never as nothing, never as markup', () => {
    const unknown = { kind: 'likely_condition', text: 'Sounds like arthritis' } as unknown as CompanionBlock
    const out = html(unknown)
    expect(out).toContain('Sounds like arthritis')
    expect(out).toMatch(/^<p>/)
  })

  it('has a component for exactly the eight kinds, and no other', () => {
    expect(Object.keys(BLOCK_RENDERERS).sort()).toEqual([...BLOCK_KINDS].sort())
  })

  it('has no diagnosis-shaped component', () => {
    for (const k of Object.keys(BLOCK_RENDERERS)) {
      expect(k).not.toMatch(/diagnos|condition|likely|assess|verdict|prognos|result|finding|cause/i)
    }
  })

  it('renders text as a paragraph with inline bold only — headings never reach the DOM', () => {
    const out = html({ kind: 'text', md: 'Keep **Max** lean' })
    expect(out).toBe('<p><span>Keep </span><strong class="font-semibold text-ink">Max</strong><span> lean</span></p>')
    expect(html({ kind: 'text', md: '<h1>x</h1>' })).not.toContain('<h1>')
  })

  it('escalates in amber, not red', () => {
    const out = html({ kind: 'escalate', reason: 'r' })
    expect(out).toContain('nudge')
    expect(out).not.toMatch(/#B3261E|#8C1D18|red/i)
  })

  it('renders nothing for a product that does not exist, rather than an empty card', () => {
    expect(html({ kind: 'product_ref', productId: 'no-such-thing', why: 'x' })).toBe('')
    // T4: the kit carries no catalogue; the renderer supplies the lookup.
    const withShop = renderToStaticMarkup(
      <RenderBlock
        block={{ kind: 'product_ref', productId: 'chews', why: 'Hip dysplasia is in its window' }}
        ctx={{ petName: 'Max', product: (id) => (id === 'chews' ? { name: 'Hip & Joint Chews', emoji: '🦴', memberPrice: 22 } : undefined) }}
      />,
    )
    expect(withShop).toContain('Hip &amp; Joint Chews')
    expect(withShop).toContain('$22 for members')
  })

  it('renders an action that is a route as a link, and any other action as a button', () => {
    const out = html({ kind: 'actions', items: [
      { label: 'Open Max’s summary', style: 'primary', action: '#/health/demo-max' },
      { label: 'Tell me more', style: 'ghost', action: 'more' },
    ] })
    expect(out).toMatch(/<a href="#\/health\/demo-max"[^>]*>Open Max’s summary<\/a>/)
    expect(out).toMatch(/<button[^>]*>Tell me more<\/button>/)
  })

  it('renders a fact with its source, and its citation when it has one', () => {
    const out = html({ kind: 'fact', claim: 'Hip dysplasia is common in Labradors.', source: 'from the breed research', citation: 'OFA evidence' })
    expect(out).toContain('Hip dysplasia is common in Labradors.')
    expect(out).toContain('from the breed research · OFA evidence')
  })

  it('renders a booking with who and when, and claims neither video nor in-person', () => {
    const out = html({ kind: 'booking_confirm', vet: 'Dr. Okafor', when: 'Thursday at 9am', prepared: 'Summary ready.' })
    expect(out).toContain('Dr. Okafor')
    expect(out).toContain('Thursday at 9am')
    expect(out).not.toMatch(/video|telehealth|in person/i)
  })

  it('omits a history date it was not given', () => {
    const out = html({ kind: 'history_ref', lead: 'From Max’s record', note: 'Hip dysplasia on file.', date: '' })
    expect(out).toContain('From Max’s record')
    expect(out).not.toContain('tabular-nums')
  })
})

describe('the chrome', () => {
  it('always carries the disclaimer, whatever the conversation holds — even nothing', () => {
    const out = renderToStaticMarkup(<ScriptedConversation turns={[]} petName="Max" since={2020} />)
    expect(out).toContain(DISCLAIMER.split(' — ')[0])
    expect(out).toContain('doesn’t diagnose')
    expect(out).toContain('never used in underwriting or claims')
    expect(out).toContain('Knows Max since')
  })
})

describe('the scripted thread, through the kit', () => {
  const max = DEMO_PETS.find((p) => p.id === 'demo-max')!
  const turns = scriptedTurns(buildCompanion(max, project(max)))

  it('arrives as blocks, with medical content only as history or watch signs', () => {
    const ai = turns.filter((t) => t.from === 'ai')
    expect(ai.length).toBeGreaterThan(0)
    const kinds = ai.flatMap((t) => (t.from === 'ai' ? t.blocks.map((b) => b.kind) : []))
    expect(kinds).toContain('history_ref')
    expect(kinds).toContain('watch_signs')
    expect(kinds).toContain('actions')
  })

  it('renders up to the first choice, with the memory moment and the chrome', () => {
    const out = renderToStaticMarkup(<ScriptedConversation turns={turns} petName="Max" since={2020} />)
    expect(out).toContain('From Max&#x27;s record')
    expect(out).toContain('history to your vet')
    // It waits for the tap: the summary has not been prepared yet.
    expect(out).not.toContain('one-page summary')
    // And it offers nothing the product cannot do (D-UI7).
    expect(out).not.toMatch(/telehealth|video slot|Dr\. Chen/i)
    expect(out).not.toMatch(/<h[1-6]|<ul class="list-disc/)
  })
})
