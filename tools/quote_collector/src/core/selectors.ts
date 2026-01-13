// Best-effort helpers for unknown competitor form structures.
// The target adapters should prefer role-based locators; these are fallbacks.

export async function fillFirstMatchingByLabel(page: any, labelCandidates: string[], value: string) {
  for (const label of labelCandidates) {
    try {
      const locator = page.getByLabel(label, { exact: false });
      if (await locator.count()) {
        await locator.first().fill(value);
        return true;
      }
    } catch {
      // continue
    }
  }
  return false;
}

export async function clickFirstMatchingByText(page: any, textCandidates: string[]) {
  for (const t of textCandidates) {
    try {
      const loc = page.getByText(t, { exact: false });
      if (await loc.count()) {
        await loc.first().click({ timeout: 5_000 });
        return true;
      }
    } catch {
      // continue
    }
  }
  return false;
}

export async function safeWait(ms: number) {
  await new Promise((r) => setTimeout(r, ms));
}
