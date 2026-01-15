/**
 * Patch Firestore underwriting rules: adds/sets excludableConditions.
 *
 * Safe-by-default: merges the starter list into whatever is already configured
 * (does NOT overwrite other underwriting rule fields).
 *
 * Usage:
 *   cd functions
 *   node patch_underwriting_excludable_conditions.js
 *
 * Optional:
 *   REPLACE=1 node patch_underwriting_excludable_conditions.js   # replace list instead of merge
 *
 * Auth:
 *   - Prefer setting GOOGLE_APPLICATION_CREDENTIALS to a service account json
 *   - If not set, this script will try ./firebase-service-account.json
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const DEFAULT_EXCLUDABLES = [
  // Orthopedic
  'cruciate',
  'cranial cruciate ligament',
  'degenerative joint disease',
  'djd',
  'arthritis',
  'osteoarthritis',
  'hip dysplasia',
  'patellar luxation',
  'luxating patella',
  'elbow dysplasia',
  // Spine
  'intervertebral disc disease',
  'ivdd',
];

function normalizeList(list) {
  return [...new Set(
    (list || [])
      .map((x) => String(x))
      .map((x) => x.trim())
      .filter(Boolean)
  )];
}

async function main() {
  const replace = process.env.REPLACE === '1';

  if (!admin.apps.length) {
    if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      const localPath = path.join(__dirname, 'firebase-service-account.json');
      if (fs.existsSync(localPath)) {
        process.env.GOOGLE_APPLICATION_CREDENTIALS = localPath;
      }
    }

    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  }

  const db = admin.firestore();
  const docRef = db.collection('admin_settings').doc('underwriting_rules');
  const snap = await docRef.get();

  const existing = snap.exists ? (snap.data() || {}) : {};
  const existingList = normalizeList(existing.excludableConditions);
  const desired = replace
    ? normalizeList(DEFAULT_EXCLUDABLES)
    : normalizeList([...existingList, ...DEFAULT_EXCLUDABLES]);

  await docRef.set(
    {
      excludableConditions: desired,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      updatedBy: 'patch_excludable_conditions',
    },
    { merge: true },
  );

  console.log('✅ Patched admin_settings/underwriting_rules.excludableConditions');
  console.log(`   Mode: ${replace ? 'REPLACE' : 'MERGE'}`);
  console.log(`   Before: ${existingList.length}`);
  console.log(`   After:  ${desired.length}`);
}

main().catch((e) => {
  console.error('❌ Failed to patch excludableConditions:', e);
  process.exit(1);
});
