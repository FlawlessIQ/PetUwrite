/**
 * The Socialization Passport (SPEC §6.3): the firsts that matter before the
 * window closes.
 *
 * QUALITATIVE ONLY, as SPEC requires. Every stamp is "they met this and it was
 * fine" — never a count, never a duration, never a protocol. A checklist that
 * said "expose to five strangers daily" would be a training programme written
 * by people who have not met the dog.
 *
 * THE TWO WINDOWS ARE NOT THE SAME, AND THIS IS THE THING MOST PRODUCTS GET
 * WRONG. The sensitive period for dogs runs roughly 3–14 weeks, so a puppy
 * homed at eight weeks arrives with most of it ahead of them. For cats it runs
 * roughly 2–7 weeks and is therefore largely OVER by the time a kitten is
 * adopted at twelve. Gamifying a closed window would be selling somebody a race
 * they have already lost, so the kitten version says so plainly and shifts to
 * habituation, which genuinely does continue.
 *
 * Content is consistent with published AAHA/AAFP behaviour guidance in shape
 * and emphasis. It is husbandry, not clinical advice, and it is deliberately
 * silent on anything that belongs to a vet — including when a given puppy is
 * safe to meet unvaccinated dogs, which is a question for their own vet.
 */
import type { Species } from './types'

export interface SocialStamp {
  id: string
  label: string
  /** Grouping for the passport pages. */
  group: string
  species: Species[]
}

/** Dogs: roughly 3–14 weeks. Cats: roughly 2–7 weeks. */
export const WINDOW_WEEKS: Record<Species, { opens: number; closes: number }> = {
  dog: { opens: 3, closes: 14 },
  cat: { opens: 2, closes: 7 },
}

/** How long the passport stays useful, even past the sensitive period. */
export const PASSPORT_VISIBLE_WEEKS = 16

const s = (id: string, label: string, group: string, species: Species[] = ['dog', 'cat']): SocialStamp => ({
  id,
  label,
  group,
  species,
})

