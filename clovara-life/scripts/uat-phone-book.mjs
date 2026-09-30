/**
 * The UAT phone book (UNBLOCKED-BUILD-PLAN UB4): every Track A step of
 * docs/UAT-PLAN.md captured at iPhone size, with what should be true beside
 * each, on one page — so the phone pass is "does yours look like this?"
 * rather than hunting for where to look. Conor still judges on his own phone.
 *
 *   BASE=https://clovara-life.web.app node scripts/uat-phone-book.mjs [out.html]
 *
 * Defaults to production and writes shots/uat-phone-book.html (gitignored).
 */
import { chromium } from 'playwright'
import { writeFile, mkdir } from 'node:fs/promises'
import { dirname } from 'node:path'

const BASE = process.env.BASE || 'https://clovara-life.web.app'
const OUT = process.argv[2] || 'shots/uat-phone-book.html'
const W = 393
const H = 852

const browser = await chromium.launch()
const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true })
const page = await ctx.newPage()
const wait = (ms) => page.waitForTimeout(ms)
const ago = (d) => new Date(Date.now() - d * 864e5).toISOString()

const bruno = (ageDays, homeDays, extra = {}) => ({
  id: 'uat-bruno', name: 'Bruno', species: 'dog', breedId: 'labrador-retriever', sex: 'male', weightLb: 70,
  conditionIds: [], birthDate: ago(ageDays).slice(0, 10), knownSince: ago(homeDays), ...extra,
})

async function seed(pet, hash) {
  await page.goto(`${BASE}/#/demo`, { waitUntil: 'networkidle' })
  await page.evaluate(([p, h]) => {
    localStorage.clear()
    localStorage.setItem('clovara-life.front-door.v1', 'seen')
    if (p) localStorage.setItem('clovara-life.pets.v1', JSON.stringify([p]))
    location.hash = h
  }, [pet, hash])
  await page.reload({ waitUntil: 'networkidle' })
  await page.evaluate(() => document.fonts.ready)
  await wait(900)
}
async function go(hash) {
  await page.evaluate((h) => { location.hash = h }, hash)
  await wait(1100)
}
/** Scrolls so the element's top sits just under the sticky header. */
async function focusOn(locator) {
  const el = typeof locator === 'string' ? page.locator(locator).first() : locator.first()
  if (await el.count()) {
    await el.evaluate((e) => {
      const y = e.getBoundingClientRect().top + window.scrollY - 76
      window.scrollTo({ top: Math.max(0, y), behavior: 'instant' })
    })
    await wait(350)
  }
}
async function top() {
  await page.evaluate(() => window.scrollTo({ top: 0, behavior: 'instant' }))
  await wait(250)
}
async function shot() {
  const buf = await page.screenshot({ type: 'jpeg', quality: 58 })
  return `data:image/jpeg;base64,${buf.toString('base64')}`
}
const heading = (text) => page.getByText(text, { exact: false })

const chapters = []
let current
const chapter = (id, title, judge, setup) => chapters.push((current = { id, title, judge, setup, steps: [] }))
const steps = []
async function step(id, action, expected, prepare) {
  await prepare()
  current.steps.push({ id, action, expected, img: await shot() })
  process.stdout.write('.')
}

// ── A0 ──────────────────────────────────────────────────────────────────────
chapter('A0', 'Before Bruno — the front door', 'Does the first screen tell you what this product is, before you have added anything?', 'Open the site in a private tab.')
await step('A0.1', 'Open clovara-life.web.app for the first time', 'The front door: "Your pet’s plan for life", one green button — "Add your dog or cat" — and "See an example first". Sign in top right.', async () => {
  await page.goto(`${BASE}/`, { waitUntil: 'networkidle' })
  await page.evaluate(() => localStorage.clear())
  await page.reload({ waitUntil: 'networkidle' })
  await page.evaluate(() => document.fonts.ready)
  await wait(700)
})
await step('A0.2', 'Tap "See an example first" (or open /#/demo)', 'Max’s day, the investor demo. The score ring’s label sits inside the ring on two lines.', async () => {
  await seed(null, '#/pet/demo-max/home')
})
await step('A0.3', 'Footer → The Data Covenant', '"The Data Covenant" — what is never done with what you tell us, plainly.', async () => {
  await go('#/covenant')
  await top()
})

