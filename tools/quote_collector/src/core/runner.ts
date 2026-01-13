import fs from 'fs';
import path from 'path';
import { chromium } from 'playwright';
import { captureScreenshot, evidenceFolderFor } from './evidence';
import { Logger } from './logger';
import { parseMoneyToNumber, promptForText, waitForEnter } from './prompts';
import { EvidenceStep, QuoteAttemptResult, QuoteInput, RunMetadata, RunOutput, TargetAdapter } from './types';

function nowIso() {
  return new Date().toISOString();
}

function sanitizeSegment(s: string) {
  return s.replace(/[^a-zA-Z0-9._-]/g, '_');
}

async function tryGitCommitHash(): Promise<string | undefined> {
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const cp = require('child_process');
    const out = cp.execSync('git rev-parse HEAD', { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
    return out || undefined;
  } catch {
    return undefined;
  }
}

function toCsvEscape(value: string) {
  const needs = value.includes(',') || value.includes('"') || value.includes('\n') || value.includes('\r');
  if (!needs) return value;
  return `"${value.replace(/"/g, '""')}"`;
}

function writeQuotesCsv(runFolder: string, runTimestamp: string, results: QuoteAttemptResult[]) {
  const csvPath = path.join(runFolder, 'quotes.csv');

  const headers = [
    'Competitor',
    'State',
    'Zip',
    'Reimbursement %',
    'Annual Deductible',
    'Annual Limit (number or “Unlimited”)',
    'Add-ons Included',
    'Monthly Premium ($)',
    'Notes / URL',
    'Run Timestamp',
    'Evidence Folder',
  ];

  const lines: string[] = [];
  lines.push(headers.map(toCsvEscape).join(','));

  for (const r of results) {
    const premium = r.monthlyPremium == null ? '' : r.monthlyPremium.toFixed(2);
    const notesUrl = [r.notes, r.url].filter(Boolean).join(' | ');

    lines.push(
      [
        r.input.competitor,
        r.input.state.state,
        r.input.state.zip,
        String(r.input.scenario.reimbursementPercent),
        String(r.input.scenario.annualDeductible),
        String(r.input.scenario.annualLimit),
        r.input.addOnsIncluded || 'None',
        premium,
        notesUrl,
        runTimestamp,
        r.evidenceFolder,
      ]
        .map((v) => toCsvEscape(String(v ?? '')))
        .join(','),
    );
  }

  fs.writeFileSync(csvPath, lines.join('\n'));
}

function writePremiumsCsv(runFolder: string, runTimestamp: string, results: QuoteAttemptResult[]) {
  const csvPath = path.join(runFolder, 'premiums.csv');

  const headers = [
    'Competitor',
    'State',
    'Zip',
    'Scenario ID',
    'Reimbursement %',
    'Annual Deductible',
    'Annual Limit (number or “Unlimited”)',
    'Monthly Premium ($)',
    'Status',
    'Run Timestamp',
    'Evidence Folder',
    'URL',
  ];

  const lines: string[] = [];
  lines.push(headers.map(toCsvEscape).join(','));

  for (const r of results) {
    const premium = r.monthlyPremium == null ? '' : r.monthlyPremium.toFixed(2);
    lines.push(
      [
        r.input.competitor,
        r.input.state.state,
        r.input.state.zip,
        r.input.scenario.id,
        String(r.input.scenario.reimbursementPercent),
        String(r.input.scenario.annualDeductible),
        String(r.input.scenario.annualLimit),
        premium,
        r.status,
        runTimestamp,
        r.evidenceFolder,
        r.url ?? '',
      ]
        .map((v) => toCsvEscape(String(v ?? '')))
        .join(','),
    );
  }

  fs.writeFileSync(csvPath, lines.join('\n'));
}

export interface RunnerOptions {
  headless: boolean;
  slowMo: number;
  timeoutMs: number;
  nonInteractive?: boolean;
  askPremium?: boolean;
  runFolder?: string;
}

export async function runCollector(
  adapters: TargetAdapter[],
  inputs: QuoteInput[],
  options: RunnerOptions,
  argsForAudit: Record<string, unknown>,
) {
  const runTimestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const runFolder =
    options.runFolder ?? path.join(process.cwd(), 'output', 'runs', runTimestamp);

  fs.mkdirSync(runFolder, { recursive: true });
  const logger = new Logger(runFolder);

  const meta: RunMetadata = {
    runTimestamp,
    gitCommitHash: await tryGitCommitHash(),
    args: argsForAudit,
  };

  logger.info(`Run folder: ${runFolder}`);

  const browser = await chromium.launch({
    headless: options.headless,
    slowMo: options.slowMo,
  });

  const context = await browser.newContext({
    viewport: { width: 1280, height: 800 },
  });

  const page = await context.newPage();
  page.setDefaultTimeout(options.timeoutMs);
  page.setDefaultNavigationTimeout(options.timeoutMs);

  const results: QuoteAttemptResult[] = [];

  for (const input of inputs) {
    const adapter = adapters.find((a) => a.id === input.competitor);
    if (!adapter) {
      logger.warn(`No adapter for competitor: ${input.competitor}`);
      continue;
    }

    const startedAt = nowIso();
    const evidenceFolder = evidenceFolderFor(
      runFolder,
      sanitizeSegment(input.competitor),
      sanitizeSegment(input.state.state),
      sanitizeSegment(input.scenario.id),
    );

    let stepIndex = 1;
    const evidence: EvidenceStep[] = [];

    const result: QuoteAttemptResult = {
      input,
      status: 'failed',
      monthlyPremium: null,
      evidenceFolder,
      evidence,
      startedAt,
      finishedAt: startedAt,
    };

    try {
      logger.info(`\n=== ${input.competitor} ${input.state.state}/${input.state.zip} ${input.scenario.id} ===`);

      await adapter.openQuoteFlow(page, input);
      result.url = page.url();
      evidence.push(await captureScreenshot(page, evidenceFolder, 'landed', stepIndex++));

      if (await adapter.isBlocked(page)) {
        evidence.push(await captureScreenshot(page, evidenceFolder, 'blocked', stepIndex++));
        logger.warn('Blocked detected (CAPTCHA/OTP/login). Waiting for manual unblock.');
        if (options.nonInteractive) {
          result.status = 'manual_required';
          result.notes = 'Blocked by CAPTCHA/OTP/login; nonInteractive mode enabled (no prompt).';
          logger.warn('nonInteractive: skipping prompt; marking manual_required.');
          continue;
        }
        await adapter.waitForUserToUnblock(page);
      }

      await adapter.fillPetInfo(page, input);
      evidence.push(await captureScreenshot(page, evidenceFolder, 'after_pet_info', stepIndex++));

      if (await adapter.isBlocked(page)) {
        evidence.push(await captureScreenshot(page, evidenceFolder, 'blocked_after_pet', stepIndex++));
        logger.warn('Blocked detected after pet info. Waiting for manual unblock.');
        if (options.nonInteractive) {
          result.status = 'manual_required';
          result.notes = 'Blocked after pet info; nonInteractive mode enabled (no prompt).';
          logger.warn('nonInteractive: skipping prompt; marking manual_required.');
          continue;
        }
        await adapter.waitForUserToUnblock(page);
      }

      await adapter.fillCoverageOptions(page, input);
      evidence.push(await captureScreenshot(page, evidenceFolder, 'after_coverage', stepIndex++));

      if (await adapter.isBlocked(page)) {
        evidence.push(await captureScreenshot(page, evidenceFolder, 'blocked_after_coverage', stepIndex++));
        logger.warn('Blocked detected after coverage. Waiting for manual unblock.');
        if (options.nonInteractive) {
          result.status = 'manual_required';
          result.notes = 'Blocked after coverage; nonInteractive mode enabled (no prompt).';
          logger.warn('nonInteractive: skipping prompt; marking manual_required.');
          continue;
        }
        await adapter.waitForUserToUnblock(page);
      }

      // Attempt extraction
      let extraction = await adapter.extractMonthlyPremium(page);
      if (extraction.premium == null) {
        // Manual fallback: let user drive to premium result screen.
        evidence.push(await captureScreenshot(page, evidenceFolder, 'premium_not_found', stepIndex++));
        result.status = 'manual_required';
        result.notes =
          'Automation could not extract premium. Please navigate to premium result screen and press ENTER.';

        if (options.nonInteractive) {
          result.notes =
            'Automation could not extract premium; nonInteractive mode enabled (no prompt).';
          logger.warn('nonInteractive: skipping prompt; leaving premium null.');
        } else {
          await waitForEnter(
            'Please complete CAPTCHA/OTP (if any) and proceed to the premium result screen, then press ENTER to continue.',
          );
          extraction = await adapter.extractMonthlyPremium(page);
        }
      }

      evidence.push(await captureScreenshot(page, evidenceFolder, 'premium_result', stepIndex++));

      result.monthlyPremium = extraction.premium;
      result.extractedText = extraction.extractedText;

      // Premium-first fallback: ask the operator to type/paste the premium.
      if (result.monthlyPremium == null && !options.nonInteractive && options.askPremium !== false) {
        result.status = 'manual_required';
        const typed = await promptForText(
          `Could not extract premium automatically.\nURL: ${page.url()}\n` +
            'Enter monthly premium (e.g. 42.13) or leave blank to skip:',
        );
        const manualPremium = parseMoneyToNumber(typed);
        if (manualPremium != null) {
          result.monthlyPremium = manualPremium;
          result.status = 'success';
          result.notes = [result.notes, 'Premium entered manually.'].filter(Boolean).join(' | ');
          evidence.push(await captureScreenshot(page, evidenceFolder, 'manual_premium_entered', stepIndex++));
        }
      }

      if (extraction.premium != null) {
        result.status = 'success';
      } else if (result.status !== 'manual_required') {
        result.status = 'failed';
      }

      // Avoid dumping full page text into notes; keep it short.
      const details = await adapter.extractPlanDetails(page);
      if (details) {
        const clipped = details.length > 300 ? details.slice(0, 300) + '…' : details;
        result.notes = [result.notes, clipped].filter(Boolean).join(' | ');
      }

      logger.info(
        `Result: status=${result.status} premium=${result.monthlyPremium ?? 'null'} url=${page.url()}`,
      );
    } catch (err: any) {
      result.status = result.status === 'manual_required' ? 'manual_required' : 'failed';
      result.error = String(err?.message ?? err);
      logger.error(`Error: ${result.error}`);
      try {
        evidence.push(await captureScreenshot(page, evidenceFolder, 'error', stepIndex++));
      } catch {
        // ignore
      }
    } finally {
      result.finishedAt = nowIso();
      results.push(result);

      // polite delay between attempts
      await page.waitForTimeout(1_500);
    }
  }

  await browser.close();

  const runOut: RunOutput = { meta, results };
  fs.writeFileSync(path.join(runFolder, 'run.json'), JSON.stringify(runOut, null, 2));
  writeQuotesCsv(runFolder, meta.runTimestamp, results);
  writePremiumsCsv(runFolder, meta.runTimestamp, results);

  logger.info(`\nWrote run.json + quotes.csv + premiums.csv to: ${runFolder}`);
  return runOut;
}
