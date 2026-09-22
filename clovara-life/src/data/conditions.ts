import type { KnownCondition } from './types'

/**
 * Conditions an owner can declare during onboarding.
 *
 * `weight` nudges the low end of the projected range down. The values are
 * deliberately modest and the engine caps their total effect — a pet with four
 * declared conditions is not four times worse off than one with a single
 * condition, and the honest response to a longer list is a wider range rather
 * than a dramatically lower one.
 *
 * `managing` is the line that replaces "watch for this" once a condition has
 * actually been diagnosed.
 */
export const KNOWN_CONDITIONS: KnownCondition[] = [
  {
    id: 'hip-dysplasia',
    name: 'Hip dysplasia or hip laxity',
    species: ['dog', 'cat'],
    weight: 0.5,
    managing: 'Keep body condition at the lean end, keep exercise regular rather than occasional, and revisit pain relief with your vet as things change.',
  },
  {
    id: 'arthritis',
    name: 'Arthritis or joint pain',
    species: ['dog', 'cat'],
    weight: 0.5,
    managing: 'Pain control, weight control, and adapting the home — traction on floors, ramps or steps, a softer bed.',
  },
  {
    id: 'periodontal',
    name: 'Dental or gum disease',
    species: ['dog', 'cat'],
    weight: 0.4,
    managing: 'Get the mouth back to a clean baseline professionally, then hold it there with daily home care.',
  },
  {
    id: 'obesity',
    name: 'Overweight',
    species: ['dog', 'cat'],
    weight: 0.6,
    managing: 'A measured plan with your vet, weighed monthly. Gradual loss, not crash dieting — especially in cats.',
  },
  {
    id: 'atopy',
    name: 'Skin allergies',
    species: ['dog', 'cat'],
    weight: 0.2,
    managing: 'Identify the pattern and season, keep a treatment plan ready before the flare rather than after it.',
  },
  {
    id: 'ear-infections',
    name: 'Recurrent ear infections',
    species: ['dog'],
    weight: 0.2,
    managing: 'Treat each episode fully rather than partially, and look for the underlying allergy driving the pattern.',
  },
  {
    id: 'mitral-valve',
    name: 'Heart murmur or valve disease',
    species: ['dog'],
    weight: 0.7,
    managing: 'Learn to count sleeping breathing rate at home — it is the earliest reliable warning. Regular cardiac reassessment.',
  },
  {
    id: 'hcm',
    name: 'Hypertrophic cardiomyopathy',
    species: ['cat'],
    weight: 0.9,
    managing: 'Regular echocardiography, resting breathing rate monitoring at home, and a plan for what to do if breathing changes.',
  },
  {
    id: 'ckd',
    name: 'Kidney disease',
    species: ['dog', 'cat'],
    weight: 0.9,
    managing: 'Staged monitoring, diet adapted to the stage, and constant access to water. Caught early this is managed for years.',
  },
  {
    id: 'diabetes',
    name: 'Diabetes',
    species: ['dog', 'cat'],
    weight: 0.8,
    managing: 'Consistent routine matters more than anything — same food, same times, same insulin. Some cats go into remission with good early control.',
  },
  {
    id: 'hyperthyroidism',
    name: 'Hyperthyroidism',
    species: ['cat'],
    weight: 0.4,
    managing: 'Very treatable, with several options. Kidney values need watching alongside, as treating one can unmask the other.',
  },
  {
    id: 'hypothyroid',
    name: 'Hypothyroidism',
    species: ['dog'],
    weight: 0.2,
    managing: 'Straightforward daily medication with periodic level checks. Usually not a limiting factor.',
  },
  {
    id: 'ivdd',
    name: 'Back or disc problems',
    species: ['dog'],
    weight: 0.6,
    managing: 'Ramps instead of jumps, lean weight, and a low threshold for urgency if the back end weakens.',
  },
  {
    id: 'epilepsy',
    name: 'Seizures or epilepsy',
    species: ['dog', 'cat'],
    weight: 0.5,
    managing: 'A seizure diary, consistent medication timing, and an agreed plan for cluster seizures.',
  },
  {
    id: 'cancer',
    name: 'Cancer, past or present',
    species: ['dog', 'cat'],
    weight: 1.0,
    managing: 'Follow the oncology plan, and keep the rest of preventive care going — quality of life is the measure that matters.',
  },
  {
    id: 'boas',
    name: 'Breathing difficulty',
    species: ['dog', 'cat'],
    weight: 0.8,
    managing: 'Weight control eases the work of breathing measurably. Avoid heat and exertion; surgical options are worth revisiting.',
  },
  {
    id: 'urinary',
    name: 'Urinary problems or stones',
    species: ['dog', 'cat'],
    weight: 0.5,
    managing: 'Water intake, diet, and a low threshold for urgency — a male unable to pass urine is an emergency within hours.',
  },
  {
    id: 'pancreatitis',
    name: 'Pancreatitis',
    species: ['dog', 'cat'],
    weight: 0.5,
    managing: 'A strictly low-fat diet with no exceptions, and a plan for what to do at the first sign of an episode.',
  },
]

export function conditionsFor(species: 'dog' | 'cat'): KnownCondition[] {
  return KNOWN_CONDITIONS.filter((c) => c.species.includes(species))
}
