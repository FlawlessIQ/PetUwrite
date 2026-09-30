import { describe, expect, it } from 'vitest'
import { componentOf, errorProps, errorSummary, makeReportGate, routeShape, scrubMessage } from './errors'
import { sanitizeProps } from './events'

describe('scrubMessage', () => {
  it('removes emails, links, routes, ids and long numbers', () => {
    expect(scrubMessage('Failed for jo.bloggs@example.com at https://x.test/a?b=c')).toBe(
      'Failed for [email] at [url]',
    )
    expect(scrubMessage('No pet at #/pet/abc123/life')).toBe('No pet at [route]')
    expect(scrubMessage('id 3f2a9c1e-1111-4a2b-8c3d-123456789abc gone')).toBe('id [id] gone')
    expect(scrubMessage('chip 985112004455667 unknown')).toBe('chip [number] unknown')
  })

  it('takes an Error, a string or anything else, and caps the length', () => {
    expect(scrubMessage(new TypeError('x is undefined'))).toBe('x is undefined')
    expect(scrubMessage(undefined)).toBe('')
    expect(scrubMessage('a'.repeat(300))).toHaveLength(120)
  })
})

describe('componentOf', () => {
  it('names the nearest component in a React stack', () => {
    const stack = '\n    at PlanReveal (http://x/assets/index.js:1:2)\n    at div\n    at App (http://x/a.js)'
    expect(componentOf(stack)).toBe('PlanReveal')
  })

  it('skips host elements and says nothing when unsure', () => {
    expect(componentOf('\n    at div\n    at Health (x)')).toBe('Health')
    expect(componentOf('')).toBeNull()
    expect(componentOf(undefined)).toBeNull()
  })
})

describe('routeShape', () => {
  it('keeps where, never which pet or card', () => {
    expect(routeShape('#/pet/3f2a9c1e-1111/life')).toBe('pet/life')
    expect(routeShape('#/pet/demo-max')).toBe('pet')
    expect(routeShape('#/card/QnJ1bm8gaXMgMw')).toBe('card')
    expect(routeShape('#/admin/metrics')).toBe('admin')
    expect(routeShape('')).toBe('home')
  })
})

describe('errorProps and the gate', () => {
  it('survives the event sanitiser unchanged', () => {
    const p = errorProps('render', new Error('boom'), { componentStack: '\n at Shop (x)', hash: '#/pet/a/shop' })
    expect(p).toEqual({ kind: 'render', message: 'boom', component: 'Shop', route: 'pet/shop' })
    expect(sanitizeProps(p)).toEqual(p)
  })

  it('reports each error once and a few per session at most', () => {
    const gate = makeReportGate(2)
    const a = errorProps('window', 'a')
    expect(gate(a)).toBe(true)
    expect(gate(a)).toBe(false)
    expect(gate(errorProps('window', 'b'))).toBe(true)
    expect(gate(errorProps('window', 'c'))).toBe(false)
  })
})

describe('errorSummary', () => {
  it('groups by message and component, newest first', () => {
    const ev = (message: string, visitorId: string, at: string, build = 'b1') => ({
      name: 'client_error' as const,
      props: { kind: 'render', message, component: 'Shop', route: 'pet/shop' },
      at,
      visitorId,
      uid: null,
      sessionId: 's',
      build,
    })
    const out = errorSummary([
      ev('boom', 'a', '2026-09-30T10:00:00Z'),
      ev('boom', 'b', '2026-09-30T11:00:00Z', 'b2'),
      ev('boom', 'b', '2026-09-30T09:00:00Z'),
      ev('older', 'c', '2026-09-29T09:00:00Z'),
    ])
    expect(out.map((g) => [g.message, g.count, g.visitors, g.lastBuild])).toEqual([
      ['boom', 3, 2, 'b2'],
      ['older', 1, 1, 'b1'],
    ])
  })
})
