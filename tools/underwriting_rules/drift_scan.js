#!/usr/bin/env node

/**
 * Drift scanner: fails if underwriting rule *values* are hardcoded outside the canonical YAML
 * and approved tooling/loader files.
 */

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..', '..');

const ALLOWLIST_PATH_PREFIXES = [
  'config/underwriting_rules.v1.yaml',
  'config/underwriting_rules.schema.json',
  'docs/UNDERWRITING_RULES.md',
  'tools/underwriting_rules/',
  'functions/underwritingRulesLoader.js',
  'functions/underwritingRulesPublic.js',
];

const IGNORE_DIRS = new Set([
  '.git',
  'build',
  'node_modules',
  'test',
  'ios',
  'android',
  'macos',
  'linux',
  'windows',
  'web',
  'public',
]);

const PATTERNS = [
  // Target *hardcoded rule literals* in code (Dart/JS objects), not prose.
  { name: 'maxRiskScore literal', re: /['"]maxRiskScore['"]\s*:\s*\d+/i },
  { name: 'minAgeMonths literal', re: /['"]minAgeMonths['"]\s*:\s*\d+/i },
  { name: 'maxAgeYears literal', re: /['"]maxAgeYears['"]\s*:\s*\d+/i },

  // List literals: key mapped directly to a string list literal.
  {
    name: 'excludedBreeds literal list',
    re: /['"]excludedBreeds['"]\s*:\s*(?:<String>\s*)?\[\s*['"]/i,
  },
  {
    name: 'criticalConditions literal list',
    re: /['"]criticalConditions['"]\s*:\s*(?:<String>\s*)?\[\s*['"]/i,
  },
  {
    name: 'excludableConditions literal list',
    re: /['"]excludableConditions['"]\s*:\s*(?:<String>\s*)?\[\s*['"]/i,
  },
];

function isAllowed(rel) {
  return ALLOWLIST_PATH_PREFIXES.some((p) => rel === p || rel.startsWith(p));
}

function walk(dirAbs, relBase = '') {
  const entries = fs.readdirSync(dirAbs, { withFileTypes: true });
  const files = [];

  for (const e of entries) {
    const abs = path.join(dirAbs, e.name);
    const rel = path.posix.join(relBase, e.name);

    if (e.isDirectory()) {
      if (IGNORE_DIRS.has(e.name)) continue;
      files.push(...walk(abs, rel));
      continue;
    }

    // Only scan code files (avoid false positives in prose docs).
    if (!/\.(js|ts|dart)$/.test(e.name)) continue;
    files.push({ abs, rel });
  }

  return files;
}

function main() {
  const matches = [];
  const files = walk(repoRoot);

  for (const f of files) {
    if (isAllowed(f.rel)) continue;

    let content;
    try {
      content = fs.readFileSync(f.abs, 'utf8');
    } catch {
      continue;
    }

    for (const p of PATTERNS) {
      if (p.re.test(content)) {
        matches.push({ file: f.rel, pattern: p.name });
        break;
      }
    }
  }

  if (matches.length) {
    console.error('\n❌ Underwriting rules drift detected.');
    console.error('Move rule values into config/underwriting_rules.v1.yaml and regenerate/publish.\n');
    for (const m of matches.slice(0, 50)) {
      console.error(`- ${m.file}  (${m.pattern})`);
    }
    if (matches.length > 50) console.error(`...and ${matches.length - 50} more`);
    console.error('\nAllowed locations:');
    for (const p of ALLOWLIST_PATH_PREFIXES) console.error(`- ${p}`);
    process.exit(1);
  }

  console.log('✅ No underwriting rules drift detected');
}

main();
