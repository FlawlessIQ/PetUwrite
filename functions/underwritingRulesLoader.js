/**
 * Underwriting rules loader (server-side).
 *
 * Single runtime source of truth: Firestore `admin_settings/underwriting_rules`.
 * No hardcoded defaults.
 */

const admin = require('firebase-admin');

// Per-instance cache.
let cached = null;
let cachedAtMs = 0;
const CACHE_TTL_MS = 60 * 1000;

function normalizeStringList(list) {
  if (!Array.isArray(list)) return [];
  return list
    .map((x) => String(x))
    .map((x) => x.trim())
    .filter(Boolean);
}

function validateRulesShape(rules) {
  const errors = [];

  const enabled = rules.enabled;
  if (enabled !== undefined && typeof enabled !== 'boolean') {
    errors.push('enabled must be boolean');
  }

  for (const k of ['maxRiskScore', 'minAgeMonths', 'maxAgeYears']) {
    if (typeof rules[k] !== 'number' || !Number.isFinite(rules[k])) {
      errors.push(`${k} must be a number`);
    }
  }

  // Cross-field constraint.
  if (
    typeof rules.minAgeMonths === 'number' &&
    typeof rules.maxAgeYears === 'number' &&
    rules.minAgeMonths > rules.maxAgeYears * 12
  ) {
    errors.push('minAgeMonths must be <= maxAgeYears*12');
  }

  // Lists.
  rules.excludedBreeds = normalizeStringList(rules.excludedBreeds);
  rules.criticalConditions = normalizeStringList(rules.criticalConditions);
  rules.excludableConditions = normalizeStringList(rules.excludableConditions);

  if (!Array.isArray(rules.excludedBreeds)) {
    errors.push('excludedBreeds must be an array');
  }

  // Uniqueness.
  for (const key of ['excludedBreeds', 'criticalConditions', 'excludableConditions']) {
    const items = rules[key];
    const unique = new Set(items.map((x) => x.toLowerCase()));
    if (unique.size !== items.length) errors.push(`${key} must be unique (case-insensitive)`);
  }

  return errors;
}

async function loadUnderwritingRules({ cache = true } = {}) {
  const now = Date.now();
  if (cache && cached && now - cachedAtMs < CACHE_TTL_MS) return cached;

  const snap = await admin
    .firestore()
    .collection('admin_settings')
    .doc('underwriting_rules')
    .get();

  if (!snap.exists) {
    return {
      ok: false,
      errorCode: 'MISSING_RULES',
      errorMessage:
        'Underwriting rules are not published. Run: node tools/underwriting_rules/publish_underwriting_rules.js --env <env>',
    };
  }

  const rules = { ...(snap.data() || {}) };
  const errors = validateRulesShape(rules);

  if (errors.length) {
    return {
      ok: false,
      errorCode: 'INVALID_RULES',
      errorMessage: `Underwriting rules document is invalid: ${errors.join('; ')}`,
    };
  }

  const out = { ok: true, rules };
  cached = out;
  cachedAtMs = now;
  return out;
}

module.exports = {
  loadUnderwritingRules,
};
