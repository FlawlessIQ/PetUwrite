#!/usr/bin/env dart
// DEPRECATED: This script hardcoded underwriting rules and caused config drift.
//
// Canonical workflow:
//  1) Edit config/underwriting_rules.v1.yaml (increment version)
//  2) node tools/underwriting_rules/render_docs.js
//  3) node tools/underwriting_rules/publish_underwriting_rules.js --env dev|stage|prod

import 'dart:io';

Future<void> main() async {
  stderr.writeln('❌ Deprecated: bin/seed_underwriting_rules.dart');
  stderr.writeln('Underwriting rules are now published from config/underwriting_rules.v1.yaml');
  stderr.writeln('Run: node tools/underwriting_rules/publish_underwriting_rules.js --env <env>');
  exit(1);
}
