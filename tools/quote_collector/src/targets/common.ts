import { waitForEnter } from '../core/prompts';

export async function detectBlockHeuristics(page: any): Promise<boolean> {
  try {
    const bodyText = await page.locator('body').innerText({ timeout: 2_500 });
    const t = bodyText.toLowerCase();
    return (
      t.includes('captcha') ||
      t.includes('verify you are human') ||
      t.includes('recaptcha') ||
      t.includes('cloudflare') ||
      t.includes('challenge') ||
      t.includes('one-time passcode') ||
      t.includes('otp') ||
      t.includes('two-factor') ||
      t.includes('sign in') ||
      t.includes('log in')
    );
  } catch {
    return false;
  }
}

export async function waitForManualUnblock(): Promise<void> {
  await waitForEnter(
    'Please complete CAPTCHA/OTP/login and proceed to the premium result screen, then press ENTER to continue.',
  );
}

export async function extractPremiumFromVisibleText(page: any): Promise<{ premium: number | null; extractedText?: string }> {
  try {
    const text = await page.locator('body').innerText({ timeout: 5_000 });

    const patterns = [
      /\$\s*(\d+(?:\.\d{1,2})?)\s*\/?\s*month/gi,
      /monthly\s*[:\-]?\s*\$\s*(\d+(?:\.\d{1,2})?)/gi,
      /\$\s*(\d+(?:\.\d{1,2})?)\s*per\s*month/gi,
      /\$\s*(\d+(?:\.\d{1,2})?)\s*\/\s*mo/gi,
    ];

    const found: number[] = [];
    for (const p of patterns) {
      let m: RegExpExecArray | null;
      // eslint-disable-next-line no-cond-assign
      while ((m = p.exec(text)) !== null) {
        const v = Number(m[1]);
        if (!Number.isNaN(v)) found.push(v);
      }
    }

    if (!found.length) {
      return { premium: null, extractedText: undefined };
    }

    // Heuristic: pick the smallest value (often the “starting at” / basic plan).
    // Notes are captured separately via extractPlanDetails.
    const premium = Math.min(...found);
    return { premium, extractedText: `found=${found.join(',')}` };
  } catch (e: any) {
    return { premium: null, extractedText: `error=${String(e?.message ?? e)}` };
  }
}
