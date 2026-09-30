/**
 * Who gets which moment email today (Phase B, AO6). Pure — no Firestore, no
 * clock of its own — so it is tested without an emulator; index.js does the
 * reading and the sending around it.
 *
 * What is due comes from the app's own engine, bundled into
 * generated/moments.js, so the email and the app cannot disagree.
 *
 * RULES
 *   - Only somebody who opted in (`prefs.moments === true`), with an email.
 *   - A moment goes once per pet: `prefs.sent` holds every key already sent.
 *   - At most MAX_PER_DAY per person per run, so a household with four puppies
 *     does not get a wall of mail on one morning; the rest go the next day.
 */
const { momentsForStoredPet, petNameOfStored } = require('./generated/moments')

const MAX_PER_DAY = 3

const sentKey = (petId, momentKey) => `${petId}|${momentKey}`

function planSends({ now, recipients, preferencesUrl }) {
  const sends = []
  for (const r of recipients || []) {
    if (!r || !r.email || !r.prefs || r.prefs.moments !== true) continue
    const sent = r.prefs.sent || {}
    let n = 0
    for (const pet of r.pets || []) {
      for (const m of momentsForStoredPet(pet, now)) {
        const key = sentKey(pet.id, m.key)
        if (sent[key] || n >= MAX_PER_DAY) continue
        const url = `${preferencesUrl}?t=${encodeURIComponent(r.prefs.unsubscribeToken || '')}`
        sends.push({
          uid: r.uid,
          to: r.email,
          key,
          data: { petName: petNameOfStored(pet), subject: m.subject, lines: m.lines, preferencesUrl: url },
          headers: {
            'List-Unsubscribe': `<${url}>`,
            // RFC 8058: mail clients may unsubscribe with one POST, no page.
            'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
          },
        })
        n++
      }
    }
  }
  return sends
}

module.exports = { planSends, sentKey, MAX_PER_DAY }
