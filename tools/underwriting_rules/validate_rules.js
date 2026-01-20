#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

const repoRoot = path.resolve(__dirname, '..', '..');
const CONFIG_PATH = path.join(repoRoot, 'config', 'underwriting_rules.v1.yaml');
const SCHEMA_PATH = path.join(repoRoot, 'config', 'underwriting_rules.schema.json');

function die(msg) {
  console.error(`\n❌ ${msg}\n`);
  process.exit(1);
}

function loadYaml(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  const parsed = yaml.load(raw);
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    die(`Invalid YAML root in ${filePath}; expected an object`);
  }
  return parsed;
}

function loadSchema(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  return JSON.parse(raw);
}

function normalizeStringList(list) {
  if (!Array.isArray(list)) return [];
  return list
    .map((x) => String(x))
    .map((x) => x.trim())
    .filter(Boolean);
}

function assertGovernanceRules(rules) {
  // Cross-field validation beyond JSON schema.
  const minAgeMonths = rules?.ageLimits?.minAgeMonths;
  const maxAgeYears = rules?.ageLimits?.maxAgeYears;

  if (typeof minAgeMonths === 'number' && typeof maxAgeYears === 'number') {
    if (minAgeMonths > maxAgeYears * 12) {
      die(
        `ageLimits.minAgeMonths (${minAgeMonths}) must be <= ageLimits.maxAgeYears*12 (${maxAgeYears * 12})`,
      );
    }
  }

  for (const key of ['excludedBreeds', 'criticalConditions', 'excludableConditions']) {
    const normalized = normalizeStringList(rules[key]);
    const unique = new Set(normalized.map((x) => x.toLowerCase()));
    if (unique.size !== normalized.length) {
      die(`${key} entries must be unique (case-insensitive) and trimmed`);
    }
    if (normalized.some((x) => x !== x.trim())) {
      die(`${key} entries must be trimmed`);
    }
    // Replace in-memory with normalized copy for downstream tooling.
    rules[key] = normalized;
  }
}

function validate() {
  if (!fs.existsSync(CONFIG_PATH)) die(`Missing canonical YAML: ${CONFIG_PATH}`);
  if (!fs.existsSync(SCHEMA_PATH)) die(`Missing schema: ${SCHEMA_PATH}`);

  const rules = loadYaml(CONFIG_PATH);
  const schema = loadSchema(SCHEMA_PATH);

  const ajv = new Ajv({ allErrors: true, strict: false });
  addFormats(ajv);
  const validateFn = ajv.compile(schema);

  const ok = validateFn(rules);
  if (!ok) {
    const errors = (validateFn.errors || [])
      .map((e) => `${e.instancePath || '(root)'} ${e.message}`)
      .join('\n');
    die(`Schema validation failed:\n${errors}`);
  }

  assertGovernanceRules(rules);

  console.log('✅ Underwriting rules YAML is valid');
  console.log(`   version: ${rules.version}`);
  console.log(`   effectiveDate: ${rules.effectiveDate}`);
}

validate();
