/**
 * The customer vocabulary, enforced over every string in the app.
 *
 * docs/VISION.md sets vocabulary rules, and several SPEC §2 invariants are in
 * the end rules about words: no treatment claim on a product, points never
 * redeemable against a premium, never a diagnosis, never a promise of a longer
 * life. Until now those lived in prose and in whichever file happened to have a
 * test of its own — which is exactly how three claims drifted onto the journey
 * map unnoticed. `verify-journey.mjs` is this same idea for that file.
 *
 * It reads the source, throws away comments and machine strings, and holds what
 * is left to the rules. Where a rule fires on real copy it should be scoped
 * with the reason written down, never deleted — every scope below says why.
 *
 * Lives here rather than in `src/*.test.ts` because the app's tsconfig has no
 * node types, and giving it them so a test can read the filesystem would open
 * the app itself to node imports.
 */
import { readdirSync, readFileSync, statSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const SRC = resolve(dirname(fileURLToPath(import.meta.url)), '../src')

let failures = 0
const ok = (label, offenders = []) => {
  if (offenders.length === 0) console.log(`  ✓ ${label}`)
  else {
    failures++
    console.log(`  ✗ ${label}`)
    for (const o of offenders.slice(0, 6)) console.log(`      ${o}`)
    if (offenders.length > 6) console.log(`      … and ${offenders.length - 6} more`)
  }
}

function sourceFiles(dir, out = []) {
  for (const entry of readdirSync(dir)) {
    const p = join(dir, entry)
    if (statSync(p).isDirectory()) sourceFiles(p, out)
    else if (/\.(ts|tsx)$/.test(p) && !/\.test\.tsx?$/.test(p)) out.push(p)
  }
  return out
}

/** Class names, ids, hex colours and import paths are not copy. */
const isMachine = (s) =>
  /^[\w./@-]+$/.test(s) ||
  /^#[0-9a-f]{3,8}$/i.test(s) ||
  /^\d[\d\s.,%-]*$/.test(s) ||
  /(^|\s)(text-|bg-|px-|py-|mt-|mb-|ml-|mr-|pt-|pb-|flex|grid|rounded|border|font-|leading-|gap-|w-|h-|absolute|relative|inline|block|hidden|shrink|space-|divide-|overflow|items-|justify-|min-|max-|sm:|md:|lg:|opacity-|transition|translate|rotate|top-|left-|right-|bottom-|z-|aria-|data-)/.test(
    s,
  )

/** Comments carry the reasoning, including the banned words themselves. */
const withoutComments = (src) =>
  src.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/(^|[^:])\/\/[^\n]*/g, '$1 ')

