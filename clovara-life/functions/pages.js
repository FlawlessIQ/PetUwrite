/**
 * The pages the email preferences link serves (Phase B). Their words live here,
 * apart from the handler, so the counsel pack (docs/review/COUNSEL-PACK.md)
 * quotes exactly what renders — `npm run review:packs`.
 */
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c])

const page = (title, body) =>
  `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(title)}</title>` +
  `<style>body{font-family:system-ui,sans-serif;background:#F6F3EA;color:#1B1E1B;margin:0;padding:48px 20px}main{max-width:520px;margin:auto}h1{font-family:Georgia,serif;font-weight:600}button{background:#1A5C38;color:#fff;border:0;border-radius:999px;padding:12px 22px;font-size:16px}p{line-height:1.6;color:#5C635C}</style></head><body><main>${body}</main></body></html>`

/** The words, as plain data — what the pack quotes. */
const COPY = {
  confirm: {
    title: 'Turn off reminders',
    heading: 'Turn off reminders?',
    body: 'You will stop getting emails about vaccinations, the socialisation window, the yearly check and Gotcha Day. Nothing else changes.',
    button: 'Turn off reminders',
  },
  off: {
    title: 'Reminders off',
    heading: 'Reminders are off',
    body: 'You will not get these emails any more. Everything in your pets’ plans is still there, and you can turn reminders back on from your account.',
  },
  notRecognised: {
    title: 'Link not recognised',
    heading: 'We do not recognise that link',
    body: 'It may be from an old email. You can change reminders from your account in Clovara Life.',
  },
}

const PAGES = {
  confirm: (token) =>
    page(
      COPY.confirm.title,
      `<h1>${esc(COPY.confirm.heading)}</h1><p>${esc(COPY.confirm.body)}</p>` +
        `<form method="post"><input type="hidden" name="t" value="${esc(token)}"><button type="submit">${esc(COPY.confirm.button)}</button></form>`,
    ),
  remindersOff: () => page(COPY.off.title, `<h1>${esc(COPY.off.heading)}</h1><p>${esc(COPY.off.body)}</p>`),
  notRecognised: () => page(COPY.notRecognised.title, `<h1>${esc(COPY.notRecognised.heading)}</h1><p>${esc(COPY.notRecognised.body)}</p>`),
}

module.exports = { PAGES, COPY, esc }
