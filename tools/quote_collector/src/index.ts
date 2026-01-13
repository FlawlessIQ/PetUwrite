import path from 'path';

import { competitors as defaultCompetitors, referencePet, scenarios as defaultScenarios, states as defaultStates } from './config';
import { runCollector } from './core/runner';
import { QuoteInput, CompetitorId, CoverageScenario, StateScenario, TargetAdapter } from './core/types';

import { lemonade } from './targets/lemonade.ts';
import { trupanion } from './targets/trupanion.ts';
import { healthyPaws } from './targets/healthyPaws.ts';
import { embrace } from './targets/embrace.ts';
import { aspca } from './targets/aspca.ts';

function parseArgs(argv: string[]) {
  const out: Record<string, string> = {};
  for (const raw of argv) {
    if (!raw.startsWith('--')) continue;
    const [k, ...rest] = raw.slice(2).split('=');
    out[k] = rest.join('=') || 'true';
  }
  return out;
}

function splitCsv(value?: string): string[] {
  if (!value) return [];
  return value
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
}

function filterById<T extends { id: string }>(items: T[], allowedIds: string[]): T[] {
  if (!allowedIds.length) return items;
  const set = new Set(allowedIds);
  return items.filter((i) => set.has(i.id));
}

function filterCompetitors(items: CompetitorId[], allowedIds: string[]): CompetitorId[] {
  if (!allowedIds.length) return items;
  const set = new Set(allowedIds);
  return items.filter((i) => set.has(i));
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  const headless = args.headless === 'true' ? true : args.headless === 'false' ? false : false;
  const slowMo = Number(args.slowMo ?? '100');
  const timeoutMs = Number(args.timeoutMs ?? '60000');
  const nonInteractive = args.nonInteractive === 'true';
  const askPremium = args.askPremium === 'false' ? false : true;

  const competitorFilter = splitCsv(args.competitors);
  const stateFilter = splitCsv(args.states);
  const scenarioFilter = splitCsv(args.scenarios);

  const competitorIds = filterCompetitors(defaultCompetitors, competitorFilter);
  const states: StateScenario[] = filterById(defaultStates, stateFilter);
  const scenarios: CoverageScenario[] = filterById(defaultScenarios, scenarioFilter);

  const adapters: TargetAdapter[] = [lemonade, trupanion, healthyPaws, embrace, aspca];

  const inputs: QuoteInput[] = [];
  for (const competitor of competitorIds) {
    for (const state of states) {
      for (const scenario of scenarios) {
        inputs.push({
          competitor,
          state,
          scenario,
          pet: referencePet,
          addOnsIncluded: 'None',
        });
      }
    }
  }

  await runCollector(adapters, inputs, { headless, slowMo, timeoutMs, nonInteractive, askPremium }, args);
}

main().catch((e) => {
  // eslint-disable-next-line no-console
  console.error(e);
  process.exitCode = 1;
});
