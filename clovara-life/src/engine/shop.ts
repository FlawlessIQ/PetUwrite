/**
 * The shop shelf (SPEC §5.1) — split out of platform.ts so the catalogue loads
 * with the Shop tab rather than with every visit to Home (BACKLOG T4).
 *
 * Pure.
 */
import { PRODUCTS, type Product } from '../data/products'
import type { PetProfile, Projection } from '../data/types'
import { isRemembered } from './remember'

// ───────────────────────────────────────────────────────────────────────────
// SHOP
// ───────────────────────────────────────────────────────────────────────────

export interface ProductRec extends Product {
  /** Why this appeared for this pet, in plain language. */
  why: string
  /** The risk card ids it matched. Empty for staples. */
  matched: string[]
  /** Higher sorts first. */
  relevance: number
}

/**
 * The shelf is derived, not merchandised. A product appears because it targets a
 * condition on this pet's own risk cards, or because it belongs to their current
 * life stage. Anything that matches neither is a staple and sorts last.
 */
export function recommendProducts(profile: PetProfile, projection: Projection): ProductRec[] {
  // Nothing is sold for a pet who has died (SPEC-HORIZON §2.5).
  if (isRemembered(profile)) return []
  const riskIds = new Set(projection.riskCards.map((r) => r.id))
  const declared = new Set(profile.conditionIds ?? [])
  const stage = projection.currentStage.id

  // Rank the pet's risks so a high-tier, in-window risk pulls its product up.
  const riskWeight = new Map<string, number>()
  projection.riskCards.forEach((r, i) => {
    let w = 10 - i
    if (r.tier === 'high') w += 6
    if (r.mode === 'manage') w += 10
    if (r.mode === 'active') w += 5
    riskWeight.set(r.id, w)
  })

  return PRODUCTS.filter((p) => p.species.includes(profile.species))
    .filter((p) => !p.stages || p.stages.includes(stage))
    // A breed-specific item only earns a place if it matches something on this
    // pet's own risk cards. Otherwise the shelf offers fold wipes to a Golden.
    .filter(
      (p) =>
        p.universal ||
        p.stages?.includes(stage) ||
        p.targets.some((t) => riskIds.has(t) || declared.has(t)),
    )
    .map((p) => {
      const matched = p.targets.filter((t) => riskIds.has(t) || declared.has(t))
      const matchScore = matched.reduce((s, m) => s + (riskWeight.get(m) ?? 4), 0)
      const stageBonus = p.stages?.includes(stage) ? 14 : 0

      let why: string
      if (matched.length > 0) {
        const card = projection.riskCards.find((r) => r.id === matched[0])
        const name = (card?.name ?? matched[0]).toLowerCase()
        why = declared.has(matched[0])
          ? `Because ${profile.name} is already managing ${name}`
          : card?.mode === 'active'
            ? `${capitalise(name)} is in its window now`
            : `For ${profile.name}'s ${name} watch`
      } else if (stageBonus) {
        why = `For the ${projection.currentStage.label.toLowerCase()} stage`
      } else {
        why = `A staple for ${profile.species === 'dog' ? 'dogs' : 'cats'} at this age`
      }

      return { ...p, why, matched, relevance: matchScore + stageBonus }
    })
    .sort((a, b) => b.relevance - a.relevance || a.price - b.price)
}

function capitalise(s: string) {
  return s.charAt(0).toUpperCase() + s.slice(1)
}
