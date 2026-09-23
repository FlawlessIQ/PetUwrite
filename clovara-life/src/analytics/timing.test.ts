import { beforeEach, describe, expect, it } from 'vitest'
import { markOnboardingStart, resetTiming, takeTimeToReveal } from './timing'

beforeEach(resetTiming)

describe('the onboarding stopwatch', () => {
  it('measures from the first step to the reveal', () => {
    markOnboardingStart(1_000)
    expect(takeTimeToReveal(46_000)).toBe(45_000)
  })

  it('reports nothing when there was no onboarding', () => {
    // A returning user opening the app to a pet they already own. Reporting
    // zero here would be a lie that flatters us.
    expect(takeTimeToReveal(5_000)).toBeNull()
  })

  it('answers once and then goes quiet', () => {
    markOnboardingStart(0)
    expect(takeTimeToReveal(30_000)).toBe(30_000)
    expect(takeTimeToReveal(31_000)).toBeNull()
  })

  it('keeps the first start, so a re-render does not restart the clock', () => {
    markOnboardingStart(1_000)
    markOnboardingStart(20_000)
    expect(takeTimeToReveal(21_000)).toBe(20_000)
  })

  it('refuses a negative measurement rather than reporting it', () => {
    // A clock that went backwards (a device time change mid-onboarding) should
    // drop the sample, not contribute a negative one to the median.
    markOnboardingStart(60_000)
    expect(takeTimeToReveal(10_000)).toBeNull()
  })
})
