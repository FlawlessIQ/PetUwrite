import type { Species } from './types'

/**
 * ═══════════════════════════════════════════════════════════════════════════
 * PRODUCT CATALOG — ILLUSTRATIVE
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * EVERY ITEM IN THIS FILE IS ILLUSTRATIVE. Names, prices, and member discounts
 * are placeholders for a real merchandised catalog. They are flagged the same
 * way the breed figures are, and the app surfaces that flag rather than hiding
 * it. Replace `name`, `price`, `memberPrice`, `partner` and `emoji` with real
 * SKUs before this is anything other than a demo.
 *
 * WHAT IS NOT ILLUSTRATIVE is the matching logic. `targets` are real condition
 * ids from the breed database, so the shelf is genuinely derived from the pet's
 * own risk profile rather than merchandised by hand. That is the part worth
 * showing an investor.
 *
 * ───────────────────────────────────────────────────────────────────────────
 * A NOTE ON SUPPLEMENT CLAIMS
 * ───────────────────────────────────────────────────────────────────────────
 * Supplement copy in this file is deliberately qualitative. The evidence for
 * joint supplements in dogs is mixed — some trials show benefit on owner-
 * reported outcomes, others show no effect against placebo, and the category is
 * not regulated as a drug. So nothing here says a supplement treats, prevents,
 * or slows a condition. Products are framed as "commonly used alongside" the
 * thing they relate to, and the strongest verbs are reserved for the items where
 * the underlying behaviour is well evidenced — toothbrushing, weight management,
 * and measured feeding.
 *
 * `claimStrength` records which is which, and drives a badge in the UI:
 *   behaviour  — the product supports a behaviour with real evidence behind it
 *                (brushing, portion control, activity measurement)
 *   supportive — commonly used, evidence mixed or limited. Qualitative copy only.
 *   comfort    — quality-of-life and husbandry. No health claim made at all.
 */

export type ClaimStrength = 'behaviour' | 'supportive' | 'comfort'

export interface Product {
  id: string
  name: string
  /** One line under the name. Never a health claim. */
  subtitle: string
  species: Species[]
  /** Condition ids from the breed database. Drives the "why this" line. */
  targets: string[]
  /** Life stages this is relevant to. Empty means all. */
  stages?: string[]
  /**
   * True for items that make sense for any pet of the species regardless of
   * breed. Items WITHOUT this flag only appear when they match something on the
   * pet's own risk cards — otherwise the shelf ends up offering facial fold
   * wipes to a Golden Retriever, which is exactly the merchandised-by-hand
   * feeling this screen exists to avoid.
   */
  universal?: boolean
  price: number
  memberPrice: number
  emoji: string
  claimStrength: ClaimStrength
  /** Shown on the product when expanded. Honest about the evidence. */
  evidenceNote: string
  /** Points earned per purchase. */
  points: number
  subscription?: boolean
  /** ILLUSTRATIVE is the only valid value today. Kept explicit on purpose. */
  confidence: 'illustrative'
}

