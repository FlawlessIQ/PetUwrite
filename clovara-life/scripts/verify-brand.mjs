/**
 * The brand, held to docs/DESIGN.md — the parts a machine can check.
 *
 * §1 is "one mark file, no drift", and before the UI pass there were four
 * redrawn clovers in circulation: the app's CloverMark component, the favicon,
 * the partner walkthrough's inline <symbol>, and the share card's canvas
 * drawing — plus the icon generator that produced a fifth. Each was written by
 * somebody who needed a mark and did not have the file to hand.
 *
 * §2 renamed `muted` to `ink-2` and unified `line`. Both are the kind of change
 * that quietly reverts the first time somebody copies an old snippet.
 *
 * Static: reads the source and public/, no browser, no build.
 */
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const CANONICAL = resolve(ROOT, '../assets/images/clovara_mark_refined.svg')

let failures = 0
const ok = (label, offenders = []) => {
  if (offenders.length === 0) console.log(`  ✓ ${label}`)
  else {
    failures++
    console.log(`  ✗ ${label}`)
    for (const o of offenders.slice(0, 6)) console.log(`      ${o}`)
  }
}

const walk = (dir, exts, out = []) => {
  for (const e of readdirSync(dir)) {
    const p = join(dir, e)
    if (e === 'node_modules' || e === 'dist') continue
    if (statSync(p).isDirectory()) walk(p, exts, out)
    else if (exts.some((x) => p.endsWith(x))) out.push(p)
  }
  return out
}
const rel = (p) => p.replace(`${ROOT}/`, '')
/** Line comments are stripped first: "was #E6E1D6" in a comment is history, not use. */
const grep = (files, re) =>
  files.flatMap((f) =>
    readFileSync(f, 'utf8')
      .split('\n')
      .map((line, i) => (re.test(line.replace(/(^|\s)\/\/.*$/, '')) ? `${rel(f)}:${i + 1}` : null))
      .filter(Boolean),
  )

const canonical = readFileSync(CANONICAL)

console.log('\n§1 — one mark file')
for (const copy of ['public/favicon.svg', 'public/partners/mark.svg']) {
  const same = readFileSync(resolve(ROOT, copy)).equals(canonical)
  ok(`${copy} is byte-for-byte the canonical`, same ? [] : [`${copy} differs — re-run \`npm run icons\`, never edit it`])
}

const code = [
  ...walk(resolve(ROOT, 'src'), ['.ts', '.tsx', '.css']),
  ...walk(resolve(ROOT, 'public'), ['.html', '.js', '.svg']),
  ...walk(resolve(ROOT, 'scripts'), ['.mjs']).filter((f) => !f.endsWith('verify-brand.mjs')),
].filter((f) => !f.endsWith('favicon.svg') && !f.endsWith('mark.svg'))

// Every signature of a clover somebody drew by hand, as found in this codebase.
ok('no redrawn clover anywhere in src/, public/ or scripts/', grep(code, /cloverMark|cloverHoles|drawClover|LOBE_R|HOLE_R|8\.6,8\.6/))

const cloverMark = readFileSync(resolve(ROOT, 'src/components/CloverMark.tsx'), 'utf8')
ok(
  'the app component imports the canonical file rather than drawing',
  /from '\.\.\/\.\.\/\.\.\/assets\/images\/clovara_mark_refined\.svg'/.test(cloverMark) && !/<path/.test(cloverMark)
    ? []
    : ['src/components/CloverMark.tsx no longer imports clovara_mark_refined.svg, or has grown a <path>'],
)

console.log('\n§2 — token names and values')
const styled = walk(resolve(ROOT, 'src'), ['.ts', '.tsx', '.css'])
ok('`muted` is gone — it is `ink-2`', grep(styled, /(?:text|fill|stroke|bg|border|placeholder|ring)-muted\b/))
ok('no retired hex values (#6B716C muted, #E6E1D6 old line)', grep([...styled, resolve(ROOT, 'tailwind.config.js'), resolve(ROOT, 'scripts/make-icons.mjs')], /#6B716C|#E6E1D6/i))

const tw = readFileSync(resolve(ROOT, 'tailwind.config.js'), 'utf8')
const want = {
  cream: '#F6F3EB', 'cream-2': '#EFEBE0', card: '#FFFFFF', line: '#E5E1D5', ink: '#1B1E1B',
  'ink-2': '#5C635C', 'ink-3': '#8A918A', forest: '#1A5C38', deep: '#0F3D26', sage: '#E4EAE0',
  'sage-2': '#D5DFD0', accent: '#D98A26', amber: '#B27117', 'nudge-fill': '#FBF4E7', track: '#EDEAE0',
}
ok(
  'tailwind.config.js carries exactly the §2 values',
  Object.entries(want)
    .filter(([k, v]) => !new RegExp(`['"]?${k}['"]?:\\s*'${v}'`, 'i').test(tw))
    .map(([k, v]) => `${k} should be ${v}`),
)

console.log(`\n${failures === 0 ? 'brand verified' : `${failures} failed`}\n`)
process.exit(failures === 0 ? 0 : 1)
