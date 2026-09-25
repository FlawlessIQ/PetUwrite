import { useEffect, useState } from 'react'
import type { Projection } from '../data/types'

/**
 * The life arc: where this pet sits between the start of life and the far end
 * of their projected healthy years, with life stages marked along it.
 *
 * Two geometries. The SVG scales to its container, so a single wide viewBox
 * would shrink the labels to unreadable at phone width — the compact geometry
 * keeps the type legible by shortening the box rather than the text.
 */

function useCompact() {
  const [compact, setCompact] = useState(
    typeof window !== 'undefined' ? window.matchMedia('(max-width: 720px)').matches : false,
  )
  useEffect(() => {
    const mq = window.matchMedia('(max-width: 720px)')
    const on = (e: MediaQueryListEvent) => setCompact(e.matches)
    mq.addEventListener('change', on)
    setCompact(mq.matches)
    return () => mq.removeEventListener('change', on)
  }, [])
  return compact
}

interface Geo {
  W: number
  H: number
  P: number
  stroke: number
  label: number
  marker: number
  dot: number
  ring: number
}

const WIDE: Geo = { W: 720, H: 168, P: 44, stroke: 9, label: 12.5, marker: 13, dot: 13, ring: 7 }
const COMPACT: Geo = { W: 380, H: 128, P: 26, stroke: 7, label: 11.5, marker: 12, dot: 10, ring: 5.5 }

export function LifeArc({ projection }: { projection: Projection }) {
  const compact = useCompact()
  const g = compact ? COMPACT : WIDE

  const S = { x: g.P, y: g.H - (compact ? 30 : 34) }
  const Cp = { x: g.W / 2, y: (compact ? 12 : 34) - (compact ? 18 : 26) }
  const E = { x: g.W - g.P, y: g.H - (compact ? 30 : 34) }

  const pointAt = (t: number) => {
    const mt = 1 - t
    return {
      x: mt * mt * S.x + 2 * mt * t * Cp.x + t * t * E.x,
      y: mt * mt * S.y + 2 * mt * t * Cp.y + t * t * E.y,
    }
  }
  const ARC = `M${S.x},${S.y} Q${Cp.x},${Cp.y} ${E.x},${E.y}`

  const { stages, ageYears, healthyYearsRange, arcPosition } = projection
  const span = healthyYearsRange.high
  const marker = pointAt(arcPosition)

  const ticks = stages
    .map((s) => ({ id: s.id, t: s.from / span }))
    .filter((s) => s.t > 0.02 && s.t < 0.985)

  // Labels sit at the MIDPOINT of each stage so they read as spans rather than
  // points, and so short early stages don't collide with their neighbour.
  const candidates = stages
    .map((s) => {
      const from = Math.min(1, s.from / span)
      const to = Math.min(1, (s.to ?? span) / span)
      return { id: s.id, label: s.label, t: (from + to) / 2, width: to - from }
    })
    // A stage too narrow to hold its own label is dropped rather than squeezed.
    .filter((s) => s.width > (compact ? 0.06 : 0.045))

  // Collision pass. Estimate each label's rendered width and drop any that would
  // overlap the one before it — a dropped label is better than two on top of
  // each other, and the stage is still readable on the timeline below.
  const labels: typeof candidates = []
  let lastRight = -Infinity
  for (const c of candidates) {
    const w = c.label.length * g.label * 0.52
    const x = pointAt(c.t).x
    const left = Math.max(x - w / 2, g.P - 6)
    if (left < lastRight + 6) continue
    labels.push(c)
    lastRight = Math.max(x + w / 2, left + w)
  }

  return (
    <figure className="m-0">
      <svg
        viewBox={`0 0 ${g.W} ${g.H}`}
        className="w-full"
        role="img"
        aria-label={`Life arc. ${projection.breed.name} aged ${ageYears} years, currently in the ${projection.currentStage.label.toLowerCase()} stage, on track for ${healthyYearsRange.low} to ${healthyYearsRange.high} healthy years.`}
      >
        <defs>
          <linearGradient id="arc-grad" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stopColor="#D98A26" />
            <stop offset="48%" stopColor="#8FA83E" />
            <stop offset="100%" stopColor="#1E7A46" />
          </linearGradient>
          <filter id="arc-shadow" x="-50%" y="-50%" width="200%" height="200%">
            <feDropShadow dx="0" dy="2" stdDeviation="3" floodColor="#1B1E1B" floodOpacity="0.18" />
          </filter>
        </defs>

        <path d={ARC} fill="none" stroke="#EDEAE0" strokeWidth={g.stroke} strokeLinecap="round" />
        <path
          d={ARC}
          fill="none"
          stroke="url(#arc-grad)"
          strokeWidth={g.stroke}
          strokeLinecap="round"
          pathLength={1}
          strokeDasharray={`${Math.max(arcPosition, 0.012)} 1`}
        />

        {/* Boundary ticks — white where they cross the travelled arc, warm grey
            where they cross the untravelled track. */}
        {ticks.map((s) => {
          const p = pointAt(s.t)
          const h = compact ? 8 : 10
          return (
            <line
              key={s.id}
              x1={p.x}
              y1={p.y - h}
              x2={p.x}
              y2={p.y + h}
              stroke={s.t <= arcPosition ? '#FFFFFF' : '#CFC8B8'}
              strokeWidth={2.5}
              strokeLinecap="round"
            />
          )
        })}

        {labels.map((s) => {
          const p = pointAt(s.t)
          const anchor = p.x < g.P + 24 ? 'start' : p.x > g.W - g.P - 24 ? 'end' : 'middle'
          return (
            <text
              key={s.id}
              x={anchor === 'start' ? g.P - 6 : anchor === 'end' ? g.W - g.P + 6 : p.x}
              y={g.H - 6}
              textAnchor={anchor}
              className="fill-ink-2"
              style={{ fontSize: g.label, fontWeight: 500 }}
            >
              {s.label}
            </text>
          )
        })}

        <g filter="url(#arc-shadow)">
          <circle cx={marker.x} cy={marker.y} r={g.dot} fill="#FFFFFF" />
          <circle cx={marker.x} cy={marker.y} r={g.ring} fill="#1A5C38" />
        </g>
        <text
          x={Math.min(Math.max(marker.x, g.P + 14), g.W - g.P - 14)}
          y={marker.y - (compact ? 19 : 24)}
          textAnchor="middle"
          className="fill-ink"
          style={{ fontSize: g.marker, fontWeight: 600 }}
        >
          {ageYears < 1 ? `${Math.round(ageYears * 12)} months` : `${ageYears} yrs`}
        </text>
      </svg>
      <figcaption className="sr-only">
        Position along a life arc from the earliest stage to the far end of the projected
        healthy-years range.
      </figcaption>
    </figure>
  )
}
