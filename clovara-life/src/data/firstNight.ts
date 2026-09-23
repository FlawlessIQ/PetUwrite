/**
 * First-Night Mode content (SPEC §6.2): the first seventy-two hours, hour by
 * hour.
 *
 * WHAT THIS IS AND IS NOT. Every line here is husbandry and behaviour — where
 * the crate goes, how often a nine-week-old needs to pee, whether crying at 2am
 * is normal. None of it is clinical. Invariant 4 holds absolutely: nothing
 * diagnoses, nothing treats, and every block carries the one symptom list that
 * ends the conversation and sends someone to a vet.
 *
 * The escalation copy is the load-bearing part. A surface that talks to
 * somebody at 2am about a crying puppy has to be very clear about the small
 * number of things that are not a settling problem, because the failure mode is
 * an owner reassured out of a phone call they should have made.
 */
import type { Species } from './types'

export interface FirstNightBlock {
  id: string
  /** Hours since they came home, inclusive of `from`, exclusive of `to`. */
  from: number
  to: number
  title: string
  /** What is happening, in the owner's terms. */
  body: string
  /** Two or three concrete things to do now. */
  doNow: string[]
  /** What is normal at this hour, said plainly so nobody panics at normal. */
  normal: string
  species?: Species
}

/**
 * The line that ends every block.
 *
 * Deliberately identical everywhere rather than tailored per hour: these signs
 * mean the same thing at 3am on night one as at noon on day three, and varying
 * the wording would imply a variation in urgency that does not exist.
 */
export const FIRST_NIGHT_ESCALATION =
  'Call a vet now, at any hour, for: repeated vomiting or diarrhoea, a refusal to eat or drink for more than about twelve hours, gums that are pale or tacky, laboured breathing, collapse, a seizure, or a fall or crush injury. None of these are settling problems.'

export const FIRST_NIGHT_FOOTER =
  'This is information, not veterinary advice, and it never replaces your own vet. If something feels wrong to you, that is reason enough to call.'

const DOG_BLOCKS: FirstNightBlock[] = [
  {
    id: 'arrival',
    from: 0,
    to: 3,
    title: 'The first few hours',
    body: 'Everything they know ended this morning. The single most useful thing you can do now is make the world small — one room, few people, no visitors.',
    doNow: [
      'Take them straight to the spot you want them to toilet in, and wait. Praise anything that happens.',
      'Show them where water is. Leave it down and leave it there.',
      'Let them sleep the moment they want to. Do not wake a sleeping puppy to play with them.',
    ],
    normal: 'Hiding, shaking, refusing food, or sleeping for hours are all normal on the first afternoon.',
    species: 'dog',
  },
  {
    id: 'evening',
    from: 3,
    to: 8,
    title: 'The first evening',
    body: 'Set the pattern you actually want tonight, because whatever happens tonight is the pattern they will expect tomorrow.',
    doNow: [
      'Feed whatever the breeder or shelter was feeding, at the time they fed it. Change food later, slowly, or you will spend tomorrow cleaning.',
      'Put the crate or bed where you intend it to live, and beside your bed for the first few nights.',
      'Last toilet trip right before lights out, on the lead, no play.',
    ],
    normal: 'Eating little or nothing on the first evening is common and not an emergency on its own.',
    species: 'dog',
  },
  {
    id: 'night',
    from: 8,
    to: 14,
    title: 'The first night',
    body: 'They have never slept alone. Crying is not manipulation and it is not a behaviour problem — it is a puppy that has lost its litter.',
    doNow: [
      'Sleep near them. A hand through the crate door settles more puppies than any gadget.',
      'Expect to get up. Under twelve weeks, most need the toilet at least once in the night.',
      'Toilet trips at night are boring on purpose: out, wait, praise, back to bed. No lights, no play, no talking.',
    ],
    normal: 'Waking two or three times is normal. So is crying for the first twenty minutes.',
    species: 'dog',
  },
  {
    id: 'morning',
    from: 14,
    to: 24,
    title: 'The first morning',
    body: 'Straight outside before anything else. The first week of toileting is almost entirely about your timing, not their training.',
    doNow: [
      'Out on waking, after every meal, after every nap, and after every burst of play.',
      'Write down when they eat and when they go. Two days of that tells you their schedule better than any guide.',
      'Book the first vet appointment today if it is not already booked.',
    ],
    normal: 'Several accidents indoors today. That is the week, not a failure.',
    species: 'dog',
  },
  {
    id: 'day-two',
    from: 24,
    to: 48,
    title: 'Day two',
    body: 'Appetite usually returns today. This is also when the second night is often worse than the first, because the novelty has worn off and the tiredness has not.',
    doNow: [
      'Keep the world small for one more day. Meeting the whole family and the neighbours can wait.',
      'Start leaving them alone for two minutes at a time, while you are still in the house.',
      'Handle their paws and ears for a few seconds, for nothing, so the vet is not the first person who does.',
    ],
    normal: 'A worse second night is so common it is almost the rule.',
    species: 'dog',
  },
  {
    id: 'day-three',
    from: 48,
    to: 72,
    title: 'Day three',
    body: 'Most puppies are eating normally and sleeping longer by now. What you build this week is the routine, not the obedience.',
    doNow: [
      'Same wake time, same meal times, same bed. Dull is what a settled animal is made of.',
      'Ask your vet when they can safely meet other dogs — the socialisation window is short, and it is already open.',
      'If they have still eaten nothing at all, call your vet today rather than waiting for the weekend.',
    ],
    normal: 'Still having accidents, still crying at bedtime. Both normal at seventy-two hours.',
    species: 'dog',
  },
]

