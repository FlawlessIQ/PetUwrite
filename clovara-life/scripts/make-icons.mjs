import { chromium } from 'playwright'
import { copyFileSync, mkdirSync, readFileSync } from 'node:fs'
import { resolve } from 'node:path'

/**
 * Every raster and copy of the Clovara mark, derived from the one canonical file.
 *
 *   public/favicon.svg          — a byte-for-byte copy of the canonical
 *   public/partners/mark.svg    — ditto, for the partner hub
 *   public/apple-touch-icon.png — 180×180, rendered from the canonical
 *   public/og.png               — 1200×630 share card, ditto
 *
 * docs/DESIGN.md §1: "every rendering of the clover derives from
 * assets/images/clovara_mark_refined.svg. Redrawing is prohibited." This script
 * used to draw its own circle-built clover; now it only ever places the file.
 * `scripts/verify-bundle.mjs` fails if a copy stops matching.
 *
 * Rendered through Playwright's Chromium and the same self-hosted fonts the app
 * uses. Re-run with `npm run icons` if the brand changes.
 */

const LAUNCH = process.env.PW_EXECUTABLE ? { executablePath: process.env.PW_EXECUTABLE } : {}
const OUT = 'public'
const CANONICAL = resolve('../assets/images/clovara_mark_refined.svg')
mkdirSync(OUT, { recursive: true })

// The copies. Copied, never edited.
copyFileSync(CANONICAL, `${OUT}/favicon.svg`)
copyFileSync(CANONICAL, `${OUT}/partners/mark.svg`)
console.log('copied canonical → favicon.svg, partners/mark.svg')

const MARK = 'data:image/svg+xml;base64,' + readFileSync(CANONICAL).toString('base64')

/**
 * Fonts are inlined as data URIs. They used to be file:// URLs, which Chromium
 * refuses to load into a page set with setContent() — so og.png silently
 * rendered in Times and the system sans for as long as it existed. DESIGN.md §3:
 * no system-font fallthrough. The script now also fails if a face is missing.
 */
const fontFile = (pkg, name) =>
  'data:font/woff2;base64,' +
  readFileSync(resolve(`node_modules/@fontsource/${pkg}/files/${name}.woff2`)).toString('base64')

const FONT_CSS = `
  @font-face { font-family:'Playfair Display'; font-weight:500; font-style:normal;
    src:url('${fontFile('playfair-display', 'playfair-display-latin-500-normal')}') format('woff2'); }
  @font-face { font-family:'Playfair Display'; font-weight:600; font-style:normal;
    src:url('${fontFile('playfair-display', 'playfair-display-latin-600-normal')}') format('woff2'); }
  @font-face { font-family:'Playfair Display'; font-weight:700; font-style:normal;
    src:url('${fontFile('playfair-display', 'playfair-display-latin-700-normal')}') format('woff2'); }
  @font-face { font-family:'Playfair Display'; font-weight:500; font-style:italic;
    src:url('${fontFile('playfair-display', 'playfair-display-latin-500-italic')}') format('woff2'); }
  @font-face { font-family:'Poppins'; font-weight:400; font-style:normal;
    src:url('${fontFile('poppins', 'poppins-latin-400-normal')}') format('woff2'); }
  @font-face { font-family:'Poppins'; font-weight:500; font-style:normal;
    src:url('${fontFile('poppins', 'poppins-latin-500-normal')}') format('woff2'); }
`

/** The canonical mark at a given size. Never recoloured, never redrawn. */
const CLOVER = (size) => `<img src="${MARK}" width="${size}" height="${size}" alt="">`

const OG = `<!doctype html><html><head><meta charset="utf-8"><style>
  ${FONT_CSS}
  *{margin:0;padding:0;box-sizing:border-box}
  body{width:1200px;height:630px;background:#F6F3EB;font-family:Poppins,sans-serif;
       display:flex;flex-direction:column;justify-content:space-between;
       padding:70px 76px;position:relative;overflow:hidden}
  .brand{display:flex;align-items:center;gap:13px}
  .brand span{font-family:'Playfair Display',serif;font-size:34px;font-weight:700;
              letter-spacing:-.02em;color:#1B1E1B}
  .brand i{font-weight:500;font-style:italic;color:#1A5C38}
  h1{font-family:'Playfair Display',serif;font-size:70px;font-weight:600;line-height:1.06;
     letter-spacing:-.02em;color:#1B1E1B;max-width:15ch}
  .range{font-family:'Playfair Display',serif;font-size:64px;font-weight:600;line-height:1;
         background:linear-gradient(140deg,#D98A26,#8FA83E 48%,#1E7A46);
         -webkit-background-clip:text;background-clip:text;color:transparent}
  .sub{font-size:22px;color:#5C635C;margin-top:16px;max-width:38ch;line-height:1.5}
  .foot{display:flex;align-items:flex-end;justify-content:space-between}
  .arc{position:absolute;right:56px;bottom:74px}
</style></head><body>
  <div class="brand">${CLOVER(30)}<span>Clovara <i>Life</i></span></div>
  <div>
    <div class="range">12&ndash;14 healthy years</div>
    <h1>Your pet's healthy years, mapped.</h1>
    <p class="sub">A projection built from published veterinary data, and a care plan that adapts as they age.</p>
  </div>
  <div class="foot"><div></div></div>
  <svg class="arc" width="470" height="250" viewBox="0 0 560 300">
    <path d="M20,250 Q280,40 540,250" fill="none" stroke="#EDEAE0" stroke-width="14" stroke-linecap="round"/>
    <path d="M20,250 Q280,40 540,250" fill="none" stroke="url(#g2)" stroke-width="14"
          stroke-linecap="round" pathLength="1" stroke-dasharray="0.62 1"/>
    <defs><linearGradient id="g2" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#D98A26"/><stop offset="48%" stop-color="#8FA83E"/>
      <stop offset="100%" stop-color="#1E7A46"/></linearGradient></defs>
    <circle cx="342" cy="151" r="18" fill="#FFFFFF"/><circle cx="342" cy="151" r="9.5" fill="#1A5C38"/>
  </svg>
</body></html>`

const ICON = `<!doctype html><html><head><meta charset="utf-8"><style>
  *{margin:0;padding:0}
  body{width:180px;height:180px;background:#F6F3EB;display:flex;
       align-items:center;justify-content:center}
</style></head><body>${CLOVER(90)}</body></html>`

const browser = await chromium.launch(LAUNCH)

for (const [html, size, file] of [
  [OG, { width: 1200, height: 630 }, `${OUT}/og.png`],
  [ICON, { width: 180, height: 180 }, `${OUT}/apple-touch-icon.png`],
]) {
  const page = await browser.newPage({ viewport: size, deviceScaleFactor: 1 })
  await page.setContent(html, { waitUntil: 'load' })
  await page.evaluate(() => document.fonts.ready)
  // Refuse to write an image that fell through to a system face.
  const missing = await page.evaluate(async () => {
    const want = ['700 34px "Playfair Display"', '600 70px "Playfair Display"', '400 22px Poppins']
    const out = []
    for (const f of want) {
      await document.fonts.load(f)
      if (!document.fonts.check(f)) out.push(f)
    }
    return out
  })
  if (missing.length) throw new Error(`${file}: fonts did not load — ${missing.join(', ')}`)
  await page.waitForTimeout(200)
  await page.screenshot({ path: file })
  await page.close()
  console.log('wrote', file)
}

await browser.close()
