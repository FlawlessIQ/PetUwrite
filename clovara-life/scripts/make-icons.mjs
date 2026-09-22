import { chromium } from 'playwright'
import { mkdirSync } from 'node:fs'
import { resolve } from 'node:path'

/**
 * Generates public/og.png (1200×630) and public/apple-touch-icon.png (180×180).
 *
 * Rendered through the same headless Chromium and the same self-hosted fonts the
 * app uses, so the share card cannot drift from the product. Re-run with
 * `npm run icons` if the brand changes.
 */

const EXE = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome'
const OUT = 'public'
mkdirSync(OUT, { recursive: true })

const fontFile = (pkg, name) =>
  'file://' + resolve(`node_modules/@fontsource/${pkg}/files/${name}.woff2`)

const FONT_CSS = `
  @font-face { font-family:'Playfair Display'; font-weight:500; font-style:normal;
    src:url('${fontFile('playfair-display', 'playfair-display-latin-500-normal')}') format('woff2'); }
  @font-face { font-family:'Playfair Display'; font-weight:600; font-style:normal;
    src:url('${fontFile('playfair-display', 'playfair-display-latin-600-normal')}') format('woff2'); }
  @font-face { font-family:'Playfair Display'; font-weight:500; font-style:italic;
    src:url('${fontFile('playfair-display', 'playfair-display-latin-500-italic')}') format('woff2'); }
  @font-face { font-family:'Poppins'; font-weight:400; font-style:normal;
    src:url('${fontFile('poppins', 'poppins-latin-400-normal')}') format('woff2'); }
  @font-face { font-family:'Poppins'; font-weight:500; font-style:normal;
    src:url('${fontFile('poppins', 'poppins-latin-500-normal')}') format('woff2'); }
`

const CLOVER = (size, id) => `
<svg width="${size}" height="${size}" viewBox="0 0 48 48">
  <defs>
    <linearGradient id="${id}" x1="8%" y1="0%" x2="82%" y2="100%">
      <stop offset="0%" stop-color="#D98A26"/><stop offset="48%" stop-color="#8FA83E"/>
      <stop offset="100%" stop-color="#1E7A46"/>
    </linearGradient>
  </defs>
  <path fill="url(#${id})" fill-rule="evenodd" d="M15.4,15.6a8.6,8.6 0 1,0 17.2,0a8.6,8.6 0 1,0 -17.2,0 M23.8,24a8.6,8.6 0 1,0 17.2,0a8.6,8.6 0 1,0 -17.2,0 M15.4,32.4a8.6,8.6 0 1,0 17.2,0a8.6,8.6 0 1,0 -17.2,0 M7,24a8.6,8.6 0 1,0 17.2,0a8.6,8.6 0 1,0 -17.2,0 M21.5,14a2.5,2.5 0 1,0 5,0a2.5,2.5 0 1,0 -5,0 M31.5,24a2.5,2.5 0 1,0 5,0a2.5,2.5 0 1,0 -5,0 M21.5,34a2.5,2.5 0 1,0 5,0a2.5,2.5 0 1,0 -5,0 M11.5,24a2.5,2.5 0 1,0 5,0a2.5,2.5 0 1,0 -5,0"/>
</svg>`

const OG = `<!doctype html><html><head><meta charset="utf-8"><style>
  ${FONT_CSS}
  *{margin:0;padding:0;box-sizing:border-box}
  body{width:1200px;height:630px;background:#F6F3EB;font-family:Poppins,sans-serif;
       display:flex;flex-direction:column;justify-content:space-between;
       padding:70px 76px;position:relative;overflow:hidden}
  .brand{display:flex;align-items:center;gap:16px}
  .brand span{font-family:'Playfair Display',serif;font-size:34px;font-weight:600;
              letter-spacing:-.015em;color:#1B1E1B}
  .brand i{font-weight:500;font-style:italic;color:#1A5C38}
  h1{font-family:'Playfair Display',serif;font-size:70px;font-weight:600;line-height:1.06;
     letter-spacing:-.02em;color:#1B1E1B;max-width:15ch}
  .range{font-family:'Playfair Display',serif;font-size:64px;font-weight:600;line-height:1;
         background:linear-gradient(140deg,#D98A26,#8FA83E 48%,#1E7A46);
         -webkit-background-clip:text;background-clip:text;color:transparent}
  .sub{font-size:22px;color:#6B716C;margin-top:16px;max-width:38ch;line-height:1.5}
  .foot{display:flex;align-items:flex-end;justify-content:space-between}
  .arc{position:absolute;right:56px;bottom:74px}
</style></head><body>
  <div class="brand">${CLOVER(46, 'g1')}<span>Clovara <i>Life</i></span></div>
  <div>
    <div class="range">12&ndash;14 healthy years</div>
    <h1>Your pet's healthy years, mapped.</h1>
    <p class="sub">A projection built from published veterinary data, and a care plan that adapts as they age.</p>
  </div>
  <div class="foot"><div></div></div>
  <svg class="arc" width="470" height="250" viewBox="0 0 560 300">
    <path d="M20,250 Q280,40 540,250" fill="none" stroke="#E6E1D6" stroke-width="14" stroke-linecap="round"/>
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
</style></head><body>${CLOVER(122, 'g3')}</body></html>`

const browser = await chromium.launch({ executablePath: EXE })

for (const [html, size, file] of [
  [OG, { width: 1200, height: 630 }, `${OUT}/og.png`],
  [ICON, { width: 180, height: 180 }, `${OUT}/apple-touch-icon.png`],
]) {
  const page = await browser.newPage({ viewport: size, deviceScaleFactor: 1 })
  await page.setContent(html, { waitUntil: 'load' })
  await page.evaluate(() => document.fonts.ready)
  await page.waitForTimeout(200)
  await page.screenshot({ path: file })
  await page.close()
  console.log('wrote', file)
}

await browser.close()
