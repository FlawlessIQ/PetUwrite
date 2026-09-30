/**
 * The daily moment-email run (Phase B, AO6): read who opted in and their pets,
 * plan with the pure planner, hand each email to the sender, record it as sent.
 *
 * Everything it touches is passed in — Firestore, the email lookup, the sender,
 * the tracker, the clock — so moments-job.emulator.test.js runs it against the
 * Firestore emulator exactly as the scheduler does.
 */
const { planSends } = require('./moments-runner')

const PREFS = 'life_prefs'
const HOUSEHOLDS = 'households'

async function runMoments({ db, now, preferencesUrl, emailOf, send, track }) {
  const opted = await db.collection(PREFS).where('moments', '==', true).limit(500).get()
  const recipients = []
  for (const doc of opted.docs) {
    const households = await db.collection(HOUSEHOLDS).where('memberIds', 'array-contains', doc.id).get()
    const pets = []
    for (const h of households.docs) {
      const ps = await h.ref.collection('pets').get()
      for (const p of ps.docs) pets.push({ ...p.data(), id: p.id })
    }
    recipients.push({ uid: doc.id, email: await emailOf(doc.id), prefs: doc.data(), pets })
  }
  const sends = planSends({ now, recipients, preferencesUrl })
  for (const s of sends) {
    const r = await send('moment', s.to, s.data, s.headers)
    // Recorded even when the console sender only logs it: "sent" means handed
    // to the sender, and the same moment must never be handed over twice.
    await db.collection(PREFS).doc(s.uid).set({ sent: { [s.key]: now.toISOString() } }, { merge: true })
    await track(s.uid, 'moment_email', { kind: s.key.split('|')[1].split(':')[0], delivered: !!(r && r.delivered) })
  }
  return { recipients: recipients.length, sent: sends.length }
}

module.exports = { runMoments }
