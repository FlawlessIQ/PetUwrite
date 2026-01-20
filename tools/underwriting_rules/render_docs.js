#!/usr/bin/env node

/**
 * Render underwriting rules docs from canonical YAML.
 *
 * Outputs:
 *  - docs/UNDERWRITING_RULES.md
 *  - Optional insertion into docs/legal/TERMS_OF_SERVICE.md between markers
 */

const fs = require('fs');
const path = require('path');
const yaml = require('js-yaml');

const repoRoot = path.resolve(__dirname, '..', '..');
const CONFIG_PATH = path.join(repoRoot, 'config', 'underwriting_rules.v1.yaml');
const OUT_DOC = path.join(repoRoot, 'docs', 'UNDERWRITING_RULES.md');
const TOS_PATH = path.join(repoRoot, 'docs', 'legal', 'TERMS_OF_SERVICE.md');

const BEGIN = '<!-- BEGIN AUTO-GENERATED UNDERWRITING RULES -->';
const END = '<!-- END AUTO-GENERATED UNDERWRITING RULES -->';

function die(msg) {
  console.error(`\n❌ ${msg}\n`);
  process.exit(1);
}

function loadRules() {
  if (!fs.existsSync(CONFIG_PATH)) die(`Missing ${CONFIG_PATH}`);
  const raw = fs.readFileSync(CONFIG_PATH, 'utf8');
  const parsed = yaml.load(raw);
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    die(`Invalid YAML root in ${CONFIG_PATH}; expected an object`);
  }
  return parsed;
}

function bulletList(items) {
  return items.map((x) => `- ${x}`).join('\n');
}

function renderMarkdown(rules) {
  const excludedSorted = [...(rules.excludedBreeds || [])].sort((a, b) =>
    String(a).localeCompare(String(b)),
  );

  return `# Underwriting Rules (Canonical)\n\n` +
    `This document is auto-generated from the canonical config file:\n` +
    `- config/underwriting_rules.v1.yaml\n\n` +
    `Do not edit this document manually.\n\n` +
    `## Current Version\n\n` +
    `- Version: ${rules.version}\n` +
    `- Effective date: ${rules.effectiveDate}\n` +
    (rules.changeNotes ? `- Change notes: ${rules.changeNotes}\n` : '') +
    `\n## Enrollment Limits\n\n` +
    `- Minimum age: ${rules?.ageLimits?.minAgeMonths} months\n` +
    `- Maximum age: ${rules?.ageLimits?.maxAgeYears} years\n\n` +
    `## Risk Threshold\n\n` +
    `- Maximum overall risk score: ${rules?.risk?.maxOverallScore} (0–100). If the AI risk score exceeds this value, the pet is declined.\n\n` +
    `## Excluded Breeds (Auto-Decline)\n\n` +
    `${bulletList(excludedSorted)}\n` +
    `\n## Critical Conditions (Auto-Decline)\n\n` +
    `${bulletList(rules.criticalConditions || [])}\n` +
    `\n## Excludable Conditions (Approved With Exclusions)\n\n` +
    `${bulletList(rules.excludableConditions || [])}\n` +
    `\n---\n\n` +
    `### How to update\n\n` +
    `1) Edit config/underwriting_rules.v1.yaml (increment version)\n` +
    `2) node tools/underwriting_rules/render_docs.js\n` +
    `3) node tools/underwriting_rules/publish_underwriting_rules.js --env dev|stage|prod\n`;
}

function upsertBetweenMarkers(original, content) {
  const beginIdx = original.indexOf(BEGIN);
  const endIdx = original.indexOf(END);

  if (beginIdx !== -1 && endIdx !== -1 && endIdx > beginIdx) {
    return (
      original.slice(0, beginIdx + BEGIN.length) +
      '\n' +
      content +
      '\n' +
      original.slice(endIdx)
    );
  }

  // If markers are absent, append them at the end.
  const suffix = `\n\n${BEGIN}\n${content}\n${END}\n`;
  return original.trimEnd() + suffix;
}

function main() {
  const rules = loadRules();
  const md = renderMarkdown(rules);

  fs.mkdirSync(path.dirname(OUT_DOC), { recursive: true });
  fs.writeFileSync(OUT_DOC, md, 'utf8');
  console.log(`✅ Wrote ${path.relative(repoRoot, OUT_DOC)}`);

  if (fs.existsSync(TOS_PATH)) {
    const snippet =
      `**Underwriting rules (auto-generated)**\n\n` +
      `- Version: ${rules.version}\n` +
      `- Effective date: ${rules.effectiveDate}\n` +
      `- Pet age eligibility: typically ${rules?.ageLimits?.minAgeMonths} months to ${rules?.ageLimits?.maxAgeYears} years at enrollment\n` +
      `- Certain high-risk breeds may be excluded (see docs/UNDERWRITING_RULES.md)\n`;

    const tos = fs.readFileSync(TOS_PATH, 'utf8');
    const updated = upsertBetweenMarkers(tos, snippet);
    fs.writeFileSync(TOS_PATH, updated, 'utf8');
    console.log(`✅ Updated ${path.relative(repoRoot, TOS_PATH)} (markers)`);
  }
}

main();
