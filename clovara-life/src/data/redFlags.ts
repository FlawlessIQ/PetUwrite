/**
 * The red-flag list (SPEC-COMPANION §3.1) — signs that end the conversation
 * and start a phone call.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * VET-REVIEW. THIS CONTENT HAS NOT BEEN READ BY A VETERINARIAN.
 *
 * SPEC-COMPANION §10 asks who owns this list clinically, and that question is
 * still open. It ships unreviewed on the same footing as `data/toxins.ts`,
 * biased hard towards escalation, and it is the most important item in the
 * open "clinical content ownership" dependency.
 *
 * THE BIAS, STATED ONCE: over-escalating costs somebody a phone call they did
 * not need. Under-escalating costs an animal. Every judgement call in this
 * file resolves in the same direction, and anyone editing it should keep
 * resolving them that way.
 *
 * WHAT A "FLAG" IS: a sign an owner can observe and describe. Not a diagnosis.
 * "Straining to urinate" is here; "urethral obstruction" is not, because the
 * owner cannot know that and we must not tell them.
 *
 * SPECIES MATTERS AND IS NOT DECORATIVE. A male cat straining in the litter
 * tray is a hours-matter emergency and the same sign in a dog usually is not.
 * Open-mouth breathing is ordinary in a dog after a run and is an emergency in
 * a cat. Flags carry species where the urgency genuinely differs.
 * ═══════════════════════════════════════════════════════════════════════════
 */
import type { Species } from './types'

export interface RedFlag {
  id: string
  /** What to show back, in the owner's words. */
  label: string
  /**
   * Lowercase phrases. Matched as substrings against the whole utterance, so
   * word-boundary problems ("fit" inside "fitting") are avoided by writing the
   * longer form.
   */
  phrases: string[]
  /** Narrows to one species where the urgency genuinely differs. */
  species?: Species
  /** Why it is urgent, in plain words. Never a diagnosis. */
  because: string
}

