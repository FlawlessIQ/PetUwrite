import { CompetitorId, CoverageScenario, PetReference, StateScenario } from './core/types';

export const competitors: CompetitorId[] = [
  'lemonade',
  'trupanion',
  'healthyPaws',
  'embrace',
  'aspca',
];

export const referencePet: PetReference = {
  species: 'dog',
  ageYears: 3,
  breed: 'Mixed',
  weightLbs: 45,
  hasPreExistingConditions: false,
  notes: 'Healthy, no pre-existing; mixed/medium-risk.',
};

export const states: StateScenario[] = [
  { id: 'PA', state: 'PA', zip: '19104', label: 'average_baseline' },
  { id: 'CA', state: 'CA', zip: '94107', label: 'ca' },
  { id: 'NY', state: 'NY', zip: '10001', label: 'ny' },
];

export const scenarios: CoverageScenario[] = [
  { id: '80_250_10k', reimbursementPercent: 80, annualDeductible: 250, annualLimit: 10_000 },
  { id: '70_250_10k', reimbursementPercent: 70, annualDeductible: 250, annualLimit: 10_000 },
  { id: '90_250_10k', reimbursementPercent: 90, annualDeductible: 250, annualLimit: 10_000 },
  { id: '80_500_10k', reimbursementPercent: 80, annualDeductible: 500, annualLimit: 10_000 },
  { id: '80_100_10k', reimbursementPercent: 80, annualDeductible: 100, annualLimit: 10_000 },
  { id: '80_250_20k', reimbursementPercent: 80, annualDeductible: 250, annualLimit: 20_000 },
  { id: '80_250_unlimited', reimbursementPercent: 80, annualDeductible: 250, annualLimit: 'Unlimited' },
];
