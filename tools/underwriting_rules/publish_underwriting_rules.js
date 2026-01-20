#!/usr/bin/env node

/**
 * Publish canonical underwriting rules to Firestore.
 *
 * Usage:
 *   cd tools/underwriting_rules && npm install
 *   node publish_underwriting_rules.js --env dev|stage|prod [--project <id>] [--dry-run]
 *
 * Credentials:
 *   - Uses Application Default Credentials (GOOGLE_APPLICATION_CREDENTIALS) or gcloud auth.
 */

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');
const admin = require('firebase-admin');

const repoRoot = path.resolve(__dirname, '..', '..');
const CONFIG_PATH = path.join(repoRoot, 'config', 'underwriting_rules.v1.yaml');
const VALIDATE_BIN = path.join(__dirname, 'validate_rules.js');

function die(msg) {
  console.error(`\n❌ ${msg}\n`);
  process.exit(1);
}

function parseArgs(argv) {
  const out = { env: null, project: null, dryRun: false };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--env') out.env = argv[++i];
    else if (a === '--project') out.project = argv[++i];
    else if (a === '--dry-run') out.dryRun = true;
    else die(`Unknown arg: ${a}`);
  }
  return out;
}

function readFirebasercDefaultProject() {
  const firebaserc = path.join(repoRoot, '.firebaserc');
  if (!fs.existsSync(firebaserc)) return null;
  try {
    const raw = fs.readFileSync(firebaserc, 'utf8');
    const parsed = JSON.parse(raw);
    return parsed?.projects?.default || null;
  } catch {
    return null;
  }
}

function projectForEnv(env) {
  const upper = String(env || '').toUpperCase();
  const fromEnv = process.env[`CLOVARA_FIREBASE_PROJECT_${upper}`];
  if (fromEnv) return fromEnv;
  return null;
}

function loadYaml() {
  const raw = fs.readFileSync(CONFIG_PATH, 'utf8');
  const parsed = yaml.load(raw);
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    die(`Invalid YAML root in ${CONFIG_PATH}; expected an object`);
  }
  return parsed;
}

function toFirestoreDoc(rules, publishedBy) {
  return {
    enabled: rules.enabled !== false,
    // Preserve existing Firestore field names used by app/UI.
    maxRiskScore: rules?.risk?.maxOverallScore,
    minAgeMonths: rules?.ageLimits?.minAgeMonths,
    maxAgeYears: rules?.ageLimits?.maxAgeYears,
    excludedBreeds: rules.excludedBreeds || [],
    criticalConditions: rules.criticalConditions || [],
    excludableConditions: rules.excludableConditions || [],

    // Governance metadata
    rulesVersion: rules.version,
    effectiveDate: rules.effectiveDate,
    changeNotes: rules.changeNotes || '',
    canonicalPath: 'config/underwriting_rules.v1.yaml',

    // Published metadata (server timestamps)
    publishedAt: admin.firestore.FieldValue.serverTimestamp(),
    publishedBy: publishedBy || rules.updatedBy || '',
  };
}

async function main() {
  const args = parseArgs(process.argv);
  if (!args.env && !args.project) {
    die('Provide --env dev|stage|prod or --project <id>');
  }

  // Validate first (exec as a child by requiring file).
  require(VALIDATE_BIN);

  const rules = loadYaml();

  const publishedBy = process.env.USER || process.env.EMAIL || '';
  const project =
    args.project ||
    projectForEnv(args.env) ||
    process.env.CLOVARA_FIREBASE_PROJECT ||
    process.env.GCLOUD_PROJECT ||
    process.env.FIREBASE_PROJECT_ID ||
    readFirebasercDefaultProject();

  if (!project) die('Unable to determine Firebase project. Use --project <id>.');

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: project,
    });
  }

  const db = admin.firestore();

  const docRef = db.collection('admin_settings').doc('underwriting_rules');
  const historyRef = db.collection('underwriting_rules_history').doc(String(rules.version));

  const payload = toFirestoreDoc(rules, publishedBy);
  const historyPayload = {
    ...payload,
    canonical: rules,
    // Ensure history is immutable: clients should never update these.
    recordedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  console.log('📦 Publishing underwriting rules');
  console.log(`   project: ${project}`);
  console.log(`   env: ${args.env || '(none)'}`);
  console.log(`   version: ${rules.version}`);
  console.log(`   effectiveDate: ${rules.effectiveDate}`);

  if (args.dryRun) {
    console.log('\n🟡 DRY RUN - no writes performed');
    console.log(`Would write: admin_settings/underwriting_rules`);
    console.log(`Would write: underwriting_rules_history/${rules.version}`);
    return;
  }

  // Guard against overwriting newer history.
  const existingHistory = await historyRef.get();
  if (existingHistory.exists) {
    die(
      `History doc underwriting_rules_history/${rules.version} already exists. Increment version in YAML before publishing.`,
    );
  }

  // Write history first, then publish current.
  await historyRef.set(historyPayload);
  await docRef.set(payload, { merge: true });

  console.log('\n✅ Published rules successfully');
}

main().catch((e) => {
  console.error('\n❌ Publish failed:', e?.message || e);
  process.exit(1);
});
