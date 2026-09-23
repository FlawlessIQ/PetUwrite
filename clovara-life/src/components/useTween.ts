import { useEffect, useRef, useState } from 'react'

/**
 * Eases a number to a new value over `ms`.
 *
 * SPEC §4.2: "Each answer visibly moves the projection — this is the incentive
 * mechanic, build it as such (animate the range change)." A number that jumps
 * is easy to miss; one that travels is the whole point of answering.
 *
 * Respects `prefers-reduced-motion` by snapping instead, and never animates the
 * first value — a page load should show the answer, not count up to it.
 */
export function useTween(target: number, ms = 650): number {
  const [value, setValue] = useState(target)
  const from = useRef(target)
  const frame = useRef(0)
  const first = useRef(true)

  useEffect(() => {
    if (first.current) {
      first.current = false
      from.current = target
      setValue(target)
      return
    }
    const reduced =
      typeof window !== 'undefined' &&
      window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
    if (reduced || from.current === target) {
      from.current = target
      setValue(target)
      return
    }

    const start = performance.now()
    const a = from.current
    const b = target
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / ms)
      // easeOutCubic — quick to move, gentle to land.
      const eased = 1 - Math.pow(1 - t, 3)
      setValue(a + (b - a) * eased)
      if (t < 1) frame.current = requestAnimationFrame(tick)
      else from.current = b
    }
    frame.current = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frame.current)
  }, [target, ms])

  return value
}
