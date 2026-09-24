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
// "will not tell you whether it grew" is a refusal, not a hedge. A promise about
// the future hedges; a promise never to do something is the opposite.
const HEDGE = /\b(will|would)\b(?! not\b)|\b(one day|eventually|the endgame|blue-sky)\b/i
const built = moments.filter((m) => m.horizon === 'built')
ok(`${built.length} moments claim "built"`, built.length > 0)
ok(
  'and none of them is hedged — a hedge means it is not built',
  built.every((m) => !HEDGE.test(m.desc)),
  built
    .filter((m) => HEDGE.test(m.desc))
    .map((m) => m.name)
    .join(', '),
)

console.log('\nWhat the map claims is finished, against the flags in the code')
/**
 * The map said "built" for four features the week they shipped and described
 * three of them by capabilities we had deliberately declined — a cost range, an
 * auto-refill, drug interaction warnings — while a fifth claimed a video vet
 * that `TELEHEALTH_AVAILABLE` says does not exist.
 *
 * So the flags are read out of the engines rather than trusted from memory. A
 * claim gated on a flag may sit at `next` or `sky` forever; it may not sit at
 * `built` while its flag is false.
 */
const flag = (file, name) => {
  const src = readFileSync(resolve(here, `../src/engine/${file}`), 'utf8')
  const m = src.match(new RegExp(`export const ${name}\\s*=\\s*(true|false)`))
  if (!m) throw new Error(`${name} not found in ${file} — the guard is stale, not the map`)
  return m[1] === 'true'
}
const GATED = [
  ['telehealth.ts', 'TELEHEALTH_AVAILABLE', /video vet|telehealth|books? a vet|vet on screen/i],
  ['renewal.ts', 'RENEWAL_EXPLAINED_ENABLED', /at renewal[:,]/i],
  ['briefing.ts', 'BRIEFING_EMAIL_ENABLED', /\binbox\b|\be-?mail(ed|s)?\b|in your mail/i],
]
for (const [file, name, re] of GATED) {
  const on = flag(file, name)
  const claimed = built.filter((m) => re.test(m.desc)).map((m) => m.name)
  ok(
    `${name} is ${on} — ${on ? 'anything may claim it' : 'nothing may claim it as built'}`,
    on || claimed.length === 0,
    claimed.join(', '),
  )
}

console.log('\nThings the product refuses permanently, which no horizon makes true')
// These are not unbuilt. They are refusals: each one would have the product
// advising on drugs, measuring what two handheld photos cannot measure, or
// naming what something is. A "sky" horizon does not make them roadmap items.
/**
 * Checked clause by clause, because the map is allowed — encouraged — to name a
 * refusal: "it will not tell you whether it grew" contains the forbidden claim
 * and is the opposite of making it. A clause carrying a refusal marker passes;
 * the same words asserted plainly do not.
 */
const REFUSES = /\b(never|not|no|without|cannot|can't|won't|refus)/i
const asserting = (re) =>
  moments
    .filter((m) =>
      m.desc
        .split(/[.;—:]/)
        .some((clause) => re.test(clause) && !REFUSES.test(clause)),
    )
    .map((m) => m.name)

for (const [rule, re] of [
  ['no interaction or dosing advice', /interaction warning|dosing advice|adjusts? (her |the )?dose|when to (skip|stop) a dose/i],
  ['never says whether a lump grew', /\b(whether|if) it (grew|has grown)\b|measures? the lump|growth rate/i],
  ['never names what something is', /tells you what (it|she) has|identifies the condition|diagnoses her/i],
  ['never estimates remaining time', /how long (she|he|they) (has|have) left|time she has left|remaining time/i],
]) {
  ok(rule, asserting(re).length === 0, asserting(re).join(', '))
}

console.log(
  `\n${failures === 0 ? `journey map verified — ${moments.length} moments across ${STAGES.length} stages` : `${failures} failed`}\n`,
)
process.exit(failures === 0 ? 0 : 1)
