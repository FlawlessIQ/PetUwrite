import type { PetProfile } from './types'

/**
 * Pre-seeded demo pets, chosen to show the engine differentiating rather than
 * producing one shape of answer:
 *
 *  Max     — a large dog in the middle of life with a declared joint finding.
 *            Shows the watch → manage transition and the weight lever at its
 *            most powerful.
 *  Winston — a breed whose published life expectancy is genuinely short and
 *            whose risk profile is unlike any other. Shows the model is reading
 *            the breed, not the size.
 *  Luna    — a cat, and an older one. Shows the species-specific body-condition
 *            logic and the fixed-age feline life stages.
 */
export const DEMO_PETS: PetProfile[] = [
  {
    id: 'demo-max',
    name: 'Max',
    species: 'dog',
    breedId: 'golden-retriever',
    birthDate: '2020-05-10',
    sex: 'male',
    neutered: true,
    weightLb: 79,
    conditionIds: ['hip-dysplasia'],
    activity: 'moderate',
    dental: 'weekly',
    diet: 'free-fed',
    demo: true,
    headline: 'Mild hip laxity noted at his 2024 check. Activity down a little this week.',
  },
  {
    id: 'demo-winston',
    name: 'Winston',
    species: 'dog',
    breedId: 'french-bulldog',
    birthDate: '2023-06-02',
    sex: 'male',
    neutered: true,
    weightLb: 28,
    conditionIds: [],
    activity: 'moderate',
    dental: 'weekly',
    diet: 'measured',
    demo: true,
    headline: 'Three years old and in good shape. A breed where what comes next is well documented.',
  },
  {
    id: 'demo-luna',
    name: 'Luna',
    species: 'cat',
    breedId: 'domestic-shorthair',
    birthDate: '2017-03-18',
    sex: 'female',
    neutered: true,
    weightLb: 11,
    conditionIds: [],
    activity: 'moderate',
    dental: 'rarely',
    diet: 'free-fed',
    demo: true,
    headline: 'Nine, indoors, and just crossing into the stage where testing starts to earn its keep.',
  },
]
