/**
 * Writes `life_config/pricing`, the document the Checkout function reads.
 *
 * SPEC §1: "price must be a config value, never a literal" — because a price
 * test ($19.99–$24.99) is planned and it must not need a deploy. Nothing in the
 * app or the functions carries the amount; they carry a pointer to this.
 *
 * Runs against the live project through the Firestore REST API using your
 * gcloud credentials, which are checked by IAM rather than by the security
 * rules — the rules deny all client writes to life_config on purpose.
 *
 *   node scripts/seed-config.mjs                      # show what is there
 *   node scripts/seed-config.mjs --price price_xxx    # write it
 *
 * `--emulator` targets the local suite instead, for `verify:stripe`.
 */
import { execSync } from 'node:child_process'

const args = process.argv.slice(2)
const flag = (name) => {
  const i = args.indexOf(`--${name}`)
  return i === -1 ? null : (args[i + 1] ?? true)
}

const PROJECT = 'pet-underwriter-ai'
const useEmulator = args.includes('--emulator')
const BASE = useEmulator
  ? `http://127.0.0.1:8080/v1/projects/${PROJECT}/databases/(default)/documents`
  : `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`

function headers() {
  if (useEmulator) return { 'Content-Type': 'application/json', Authorization: 'Bearer owner' }
  const token = execSync('gcloud auth print-access-token', { encoding: 'utf8' }).trim()
  return {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${token}`,
    'X-Goog-User-Project': PROJECT,
  }
}

const url = `${BASE}/life_config/pricing`

const priceId = flag('price')
if (!priceId || priceId === true) {
  const res = await fetch(url, { headers: headers() })
  if (res.status === 404) {
    console.log('life_config/pricing does not exist yet.')
    console.log('Write it with:  node scripts/seed-config.mjs --price price_xxx')
    process.exit(0)
  }
  const body = await res.json()
  console.log(JSON.stringify(body.fields ?? body, null, 2))
  process.exit(0)
}

// Display strings only. Stripe remains the authority on what is charged; these
// exist so the checkout disclosure can say a number without a second API call.
const doc = {
  fields: {
    priceId: { stringValue: String(priceId) },
    amountDisplay: { stringValue: flag('display') || '$22.99' },
    interval: { stringValue: flag('interval') || 'month' },
    trialDays: { integerValue: String(flag('trial') || 7) },
    updatedAt: { stringValue: new Date().toISOString() },
    note: {
      stringValue:
        'Written by scripts/seed-config.mjs. Clients cannot write here — the rules deny it. Stripe is the authority on the amount actually charged.',
    },
  },
}

const res = await fetch(url, { method: 'PATCH', headers: headers(), body: JSON.stringify(doc) })
if (!res.ok) {
  console.error(`Failed: ${res.status}`, (await res.text()).slice(0, 400))
  process.exit(1)
}
console.log(`life_config/pricing → ${priceId} (${useEmulator ? 'emulator' : 'live'})`)