const CAT_BLOCKS: FirstNightBlock[] = [
  {
    id: 'arrival',
    from: 0,
    to: 3,
    title: 'The first few hours',
    body: 'A kitten does not want the run of the house. One quiet room with everything in it is not unkind — it is the only thing that makes the house survivable.',
    doNow: [
      'One room: litter tray at one end, food and water at the other, a box or bed to hide in.',
      'Show them the tray, then leave them alone. Do not carry them around.',
      'Let them come out when they come out. Sitting quietly in the room beats coaxing.',
    ],
    normal: 'Going behind the sofa and staying there for hours is normal and is not fear of you.',
    species: 'cat',
  },
  {
    id: 'evening',
    from: 3,
    to: 8,
    title: 'The first evening',
    body: 'Cats settle by smell before anything else. The room smelling of them rather than of you is what turns it into somewhere they live.',
    doNow: [
      'Same food, same brand, as they were on. A diet change now usually means diarrhoea tomorrow.',
      'Keep the tray far from the food. A cat that has to eat beside its toilet will pick somewhere else to go.',
      'Play with a wand toy at their level for five minutes. It works better than picking them up.',
    ],
    normal: 'Eating only once they think nobody is watching is normal.',
    species: 'cat',
  },
  {
    id: 'night',
    from: 8,
    to: 14,
    title: 'The first night',
    body: 'Leave them in their room with the door shut. It sounds harsh at midnight and it is the reason night two is quiet.',
    doNow: [
      'Tray, water, somewhere to hide. Nothing else is needed.',
      'Expect noise at 3am — kittens are crepuscular and yours has slept all afternoon.',
      'Do not go in every time they call, or you have taught them what calling does.',
    ],
    normal: 'Crying, and tearing around the room at four in the morning. Both normal.',
    species: 'cat',
  },
  {
    id: 'morning',
    from: 14,
    to: 24,
    title: 'The first morning',
    body: 'Check the tray before anything else — it is the best single piece of information you have about how they are doing.',
    doNow: [
      'Look for urine and for a formed stool. Note what you see.',
      'Feed at a fixed time and take the bowl up between meals, so you can tell what they have actually eaten.',
      'Book the first vet appointment today if it is not already booked.',
    ],
    normal: 'Softer stools in the first days are common with the stress of moving.',
    species: 'cat',
  },
  {
    id: 'day-two',
    from: 24,
    to: 48,
    title: 'Day two',
    body: 'Widen the world by one room, not by the whole house. Confidence in cats is built by letting them choose to come out.',
    doNow: [
      'Open the door and let them decide. Do not carry them to the new room.',
      'Put a scratching post where they already scratch, not where it suits the furniture.',
      'Handle paws and ears for a few seconds so a vet is not the first person to do it.',
    ],
    normal: 'Going back to the first room and staying there is progress, not a setback.',
    species: 'cat',
  },
  {
    id: 'day-three',
    from: 48,
    to: 72,
    title: 'Day three',
    body: 'Most kittens are eating properly and using the tray reliably by now. Everything else is routine and patience.',
    doNow: [
      'Keep the tray where it is. Moving it is the most common cause of a cat going elsewhere.',
      'Ask your vet about the vaccination schedule and about when they can safely go out, if they ever will.',
      'If they have still not used the tray at all, call your vet today.',
    ],
    normal: 'Hiding at loud noises and sleeping sixteen hours a day. Both normal.',
    species: 'cat',
  },
]

export const FIRST_NIGHT_BLOCKS: FirstNightBlock[] = [...DOG_BLOCKS, ...CAT_BLOCKS]
