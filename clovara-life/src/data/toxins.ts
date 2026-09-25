/**
 * Toxin lookup (SPEC §6.5) — "he ate a grape".
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * READ ALL OF THIS BEFORE CHANGING ANY NUMBER IN THIS FILE.
 *
 * This is the only surface in the product somebody opens when an animal is
 * already in trouble, and the failure mode is a dead animal. Every design
 * decision below is biased towards the phone call.
 *
 * 1. BANDS OUT, NEVER NUMBERS OUT. SPEC §6.5 allows dose-by-weight *risk
 *    banding* and forbids presenting mg thresholds as clinical advice. The
 *    thresholds below are used to COMPUTE a band and are never rendered. An
 *    owner reading "your dog ate 180mg/kg" will try to decide for themselves;
 *    an owner reading "call now" picks up the phone.
 *
 * 2. THE THRESHOLDS ARE DELIBERATELY LOWER THAN THE CLINICAL ONES. Where
 *    published toxic doses begin around a figure, the band here escalates
 *    below it. Over-referring costs somebody a phone call. Under-referring
 *    costs an animal.
 *
 * 3. SOME THINGS HAVE NO SAFE DOSE AND ARE NEVER BANDED BY WEIGHT. Grapes and
 *    raisins are idiosyncratic — dogs have died from a handful and others eaten
 *    a punnet with nothing. Xylitol acts at tiny quantities. A lily and a cat is
 *    an emergency at any exposure, including pollen groomed off a coat. These
 *    carry `alwaysCall` and the weight field is not consulted.
 *
 * 4. NOTHING HERE TELLS ANYBODY TO MAKE AN ANIMAL VOMIT. Inducing vomiting at
 *    home injures and kills animals — it is contraindicated for corrosives and
 *    petroleum products, and hydrogen peroxide causes its own damage. It is a
 *    decision for somebody holding a phone or a stethoscope. A test asserts no
 *    string in this file suggests it.
 *
 * 5. CONTENT IS UNREVIEWED BY A VETERINARIAN. The ROADMAP carries "vet review
 *    pass: clinical content ownership" as an open dependency and this file is
 *    the most important thing in it. Marked LEGAL-REVIEW/VET-REVIEW.
 * ═══════════════════════════════════════════════════════════════════════════
 */
import type { Species } from './types'

export type RiskBand =
  /** Ring a vet or a poison line now. */
  | 'call-now'
  /** Be seen today; ring for advice first. */
  | 'vet-today'
  /** Watch, and ring if anything changes. */
  | 'monitor'

export interface Toxin {
  id: string
  name: string
  /** Other things people type. */
  aka: string[]
  species: Species[]
  /** Nothing is safe at any amount — weight is not consulted. */
  alwaysCall?: boolean
  /**
   * Milligrams of the active agent per gram of the thing eaten, for the forms
   * people actually have in the house. Only for weight-banded toxins.
   */
  forms?: { id: string; label: string; mgPerGram: number }[]
  /**
   * mg per kg of bodyweight at which the band escalates. Deliberately below
   * published clinical thresholds. Internal only — never rendered.
   */
  thresholds?: { vetToday: number; callNow: number }
  /** What to watch for. Signs, never a diagnosis. */
  signs: string
  /** Why it matters, in plain words. */
  why: string
}

