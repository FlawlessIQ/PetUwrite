/**
 * The review packs (UNBLOCKED-BUILD-PLAN UB1–UB3): docs/review/VET-PACK.md,
 * COUNSEL-PACK.md and EMAIL-PREVIEW.md, generated from the code that renders
 * every line in them — so what a reviewer signs off is what ships.
 *
 *   npm run review:packs          regenerate
 *   node scripts/review-packs.mjs --check   fail if any pack is stale (verify:all)
 *
 * Rolldown (already installed with Vite) bundles src/server/review-data.tsx for
 * Node; the Life functions' own email templates and pages are required directly.
 */
import { rolldown } from 'rolldown'
import { createRequire } from 'node:module'
import { mkdir, readFile, writeFile, mkdtemp, rm } from 'node:fs/promises'
import { join } from 'node:path'

const require = createRequire(import.meta.url)
const OUT = '../docs/review'
const CHECK = process.argv.includes('--check')

// ── Load the app's data ─────────────────────────────────────────────────────
const assets = {
  name: 'assets-as-urls',
  load(id) {
    // Vite serves images as URLs; the packs only need the words.
    if (/\.(svg|png|jpe?g|webp)(\?.*)?$/.test(id)) return `export default "/asset"`
    return null
  },
}
const bundle = await rolldown({
  input: 'src/server/review-data.tsx',
  platform: 'node',
  logLevel: 'silent',
  // Outside Vite there is no import.meta.env; every flag reads as unset.
  transform: { jsx: 'react-jsx', define: { 'import.meta.env': '{}' } },
  external: [/^react($|\/)/, /^react-dom($|\/)/],
  plugins: [assets],
})
const { output } = await bundle.generate({ format: 'cjs' })
await bundle.close()
// Inside the project, so the bundle resolves react from node_modules.
await mkdir('node_modules/.cache', { recursive: true })
const dir = await mkdtemp(join('node_modules/.cache', 'review-packs-'))
await writeFile(join(dir, 'data.cjs'), output[0].code)
const { reviewData } = require(join(process.cwd(), dir, 'data.cjs'))
await rm(dir, { recursive: true, force: true })
const D = reviewData()

const email = require('../functions/email.js')
const legal = require('../functions/legal.js')
const pages = require('../functions/pages.js')

// ── Helpers ─────────────────────────────────────────────────────────────────
const VERDICT = '- **Verdict:** keep · change (write the change) · discuss'
const quote = (s) => String(s).split('\n').map((l) => `> ${l}`).join('\n')
const HEAD = (title, intro) =>
  `# ${title}\n\n` +
  `*Generated from the code by \`npm run review:packs\` — do not edit by hand. ` +
  `\`verify:all\` fails if this file no longer matches what the app says, so what you sign off is what ships.*\n\n` +
  intro.trim() + '\n'
let n = 0
const item = (prefix, title, body, where, extra = []) =>
  `### ${prefix}${++n} · ${title}\n\n${quote(body)}\n\n- **Where:** ${where}\n${extra.map((e) => `- ${e}\n`).join('')}${VERDICT}\n`

// ── EMAIL-PREVIEW.md ────────────────────────────────────────────────────────
const PREFS = 'https://example.test/emailPreferences?t=SAMPLE'
const renderMail = (name, data) => email.TEMPLATES[name](data)
const mailBlock = (label, m, headers) =>
  `## ${label}\n\n**Subject:** ${m.subject}\n\n` +
  (headers ? `**Headers:** ${Object.entries(headers).map(([k, v]) => `\`${k}: ${v}\``).join(' · ')}\n\n` : '') +
  '```text\n' + m.text + '\n```\n'
const emailPreview = [
  HEAD('Every email Clovara Life can send', `
Nothing is sent today: the sender only logs until a sending domain, a key and counsel's
postal line exist (\`docs/DEPLOYMENT.md\` → Switching email on). Sample pet: **Bruno**.
Reminder emails go only to people who turned them on.`),
  mailBlock('Welcome — when a trial starts', renderMail('welcome', { petName: 'Bruno' })),
  mailBlock('Trial ending — three days out, from Stripe', renderMail('trialEnding', { petName: 'Bruno', daysLeft: 3, amountDisplay: '$22.99' })),
  mailBlock('Plan saved — once, when the first pet reaches an account', renderMail('planSaved', { petName: 'Bruno' })),
  ...D.moments.flatMap((s) =>
    s.moments.slice(0, 1).map((m) =>
      mailBlock(`Reminder — ${s.label}`, renderMail('moment', { petName: 'Bruno', subject: m.subject, lines: m.lines, preferencesUrl: PREFS }), {
        'List-Unsubscribe': `<${PREFS}>`,
        'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
      }),
    ),
  ),
].join('\n')

