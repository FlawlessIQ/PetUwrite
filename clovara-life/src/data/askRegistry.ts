/**
 * The ask registry — SPEC §4.3's "declarative table (field, trigger screen,
 * benefit copy) so product can tune without code".
 *
 * The principle it enforces is SPEC §4's: **no field is asked without a visible
 * benefit on the screen where it is asked.** Microchip is not a profile field
 * you fill in because a form has a box for it; it is asked the moment someone
 * turns on the lost-pet card, because that is the moment it does something.
 *
 * This is not documentation. It is the single declaration of where each thing
 * may be asked, and a test asserts no screen asks for anything the registry
 * does not place there. Adding a question to a screen without adding it here
 * fails the build, which is the point — "just one more field" is how onboarding
 * stops ever ending in the bad sense.
 *
 * TUNING WITHOUT CODE: the shape is deliberately plain data, so this table can
 * move to `life_config` (already readable by signed-in clients, already
 * unwritable by them) when product wants to change copy without a deploy. It is
 * in the repo for now because it is also the thing tests assert against, and a
 * remote table cannot fail a build.
 */
import type { PetProfile, Species } from './types'

/** Screens that may ask for something. */
export type AskTrigger =
  /** The Life surface, post-reveal. Tier 1 (SPEC §4.2). */
  | 'life'
  /** First visit to Shop. */
  | 'shop'
  /** Turning on the lost-pet card (P3). */
  | 'lost-pet-card'
  /** Turning on Sitter Mode (SPEC §6.6). */
  | 'sitter-mode'
  /** The insurance attach flow (P2). */
  | 'attach'
  /** Trial end, via Stripe's hosted Checkout. */
  | 'trial-end'

export interface Ask {
  /** The field this collects. Matches PetProfile where one exists. */
  field: string
  trigger: AskTrigger
  /** The question, as asked. */
  question: string
  /**
   * What answering does for this pet, on this screen. Never "complete your
   * profile" — if the only benefit is our completeness, it should not be asked.
   */
  benefit: string
  /** Narrows the ask to one species. */
  species?: Species
  /** True when the ask still applies to this pet. */
  applies?: (pet: PetProfile) => boolean
  /**
   * Set where the answer is NOT stored on the pet — identity and payment belong
   * to the person and to Stripe, and must never drift onto the animal's record.
   */
  storedOn?: 'household' | 'stripe'
}

const answered = (key: keyof PetProfile) => (pet: PetProfile) => pet[key] === undefined

export const ASK_REGISTRY: Ask[] = [
  // ── Tier 1, on the Life surface ──────────────────────────────────────────
  {
    field: 'weightLb',
    trigger: 'life',
    question: 'What shape are they in?',
    benefit: 'Body condition moves the projection more than anything else you can tell us.',
  },
  {
    field: 'conditionIds',
    trigger: 'life',
    question: 'Anything already diagnosed?',
    benefit: 'Anything already diagnosed changes the plan from watching for it to managing it.',
  },
  {
    field: 'neutered',
    trigger: 'life',
    question: 'Neutered or spayed?',
    benefit: 'Neutering is consistently associated with longer life across large datasets.',
  },
  {
    field: 'neuterAgeBand',
    trigger: 'life',
    question: 'Roughly how old were they then?',
    benefit: 'In a dog this size, the timing tells us what to watch for in their joints.',
    species: 'dog',
    applies: (pet) => pet.neutered === true && pet.neuterAgeBand === undefined,
  },
  {
    field: 'outdoorAccess',
    trigger: 'life',
    question: 'How much of the world do they get?',
    benefit: 'Whether a cat goes out is the biggest thing we can still ask about a cat.',
    species: 'cat',
    applies: answered('outdoorAccess'),
  },
  {
    field: 'activity',
    trigger: 'life',
    question: 'How much do they move on a normal day?',
    benefit: 'How much they move is part of the healthy-years picture.',
    applies: answered('activity'),
  },
  {
    field: 'dental',
    trigger: 'life',
    question: 'Teeth cleaned at home?',
    benefit: 'Dental routine is a small but real part of the picture.',
    applies: answered('dental'),
  },

  {
    // Worth zero to the accuracy meter on purpose — it sharpens nothing. It is
    // on the Life surface because it is where someone is already looking at
    // their pet, not because the plan needs it.
    field: 'photo',
    trigger: 'life',
    question: 'Add a photo of them?',
    benefit: 'It makes the app theirs, and we keep a larger copy so their shape can be compared over time.',
    applies: (pet) => pet.photo === undefined,
  },

  // ── Contextual: asked where the answer does something ────────────────────
  {
    // SPEC §4.3's own example. Diet is worth almost nothing to the projection
    // and quite a lot to a shelf of food, so it is asked at the shelf.
    field: 'diet',
    trigger: 'shop',
    question: 'How do they eat at the moment?',
    benefit: 'So the food on this shelf is the kind you would actually buy.',
    applies: answered('diet'),
  },
  {
    field: 'microchipId',
    trigger: 'lost-pet-card',
    question: "What is their microchip number?",
    benefit: 'It goes on the lost-pet card, which is the one moment it matters.',
  },
  {
    field: 'careNotes',
    trigger: 'sitter-mode',
    question: 'What would you write on a note for them?',
    benefit: 'It is the whole of what the sitter sees — feeding, medication, the vet, and who to ring.',
  },
  {
    field: 'ownerAddress',
    trigger: 'attach',
    question: 'Where do you live?',
    benefit: 'Insurance is priced and filed by state, so a policy cannot be quoted without it.',
    storedOn: 'household',
  },
  {
    field: 'paymentMethod',
    trigger: 'trial-end',
    question: 'Which card should we use?',
    benefit: 'Only asked when the trial is ending — never to start one.',
    storedOn: 'stripe',
  },
]

/**
 * What this screen may ask this pet, in registry order.
 *
 * Nothing else may be asked there. That is the contract, and the test that
 * enforces it is the reason this exists rather than a comment.
 */
export function asksFor(trigger: AskTrigger, pet: PetProfile): Ask[] {
  return ASK_REGISTRY.filter((a) => {
    if (a.trigger !== trigger) return false
    if (a.species && a.species !== pet.species) return false
    if (a.applies && !a.applies(pet)) return false
    return true
  })
}

/** Every field the registry places on a given screen, species aside. */
export function fieldsOn(trigger: AskTrigger): string[] {
  return ASK_REGISTRY.filter((a) => a.trigger === trigger).map((a) => a.field)
}