export const TOXINS: Toxin[] = [
  {
    id: 'grapes',
    name: 'Grapes, raisins, sultanas or currants',
    aka: ['grape', 'raisin', 'sultana', 'currant', 'mince pie', 'christmas pudding'],
    species: ['dog'],
    alwaysCall: true,
    why: 'The reaction is idiosyncratic — some dogs have gone into kidney failure after a handful, and others have eaten a punnet with nothing at all. Because nobody can tell which dog they have, there is no amount treated as safe.',
    signs: 'Vomiting, then being quiet or off food over the following day or two.',
  },
  {
    id: 'xylitol',
    name: 'Xylitol or birch sugar',
    aka: ['xylitol', 'birch sugar', 'sugar free gum', 'sugarfree', 'peanut butter', 'sweetener'],
    species: ['dog', 'cat'],
    alwaysCall: true,
    why: 'It acts at very small quantities and very quickly — a few pieces of sugar-free gum is enough for a small dog. It is increasingly in peanut butter, protein bars and some medicines.',
    signs: 'Wobbliness, weakness or collapse, sometimes within half an hour.',
  },
  {
    id: 'lily-cat',
    name: 'Lily — any part, including pollen',
    aka: ['lily', 'lilies', 'easter lily', 'stargazer', 'daylily', 'pollen'],
    species: ['cat'],
    alwaysCall: true,
    why: 'True lilies and daylilies cause kidney failure in cats. Chewing a leaf, drinking the vase water, or grooming pollen off their own coat is enough. Treatment works best before signs appear, which is why this is a now call rather than a wait-and-see.',
    signs: 'Drooling, vomiting, hiding, or not drinking. Often nothing at all at first.',
  },
  {
    id: 'antifreeze',
    name: 'Antifreeze or screenwash',
    aka: ['antifreeze', 'ethylene glycol', 'screenwash', 'coolant', 'radiator'],
    species: ['dog', 'cat'],
    alwaysCall: true,
    why: 'Very small amounts cause kidney failure, it tastes sweet so animals drink it willingly, and the window in which treatment works is measured in hours.',
    signs: 'Appearing drunk, then seeming to recover, then becoming very unwell a day or two later.',
  },
  {
    id: 'rodenticide',
    name: 'Rat or mouse poison',
    aka: ['rat poison', 'rodenticide', 'mouse bait', 'warfarin', 'bromadiolone', 'slug pellets'],
    species: ['dog', 'cat'],
    alwaysCall: true,
    why: 'Different poisons do entirely different things and the treatment differs completely, so the packet matters more than the amount. Take a photograph of it before you leave the house.',
    signs: 'Often nothing for days, which is the danger. Later: bruising, bleeding, weakness, or fits.',
  },
  {
    id: 'nsaid',
    name: 'Human painkillers — ibuprofen, paracetamol, aspirin, naproxen',
    aka: ['ibuprofen', 'paracetamol', 'acetaminophen', 'aspirin', 'naproxen', 'nurofen', 'tylenol', 'advil', 'painkiller'],
    species: ['dog', 'cat'],
    alwaysCall: true,
    why: 'Doses that are ordinary for a person damage the stomach, the kidneys or the liver in a dog, and cats cannot process paracetamol at all — a single tablet can kill a cat.',
    signs: 'Vomiting, being off food, dark or tarry stools. In cats, brown gums and laboured breathing.',
  },
  {
    id: 'cannabis',
    name: 'Cannabis or edibles',
    aka: ['cannabis', 'weed', 'thc', 'edible', 'marijuana', 'hash', 'gummies'],
    species: ['dog', 'cat'],
    alwaysCall: true,
    why: 'Edibles are the real problem, because they usually also contain chocolate or xylitol. Nobody is in trouble for saying what was eaten, and a vet needs to know to treat it properly.',
    signs: 'Wobbling, dribbling urine, startling at sounds, very dilated pupils.',
  },
  {
    id: 'sago',
    name: 'Sago palm',
    aka: ['sago', 'cycad', 'cardboard palm', 'zamia'],
    species: ['dog', 'cat'],
    alwaysCall: true,
    why: 'Every part is toxic and the seeds most of all. It causes liver failure and it is one of the least survivable things on this list if it waits.',
    signs: 'Vomiting, then jaundice a day or two later.',
  },
  {
    id: 'chocolate',
    name: 'Chocolate',
    aka: ['chocolate', 'cocoa', 'cacao', 'brownie', 'choc'],
    species: ['dog', 'cat'],
    forms: [
      { id: 'white', label: 'White chocolate', mgPerGram: 0.1 },
      { id: 'milk', label: 'Milk chocolate', mgPerGram: 2.0 },
      { id: 'dark', label: 'Dark or plain', mgPerGram: 5.5 },
      { id: 'baking', label: 'Baking or cocoa powder', mgPerGram: 15 },
    ],
    // Published signs begin around 20 mg/kg and cardiac effects around 40.
    // Banded well below both.
    thresholds: { vetToday: 8, callNow: 20 },
    why: 'The problem is theobromine, and how much is in it varies enormously — the same weight of baking chocolate carries roughly seven times what milk chocolate does.',
    signs: 'Restlessness, a racing heart, vomiting, tremors.',
  },
  {
    id: 'onion',
    name: 'Onion, garlic, leek or chive',
    aka: ['onion', 'garlic', 'leek', 'chive', 'shallot', 'gravy', 'stuffing'],
    species: ['dog', 'cat'],
    forms: [
      { id: 'raw', label: 'Raw or cooked pieces', mgPerGram: 1000 },
      { id: 'powder', label: 'Powder or concentrate', mgPerGram: 5000 },
    ],
    // Damage is described from roughly 5 g/kg of onion. Banded below.
    thresholds: { vetToday: 1500, callNow: 4000 },
    why: 'They damage red blood cells, and cats are considerably more sensitive than dogs. Powders and gravy granules are far more concentrated than the vegetable.',
    signs: 'Often nothing for a few days, then pale gums, tiredness, or orange-brown urine.',
  },
  {
    id: 'macadamia',
    name: 'Macadamia nuts',
    aka: ['macadamia', 'nuts'],
    species: ['dog'],
    forms: [{ id: 'nuts', label: 'Nuts', mgPerGram: 1000 }],
    // Signs described from roughly 2 g/kg. Banded below.
    thresholds: { vetToday: 600, callNow: 1500 },
    why: 'Dogs get weak in the back legs and feverish. It is rarely fatal and it is alarming to watch.',
    signs: 'Wobbliness or weakness in the back legs, tremors, a temperature.',
  },
  {
    id: 'caffeine',
    name: 'Coffee, tea or energy drinks',
    aka: ['coffee', 'caffeine', 'espresso', 'energy drink', 'tea bag', 'pro plus'],
    species: ['dog', 'cat'],
    forms: [
      { id: 'brewed', label: 'Brewed coffee or tea', mgPerGram: 0.4 },
      { id: 'grounds', label: 'Grounds, beans or tea bags', mgPerGram: 12 },
      { id: 'tablet', label: 'Caffeine tablets', mgPerGram: 200 },
    ],
    // Mild signs described around 14 mg/kg, severe around 23. Banded below.
    thresholds: { vetToday: 6, callNow: 14 },
    why: 'It does much what chocolate does, and grounds and tablets are far more concentrated than a cup of anything.',
    signs: 'Restlessness, a racing heart, vomiting, tremors.',
  },
  {
    id: 'dough',
    name: 'Raw bread dough',
    aka: ['dough', 'bread dough', 'yeast'],
    species: ['dog', 'cat'],
    alwaysCall: true,
    why: 'It keeps rising in a warm stomach and the yeast produces alcohol while it does. Both halves are dangerous and the swelling can be a surgical problem.',
    signs: 'A swollen, painful belly, retching without bringing anything up, appearing drunk.',
  },
  {
    id: 'alcohol',
    name: 'Alcohol',
    aka: ['alcohol', 'beer', 'wine', 'spirits', 'vodka', 'whisky'],
    species: ['dog', 'cat'],
    alwaysCall: true,
    why: 'Animals are far smaller than us and far more sensitive, and it drops their blood sugar and their temperature as well as intoxicating them.',
    signs: 'Wobbliness, vomiting, cold, drowsy, slow breathing.',
  },
  {
    id: 'vitamin-d',
    name: 'Vitamin D supplements',
    aka: ['vitamin d', 'cholecalciferol', 'supplement', 'psoriasis cream'],
    species: ['dog', 'cat'],
    alwaysCall: true,
    why: 'The margin between a human dose and a toxic one for an animal is very small, and it causes kidney damage that is hard to reverse once it is under way.',
    signs: 'Drinking and urinating much more than usual, vomiting, being off food.',
  },
  {
    id: 'battery',
    name: 'A battery, especially a button cell',
    aka: ['battery', 'button cell', 'coin cell', 'aa'],
    species: ['dog', 'cat'],
    alwaysCall: true,
    why: 'A swallowed button cell can burn through tissue within hours. This is one of the few things on this list where the clock genuinely matters that much.',
    signs: 'Drooling, retching, refusing food, pawing at the mouth.',
  },
]

