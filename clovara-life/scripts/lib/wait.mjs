/**
 * Waits for the thing itself rather than a fixed number of milliseconds
 * (BACKLOG UB9). A fixed wait is either too long (slow suite) or too short on
 * a busy machine (a flaky check); these return the moment the condition holds
 * and never throw — the `ok()` after them reports what is actually there.
 */
const TIMEOUT = 8000

/** Until `scope`'s visible text matches `re`. */
export async function waitForText(page, re, { scope = 'body', timeout = TIMEOUT } = {}) {
  await page
    .waitForFunction(
      ([sel, src, flags]) => new RegExp(src, flags).test(document.querySelector(sel)?.innerText ?? ''),
      [scope, re.source, re.flags],
      { timeout },
    )
    .catch(() => {})
}

/** Until `scope`'s visible text is no longer `before`. */
export async function waitForChange(page, before, { scope = 'body', timeout = TIMEOUT } = {}) {
  await page
    .waitForFunction(
      ([sel, b]) => (document.querySelector(sel)?.innerText ?? '') !== b,
      [scope, before],
      { timeout },
    )
    .catch(() => {})
}

/** Until a locator is attached to the page. */
export async function waitForLocator(locator, { timeout = TIMEOUT } = {}) {
  await locator.waitFor({ state: 'attached', timeout }).catch(() => {})
}

/** Until a locator's element is enabled (or `enabled: false`, disabled). */
export async function waitForEnabled(locator, { enabled = true, timeout = TIMEOUT } = {}) {
  const until = Date.now() + timeout
  while (Date.now() < until) {
    try {
      if ((await locator.isEnabled({ timeout: 250 })) === enabled) return
    } catch {
      /* not there yet */
    }
    await new Promise((r) => setTimeout(r, 50))
  }
}
