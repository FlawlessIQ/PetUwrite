import { TargetAdapter, QuoteInput } from '../core/types';
import { detectBlockHeuristics, extractPremiumFromVisibleText, waitForManualUnblock } from './common';

export const lemonade: TargetAdapter = {
  id: 'lemonade',
  displayName: 'Lemonade',
  baseUrl: 'https://www.lemonade.com',

  async openQuoteFlow(page: any, _input: QuoteInput) {
    await page.goto('https://www.lemonade.com/pet', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(1_000);
  },

  async fillPetInfo(page: any, input: QuoteInput) {
    // Best-effort: many sites require multi-step flows; this may no-op.
    // Do not attempt to bypass blocks; user can complete manually.
    try {
      await page.getByLabel(/zip/i).first().fill(input.state.zip);
    } catch {
      // ignore
    }
  },

  async fillCoverageOptions(_page: any, _input: QuoteInput) {
    // Lemonade coverage selection is highly dynamic; leave to manual when needed.
  },

  async extractMonthlyPremium(page: any) {
    return extractPremiumFromVisibleText(page);
  },

  async extractPlanDetails(page: any) {
    // Keep notes small; evidence screenshots are the source of truth.
    return `url=${page.url()}`;
  },

  async isBlocked(page: any) {
    return detectBlockHeuristics(page);
  },

  async waitForUserToUnblock(_page: any) {
    await waitForManualUnblock();
  },
};