export const PRODUCTS: Product[] = [
  // ── Joint and mobility ───────────────────────────────────────────────────
  {
    id: 'joint-chews',
    name: 'Hip & Joint Chews',
    subtitle: 'Glucosamine, chondroitin and omega-3',
    species: ['dog'],
    targets: ['hip-dysplasia', 'elbow-dysplasia', 'arthritis', 'ccl', 'patellar-luxation', 'degenerative-myelopathy'],
    price: 28,
    memberPrice: 22,
    emoji: '🦴',
    claimStrength: 'supportive',
    evidenceNote:
      'Widely used in dogs with joint findings. Trial results are mixed — some show improvement on owner-reported measures, others show no difference against placebo. Worth discussing with your vet alongside the two things that are well evidenced here: keeping weight lean, and keeping exercise regular.',
    points: 120,
    subscription: true,
    universal: true,
    confidence: 'illustrative',
  },
  {
    id: 'joint-chews-cat',
    name: 'Feline Mobility Chews',
    subtitle: 'Omega-3 and green-lipped mussel',
    species: ['cat'],
    targets: ['arthritis', 'hip-dysplasia'],
    price: 24,
    memberPrice: 19,
    emoji: '🐾',
    claimStrength: 'supportive',
    evidenceNote:
      'Feline joint supplement evidence is thinner than the canine literature. Included because arthritis is badly under-recognised in cats, and the conversation it starts with your vet is the point. Environmental changes — steps, low-sided trays, warm beds — do more.',
    points: 100,
    subscription: true,
    universal: true,
    confidence: 'illustrative',
  },
  {
    id: 'mobility-ramp',
    name: 'Non-slip Ramp',
    subtitle: 'Sofa and car height, folds flat',
    species: ['dog'],
    targets: ['ivdd', 'hip-dysplasia', 'arthritis', 'degenerative-myelopathy', 'fractures'],
    price: 89,
    memberPrice: 72,
    emoji: '🛝',
    claimStrength: 'behaviour',
    evidenceNote:
      'Reducing repeated jumping is standard advice for long-backed breeds and for any dog with a joint or disc finding. This is husbandry rather than treatment, and it is the kind of change that is easy to make before it is needed.',
    points: 300,
    confidence: 'illustrative',
  },
  {
    id: 'cat-steps',
    name: 'Perch Steps',
    subtitle: 'Carpeted, for windowsills and beds',
    species: ['cat'],
    targets: ['arthritis', 'hip-dysplasia'],
    price: 54,
    memberPrice: 44,
    emoji: '🪜',
    claimStrength: 'comfort',
    evidenceNote:
      'A cat that stops jumping to a favourite spot is often in pain rather than being lazy. Steps keep the spot reachable, which is both a comfort measure and a way to notice the change early.',
    points: 200,
    confidence: 'illustrative',
  },

  // ── Dental ───────────────────────────────────────────────────────────────
  {
    id: 'dental-kit',
    name: 'Dental Care Kit',
    subtitle: 'Enzymatic paste, finger brush and angled brush',
    species: ['dog', 'cat'],
    targets: ['periodontal'],
    price: 18,
    memberPrice: 14,
    emoji: '🦷',
    claimStrength: 'behaviour',
    evidenceNote:
      'Daily brushing is the standard the veterinary dental guidelines describe, and it is the behaviour this product exists to make easier. Note what we do not claim: no study shows dental care extends lifespan. What is documented is an association between periodontal disease and kidney disease, and a clear effect on comfort.',
    points: 80,
    subscription: true,
    universal: true,
    confidence: 'illustrative',
  },
  {
    id: 'dental-water',
    name: 'Water Additive',
    subtitle: 'For the days brushing does not happen',
    species: ['dog', 'cat'],
    targets: ['periodontal'],
    price: 15,
    memberPrice: 12,
    emoji: '💧',
    claimStrength: 'supportive',
    evidenceNote:
      'A fallback, not a replacement. Look for the Veterinary Oral Health Council seal on any dental product making a plaque or tartar claim — it is the only independent check in the category.',
    points: 60,
    subscription: true,
    universal: true,
    confidence: 'illustrative',
  },

  // ── Weight and feeding ───────────────────────────────────────────────────
  {
    id: 'portion-scale',
    name: 'Smart Feeding Scale',
    subtitle: 'Weighs the meal, logs it to the app',
    species: ['dog', 'cat'],
    targets: ['obesity', 'diabetes'],
    price: 45,
    memberPrice: 36,
    emoji: '⚖️',
    claimStrength: 'behaviour',
    evidenceNote:
      'The single best-evidenced lever in this whole product, made measurable. Lean-fed dogs in a controlled lifetime feeding study lived a median of 1.8 years longer than their pair-fed littermates. Measuring by cup is where portion control usually goes wrong.',
    points: 180,
    universal: true,
    confidence: 'illustrative',
  },
  {
    id: 'puzzle-feeder',
    name: 'Slow Feeder Bowl',
    subtitle: 'Slows eating, adds a bit of work to a meal',
    species: ['dog', 'cat'],
    targets: ['obesity', 'gdv', 'diabetes'],
    price: 22,
    memberPrice: 17,
    emoji: '🍽️',
    claimStrength: 'comfort',
    evidenceNote:
      'Turns a meal into an activity, which helps with both pace and boredom. Often suggested for deep-chested breeds, though the evidence that slower eating reduces bloat risk is not settled.',
    points: 90,
    universal: true,
    confidence: 'illustrative',
  },

  // ── Monitoring ───────────────────────────────────────────────────────────
  {
    id: 'clotag',
    name: 'CloTag Wearable',
    subtitle: 'Activity, rest quality and resting respiratory rate',
    species: ['dog', 'cat'],
    targets: [],
    price: 99,
    memberPrice: 79,
    emoji: '📍',
    claimStrength: 'behaviour',
    evidenceNote:
      'Resting respiratory rate is the genuinely useful number here — it is the earliest reliable home signal of heart failure in dogs, and vets act on it. The activity trend matters less on any given day than it does as a change from that animal\'s own baseline.',
    points: 400,
    universal: true,
    confidence: 'illustrative',
  },
  {
    id: 'body-condition-guide',
    name: 'Body Condition Card',
    subtitle: 'The nine-point scale, on your fridge',
    species: ['dog', 'cat'],
    targets: ['obesity'],
    price: 0,
    memberPrice: 0,
    emoji: '📋',
    claimStrength: 'behaviour',
    evidenceNote:
      'Free, and the highest-value object in this shop. Owners consistently underestimate their pet\'s body condition; a physical reference you check by hand fixes more of that than any scale does.',
    points: 40,
    universal: true,
    confidence: 'illustrative',
  },

  // ── Skin, coat and husbandry ─────────────────────────────────────────────
  {
    id: 'oat-shampoo',
    name: 'Oatmeal Shampoo',
    subtitle: 'Unscented, for sensitive skin',
    species: ['dog', 'cat'],
    targets: ['atopy', 'skin-fold', 'skin-care', 'zinc-dermatosis'],
    price: 16,
    memberPrice: 12,
    emoji: '🧴',
    claimStrength: 'comfort',
    evidenceNote:
      'Soothing rather than treating. Persistent itch is an allergy or infection question for a vet, and a shampoo will not resolve it on its own.',
    points: 60,
    universal: true,
    confidence: 'illustrative',
  },
  {
    id: 'fold-wipes',
    name: 'Facial Fold Wipes',
    subtitle: 'Fragrance-free, for folds and tail pockets',
    species: ['dog'],
    targets: ['skin-fold', 'eye-ulcers', 'brachycephalic-cat'],
    price: 14,
    memberPrice: 11,
    emoji: '🧻',
    claimStrength: 'behaviour',
    evidenceNote:
      'Keeping folds clean and dry is routine care for flat-faced breeds rather than an occasional treatment. Cheap habit, prevents a chronic problem.',
    points: 50,
    subscription: true,
    confidence: 'illustrative',
  },
  {
    id: 'ear-cleaner',
    name: 'Ear Cleaning Solution',
    subtitle: 'Drying, for after swimming and baths',
    species: ['dog'],
    targets: ['ear-infections'],
    price: 17,
    memberPrice: 13,
    emoji: '👂',
    claimStrength: 'behaviour',
    evidenceNote:
      'Drying the ears after water is genuinely preventive in drop-eared breeds. An ear that is already sore, smelly or painful needs a vet before anything goes into it.',
    points: 60,
    subscription: true,
    confidence: 'illustrative',
  },

  // ── Breed-specific and environmental ─────────────────────────────────────
  {
    id: 'cooling-mat',
    name: 'Cooling Mat',
    subtitle: 'Pressure-activated, no power needed',
    species: ['dog'],
    targets: ['boas', 'heat-intolerance'],
    price: 39,
    memberPrice: 31,
    emoji: '❄️',
    claimStrength: 'comfort',
    evidenceNote:
      'Comfort, not a safety device. For a flat-faced breed the things that actually prevent heatstroke are walking early and late, staying home on hot days, and never waiting in a warm car.',
    points: 140,
    confidence: 'illustrative',
  },
  {
    id: 'harness',
    name: 'Y-Front Harness',
    subtitle: 'Takes pressure off the throat',
    species: ['dog'],
    targets: ['tracheal-collapse', 'boas', 'ivdd'],
    price: 34,
    memberPrice: 27,
    emoji: '🦺',
    claimStrength: 'behaviour',
    evidenceNote:
      'For a small breed prone to tracheal collapse, or any flat-faced dog, moving off a neck collar is standard advice and easy to act on.',
    points: 120,
    confidence: 'illustrative',
  },
  {
    id: 'water-fountain',
    name: 'Circulating Water Fountain',
    subtitle: 'Encourages drinking through the day',
    species: ['cat'],
    targets: ['ckd', 'urinary', 'diabetes'],
    price: 49,
    memberPrice: 39,
    emoji: '⛲',
    claimStrength: 'supportive',
    evidenceNote:
      'Cats often drink more from moving water, and water intake matters for both kidney and urinary problems. Useful, but it does not replace monitoring — and a cat that suddenly starts drinking a lot more needs bloodwork, not a bigger bowl.',
    points: 180,
    confidence: 'illustrative',
  },
  {
    id: 'litter-tray',
    name: 'Low-Entry Litter Tray',
    subtitle: 'Two-inch step, high sides',
    species: ['cat'],
    targets: ['arthritis', 'urinary', 'ckd'],
    price: 32,
    memberPrice: 26,
    emoji: '📦',
    claimStrength: 'behaviour',
    evidenceNote:
      'An older cat that starts missing the tray is often telling you that climbing into it hurts. Changing the tray is the first thing to try, and it frequently solves what looks like a behaviour problem.',
    points: 110,
    confidence: 'illustrative',
  },
  {
    id: 'senior-bloods',
    name: 'Senior Screening Voucher',
    subtitle: 'Bloodwork, urinalysis and blood pressure',
    species: ['dog', 'cat'],
    targets: ['ckd', 'hyperthyroidism', 'hypothyroid', 'diabetes', 'lymphoma'],
    stages: ['mature-adult', 'senior'],
    price: 120,
    memberPrice: 85,
    emoji: '🩺',
    claimStrength: 'behaviour',
    evidenceNote:
      'The guidelines are unambiguous about this one: twice-yearly bloodwork and urinalysis from the senior stage. It finds kidney disease, thyroid disease and diabetes in the window where they are still manageable.',
    points: 350,
    universal: true,
    confidence: 'illustrative',
  },
  {
    id: 'puppy-box',
    name: 'New Puppy Starter Box',
    subtitle: 'Brush, training paste, growth chart and a clicker',
    species: ['dog'],
    targets: ['periodontal'],
    stages: ['puppy'],
    price: 45,
    memberPrice: 36,
    emoji: '🎁',
    claimStrength: 'behaviour',
    evidenceNote:
      'The habits formed in the first year are the ones still paying off in ten. Toothbrushing accepted as a puppy is toothbrushing accepted for life.',
    points: 160,
    universal: true,
    confidence: 'illustrative',
  },
  {
    id: 'kitten-box',
    name: 'New Kitten Starter Box',
    subtitle: 'Carrier liner, brush, paste and a wand toy',
    species: ['cat'],
    targets: ['periodontal'],
    stages: ['kitten'],
    price: 42,
    memberPrice: 34,
    emoji: '🎀',
    claimStrength: 'behaviour',
    evidenceNote:
      'Getting a kitten used to having its mouth, ears and paws handled — and to the carrier being furniture rather than a warning — pays back at every vet visit for the next fifteen years.',
    points: 150,
    universal: true,
    confidence: 'illustrative',
  },
]

export function productsFor(species: Species): Product[] {
  return PRODUCTS.filter((p) => p.species.includes(species))
}

export const CLAIM_STRENGTH_LABELS: Record<ClaimStrength, { label: string; blurb: string }> = {
  behaviour: {
    label: 'Backs a proven habit',
    blurb: 'Supports a behaviour with real evidence behind it.',
  },
  supportive: {
    label: 'Commonly used',
    blurb: 'Widely used for this, but the evidence is mixed or limited.',
  },
  comfort: {
    label: 'Comfort & care',
    blurb: 'Quality of life and husbandry. No health claim made.',
  },
}
