/**
 * C2 — retrieval and grounding (SPEC-COMPANION §3.2).
 *
 * Pure. No model, no IO, injected clock.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * THE RULE THIS FILE EXISTS TO ENFORCE: the companion may only say things that
 * are already in the pet graph. Retrieval produces facts with sources;
 * composition may use those facts and nothing else. When the model arrives in
 * C3 it gets this set and the same rule, so the model adds language rather than
 * information.
 *
 * Until then, composition is templates over the same facts. That is not a
 * placeholder — it is the honest version of the scripted exhibit, and it can
 * only say true things because it has nothing else to say.
 *
 * EVERY FACT CARRIES A SOURCE, AND WHERE A PERSON SUPPLIED IT, A PROVENANCE.
 * An owner reading the reply can see that "hip dysplasia is on his record" came
 * from them and that "Labradors are in the window from two" came from a table
 * with a citation. Those are different kinds of claim and the difference is
 * exactly what makes recall trustworthy.
 * ═══════════════════════════════════════════════════════════════════════════
 */
import type { PetProfile, Projection } from '../data/types'
import type { Provenance } from '../data/stored'
import { KNOWN_CONDITIONS } from '../data/conditions'

export type FactSource =
  | { kind: 'pet-record'; field: string }
  | { kind: 'breed-table'; breedId: string; citation: string }
  | { kind: 'projection'; component: string }
  | { kind: 'vaccination' }
  | { kind: 'care-note' }

export interface GroundedFact {
  id: string
  /** The claim, in plain words, already true. */
  claim: string
  source: FactSource
  provenance?: Provenance
  /** Words that make this fact relevant. Lowercase. */
  topics: string[]
}

export interface GroundingSet {
  facts: GroundedFact[]
  /** Everything we hold, for "here is what I actually know". */
  total: number
  /** Matched topics, so the surface can say what it keyed on. */
  matchedOn: string[]
}

