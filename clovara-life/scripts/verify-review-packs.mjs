/**
 * The vet and counsel packs quote the code. If the code changes and the packs
 * are not regenerated, a reviewer would be signing off words that no longer
 * ship — this fails (UNBLOCKED-BUILD-PLAN UB1–UB3).
 */
process.argv.push('--check')
await import('./review-packs.mjs')