// Poison lines live in ./poisonLines, so that a surface needing three phone
// numbers does not have to import this whole table. Re-exported for the
// existing importers.
export { POISON_LINES } from './poisonLines'

export const TOXIN_PRIMARY_INSTRUCTION =
  'Ring your vet or a poison line now. Do not wait for signs — for most of what is on this list, treatment works best before an animal looks unwell.'

/**
 * The single most important sentence in the file.
 *
 * Making an animal vomit at home injures and kills them: it is dangerous for
 * corrosives and petroleum products, and hydrogen peroxide does its own damage.
 * It is a decision for somebody with training, and people reach for it because
 * the internet told them to.
 */
export const TOXIN_NEVER_DIY =
  'Do not try to make them sick. It is the wrong thing for some of what is on this list and it causes its own injuries — whether to do it at all is a decision for the person on the phone.'

export const TOXIN_TAKE_WITH_YOU =
  'Take the packet, the wrapper or a photograph of the plant with you. What it was matters more than how much, and it is the first thing you will be asked.'

export const TOXIN_DISCLAIMER =
  'This is information, not veterinary advice, and it is not a substitute for ringing someone. If you are not sure, ring. Nobody minds the call that turned out to be nothing.'

/** VET-REVIEW: this content has not been reviewed by a veterinarian. */
export const TOXIN_REVIEW_STATUS = 'VET-REVIEW' as const