export const RED_FLAGS: RedFlag[] = [
  {
    id: 'collapse',
    label: 'Collapsed, or will not get up',
    phrases: ['collapse', 'collapsed', 'collaped', 'passed out', 'fainted', 'unresponsive', 'wont get up', "won't get up", 'cannot get up', 'get up', 'cannot stand', "can't stand", 'unconscious', 'went floppy', 'gone floppy', 'went limp', 'gone limp', 'all limp', 'funny turn', 'went stiff'],
    because: 'An animal that cannot stand needs to be seen now, whatever the cause.',
  },
  {
    id: 'breathing',
    label: 'Struggling to breathe',
    // Owners write "breathing funny", not "dyspnoea". The list is written from
    // how people actually type at 2am, not from how it would be charted.
    phrases: ['struggling to breathe', 'strugling to breath', 'struggling to breath', 'difficulty breathing', 'trouble breathing', 'laboured breathing', 'labored breathing', 'gasping', 'choking', 'cannot breathe', "can't breathe", 'not breathing', 'breathing funny', 'breathing fast', 'breathing a bit fast', 'breathing quickly', 'breathing heavy', 'breathing hard', 'breathing weird', 'wheezing', 'blue gums', 'grey gums', 'gray gums', 'blue tongue', 'gums look blue', 'gums are blue', 'gums look grey', 'gums look gray', 'tongue looks blue'],
    because: 'Breathing trouble is the one thing that does not wait, and it can look mild minutes before it does not.',
  },
  {
    id: 'cat-open-mouth',
    label: 'Open-mouth breathing or panting',
    phrases: ['open mouth breathing', 'panting', 'breathing with mouth open', 'mouth open breathing'],
    species: 'cat',
    because: 'A panting cat is not a hot cat. Cats almost never pant, and one that is doing it needs to be seen now.',
  },
  {
    id: 'seizure',
    label: 'A seizure, or fitting',
    phrases: ['seizure', 'siezure', 'seizeure', 'seazure', 'seizing', 'fitting', 'convulsing', 'convulsion', 'twitching uncontrollably', 'paddling'],
    because: 'A first seizure, a long one, or several close together all need a vet the same day.',
  },
  {
    id: 'cat-urinating',
    label: 'Straining in the litter tray',
    // Written from how somebody types it, not how it reads in a textbook. The
    // first version had "nothing coming out" and missed "nothing IS coming
    // out", which is what a person actually writes.
    phrases: ['straining to pee', 'straining to urinate', 'cannot pee', "can't pee", 'not peed', "hasn't peed", 'hasnt peed', 'not urinated', 'not weed', 'cannot wee', 'trying to pee', 'nothing coming out', 'nothing is coming out', 'no urine', 'blocked', 'in and out of the litter', 'keeps going to the litter', 'going to the litter tray', 'keeps going in the litter', 'in and out of the tray', 'squatting', 'crying in the litter'],
    species: 'cat',
    because: 'In a male cat this can be a blockage, and it becomes life-threatening in hours rather than days. It is the single most time-critical thing on this list.',
  },
  {
    id: 'bloat',
    label: 'Swollen belly, retching with nothing coming up',
    phrases: ['swollen belly', 'bloated', 'distended', 'hard belly', 'retching', 'trying to be sick', 'unproductive vomiting', 'dry heaving', 'heaving'],
    species: 'dog',
    because: 'A swollen abdomen with unproductive retching is an emergency in any dog and especially a deep-chested one. Hours matter.',
  },
  {
    id: 'bleeding',
    label: 'Bleeding that will not stop',
    phrases: ['bleeding', 'blood', 'blood everywhere', 'wont stop bleeding', "won't stop bleeding", 'haemorrhage', 'hemorrhage'],
    because: 'Press on it with something clean and go. Judging how much blood is too much is not something to do at home.',
  },
  {
    id: 'trauma',
    label: 'Hit, fallen, or crushed',
    phrases: ['hit by a car', 'hit by car', 'run over', 'fell from', 'fell off', 'crushed', 'stood on', 'attacked', 'attacked by', 'bitten by a dog', 'dog attack', 'mauled', 'in a fight', 'got into a fight', 'bitten by'],
    because: 'Serious internal injury is common after impact and often shows nothing at all at first.',
  },
  {
    id: 'gums',
    label: 'Pale, white or tacky gums',
    phrases: ['pale gums', 'white gums', 'tacky gums', 'gums are pale', 'gums look white', 'gums to look white', 'gums look pale', 'gums are white', 'funny colour', 'funny color', 'gums are a funny', 'gum colour', 'gums look'],
    because: 'Gum colour is one of the few things an owner can check that genuinely changes the urgency.',
  },
  {
    id: 'toxin',
    label: 'Ate something they should not have',
    phrases: ['ate rat poison', 'ate poison', 'antifreeze', 'chocolate', 'grapes', 'raisins', 'ate raisins', 'xylitol', 'ate a lily', 'ate my tablets', 'ate ibuprofen', 'ate paracetamol', 'swallowed a battery'],
    because: 'For most of what is dangerous, treatment works best before an animal looks unwell.',
  },
  {
    id: 'heat',
    label: 'Overheated',
    phrases: ['heatstroke', 'heat stroke', 'overheated', 'left in the car', 'too hot and'],
    because: 'Heatstroke does damage that continues after the animal looks cooler.',
  },
  {
    id: 'swelling',
    label: 'Sudden swelling of the face, or hives',
    phrases: ['face is swollen', 'swollen face', 'hives', 'swollen muzzle', 'lips swollen', 'stung'],
    because: 'A reaction that is swelling a face can go on to affect breathing.',
  },
  {
    id: 'birth',
    label: 'Trouble giving birth',
    phrases: ['in labour', 'in labor', 'straining to give birth', 'stuck', 'been pushing'],
    because: 'Time between puppies or kittens is the thing that matters, and it is easy to leave too long.',
  },
  {
    id: 'eye',
    label: 'A painful or injured eye',
    phrases: ['eye is', 'scratched his eye', 'scratched her eye', 'eye popped', 'cannot see', "can't see", 'gone blind', 'suddenly blind'],
    because: 'Eyes do not wait. A day can be the difference between keeping and losing one.',
  },
  {
    id: 'pain',
    label: 'In obvious pain',
    phrases: ['screaming', 'crying out', 'yelping when', 'wont let me touch', "won't let me touch", 'in agony', 'shaking and'],
    because: 'An animal showing pain that plainly has usually been hiding it for a while.',
  },
  {
    id: 'not-eating-cat',
    label: 'Not eating',
    phrases: ['not eaten', 'not eating', 'refusing food', 'off his food', 'off her food', 'wont eat', "won't eat"],
    species: 'cat',
    because: 'A cat that stops eating for a couple of days can develop a serious liver problem from the fasting itself, whatever started it.',
  },
  {
    id: 'vomiting',
    label: 'Repeated vomiting or diarrhoea',
    phrases: ['keeps being sick', 'vomiting repeatedly', 'cannot keep water down', "can't keep water down", 'blood in his stool', 'blood in her stool', 'bloody diarrhoea', 'bloody diarrhea', 'vomiting blood'],
    because: 'Dehydration happens quickly in a small animal, and blood changes the urgency.',
  },
]

export const RED_FLAG_HEADLINE = 'Stop and ring a vet now.'

export const RED_FLAG_BODY =
  'From what you have written, this is not something to watch and see. Ring your own practice — out of hours they will have a number that is answered — or the nearest emergency vet. If you are not sure, ring anyway. Nobody minds the call that turned out to be nothing.'

/**
 * What we say when nothing matched.
 *
 * NOT REASSURANCE. This is the sentence that decides whether the whole surface
 * is safe: nothing matching means our list did not recognise anything, which
 * is a fact about our list and not about the animal. An owner who reads "sounds
 * fine" and goes to bed is the failure this file exists to prevent.
 */
export const NO_FLAG_HEADLINE = 'We have not spotted anything on our urgent list.'

export const NO_FLAG_BODY =
  'That is a statement about our list, not about your pet. We match a short set of signs that always need a vet immediately, and plenty of serious things are not on it. If you are worried, ring your practice — you know them and we do not.'

/** VET-REVIEW: not read by a veterinarian. */
export const RED_FLAGS_REVIEW_STATUS = 'VET-REVIEW' as const