// ── VET-PACK.md ─────────────────────────────────────────────────────────────
n = 0
const species = (s) => (Array.isArray(s) ? (s.length ? s.join(', ') : 'dogs and cats') : s ? `${s}s only` : 'dogs and cats')
const vet = [
  HEAD('The vet pack', `
Everything in Clovara Life that a vet should read before a real owner sees it (BACKLOG **A1**,
**R1**). Each item is the exact words, where they appear, and a Verdict line. Nothing here has
been read by a vet. The rule the whole product is built on: it can tell someone to ring a vet,
it never tells them what something is, and it never tells them it is fine.

**The one thing to look at hardest:** section 2's thresholds. They are never shown to anyone —
they decide whether a poison lookup says "ring now", "vet today" or "watch" — and they are ours,
not a published source.`),
  '## 1. "Something is wrong" — the escalation ladder\n',
  item('V', 'When a sign on the list matches — headline', D.red.headline, 'The "something is wrong" screen'),
  item('V', 'When a sign matches — body', D.red.body, 'The "something is wrong" screen'),
  item('V', 'When nothing matches — headline', D.red.noFlagHeadline, 'The "something is wrong" screen', ['**Must never read as reassurance.**']),
  item('V', 'When nothing matches — body', D.red.noFlagBody, 'The "something is wrong" screen'),
  ...D.red.flags.map((f) => item('V', `Red flag: ${f.label}`, f.because, `Escalates to "Stop and ring a vet now" — ${species(f.species)}`, [`**Matched when an owner writes words like:** ${f.phrases.join(' · ')}`])),
  '## 2. "Ate something" — the poison lookup\n',
  item('V', 'First thing on the screen', D.tox.primary, 'Top of "ate something"'),
  item('V', 'Never make them sick', D.tox.neverDiy, 'Top of "ate something"'),
  item('V', 'Take the packet', D.tox.takeWithYou, 'Top of "ate something"'),
  item('V', 'Footer', D.tox.disclaimer, 'Foot of "ate something"'),
  ...D.tox.entries.map((t) =>
    item('V', t.name, `Why: ${t.why}\n\nWhat you might see: ${t.signs}`, `Poison lookup — ${species(t.species)}`, [
      `**Urgency:** ${t.alwaysCall ? 'always "ring now", at any amount' : t.thresholds ? `banded by amount — **vet today from ${t.thresholds.vetToday} mg/kg, ring now from ${t.thresholds.callNow} mg/kg of bodyweight** (never shown to anyone; it decides the band)` : 'fixed per entry'}`,
      ...(t.forms ? [`**Forms and strengths used in the calculation:** ${t.forms.map((f) => `${f.label} (${f.mgPerGram} mg/g)`).join('; ')}`] : []),
      ...(t.aka?.length ? [`**Also found by:** ${t.aka.join(', ')}`] : []),
    ]),
  ),
  item('V', 'The phone numbers offered', D.tox.lines.map((l) => `${l.name} — ${l.display}${l.note ? ` — ${l.note}` : ''}`).join('\n'), 'Both urgent screens'),
  '## 3. First Nights — the first 72 hours with a new puppy or kitten\n',
  item('V', 'When to ring, at any hour (always visible)', D.firstNight.escalation, 'First Nights, and the first-night email'),
  ...D.firstNight.blocks.map((b) =>
    item('V', `${b.title} (hours ${b.from}–${b.to}${b.species ? `, ${b.species}` : ''})`, `${b.body}\n\nDo now: ${b.doNow.join(' / ')}\n\nNormal right now: ${b.normal}`, 'First Nights'),
  ),
  item('V', 'Footer', D.firstNight.footer, 'First Nights'),
  '## 4. Vaccinations\n',
  item('V', 'What the schedule is', D.vaccines.disclaimer, 'Health File → Vaccinations'),
  ...D.vaccines.core.map((v) =>
    item('V', `${v.label} (${v.species})`, `${v.protects}\n\n${D.vaccines.doses.filter((d) => d.vaccineId === v.id).map((d) => `${d.label}: usually ${d.fromWeeks}–${d.toWeeks} weeks`).join('\n')}`, 'Health File → Vaccinations; calendar; reminder emails', v.lawDependent ? ['**Law-dependent:** shown as "depends on local law"'] : []),
  ),
  ...Object.entries(D.vaccines.nonCore).map(([sp, list]) => item('V', `Worth asking your vet about (${sp})`, list.join('\n'), 'Health File → Vaccinations')),
  '## 5. The senior suite\n',
  item('V', 'Opening', D.senior.opening, 'Health File, older pets'),
  item('V', 'The refusal to score a life', D.senior.noScale, 'Health File, older pets', ['A deliberate choice (BACKLOG P4, X2)']),
  item('V', 'Worth mentioning — the note', D.senior.mention, 'Health File, older pets'),
  ...Object.entries(D.senior.worthMentioning).map(([sp, list]) => item('V', `Worth mentioning at the next visit (${sp})`, list.join('\n'), 'Health File, older pets', ['**Must stay observations — never named as conditions**'])),
  ...D.senior.adaptations.map((a) => item('V', `Around the house: ${a.what}`, a.why, `Health File, older pets — ${species(a.species)}`)),
  '## 6. What the reminder emails say that is clinical\n',
  ...D.moments.flatMap((s) => s.moments.filter((m) => m.kind === 'first-nights' || m.kind === 'vaccine').slice(0, 1).map((m) => item('V', `Email: ${m.subject}`, m.lines.join('\n\n'), `Reminder email (${s.label})`))),
].join('\n')

