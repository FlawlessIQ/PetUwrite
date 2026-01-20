#!/usr/bin/env node
/**
 * DEPRECATED: Hardcoded underwriting rules seeder.
 *
 * Underwriting rules are now authored in:
 *   config/underwriting_rules.v1.yaml
 *
 * And published via:
 *   node tools/underwriting_rules/publish_underwriting_rules.js --env <env>
 *
 * This wrapper exists to keep old workflows working without reintroducing drift.
 */

const path = require('path');
const {spawnSync} = require('child_process');

function main() {
  const envArgIndex = process.argv.indexOf('--env');
  const env = envArgIndex !== -1 ? process.argv[envArgIndex + 1] : 'dev';

  console.log('═══════════════════════════════════════════════════════════');
  console.log('  Clovara - Underwriting Rules Seeder (DEPRECATED)');
  console.log('═══════════════════════════════════════════════════════════\n');
  console.log('This command now publishes from the canonical YAML:');
  console.log('  config/underwriting_rules.v1.yaml\n');

  const script = path.resolve(__dirname, '..', 'tools', 'underwriting_rules', 'publish_underwriting_rules.js');
  const result = spawnSync(process.execPath, [script, '--env', env], {stdio: 'inherit'});
  process.exit(result.status ?? 1);
}

main();