// ── A1 ──────────────────────────────────────────────────────────────────────
chapter('A1', 'Day one — nine weeks old, just home', '2am, a crying puppy — is First Nights calm and specific enough? Do the step count and streak look measured?', 'Real onboarding on your phone: Add your dog or cat → A dog → Labrador → Bruno → exact date 63 days ago → Male.')
await seed(bruno(63, 0.05, { weightLb: 0 }), '#/pet/uat-bruno/life')
await step('A1.2', 'The reveal', '"LABRADOR RETRIEVER · 2 MONTHS OLD · MALE", "on track for" a range in solid green, "Currently a puppy".', top)
await step('A1.3', 'Scroll to First Nights', '"The first few hours", "Bruno has been home about 1 hour", hour-by-hour advice and when to ring a vet at any hour.', () => focusOn(heading('FIRST NIGHTS')))
await step('A1.3b', 'Just below: keep the plan', '"Bruno’s plan lives only in this browser until you save it… No card needed." with "Keep Bruno’s plan" and "Not now".', () => focusOn('#save-life'))
await step('A1.5', 'Home', 'No name in the greeting. "40% sharp — add body condition to reach 59%", the DHP / DAPP briefing, "No policy yet" as a neutral grey chip.', async () => { await go('#/pet/uat-bruno/home'); await top() })
await step('A1.7', 'Health File → Reminders', '"Put Bruno’s dates in your calendar" — the next date named, "Add to my calendar".', async () => { await go('#/health/uat-bruno'); await focusOn('section[aria-labelledby="calendar-heading"]') })
await step('A1.7b', 'Health File → Vaccinations', 'DHP / DAPP first dose "Usually now"; later doses "Later"; your vet sets the schedule.', () => focusOn('section[aria-labelledby="vaccines-heading"]'))
await step('A1.7c', 'Health File → Passport', '"6 weeks of the easy part left", 0 of 98, grouped by People, Handling, Sounds…', () => focusOn(heading('PASSPORT')))

// ── A2 ──────────────────────────────────────────────────────────────────────
chapter('A2', 'Puppyhood — thirteen weeks', 'Does "1 week left" create useful urgency, or guilt?', 'uatSeed(91, 28)')
await seed(bruno(91, 28, { weightLb: 0 }), '#/health/uat-bruno')
await step('A2.2', 'Health File → Passport', '"1 week of the easy part left".', () => focusOn(heading('PASSPORT')))
await step('A2.3', 'Health File → Vaccinations', 'Doses he should have had show "Window passed" until recorded.', () => focusOn('section[aria-labelledby="vaccines-heading"]'))

// ── A3 ──────────────────────────────────────────────────────────────────────
chapter('A3', 'One year home — the review, and Gotcha Day', 'Does the review feel like a ritual or a form?', 'uatSeed(430, 366)')
await seed(bruno(430, 366), '#/pet/uat-bruno/life')
await step('A3.1', 'Life → A year with Bruno', 'Questions never asked say "we have never asked" and offer "Answer it / Skip"; Done works at any point.', () => focusOn(heading('A year with Bruno')))
await step('A3.2', 'Life → Gotcha Day', 'A square card with the mark, "One year home.", and Save or share.', () => focusOn(heading('Gotcha Day')))

// ── A4 ──────────────────────────────────────────────────────────────────────
chapter('A4', 'Everyday life — four years old', 'Is there anything on Home you would not look at twice?', 'uatSeed(4*365+40, 4*365-23, { lastReviewedAt: 38 days ago })')
await seed(bruno(4 * 365 + 40, 4 * 365 - 23, { lastReviewedAt: ago(38) }), '#/pet/uat-bruno/home')
await step('A4.1', 'Home', '"Nothing needs doing for Bruno today. Mature adult stage…" — said plainly.', top)
await step('A4.2', 'Life → What you can change', 'Levers with evidence labels; moving one moves the range; "How we work this out" names sources.', async () => { await go('#/pet/uat-bruno/life'); await focusOn('#levers-heading') })
await step('A4.3', 'Care → the scripted conversation', 'It streams in and waits at "Send Bruno’s history to your vet". No telehealth booking anywhere.', async () => { await go('#/pet/uat-bruno/care'); await wait(4500); await focusOn(heading('Knows Bruno since')) })
await step('A4.5', 'Coverage', '"Bruno has no policy… cover cannot be bought yet"; prices labelled illustrative; "How a claim would work".', async () => { await go('#/pet/uat-bruno/coverage'); await top() })
await step('A4.5b', 'Protect → step 2, bottom', '"Cover cannot be bought yet…" before the declaration; the button stays off until you have read to the end.', async () => {
  await go('#/protect')
  await page.getByRole('button', { name: /See exactly what this covers/ }).click().catch(() => {})
  await wait(900)
  await page.evaluate(() => window.scrollTo({ top: document.body.scrollHeight, behavior: 'instant' }))
  await wait(300)
})
await step('A4.6', 'Shop', 'Each product says why it is here for Bruno; nothing claims to treat or prevent anything.', async () => { await go('#/pet/uat-bruno/shop'); await top() })
await step('A4.7', 'Rewards', 'Points follow evidence; "Monthly weigh-in logged · Monthly"; points never touch the premium.', async () => { await go('#/pet/uat-bruno/rewards'); await top() })
await step('A4.8', 'Health File → For the vet', 'A one-page summary: "Not asked" where nothing was said; no healthy-years projection.', async () => {
  await go('#/health/uat-bruno')
  await page.getByRole('button', { name: 'Read it first' }).click().catch(() => {})
  await wait(500)
  await focusOn(heading('FOR THE VET'))
})

