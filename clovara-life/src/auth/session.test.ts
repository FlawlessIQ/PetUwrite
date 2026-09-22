import { describe, expect, it } from 'vitest'
import { authErrorMessage, displayNameFor, errorCode, looksLikeEmail } from './session'

describe('authErrorMessage', () => {
  it('keeps the wrong-password / no-such-account ambiguity Firebase deliberately creates', () => {
    // Firebase collapses these into one code so an attacker cannot enumerate
    // accounts. Our copy must not helpfully un-collapse it.
    const codes = [
      'auth/invalid-credential',
      'auth/invalid-login-credentials',
      'auth/wrong-password',
      'auth/user-not-found',
    ]
    const messages = new Set(codes.map(authErrorMessage))
    expect(messages.size).toBe(1)
    expect([...messages][0]).not.toMatch(/no account|not registered|wrong password/i)
  })

  it('never leaks a raw code or returns an empty string', () => {
    const inputs = [
      'auth/invalid-email',
      'auth/weak-password',
      'auth/too-many-requests',
      'auth/network-request-failed',
      'auth/some-code-that-does-not-exist-yet',
      '',
      undefined,
      null,
      42,
      { code: 'nope' },
    ]
    for (const i of inputs) {
      const msg = authErrorMessage(i)
      expect(msg.length, String(i)).toBeGreaterThan(10)
      expect(msg, String(i)).not.toMatch(/auth\//)
    }
  })

  it('gives distinct, actionable copy for the errors a real person hits', () => {
    expect(authErrorMessage('auth/email-already-in-use')).toMatch(/signing in/i)
    expect(authErrorMessage('auth/weak-password')).toMatch(/six/i)
    expect(authErrorMessage('auth/popup-blocked')).toMatch(/popup/i)
    expect(authErrorMessage('auth/network-request-failed')).toMatch(/connection/i)
  })
})

describe('errorCode', () => {
  it('reads a code off whatever the SDK threw, without trusting its shape', () => {
    expect(errorCode({ code: 'auth/invalid-email' })).toBe('auth/invalid-email')
    expect(errorCode(new Error('boom'))).toBe('')
    expect(errorCode({ code: 123 })).toBe('')
    expect(errorCode(null)).toBe('')
    expect(errorCode(undefined)).toBe('')
    expect(errorCode('auth/invalid-email')).toBe('')
  })
})

describe('looksLikeEmail', () => {
  it('accepts addresses people actually have', () => {
    for (const e of [
      'a@b.co',
      'conor@flawlessiq.com',
      'first.last+tag@sub.domain.org',
      "o'brien@example.ie",
      '  spaced@example.com  ',
    ]) {
      expect(looksLikeEmail(e), e).toBe(true)
    }
  })

  it('catches the typos worth catching before a network round trip', () => {
    for (const e of ['', 'nope', 'no@domain', 'no.domain.com', 'two @spaces.com', '@example.com']) {
      expect(looksLikeEmail(e), JSON.stringify(e)).toBe(false)
    }
  })
})

describe('displayNameFor', () => {
  it('prefers a display name, falls back to the email local part', () => {
    expect(displayNameFor({ displayName: 'Conor', email: 'c@x.com' })).toBe('Conor')
    expect(displayNameFor({ displayName: null, email: 'conor@x.com' })).toBe('conor')
    expect(displayNameFor({ displayName: '   ', email: 'conor@x.com' })).toBe('conor')
  })

  it('never renders blank, whatever the provider gave us', () => {
    expect(displayNameFor({}).length).toBeGreaterThan(0)
    expect(displayNameFor({ displayName: null, email: null }).length).toBeGreaterThan(0)
    expect(displayNameFor({ displayName: '', email: '' }).length).toBeGreaterThan(0)
  })
})
