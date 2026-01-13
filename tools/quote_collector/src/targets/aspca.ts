import { TargetAdapter, QuoteInput } from '../core/types';
import { detectBlockHeuristics, extractPremiumFromVisibleText, waitForManualUnblock } from './common';

export const aspca: TargetAdapter = {
  id: 'aspca',
  displayName: 'ASPCA',
  baseUrl: 'https://www.aspcapetinsurance.com',

  async openQuoteFlow(page: any, _input: QuoteInput) {
    await page.goto('https://www.aspcapetinsurance.com', { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(1_000);
  },

  async fillPetInfo(_page: any, _input: QuoteInput) {
    // Best-effort placeholder
  },

  async fillCoverageOptions(_page: any, _input: QuoteInput) {
    // Best-effort placeholder
  },

  async extractMonthlyPremium(page: any) {
    return extractPremiumFromVisibleText(page);
  },

  async extractPlanDetails(page: any) {
    return `url=${page.url()}`;
  },

  async isBlocked(page: any) {
    return detectBlockHeuristics(page);
  },

  async waitForUserToUnblock(_page: any) {
    await waitForManualUnblock();
  },
};