// ── A5 ──────────────────────────────────────────────────────────────────────
chapter('A5', 'A worry', 'A5.2 is the most important screen in the product. Amber was a deliberate choice. Is it unmissable? Would you ring?', 'Continue from A4.')
async function ask(text) {
  await go('#/wrong')
  await page.getByLabel(/What are you seeing/i).fill(text)
  await page.getByRole('button', { name: 'Check it' }).click()
  await wait(900)
}
await step('A5.1', 'Something’s wrong: "He seems a bit quiet today and is sleeping more"', '"We have not spotted anything on our urgent list" — a statement about the list, never reassurance. The answer comes into view.', () => ask('He seems a bit quiet today and is sleeping more'))
await step('A5.2', 'Something’s wrong: "He collapsed in the garden and his gums look pale"', '"Stop and ring a vet now." in amber, the two matched signs, tap-to-call numbers and "Find the nearest vet open now". The answer comes into view by itself.', () => ask('He collapsed in the garden and his gums look pale'))
await step('A5.3', 'Ate something → Grapes, raisins, sultanas or currants', '"Ring now", "There is no amount of this treated as safe", no doses.', async () => {
  await go('#/ate')
  await page.getByRole('button', { name: 'Grapes, raisins, sultanas or currants' }).click()
  await wait(600)
  await focusOn(heading('Ring now'))
})
await step('A5.5', 'Health File → second opinion: "Vet recommends TPLO surgery, estimate $6,000"', 'Questions to ask the vet; it never second-guesses the recommendation or judges the price.', async () => {
  await go('#/health/uat-bruno')
  const box = page.getByPlaceholder(/recommended surgery/)
  await box.fill('Vet recommends TPLO surgery, estimate $6,000')
  await page.getByRole('button', { name: 'What should I ask?' }).click()
  await wait(600)
  await focusOn(heading('What happens if we do nothing'))
})

// ── A6 ──────────────────────────────────────────────────────────────────────
chapter('A6', 'Seven years — a condition on the record', 'Does it feel like it remembers Bruno, or like it is reading a database at you?', 'uatSeed(7*365+40, 7*365-23, { hip dysplasia })')
await seed(bruno(7 * 365 + 40, 7 * 365 - 23, { conditionIds: ['hip-dysplasia'], conditionsReviewed: true }), '#/pet/uat-bruno/care')
async function companion(q) {
  await page.getByPlaceholder(/Has Bruno been slowing down/).fill(q)
  await page.getByRole('button', { name: 'Ask', exact: true }).click()
  await wait(2600)
  await focusOn(page.getByText(q))
}
await step('A6.1', 'Care → ask "His hip seems sore after walks"', 'Fact cards, each with its source; closes "This is recall, not an opinion — we have not examined Bruno…".', () => companion('His hip seems sore after walks'))
await step('A6.2', 'Care → ask "Can I speak to a vet about this?"', '"We cannot put you through to a vet ourselves", "There is no video vet behind Clovara yet", and an "Open Bruno’s summary" link.', () => companion('Can I speak to a vet about this?'))

// ── A7 ──────────────────────────────────────────────────────────────────────
chapter('A7', 'Senior — ten and a half', 'Does it respect him, or count him down?', 'uatSeed(10.5 years, 10 years, { hip dysplasia, reviewed 20 days ago })')
await seed(bruno(Math.round(10.5 * 365), 10 * 365, { conditionIds: ['hip-dysplasia'], conditionsReviewed: true, lastReviewedAt: ago(20) }), '#/health/uat-bruno')
await step('A7.2', 'Health File → Making the house easier', 'Rugs, ramps, a thicker bed; "Worth mentioning at the next visit" as observations, none named as a condition.', () => focusOn(heading('Making the house easier')))
await step('A7.3', 'Health File → just below', '"We do not score how good your pet’s life is." No quality-of-life score, no time-left estimate anywhere.', () => focusOn(heading('We do not score')))

