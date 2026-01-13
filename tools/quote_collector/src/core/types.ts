export type CompetitorId = 'lemonade' | 'trupanion' | 'healthyPaws' | 'embrace' | 'aspca';

export type AnnualLimit = number | 'Unlimited';

export interface PetReference {
  species: 'dog' | 'cat';
  ageYears: number;
  breed: string;
  weightLbs: number;
  hasPreExistingConditions: boolean;
  notes?: string;
}

export interface StateScenario {
  id: 'PA' | 'CA' | 'NY' | string;
  state: string;
  zip: string;
  label: string;
}

export interface CoverageScenario {
  id: string;
  reimbursementPercent: number;
  annualDeductible: number;
  annualLimit: AnnualLimit;
}

export interface QuoteInput {
  competitor: CompetitorId;
  state: StateScenario;
  scenario: CoverageScenario;
  pet: PetReference;
  addOnsIncluded: string; // default "None" (competitors may bundle)
}

export type QuoteStatus = 'success' | 'manual_required' | 'failed';

export interface EvidenceStep {
  step: string;
  path: string;
  timestamp: string;
}

export interface QuoteAttemptResult {
  input: QuoteInput;
  url?: string;
  status: QuoteStatus;
  monthlyPremium?: number | null;
  extractedText?: string;
  notes?: string;
  error?: string;
  evidenceFolder: string;
  evidence: EvidenceStep[];
  startedAt: string;
  finishedAt: string;
}

export interface RunMetadata {
  runTimestamp: string;
  gitCommitHash?: string;
  args: Record<string, unknown>;
}

export interface RunOutput {
  meta: RunMetadata;
  results: QuoteAttemptResult[];
}

export interface TargetAdapter {
  id: CompetitorId;
  displayName: string;
  baseUrl: string;

  openQuoteFlow(page: any, input: QuoteInput): Promise<void>;
  fillPetInfo(page: any, input: QuoteInput): Promise<void>;
  fillCoverageOptions(page: any, input: QuoteInput): Promise<void>;

  extractMonthlyPremium(page: any): Promise<{ premium: number | null; extractedText?: string }>; // best effort
  extractPlanDetails(page: any): Promise<string | undefined>; // optional text blob

  isBlocked(page: any): Promise<boolean>;
  waitForUserToUnblock(page: any): Promise<void>;
}