const norm = (s: string) =>
  s.toLowerCase().replace(/[’']/g, "'").replace(/[^a-z0-9' ]+/g, ' ').replace(/\s+/g, ' ').trim()

/**
 * Content words from a phrase, for topic building.
 *
 * THREE LETTERS COUNT. The first version required four and silently dropped
 * hip, eye, ear, paw, leg, gum and jaw — which is most of what somebody points
 * at when something is wrong. The stop list does the work instead.
 */
function words(s: string): string[] {
  const stop = new Set([
    'the','a','an','and','or','of','to','in','on','for','with','is','are','was','were','be','been',
    'his','her','their','its','it','he','she','they','them','that','this','has','have','had','at',
    'after','before','more','less','than','from','up','down','out','off','over','under','not','no',
    'but','you','all','any','can','get','got','how','let','may','new','now','one','our','say','see',
    'too','two','use','way','who','why','yes','yet','did','been','just','been','she','him','been',
    'what','when','some','been','very','like','been','does','been','than','into','been','about',
  ])
  return [...new Set(norm(s).split(' ').filter((w) => w.length > 2 && !stop.has(w)))]
}

/**
 * Everything we hold about this animal, as facts with sources.
 *
 * Built unconditionally and filtered afterwards, so `total` can honestly say
 * how much we know rather than how much matched.
 */
export function allFacts(pet: PetProfile, projection: Projection): GroundedFact[] {
  const out: GroundedFact[] = []
  const add = (f: GroundedFact) => out.push(f)

  // ── Declared conditions ───────────────────────────────────────────────
  for (const id of pet.conditionIds ?? []) {
    const c = KNOWN_CONDITIONS.find((k) => k.id === id)
    const name = c?.name ?? id
    add({
      id: `condition-${id}`,
      claim: `${name} is already on ${pet.name}'s record.`,
      source: { kind: 'pet-record', field: 'conditionIds' },
      provenance: 'owner_declared',
      topics: [...words(name), 'diagnosed', 'condition', 'record'],
    })
  }

  // ── Breed risk, with its citation ─────────────────────────────────────
  for (const card of projection.riskCards) {
    add({
      id: `risk-${card.id}`,
      claim:
        card.mode === 'manage'
          ? `${card.name} is on the record, and the plan has been to watch it as ${pet.name} ages — ${card.window.toLowerCase()}.`
          : `For a ${projection.breed.name}, ${card.name.toLowerCase()} is something we watch for — ${card.window.toLowerCase()}.`,
      source: { kind: 'breed-table', breedId: pet.breedId, citation: card.confidence },
      topics: [...words(card.name), ...words(card.watch), card.mode],
    })
    add({
      id: `watch-${card.id}`,
      claim: `What we would watch for with ${card.name.toLowerCase()}: ${card.watch}`,
      source: { kind: 'breed-table', breedId: pet.breedId, citation: card.confidence },
      topics: [...words(card.watch), ...words(card.name)],
    })
  }

  // ── Age and stage ─────────────────────────────────────────────────────
  add({
    id: 'stage',
    claim: `${pet.name} is ${Math.floor(projection.ageYears)} and currently a ${projection.currentStage.label.toLowerCase()}.`,
    source: { kind: 'projection', component: 'currentStage' },
    topics: ['age', 'old', 'older', 'young', 'senior', 'ageing', 'aging', 'stage', 'years'],
  })

  // ── Shape ─────────────────────────────────────────────────────────────
  if (pet.weightLb > 0) {
    add({
      id: 'weight',
      claim: `You told us ${pet.name} weighs about ${pet.weightLb} lb.`,
      source: { kind: 'pet-record', field: 'weightLb' },
      provenance: 'owner_declared',
      topics: ['weight', 'heavy', 'thin', 'fat', 'shape', 'skinny', 'weighs', 'size'],
    })
  }

  // ── Routine ───────────────────────────────────────────────────────────
  if (pet.activity) {
    add({
      id: 'activity',
      claim: `You described ${pet.name} as ${pet.activity === 'low' ? 'not very active' : pet.activity === 'high' ? 'very active' : 'active most days'}.`,
      source: { kind: 'pet-record', field: 'activity' },
      provenance: 'owner_declared',
      topics: ['walk', 'walks', 'active', 'exercise', 'slow', 'slowing', 'stiff', 'moving', 'lazy', 'tired'],
    })
  }
  if (pet.dental) {
    add({
      id: 'dental',
      claim: `Teeth are cleaned ${pet.dental === 'rarely' ? 'rarely' : pet.dental}.`,
      source: { kind: 'pet-record', field: 'dental' },
      provenance: 'owner_declared',
      topics: ['teeth', 'tooth', 'breath', 'mouth', 'gums', 'dental', 'chewing'],
    })
  }
  if (pet.species === 'cat' && pet.outdoorAccess) {
    add({
      id: 'outdoor',
      claim: `${pet.name} is ${pet.outdoorAccess === 'indoor' ? 'kept indoors' : pet.outdoorAccess === 'outdoor' ? 'mostly outdoors' : 'in and out'}.`,
      source: { kind: 'pet-record', field: 'outdoorAccess' },
      provenance: 'owner_declared',
      topics: ['outside', 'outdoors', 'indoor', 'garden', 'roaming', 'out'],
    })
  }

  // ── Vaccinations ──────────────────────────────────────────────────────
  const shots = pet.vaccineRecords ?? []
  if (shots.length > 0) {
    add({
      id: 'vaccines',
      claim: `You have recorded ${shots.length} vaccination${shots.length === 1 ? '' : 's'} for ${pet.name}.`,
      source: { kind: 'vaccination' },
      provenance: 'owner_declared',
      topics: ['vaccine', 'vaccination', 'jab', 'shot', 'booster', 'injection'],
    })
  }

  // ── Medication from the sitter card ───────────────────────────────────
  if (pet.careNotes?.meds) {
    add({
      id: 'meds',
      claim: `You noted ${pet.name} takes: ${pet.careNotes.meds}`,
      source: { kind: 'care-note' },
      provenance: 'owner_declared',
      topics: ['medication', 'medicine', 'tablet', 'tablets', 'pill', 'pills', 'taking', 'dose'],
    })
  }

  return out
}

/** What is relevant to what somebody actually asked. */
export function buildGroundingSet(
  pet: PetProfile,
  projection: Projection,
  utterance: string,
  _now: Date,
): GroundingSet {
  const all = allFacts(pet, projection)
  const asked = new Set(words(utterance))
  if (asked.size === 0) return { facts: [], total: all.length, matchedOn: [] }

  const matchedOn = new Set<string>()
  const facts = all.filter((f) =>
    f.topics.some((t) => {
      const hit = asked.has(t) || [...asked].some((a) => a.includes(t) || t.includes(a))
      if (hit) matchedOn.add(t)
      return hit
    }),
  )

  return { facts, total: all.length, matchedOn: [...matchedOn] }
}

/**
 * Is this asking us to say what it IS?
 *
 * Found by the red team: "just tell me, is it cancer?" retrieved the breed's
 * cancer risk card and opened with "here is what is already on Scout's
 * record" — legitimate research, and in answer to that question it reads as
 * confirmation. Naming a condition in a question must not be a way to have it
 * named back.
 *
 * So identification questions are refused before retrieval runs at all, rather
 * than answered with facts that happen to be true.
 */
export function asksForIdentification(utterance: string): boolean {
  const said = norm(utterance)
  return [
    'is it ', 'is this ', 'could it be', 'could this be', 'do you think it', 'what is it',
    'whats it', 'what do you think it', 'sounds like', 'sound like', 'looks like', 'look like',
    'best guess', 'if you had to say', 'tell me what it is', 'tell me what is wrong',
    'diagnose', 'diagnosis', 'what is wrong with', 'whats wrong with', 'how bad is',
    'scale of one to ten', 'out of ten', 'is he dying', 'is she dying',
  ].some((p) => said.includes(p))
}

export interface Recall {
  /** Null when we know nothing relevant — invariant 9. */
  opening: string | null
  facts: GroundedFact[]
  /** Whether this is worth a vet, and why. Never a diagnosis. */
  route: 'vet-soon' | 'none'
  closing: string
}

/**
 * Composition, deterministically (C2).
 *
 * Templates over the grounded facts and nothing else. When the model lands in
 * C3 it replaces this function and keeps the same inputs and the same rule.
 *
 * IT NEVER CONCLUDES. It recalls what is on the record and says whether that is
 * worth a vet looking. "Your dog has arthritis" is not something this can say,
 * because no fact in the set says it.
 */
export function composeRecall(pet: PetProfile, set: GroundingSet, utterance = ''): Recall {
  // Refused before anything is retrieved: see asksForIdentification.
  if (utterance && asksForIdentification(utterance)) {
    return {
      opening: null,
      facts: [],
      route: 'vet-soon',
      closing: `We cannot tell you what it is. That needs somebody who can examine ${pet.name}, and naming a possibility here would be a guess dressed up as an answer — which is worse than saying nothing. Ring your vet and describe what you are seeing.`,
    }
  }
  if (set.facts.length === 0) {
    return {
      opening: null,
      facts: [],
      route: 'none',
      closing: `We hold ${set.total} things about ${pet.name}, and none of them speak to what you have described. That is a gap in what we know, not a judgement about ${pet.name} — if it is worrying you, it is worth a call to your vet.`,
    }
  }

  // A matched risk card means the record has something to say about this.
  const touchesRisk = set.facts.some((f) => f.id.startsWith('risk-') || f.id.startsWith('condition-'))

  return {
    opening: `Here is what is already on ${pet.name}'s record about that.`,
    facts: set.facts,
    route: touchesRisk ? 'vet-soon' : 'none',
    closing: touchesRisk
      ? `This is recall, not an opinion — we have not examined ${pet.name} and cannot tell you what it is. Given what is on the record, it is worth a vet's eyes.`
      : `This is recall, not an opinion. If what you are seeing is new or getting worse, ring your vet.`,
  }
}
