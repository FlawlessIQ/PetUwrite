/**
 * The senior suite (SPEC-HORIZON §1.5): what changes around the house.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * HUSBANDRY, NOT MEDICINE. Everything here is a rug, a ramp, a lower-sided
 * litter tray — things an owner does to a room rather than to an animal.
 * Nothing in this file treats, prevents or slows anything, and nothing here
 * requires a vet to have said so first.
 *
 * TONE, WHICH IS THE HARDER HALF. VISION's vocabulary rules forbid promising
 * longer life, and ageing is not framed here as decline to be fought. An
 * eleven-year-old dog who needs a ramp has not failed at anything, and neither
 * has their owner. The copy says what changes and what helps, and it does not
 * reach for "still young at heart" either — that is the same lie in a kinder
 * voice.
 *
 * WHAT IS DELIBERATELY ABSENT: a quality-of-life scale. Validated ones exist
 * clinically, adopting one is a clinical decision, and SPEC-HORIZON §10 leaves
 * it with whoever owns `toxins.ts` and `redFlags.ts`. Inventing a scoring scale
 * for how good an animal's life is would be the worst thing in this codebase.
 * ═══════════════════════════════════════════════════════════════════════════
 */
import type { Species } from './types'

export interface Adaptation {
  id: string
  /** What to change. */
  what: string
  /** Why it helps, in plain words. Never clinical. */
  why: string
  species: Species[]
}

export const ADAPTATIONS: Adaptation[] = [
  {
    id: 'floors',
    what: 'Rugs or runners on hard floors',
    why: 'Laminate and tile are the hardest thing in most houses for an older animal. A path of rugs between the bed, the door and the water bowl changes more than almost anything else you can buy.',
    species: ['dog', 'cat'],
  },
  {
    id: 'ramp',
    what: 'A ramp or steps for the car and the sofa',
    why: 'Jumping down is harder on joints than jumping up, and most dogs will use a ramp within a week if it is left out rather than produced at the car.',
    species: ['dog'],
  },
  {
    id: 'bed',
    what: 'A thicker, lower bed',
    why: 'Thin bedding on a hard floor means pressure points. Low sides matter as much as the padding — a bed they have to climb into stops being a bed.',
    species: ['dog', 'cat'],
  },
  {
    id: 'tray',
    what: 'A litter tray with one low side',
    why: 'Stepping over a high edge is often the reason a cat starts going elsewhere, and it is read as a behaviour problem far more often than it is one.',
    species: ['cat'],
  },
  {
    id: 'steps',
    what: 'Steps up to the windowsill or the bed',
    why: 'Cats give up favourite places quietly rather than struggling in front of you. Somewhere they have stopped going is worth noticing.',
    species: ['cat'],
  },
  {
    id: 'water',
    what: 'Water in more than one place',
    why: 'Fewer trips across the house, and it makes it much easier to notice a change in how much they are drinking.',
    species: ['dog', 'cat'],
  },
  {
    id: 'walks',
    what: 'Shorter walks, more of them',
    why: 'The same total, split up, is usually easier on an older dog than one long outing — and sniffing tires them out more kindly than distance does.',
    species: ['dog'],
  },
  {
    id: 'grooming',
    what: 'A hand with grooming',
    why: 'Cats who stop reaching their back end are not being lazy, and matted fur behind the shoulders is uncomfortable long before it looks bad.',
    species: ['cat'],
  },
  {
    id: 'night',
    what: 'A night light on the route to the door',
    why: 'Eyesight and confidence both go quietly. A lit path is a small thing that prevents a lot of stumbling and a lot of accidents.',
    species: ['dog', 'cat'],
  },
  {
    id: 'nails',
    what: 'Nails checked more often',
    why: 'Less walking means less wear, and overgrown nails change how they stand — which makes everything else harder.',
    species: ['dog', 'cat'],
  },
]

/**
 * Things worth mentioning at the next visit.
 *
 * NOT SYMPTOMS, AND NOT A CHECKLIST TO SCORE. Each is something an owner sees
 * at home and a vet cannot see in a ten-minute consultation, phrased as an
 * observation to pass on rather than as a sign of anything. Naming what each
 * might mean would be diagnosing, and would turn this into the scale that is
 * deliberately not here.
 */
export const WORTH_MENTIONING: Record<Species, string[]> = {
  dog: [
    'Slower to get up, or settling with more shuffling than they used to.',
    'Hesitating at stairs, or at the car, when they did not before.',
    'Drinking more, or asking to go out in the night.',
    'Restless or unsettled in the evenings.',
    'Going off their food, or eating more slowly.',
    'Less interested in a walk they used to like.',
  ],
  cat: [
    'Stopped jumping to somewhere they always used to sit.',
    'Grooming less, or matting behind the shoulders.',
    'Drinking more, or spending longer at the water bowl.',
    'Going outside the tray, or standing differently in it.',
    'Sleeping somewhere new, especially somewhere warmer.',
    'Louder at night, or awake when the house is not.',
  ],
}

export const SENIOR_OPENING =
  'Nothing here is about slowing anything down. It is about the house being easier to live in, and about the handful of things you see at home that a vet cannot see in ten minutes.'

export const NO_SCALE_NOTE =
  'We do not score how good your pet’s life is. Scales for that exist and they belong with a vet who knows them and knows your animal — not with an app making a number out of six tick boxes.'

export const MENTION_NOTE =
  'None of these mean anything on their own, and we are not going to tell you what they might be. They are worth saying out loud at the next appointment, which is all.'