// ── A8 ──────────────────────────────────────────────────────────────────────
chapter('A8', 'Goodbye — twelve and a half', 'This is the hardest screen in the product. Read it as someone whose dog died yesterday.', 'uatSeed(12.5 years, 12 years), then "Bruno has died" in the Health File.')
await seed(bruno(Math.round(12.5 * 365), 12 * 365, { conditionIds: ['hip-dysplasia'], conditionsReviewed: true, lastReviewedAt: ago(20), diedOn: ago(1).slice(0, 10) }), '#/health/uat-bruno')
await step('A8.3', 'Health File, after telling us', '"Bruno’s record is still here", nothing deleted, "Undo — this was a mistake".', () => focusOn(heading('record is still here')))
await step('A8.4', 'Home', 'Quiet: his name, the record one tap away, the Remembering card, the stage he reached. No score, no prompts.', async () => { await go('#/pet/uat-bruno/home'); await top() })
await step('A8.5', 'Life', '"Bruno’s life · 12 years" and his dates; the stages he lived through. No forecast.', async () => { await go('#/pet/uat-bruno/life'); await top() })
await step('A8.5b', 'Rewards', '"Nothing is being counted for Bruno any more." and the way back to his record.', async () => { await go('#/pet/uat-bruno/rewards'); await top() })

await browser.close()
process.stdout.write('\n')

