/**
 * Firebase web configuration.
 *
 * None of this is secret. A Firebase web API key identifies the project; it
 * does not authorise anything. Access control lives entirely in the Firestore
 * rules and the console's authorised-domain list, and this same config is
 * already committed to this repo in `lib/firebase_options.dart` and shipped in
 * every web build of the Flutter app.
 *
 * It is hardcoded rather than required from the environment ON PURPOSE. A
 * missing `.env` must never be able to break the investor demo — the worst a
 * misconfigured environment can do here is fall back to the right values.
 * `VITE_FIREBASE_*` still overrides, so a future staging project needs no code
 * change.
 */
const env = import.meta.env

export const FIREBASE_CONFIG = {
  apiKey: env.VITE_FIREBASE_API_KEY ?? 'AIzaSyAasP7WKdW7RaJ55uaOvcf5iu5mDDSn_FU',
  authDomain: env.VITE_FIREBASE_AUTH_DOMAIN ?? 'pet-underwriter-ai.firebaseapp.com',
  projectId: env.VITE_FIREBASE_PROJECT_ID ?? 'pet-underwriter-ai',
  storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET ?? 'pet-underwriter-ai.firebasestorage.app',
  messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID ?? '984654950987',
  appId: env.VITE_FIREBASE_APP_ID ?? '1:984654950987:web:f9c4d1e5fe50cf2ba193ce',
}

/**
 * Where Clovara Life keeps its own data.
 *
 * Deliberately NOT `users/{uid}` — that collection belongs to the underwriting
 * product and carries `userRole`, admin claims and a large reviewed rules
 * block. Life members get their own top-level namespace so nothing here can
 * collide with, or weaken, any of that. The auth user pool is shared, so one
 * Clovara identity works across both products; only the data is separated.
 */
export const MEMBERS_COLLECTION = 'life_members'