export const SOCIAL_STAMPS: SocialStamp[] = [
  // ── People ───────────────────────────────────────────────────────────────
  s('p-child', 'A calm, gentle child', 'People'),
  s('p-toddler', 'A toddler, at a distance', 'People'),
  s('p-teen', 'Teenagers', 'People'),
  s('p-elderly', 'Someone older, moving slowly', 'People'),
  s('p-beard', 'A man with a beard', 'People'),
  s('p-hat', 'Somebody in a hat', 'People'),
  s('p-hood', 'Somebody with their hood up', 'People'),
  s('p-glasses', 'Somebody in sunglasses', 'People'),
  s('p-uniform', 'A uniform — post, delivery, high-vis', 'People'),
  s('p-stick', 'Someone with a walking stick or frame', 'People'),
  s('p-wheelchair', 'A wheelchair', 'People'),
  s('p-crowd', 'A small group talking at once', 'People'),
  s('p-running', 'Somebody running past', 'People'),
  s('p-tall', 'Somebody very tall standing over them', 'People'),
  s('p-stranger-home', 'A visitor arriving at the door', 'People'),
  s('p-vet-nurse', 'A vet or vet nurse, with nothing done', 'People'),

  // ── Handling ─────────────────────────────────────────────────────────────
  s('h-paws', 'Paws held, briefly', 'Handling'),
  s('h-nails', 'Nail clippers touched to a nail', 'Handling'),
  s('h-ears', 'Ears looked in', 'Handling'),
  s('h-mouth', 'Lips lifted, teeth seen', 'Handling'),
  s('h-brush', 'Brushed', 'Handling'),
  s('h-towel', 'Towelled dry', 'Handling'),
  s('h-collar', 'Collar or harness on', 'Handling'),
  s('h-lift', 'Picked up and put down calmly', 'Handling'),
  s('h-table', 'Standing on a table or worktop', 'Handling'),
  s('h-tail', 'Tail and back end touched', 'Handling'),
  s('h-carrier', 'In and out of the carrier, door open', 'Handling', ['cat']),
  s('h-lead', 'Lead clipped on and off indoors', 'Handling', ['dog']),

  // ── Sounds ───────────────────────────────────────────────────────────────
  s('s-vacuum', 'The vacuum, running in the next room', 'Sounds'),
  s('s-hairdryer', 'A hairdryer', 'Sounds'),
  s('s-doorbell', 'The doorbell', 'Sounds'),
  s('s-tv', 'Television and music at normal volume', 'Sounds'),
  s('s-kitchen', 'Pans, the blender, the dishwasher', 'Sounds'),
  s('s-washing', 'The washing machine spinning', 'Sounds'),
  s('s-traffic', 'Traffic from a pavement', 'Sounds'),
  s('s-sirens', 'A siren going past', 'Sounds'),
  s('s-thunder', 'Thunder or heavy rain', 'Sounds'),
  s('s-fireworks', 'Fireworks, from indoors', 'Sounds'),
  s('s-baby', 'A baby crying', 'Sounds'),
  s('s-barking', 'Another dog barking', 'Sounds'),
  s('s-alarm', 'A smoke alarm test', 'Sounds'),
  s('s-clapping', 'Clapping and cheering', 'Sounds'),
  s('s-drill', 'A drill or DIY next door', 'Sounds'),

  // ── Surfaces ─────────────────────────────────────────────────────────────
  s('f-wood', 'Wooden floor', 'Surfaces'),
  s('f-tile', 'Tile or lino', 'Surfaces'),
  s('f-carpet', 'Carpet', 'Surfaces'),
  s('f-grass', 'Grass', 'Surfaces'),
  s('f-gravel', 'Gravel', 'Surfaces'),
  s('f-metal', 'A metal drain cover or grate', 'Surfaces'),
  s('f-wet', 'Wet ground, a puddle', 'Surfaces'),
  s('f-sand', 'Sand or soil', 'Surfaces'),
  s('f-stairs', 'Stairs, up and down', 'Surfaces'),
  s('f-wobbly', 'Something that moves underfoot', 'Surfaces'),
  s('f-shiny', 'A shiny or polished floor', 'Surfaces'),
  s('f-rubber', 'A doormat or rubber matting', 'Surfaces'),
  s('f-cold', 'Cold ground, frost or snow', 'Surfaces'),

  // ── Things ───────────────────────────────────────────────────────────────
  s('t-umbrella', 'An umbrella opening', 'Things'),
  s('t-bags', 'Bin bags and rustling plastic', 'Things'),
  s('t-bikes', 'Bicycles going past', 'Things'),
  s('t-scooter', 'A scooter or skateboard', 'Things'),
  s('t-pram', 'A pram', 'Things'),
  s('t-trolley', 'A shopping trolley', 'Things'),
  s('t-balloon', 'A balloon', 'Things'),
  s('t-broom', 'A broom or mop being used', 'Things'),
  s('t-mirror', 'Their own reflection', 'Things'),
  s('t-statue', 'A bin, a postbox, something large and still', 'Things'),
  s('t-flags', 'Flags or bunting moving in the wind', 'Things'),
  s('t-hose', 'A hose or sprinkler', 'Things'),
  s('t-ladder', 'A ladder or step stool', 'Things'),
  s('t-suitcase', 'A suitcase being wheeled', 'Things'),

  // ── Places ───────────────────────────────────────────────────────────────
  s('l-car', 'A car journey that ends somewhere nice', 'Places'),
  s('l-garden', 'The garden alone with you', 'Places'),
  s('l-street', 'A quiet street', 'Places'),
  s('l-town', 'A busier street, watched from your arms or a bench', 'Places'),
  s('l-cafe', 'Sitting outside a café', 'Places'),
  s('l-carpark', 'A car park', 'Places'),
  s('l-vets', 'The vet waiting room, for nothing at all', 'Places'),
  s('l-friends', "Somebody else's house", 'Places'),
  s('l-lift', 'A lift', 'Places'),
  s('l-countryside', 'Fields or woods', 'Places', ['dog']),
  s('l-window', 'A window perch onto the street', 'Places', ['cat']),
  s('l-room-new', 'A new room in the house', 'Places', ['cat']),

  // ── Animals ──────────────────────────────────────────────────────────────
  s('a-adult-dog', 'A calm, vaccinated adult dog', 'Animals'),
  s('a-puppy', 'Another puppy their own size', 'Animals', ['dog']),
  s('a-cat', 'A cat, at a distance', 'Animals'),
  s('a-livestock', 'Sheep, horses or cows behind a fence', 'Animals', ['dog']),
  s('a-birds', 'Birds and squirrels', 'Animals'),
  s('a-kitten', 'Another kitten', 'Animals', ['cat']),
  s('a-small-dog', 'A dog much smaller than them', 'Animals'),
  s('a-big-dog', 'A dog much larger than them', 'Animals'),
  s('a-dog-behind-gate', 'A dog barking behind a gate', 'Animals'),
  s('a-on-lead-pass', 'Passing another dog without meeting', 'Animals', ['dog']),

  // ── Being a pet ──────────────────────────────────────────────────────────
  s('e-alone-short', 'Left alone for a few minutes', 'Being a pet'),
  s('e-alone-longer', 'Left alone for half an hour', 'Being a pet'),
  s('e-crate', 'Settling in the crate with the door shut', 'Being a pet', ['dog']),
  s('e-chew', 'Something of their own to chew', 'Being a pet', ['dog']),
  s('e-scratch', 'A scratching post used instead of the sofa', 'Being a pet', ['cat']),
  s('e-tray-change', 'A second litter tray somewhere else', 'Being a pet', ['cat']),
  s('e-food-taken', 'Food bowl approached while eating, then added to', 'Being a pet'),
  s('e-toy-swap', 'A toy traded for something better', 'Being a pet'),
  s('e-name', 'Their name, and coming back for it', 'Being a pet'),
  s('e-sleep-undisturbed', 'Left to sleep without being woken', 'Being a pet'),
  s('e-groomer', 'A groomer or a bath', 'Being a pet'),
  s('e-boarding', 'Somebody else feeding them', 'Being a pet'),
]

export function stampsFor(species: Species): SocialStamp[] {
  return SOCIAL_STAMPS.filter((x) => x.species.includes(species))
}

export const PASSPORT_PRINCIPLE =
  'A stamp means they met it and were fine — curious, or calm, or bored. If they were frightened it does not count, and repeating it louder makes it worse. Go further away, make it smaller, and try again another day.'

export const PASSPORT_VET_LINE =
  'When your puppy can safely meet dogs you do not know depends on their vaccinations and on where you live. That is a question for your vet, not for us.'
