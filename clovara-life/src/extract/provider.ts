/**
 * Vet-record extraction (SPEC §4.3, P1.7) — the seam, and why it ships dark.
 *
 * ═══════════════════════════════════════════════════════════════════════════
 * THIS FEATURE IS BUILT AND SWITCHED OFF, AND BOTH HALVES OF THAT ARE
 * DELIBERATE.
 *
 * Two things gate it, and neither is engineering:
 *
 *  1. THE FIRESTORE SECURITY REVIEW that SPEC §7 requires before vet records
 *     ship. Until it happens, `records/` is denied outright in both
 *     firestore.rules and storage.rules — so nothing can be uploaded even if
 *     somebody flipped this flag.
 *  2. AN LLM KEY. There is no extraction provider, and `StubExtractor` does
 *     not pretend there is.
 *
 * Building it anyway is the point: when the review lands and a key exists, a
 * real provider implements `ExtractionProvider`, the flag goes true, and no
 * surface changes. The same pattern as the rating adapter and the fitness
 * provider.
 *
 * INVARIANT 8 IS THE WHOLE DESIGN. Nothing extracted becomes structured data
 * until the owner confirms it as a chip. The types below make that
 * unavoidable: an extractor returns `Candidate`, never a stored field, and the
 * only way a Candidate becomes data is `confirm()`, which stamps provenance
 * `extracted_confirmed`. There is deliberately no path from a document to the
 * record that does not pass through a person.
 * ═══════════════════════════════════════════════════════════════════════════
 */
import type { Provenance } from '../data/stored'

/** SPEC §7's review, and a key. Both are Conor's, not engineering's. */
export const EXTRACTION_ENABLED = false

export type CandidateKind = 'vaccine' | 'condition' | 'weight' | 'visit'

/**
 * Something an extractor thinks it saw. NOT data.
 *
 * `confidence` is deliberately not rendered as a percentage anywhere: a number
 * invites an owner to trust the high ones without reading them, which is the
 * exact failure invariant 8 exists to prevent. It is used only for ordering.
 */
export interface Candidate {
  id: string
  kind: CandidateKind
  /** What to show on the chip, in the owner's words. */
  label: string
  /** The raw text it came from, so somebody can check it against the page. */
  sourceText: string
  /** For ordering only. Never rendered. */
  confidence: number
  /** The structured value, applied only once confirmed. */
  value: unknown
}

export interface ExtractionResult {
  candidates: Candidate[]
  /** Set when nothing could be attempted, so the UI can say why. */
  unavailableReason?: string
  providerId: string
}

export interface ExtractionProvider {
  id: string
  available: boolean
  extract(file: { name: string; type: string; size: number }): Promise<ExtractionResult>
}

/**
 * The provider in place today.
 *
 * It returns nothing and says why. It must never return plausible-looking
 * sample candidates: a stub that invents "Rabies, 12 March 2025" would put a
 * fabricated vaccination in front of an owner to confirm, and a confirmed
 * fabrication is indistinguishable from a real record forever after.
 */
export const StubExtractor: ExtractionProvider = {
  id: 'stub',
  available: false,
  async extract() {
    return {
      candidates: [],
      providerId: 'stub',
      unavailableReason:
        'Reading vet records is not switched on yet. It needs a security review of how those documents are stored, which is booked separately — we would rather not hold them at all than hold them badly.',
    }
  },
}

let provider: ExtractionProvider = StubExtractor
export function setExtractionProvider(p: ExtractionProvider): void {
  provider = p
}
export function extractionProvider(): ExtractionProvider {
  return provider
}

export interface ConfirmedField {
  kind: CandidateKind
  value: unknown
  provenance: Provenance
  confirmedAt: string
  /** Kept so a confirmed value can always be traced back to what was read. */
  sourceText: string
}

/**
 * The only way a candidate becomes data (invariant 8).
 *
 * Stamps `extracted_confirmed` — never `vet_verified`, which would claim a
 * clinician stood behind it. An owner reading a scan and tapping yes is not a
 * veterinary attestation, and conflating the two would quietly launder a
 * guess into a medical fact.
 */
export function confirm(candidate: Candidate, now: Date): ConfirmedField {
  return {
    kind: candidate.kind,
    value: candidate.value,
    provenance: 'extracted_confirmed',
    confirmedAt: now.toISOString(),
    sourceText: candidate.sourceText,
  }
}

/** Highest confidence first; ties keep their original order. */
export function ordered(candidates: Candidate[]): Candidate[] {
  return candidates.map((c, i) => ({ c, i })).sort((a, b) => b.c.confidence - a.c.confidence || a.i - b.i).map((x) => x.c)
}