// ── COUNSEL-PACK.md ─────────────────────────────────────────────────────────
n = 0
const covenant = D.covenant.filter((l) => !/^(Clovara|Back to the app)$/.test(l))
const counsel = [
  HEAD('The counsel pack', `
Everything in Clovara Life that counsel should read before a real person pays or signs up
(BACKLOG **A2**). Exact words, where they appear, and a Verdict line. **Placeholders marked
\`LEGAL-REVIEW\` are deliberately not drafted by us** — they are yours to supply.

Start with section 1: the things that do not exist yet.`),
  '## 1. What is missing entirely\n',
  item('C', 'Terms of service', 'There are none. Nothing in Life links to terms, and signing up does not ask anyone to accept any.', 'Nowhere — a gap', ['Needed before anyone pays; probably before sign-up']),
  item('C', 'Privacy policy', 'There is none. The Data Covenant (section 3) makes promises; there is no policy document behind it.', 'Nowhere — a gap'),
  item('C', 'Auto-renewal disclosure (CA/NY)', legal.autoRenewalDisclosure({ amount: '$22.99', interval: 'month', trialDays: 7 }), 'Stripe Checkout, before the card', ['Currently a marked placeholder; the final wording is yours']),
  item('C', 'The postal address in commercial email', '[LEGAL-REVIEW: postal address, required in every commercial email — counsel to supply]', 'Foot of every reminder email', ['Email cannot be switched on without it']),
  '## 2. Buying cover — the Protect flow\n',
  item('C', 'The price label', D.attach.illustrative, 'Protect, step 1'),
  item('C', 'Before the declaration', D.attach.notLive, 'Protect, step 2', ['Added after UAT run 1 (D12): says nothing can be bought before anyone ticks anything']),
  ...D.attach.waiting.map((w) => item('C', `Waiting period — ${w.label} (${w.days} days)`, w.because, 'Protect, step 2')),
  ...D.attach.disclosures.map((x) => item('C', x.heading, x.body, 'Protect, step 2 — scroll-to-enable')),
  item('C', 'Fraud notice', D.attach.fraud, 'Protect, step 2'),
  item('C', 'The declaration', D.attach.attestation, 'Protect, step 2 — the checkbox'),
  item('C', 'Membership and insurance are separate', legal.membershipSeparationNotice(), 'Checkout'),
  '## 3. The Data Covenant\n',
  item('C', 'The whole page, as it renders', covenant.join('\n\n'), '#/covenant — linked from the footer, onboarding and settings', [
    'UB12 is built ("Download everything about your pet", below): the Covenant\'s "ask us for everything" could say the pet record is self-serve — not changed until you have seen it',
  ]),
  item('C', 'Download everything about your pet — the card', D.recordCard.join('\n'), 'Health File, near the foot; shown for pets who have died too'),
  item('C', 'Download everything about your pet — what the file says about itself', `${D.recordFile.lede}\n\n${D.recordFile.footer}`, 'The downloaded page', [
    'It covers the pet record only. Not in it: live sitter links (each holds a copy of the sitter notes, which are in the file, and an expiry date), the account\'s email, email preferences and analytics events. The Covenant says "everything we hold on your pet" — whether this file answers that, or needs a line saying what it leaves out, is yours',
  ]),
  '## 4. Money and membership lines\n',
  ...D.shopMembership.map((l) => item('C', 'Shop — membership', l, 'Shop', ['Reworded in UAT run 1 (D14) from "the products that keep Bruno healthy"'])),
  item('C', 'Coverage — standing disclaimer', D.disclaimers.coverage, 'Coverage'),
  item('C', 'Rewards — standing disclaimer', D.disclaimers.rewards, 'Rewards'),
  '## 5. Claims the product makes to a new visitor\n',
  item('C', 'The front door', `${D.frontDoor.eyebrow}\n${D.frontDoor.headline}\n${D.frontDoor.body}\n${D.frontDoor.exampleNote}`, 'First visit to the site'),
  item('C', 'Keep the plan', D.saveNudge.filter((l) => !/^Keep |^Not now$/.test(l)).join('\n'), 'After the plan reveal, and Home'),
  '## 6. Email\n',
  item('C', 'Every email, rendered', 'See EMAIL-PREVIEW.md in this folder — welcome, trial ending, plan saved, and one of each reminder.', 'docs/review/EMAIL-PREVIEW.md'),
  item('C', 'Reminder opt-in (not yet shown to anyone)', 'Email me when something is due — Vaccination windows, the socialisation window, the yearly check and Gotcha Day. Never more than three a day, one tap to stop, and off unless you turn it on.', 'Account panel, once email is switched on'),
  ...['confirm', 'off', 'notRecognised'].map((k) => item('C', `Unsubscribe page — ${pages.COPY[k].title}`, [pages.COPY[k].heading, pages.COPY[k].body, pages.COPY[k].button].filter(Boolean).join('\n'), 'The link at the foot of every reminder')),
  '## 7. What data goes where — our description, for you to check against the Covenant\n',
  item('C', 'Analytics', 'Event names and simple values (never a pet name, email or free text), a random id per browser, and — on a first visit — the referring site\'s host (never the full address) and any utm tags. Stored on the device, sent to our database only once someone signs in. No third-party pixels or trackers.', 'Everywhere', ['AO13 is built, not deployed: once it is, anonymous visits also reach our database, with the same fields and no account', 'Crashes are recorded the same way (UB7): the error message with emails, links and long numbers removed, the component and the route\'s shape — never a stack']),
  item('C', 'A shared card\'s link', 'Carries only what is printed on the card — the pet\'s name, breed, age, the date and which card. Never the photo (which stays on the sharer\'s phone), an id or anything else from the record. Nothing is uploaded.', 'Arrival and Gotcha Day cards'),
  item('C', 'The calendar file', 'Made on the device and handed to the browser as a download. Nothing is sent to us or anyone else.', 'Health File → Reminders'),
  item('C', 'Owner-written text and Google', 'Switched off. Vet-record reading and conversational onboarding would send owner-written text to Google; that is decision B2, with a memo (docs/MODEL-DATA-DECISION.md).', 'Not live'),
].join('\n')

// ── Write, or check ─────────────────────────────────────────────────────────
const files = { 'EMAIL-PREVIEW.md': emailPreview, 'VET-PACK.md': vet, 'COUNSEL-PACK.md': counsel }
if (CHECK) {
  let stale = 0
  for (const [name, content] of Object.entries(files)) {
    const current = await readFile(join(OUT, name), 'utf8').catch(() => '')
    if (current !== content) {
      stale++
      console.log(`  ✗ docs/review/${name} is stale — run \`npm run review:packs\` and commit it`)
    } else console.log(`  ✓ docs/review/${name} matches the code`)
  }
  console.log(stale ? `\n${stale} failed\n` : '\nreview packs verified\n')
  process.exit(stale ? 1 : 0)
}
await mkdir(OUT, { recursive: true })
for (const [name, content] of Object.entries(files)) await writeFile(join(OUT, name), content)
console.log(`wrote ${Object.keys(files).map((f) => `docs/review/${f}`).join(', ')}`)