const COPY = []
for (const file of sourceFiles(SRC)) {
  withoutComments(readFileSync(file, 'utf8'))
    .split('\n')
    .forEach((line, i) => {
      const literals = [
        ...(line.match(/'((?:[^'\\]|\\.){6,}?)'/g) ?? []),
        ...(line.match(/"((?:[^"\\]|\\.){6,}?)"/g) ?? []),
        ...(line.match(/`((?:[^`\\]|\\.){6,}?)`/g) ?? []),
      ].map((s) => s.slice(1, -1))
      const jsxText = (line.match(/>([^<>{}]{8,})</g) ?? []).map((s) => s.slice(1, -1).trim())
      for (const text of [...literals, ...jsxText])
        if (text.trim() && /\s/.test(text) && !isMachine(text))
          COPY.push({ file: file.replace(`${SRC}/`, 'src/'), line: i + 1, text })
    })
}

const at = (c) => `${c.file}:${c.line} — ${c.text.slice(0, 110)}`
const breaking = (re, within = COPY) => within.filter((c) => re.test(c.text)).map(at)

/**
 * Some rules are about asserting a thing rather than mentioning it. The product
 * says "it will not tell you whether it grew" and "comfort, not a safety
 * device", and both must pass — so those rules read clause by clause, and a
 * clause carrying a refusal is not an assertion.
 */
const REFUSAL = /\b(never|not|no|nothing|without|cannot|can't|won't|rather than|instead of)\b/i
const asserting = (re, within = COPY) =>
  within
    .filter((c) => c.text.split(/[.;—:]/).some((cl) => re.test(cl) && !REFUSAL.test(cl)))
    .map(at)

console.log('\nThe extractor itself')
// If extraction breaks, every rule below passes on an empty list.
ok(
  `${COPY.length} customer strings across ${sourceFiles(SRC).length} files`,
  COPY.length > 1500 ? [] : [`only ${COPY.length} strings found — extraction is broken`],
)

console.log('\nVISION vocabulary')
ok('never "lifecycle"', breaking(/\blifecycle\b/i))
ok('never "platform"', breaking(/\bplatform\b/i))
// "Wellness rider" is the filed coverage; "wellness visit" is what a vet calls
// the appointment. Neither is wellness-as-a-category, which is what VISION bars.
ok('never "wellness" on its own', breaking(/\bwellness\b(?! (rider|visit|copay))/i))

console.log('\nNever promise a longer life')
ok('no "live longer"', breaking(/\b(live|living|lives) longer\b/i))
ok('no "extends her life"', breaking(/\bextends? (her|his|their|its) life\b/i))
ok('no "adds years"', breaking(/\b(adds?|gains?|buys?|earns?) [a-z-]{0,12} ?years\b/i))
// "More good years" is the sanctioned phrase. "More years" is not.
ok('no "more years" without "good"', breaking(/\b(more|extra) (?!good )[a-z-]{0,12} ?years\b/i))
ok('no guarantee language', breaking(/\b(guarantee|guaranteed|we ensure|proven to)\b/i))
// Neutering genuinely is associated with longer life in large datasets, and
// saying so is citing evidence rather than promising an outcome. The difference
// is the attribution, so the attribution is what gets checked.
ok(
  '"longer life" only ever as something a study found',
  COPY.filter(
    (c) =>
      /\blonger (life|lives)\b/i.test(c.text) &&
      !/\b(associated with|correlated|linked to|studies?|datasets?|evidence)\b/i.test(c.text),
  ).map(at),
)

console.log('\nInvariant 1 — points never redeem against a premium')
ok(
  'nothing links points, rewards or streaks to a premium',
  COPY.filter((c) =>
    c.text
      .split(/[.;—:]/)
      .some(
        (cl) =>
          /\b(points?|rewards?|streaks?)\b/i.test(cl) &&
          /\b(premium|deductible|excess)\b/i.test(cl) &&
          !REFUSAL.test(cl),
      ),
  ).map(at),
)

console.log('\nInvariant 3 — no treatment claim on a product')
const shop = COPY.filter((c) => /products\.ts$/.test(c.file))
ok('the shop copy is still being read', shop.length > 40 ? [] : [`only ${shop.length} strings`])
ok('nothing cures, heals, reverses or eliminates', asserting(/\b(cures?|heals?|reverses?|eliminates?)\b/i, shop))
// "Prevents" and "treats" are drug verbs. products.ts reserves its strongest
// language for toothbrushing, weight management and measured feeding, and frames
// everything else as used alongside the thing it relates to.
ok('nothing prevents or treats', asserting(/\b(prevents?|treats?)\b/i, shop))

console.log('\nInvariant 4 — never diagnoses')
/**
 * Scoped to the surfaces that answer an owner describing a symptom, because that
 * is the only place these constructions would be a diagnosis. Breed reference
 * content uses the same words about a *named condition*: the zinc-responsive
 * dermatosis card says "it looks like an allergy but responds to something quite
 * different", where "it" is the condition and the point is to send somebody to a
 * vet with a possibility worth naming. Banning that would delete reference
 * content to satisfy a regex.
 */
const conversational = COPY.filter(
  (c) =>
    /(companion|grounding|safety|verification|secondOpinion|SomethingWrong|AskCompanion)\.tsx?$/i.test(c.file) ||
    // The conversation kit (DESIGN.md §5b) renders every companion reply.
    /\/companion\//.test(c.file) ||
    // …and the scripted thread it renders is written here. It was outside this
    // rule's scope, which is how "fits that picture" survived until D-UI7.
    /engine\/platform\.ts$/.test(c.file),
)
ok(
  'the conversational surfaces are still being read',
  conversational.length > 30 ? [] : [`only ${conversational.length} strings`],
)
ok('no "it sounds like" / "most likely"', asserting(/\bit (sounds|looks) like\b|\bmost likely\b/i, conversational))
ok('no "we think she has"', asserting(/\bwe (think|believe) (she|he|they|it) (has|have)\b/i, conversational))
ok('no "probably a …"', asserting(/\b(probably|likely) (a|an|the) [a-z]/i, conversational))
// Linking what an owner describes to a condition, without naming it as such.
ok('no "fits that picture" / "consistent with"', asserting(/\bfits (that|this|the) picture\b|\bconsistent with (a|an|the|that|this)\b|\bpoints to (a|an)\b/i, conversational))

console.log(`\n${failures === 0 ? 'copy verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