// ── The page ────────────────────────────────────────────────────────────────
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c])
const when = new Date().toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' })
const total = chapters.reduce((n, c) => n + c.steps.length, 0)
const html = `<title>Bruno’s Phone Book</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@600&family=Poppins:wght@300;400;500;600&display=swap">
<style>
:root{--bg:#F6F3EA;--card:#FFFFFF;--ink:#1B1E1B;--ink2:#5C635C;--line:#E5E1D5;--forest:#1A5C38;--sage:#E4ECE4;--amber:#935E13;--nudge:#FBF1E2;--frame:#1B1E1B}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#121513;--card:#1A1E1B;--ink:#ECEDE8;--ink2:#A9B0A8;--line:#2D332E;--forest:#8FCBA5;--sage:#233026;--amber:#E0A55B;--nudge:#2A2419;--frame:#050605;color-scheme:dark}}
:root[data-theme="dark"]{--bg:#121513;--card:#1A1E1B;--ink:#ECEDE8;--ink2:#A9B0A8;--line:#2D332E;--forest:#8FCBA5;--sage:#233026;--amber:#E0A55B;--nudge:#2A2419;--frame:#050605;color-scheme:dark}
body{background:var(--bg);color:var(--ink);font:300 15px/1.6 Poppins,system-ui,-apple-system,sans-serif;padding-inline:16px}
main{max-width:980px;margin:0 auto;padding-block:32px 64px}
h1,h2{font-family:"Playfair Display",Georgia,serif;font-weight:600;text-wrap:balance;margin:0}
h1{font-size:34px;line-height:1.1}
h2{font-size:24px;line-height:1.2}
.lede{color:var(--ink2);max-width:62ch;margin:10px 0 0}
.how{display:grid;gap:6px;margin:18px 0 0;padding:14px 16px;background:var(--card);border:1px solid var(--line);border-radius:12px;max-width:66ch}
.how b{font-weight:600}
nav{position:sticky;top:env(safe-area-inset-top,0px);z-index:2;background:var(--bg);padding-block:12px;margin-top:22px;border-bottom:1px solid var(--line);display:flex;gap:8px;overflow-x:auto}
nav a{flex:none;color:var(--ink);text-decoration:none;font-weight:500;font-size:13px;padding:6px 12px;border:1px solid var(--line);border-radius:999px;background:var(--card);font-variant-numeric:tabular-nums}
nav a:focus-visible,input:focus-visible{outline:2.5px solid var(--forest);outline-offset:2px}
section.ch{padding-top:40px;scroll-margin-top:64px}
.label{font-size:11px;font-weight:600;letter-spacing:.18em;text-transform:uppercase;color:var(--ink2)}
.judge{margin:12px 0 0;padding:12px 14px;background:var(--nudge);border-left:3px solid var(--amber);border-radius:10px;max-width:66ch}
.judge .label{color:var(--amber)}
.setup{margin:8px 0 0;color:var(--ink2);font-size:13px}
.setup code{font:12px ui-monospace,SFMono-Regular,Menlo,monospace;background:var(--card);border:1px solid var(--line);border-radius:6px;padding:1px 5px}
.steps{display:grid;gap:22px;margin-top:22px}
.step{display:grid;grid-template-columns:minmax(0,240px) minmax(0,1fr);gap:20px;align-items:start;padding:16px;background:var(--card);border:1px solid var(--line);border-radius:14px}
.phone{margin:0;background:var(--frame);border-radius:22px;padding:6px;max-width:240px}
.phone img{display:block;width:100%;height:auto;border-radius:17px;aspect-ratio:${W}/${H};max-width:100%}
.id{font-variant-numeric:tabular-nums;font-weight:600;color:var(--forest);font-size:13px}
.action{font-weight:500;margin:4px 0 0}
.expect{margin:10px 0 0;color:var(--ink2)}
.expect b{color:var(--ink);font-weight:500}
.seen{display:flex;align-items:center;gap:8px;margin-top:14px;font-size:14px;cursor:pointer}
.seen input{width:20px;height:20px;accent-color:var(--forest)}
.progress{margin-top:10px;color:var(--ink2);font-size:13px;font-variant-numeric:tabular-nums}
@media (max-width:640px){.step{grid-template-columns:1fr}.phone{max-width:260px}}
@media (prefers-reduced-motion:no-preference){html{scroll-behavior:smooth}}
</style>
<main>
  <p class="label">Clovara Life · UAT Track A</p>
  <h1>Bruno’s phone book</h1>
  <p class="lede">Every step of Track A on the live site at iPhone size (${W}×${H}), captured ${esc(when)}. Open the real app on your phone beside this: if yours looks like the picture and says what the line says, tick it. The judging — whether it is right for someone at 2am — is still yours.</p>
  <div class="how">
    <div><b>Time-travel:</b> chapters after A1 recreate Bruno at a later age. The console snippet for each is in <code>docs/UAT-PLAN.md</code> §2; its call is shown under each chapter.</div>
    <div><b>Found something?</b> Log it in <code>docs/UAT-PLAN.md</code> §8 with the step id.</div>
    <div class="progress" id="progress">0 of ${total} ticked</div>
  </div>
  <nav aria-label="Chapters">${chapters.map((c) => `<a href="#${c.id}">${c.id}</a>`).join('')}</nav>
  ${chapters.map((c) => `
  <section class="ch" id="${c.id}" aria-labelledby="h-${c.id}">
    <p class="label">${c.id}</p>
    <h2 id="h-${c.id}">${esc(c.title)}</h2>
    <p class="setup">Setup: <code>${esc(c.setup)}</code></p>
    <div class="judge"><div class="label">Judge</div>${esc(c.judge)}</div>
    <div class="steps">${c.steps.map((s) => `
      <article class="step">
        <figure class="phone"><img src="${s.img}" alt="${esc(s.id)}: ${esc(s.action)}" loading="lazy" width="${W}" height="${H}"></figure>
        <div>
          <div class="id">${esc(s.id)}</div>
          <p class="action">${esc(s.action)}</p>
          <p class="expect"><b>Should be true:</b> ${esc(s.expected)}</p>
          <label class="seen"><input type="checkbox" id="seen-${esc(s.id)}" data-step="${esc(s.id)}"> Looks right on my phone</label>
        </div>
      </article>`).join('')}
    </div>
  </section>`).join('')}
</main>
<script>
(function () {
  var KEY = 'uat-phone-book.seen.v1'
  var boxes = Array.prototype.slice.call(document.querySelectorAll('input[data-step]'))
  var seen = {}
  try { seen = JSON.parse(localStorage.getItem(KEY) || '{}') } catch (e) {}
  function count() {
    var n = boxes.filter(function (b) { return b.checked }).length
    document.getElementById('progress').textContent = n + ' of ' + boxes.length + ' ticked'
  }
  boxes.forEach(function (b) {
    b.checked = !!seen[b.dataset.step]
    b.addEventListener('change', function () {
      seen[b.dataset.step] = b.checked
      try { localStorage.setItem(KEY, JSON.stringify(seen)) } catch (e) {}
      count()
    })
  })
  count()
})()
</script>
`
await mkdir(dirname(OUT), { recursive: true })
await writeFile(OUT, html)
console.log(`wrote ${OUT} — ${total} steps, ${(html.length / 1024 / 1024).toFixed(1)} MB`)
