/**
 * The journey map, checked against the promises the product actually makes.
 *
 * `public/partners/journey-data.js` is the single source of truth for the
 * partner map (CLAUDE.md), which means it is customer-facing copy that no
 * component test covers. Three separate claims drifted past the Data Covenant
 * and the VISION vocabulary before anybody read the file end to end:
 *
 *  - a premium reflecting "what her care this year kept it from being"
 *  - points mapping to "what actually adds healthy years"
 *  - member data that "adds healthy years for every dog"
 *
 * Each was a promise the product is not allowed to make, sitting three lines
 * from the moment promising the opposite. Reading the file carefully is not a
 * control; this is.
 *
 * No browser, no build — it reads the source of truth directly.
 */
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const here = dirname(fileURLToPath(import.meta.url))
const FILE = resolve(here, '../public/partners/journey-data.js')
const src = readFileSync(FILE, 'utf8')
const STAGES = new Function(`${src}; return STAGES`)()

let failures = 0
const ok = (label, cond, detail = '') => {
  if (cond) console.log(`  ✓ ${label}`)
  else {
    failures++
    console.log(`  ✗ ${label}${detail ? ' — ' + detail : ''}`)
  }
}

const moments = STAGES.flatMap((s) =>
  s.moments.map(([name, desc, pillar, horizon, value]) => ({
    stage: s.name,
    name,
    desc,
    pillar,
    horizon,
    value,
    len: s.moments.find((m) => m[0] === name).length,
  })),
)
/** Where a rule is broken, name the moment — a count is not actionable. */
const breaking = (re) => moments.filter((m) => re.test(m.desc)).map((m) => m.name)

console.log('\nShape')
ok('every stage has a name, an age and a job', STAGES.every((s) => s.name && s.age && s.job))
ok('every moment is a 5-tuple', moments.every((m) => m.len === 5), String(moments.length))
ok(
  'pillars are Plan, Care or Protect',
  moments.every((m) => ['Plan', 'Care', 'Protect'].includes(m.pillar)),
)
ok(
  'horizons are built, launch, next or sky',
  moments.every((m) => ['built', 'launch', 'next', 'sky'].includes(m.horizon)),
)
ok(
  'values are growth, love, habit, revenue or data',
  moments.every((m) => ['growth', 'love', 'habit', 'revenue', 'data'].includes(m.value)),
)
ok('no two moments share a name', new Set(moments.map((m) => m.name)).size === moments.length)
ok(
  'every description is a real sentence',
  moments.every((m) => m.desc.length > 30 && m.desc.trim().endsWith('.')),
  breaking(/^.{0,30}$/).join(', '),
)

console.log('\nVISION vocabulary (docs/VISION.md)')
for (const [rule, re] of [
  ['never "lifecycle"', /lifecycle/i],
  ['never "platform"', /platform/i],
  ['never standalone "wellness"', /\bwellness\b(?! rider)/i],
]) {
  ok(rule, breaking(re).length === 0, breaking(re).join(', '))
}

console.log('\nNever promise a longer life')
// "more good years" is the sanctioned phrase; "more years" is not, and neither
// is anything that *adds* them. A projection is a range that moves, not a gift.
for (const [rule, re] of [
  ['no "adds years" in any form', /\b(adds?|added|adding|gains?|buys?) [a-z-]* ?years\b/i],
  ['no "more years" without "good"', /\b(more|extra) (?!good )[a-z-]* ?years\b/i],
  ['no "live longer" / "longer life"', /live longer|longer (life|lives)/i],
  ['no guarantee language', /\b(guarantee|guaranteed|ensures?|proven to|will add)\b/i],
]) {
  ok(rule, breaking(re).length === 0, breaking(re).join(', '))
}
// The noun does not have to be adjacent — "real healthy-years and
// lifetime-cost expectations" is fine — but it has to be there. What is being
// caught is healthy years as a thing handed over rather than a range estimated.
const FRAMED = /healthy[- ]years?\b[^.]{0,60}?(projection|outlook|expectation|range|figure|estimate)/i
const unframed = moments
  .filter((m) => /healthy[- ]years?/i.test(m.desc))
  .filter((m) => !FRAMED.test(m.desc))
ok(
  'healthy years always appear as a projection, outlook, range or expectation',
  unframed.length === 0,
  unframed.map((m) => m.name).join(', '),
)

console.log('\nThe Data Covenant, which the map has to agree with')
const covenant = moments.find((m) => m.name === 'The Data Covenant')
ok('the covenant is still on the map', !!covenant)
ok('and still claims to be built', covenant?.horizon === 'built')
ok(
  'and still says never against a claim or a premium',
  /never against an individual claim or premium/i.test(covenant?.desc ?? ''),
)

// The promise is symmetrical: data may not raise a price, and may not lower one
// as a reward either. A moment may mention a price only to refuse the link, or
// to describe the separate filed programme that is allowed to make it.
const priced = moments.filter((m) => /premium|\bprice\b|\brates?\b/i.test(m.desc))
const earned = priced.filter(
  (m) =>
    /\b(care|behaviour|behavior|streaks?|score|tracker|companion|engagement|reward)\b/i.test(
      m.desc,
    ) && !/\b(never|not in it|filed)\b/i.test(m.desc),
)
ok(
  'no moment links data or behaviour to a price outside a filed programme',
  earned.length === 0,
  earned.map((m) => m.name).join(', '),
)
ok(
  'and the moment that does is explicitly filed and state-approved',
  priced
    .filter((m) => /\bearns? the price\b/i.test(m.desc))
    .every((m) => /filed/i.test(m.desc) && /state-approved|regulator/i.test(m.desc)),
)

console.log('\nWhat the map claims is finished')
const built = moments.filter((m) => m.horizon === 'built')
ok(`${built.length} moments claim "built"`, built.length > 0)
ok(
  'and none of them is hedged — a hedge means it is not built',
  built.every((m) => !/\b(will|would|one day|eventually|the endgame|blue-sky)\b/i.test(m.desc)),
  built
    .filter((m) => /\b(will|would|one day|eventually|the endgame|blue-sky)\b/i.test(m.desc))
    .map((m) => m.name)
    .join(', '),
)

console.log(
  `\n${failures === 0 ? `journey map verified — ${moments.length} moments across ${STAGES.length} stages` : `${failures} failed`}\n`,
)
process.exit(failures === 0 ? 0 : 1)
