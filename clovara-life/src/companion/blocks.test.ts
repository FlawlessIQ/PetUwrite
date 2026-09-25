import { describe, expect, it } from 'vitest'
import { BLOCK_KINDS, inlineSegments, MAX_ACTIONS, normalise, plainInline } from './blocks'

describe('the schema', () => {
  it('has exactly the eight kinds in DESIGN.md §5b — adding one is a design decision', () => {
    expect([...BLOCK_KINDS].sort()).toEqual(
      ['actions', 'booking_confirm', 'escalate', 'fact', 'history_ref', 'product_ref', 'text', 'watch_signs'].sort(),
    )
  })

  it('has no kind shaped like a diagnosis', () => {
    for (const k of BLOCK_KINDS) {
      expect(k).not.toMatch(/diagnos|condition|likely|assess|verdict|prognos|result|finding|cause/i)
    }
  })
})

describe('normalise — what arrives is made safe before anything renders it', () => {
  it('turns an unknown kind into text, keeping whatever it said', () => {
    const [b] = normalise([{ kind: 'likely_condition', text: 'Probably arthritis' }])
    expect(b).toEqual({ kind: 'text', md: 'Probably arthritis' })
  })

  it('turns a known kind with the wrong shape into text rather than a broken component', () => {
    const [b] = normalise([{ kind: 'history_ref', note: 42 }])
    expect(b.kind).toBe('text')
  })

  it('turns something that is not an object at all into empty text, not a crash', () => {
    expect(normalise([null, 7, 'x'])).toEqual([
      { kind: 'text', md: '' },
      { kind: 'text', md: '' },
      { kind: 'text', md: '' },
    ])
  })

  it('strips headings and list markers: text is inline bold only', () => {
    expect(plainInline('# Diagnosis\n- one\n2. two\n> quote')).toBe('Diagnosis one two quote')
    const [b] = normalise([{ kind: 'text', md: '## Heading\n* item' }])
    expect(b).toEqual({ kind: 'text', md: 'Heading item' })
  })

  it('caps actions at three with no more than one primary', () => {
    const items = Array.from({ length: 5 }, (_, i) => ({ label: `L${i}`, action: `a${i}`, style: 'primary' }))
    const [b] = normalise([{ kind: 'actions', items }])
    if (b.kind !== 'actions') throw new Error('expected actions')
    expect(b.items).toHaveLength(MAX_ACTIONS)
    expect(b.items.filter((i) => i.style === 'primary')).toHaveLength(1)
  })

  it('drops an actions block with nothing tappable in it', () => {
    expect(normalise([{ kind: 'actions', items: [{ nope: true }] }])).toEqual([])
  })

  it('keeps one product per reply', () => {
    const out = normalise([
      { kind: 'product_ref', productId: 'a', why: 'x' },
      { kind: 'product_ref', productId: 'b', why: 'y' },
    ])
    expect(out.filter((b) => b.kind === 'product_ref')).toHaveLength(1)
  })

  it('never lets `now` stand alone: it always brings an escalate', () => {
    const out = normalise([{ kind: 'watch_signs', intro: 'i', signs: ['s'], urgency: 'now' }])
    expect(out.map((b) => b.kind)).toEqual(['watch_signs', 'escalate'])
  })

  it('does not add a second escalate when one is already there', () => {
    const out = normalise([
      { kind: 'watch_signs', intro: 'i', signs: [], urgency: 'now' },
      { kind: 'escalate', reason: 'r' },
    ])
    expect(out.filter((b) => b.kind === 'escalate')).toHaveLength(1)
  })

  it('refuses a fact with no source — it becomes plain text, never a sourceless fact card', () => {
    const [b] = normalise([{ kind: 'fact', claim: 'Hip dysplasia is common in the breed', source: '  ' }])
    expect(b).toEqual({ kind: 'text', md: 'Hip dysplasia is common in the breed' })
  })

  it('keeps a citation only when there is one', () => {
    const [a] = normalise([{ kind: 'fact', claim: 'c', source: 's' }])
    const [b] = normalise([{ kind: 'fact', claim: 'c', source: 's', citation: 'Dog Aging Project evidence' }])
    expect(a).toEqual({ kind: 'fact', claim: 'c', source: 's' })
    expect(b).toEqual({ kind: 'fact', claim: 'c', source: 's', citation: 'Dog Aging Project evidence' })
  })

  it('never invents a date for history', () => {
    const [b] = normalise([{ kind: 'history_ref', lead: 'From Max’s history', note: 'n' }])
    expect(b).toEqual({ kind: 'history_ref', lead: 'From Max’s history', note: 'n', date: '' })
  })
})

describe('inline markup', () => {
  it('knows bold and nothing else', () => {
    expect(inlineSegments('a **b** c')).toEqual([
      { text: 'a ', bold: false },
      { text: 'b', bold: true },
      { text: ' c', bold: false },
    ])
    expect(inlineSegments('<h1>x</h1>')).toEqual([{ text: '<h1>x</h1>', bold: false }])
  })
})
