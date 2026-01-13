import 'dart:convert';
import 'dart:io';

String _csvEscape(String value) {
  final needsQuotes = value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r');
  if (!needsQuotes) return value;
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

String _asString(dynamic v) => v == null ? '' : v.toString();

double _asDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(_asString(v)) ?? 0.0;

int _asInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse(_asString(v)) ?? 0;

Map<String, dynamic> _asMap(dynamic v) => (v is Map) ? v.cast<String, dynamic>() : <String, dynamic>{};

List<dynamic> _asList(dynamic v) => (v is List) ? v : const [];

void main(List<String> args) {
  final inputPath = args.isNotEmpty ? args[0] : 'pricing/validation/pricing_validation_snapshot.json';

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Input file not found: $inputPath');
    stderr.writeln('Run the test to generate it: flutter test test/pricing/pricing_validation_snapshot_test.dart');
    exitCode = 2;
    return;
  }

  final root = jsonDecode(inputFile.readAsStringSync());
  final rootMap = _asMap(root);
  final entries = _asList(rootMap['entries']);

  final headers = <String>[
    'species',
    'ageYears',
    'riskBand',
    'state',
    'zip',
    'reimbursementPercent',
    'annualDeductible',
    'annualLimit',
    'addOns',
    'basePremium',
    'regionalMultiplier',
    'riskMultiplier',
    'reimbursementFactor',
    'deductibleFactor',
    'annualLimitFactor',
    'addOnTotal',
    'finalMonthlyPremium',
    'pricingVersion',
  ];

  stdout.writeln(headers.map(_csvEscape).join(','));

  for (final entry in entries) {
    final entryMap = _asMap(entry);
    final pet = _asMap(entryMap['petProfile']);
    final state = _asMap(entryMap['state']);
    final levers = _asMap(entryMap['coverageLevers']);
    final breakdown = _asMap(entryMap['pricingBreakdown']);

    final species = _asString(pet['species']);
    final ageYears = _asInt(pet['ageYears']);
    final riskBand = _asString(entryMap['riskBand']);
    final stateCode = _asString(state['state']);
    final zip = _asString(state['zip']);

    final reimbursementPercent = _asInt(levers['reimbursementPercent']);
    final annualDeductible = _asInt(levers['annualDeductible']);
    final annualLimitRaw = levers['annualLimit'];
    final annualLimit = annualLimitRaw == null ? 'Unlimited' : _asString(_asInt(annualLimitRaw));

    final addOns = _asList(entryMap['addOns']).map((e) => _asString(e)).where((s) => s.isNotEmpty).join('|');

    // Breakdown fields
    final basePremium = _asDouble(breakdown['pricingBasePremium']);
    final regionalMultiplier = _asDouble(breakdown['regionalMultiplier']);
    final riskMultiplier = _asDouble(breakdown['riskBandMultiplier']);
    final reimbursementFactor = _asDouble(breakdown['reimbursementFactor']);
    final deductibleFactor = _asDouble(breakdown['deductibleFactor']);
    final annualLimitFactor = _asDouble(breakdown['annualLimitFactor']);
    final addOnTotal = _asDouble(breakdown['addOnTotal']);

    final finalMonthlyPremium = _asDouble(entryMap['finalMonthlyPremium']);
    final pricingVersion = _asString(entryMap['pricingVersion']);

    final row = <String>[
      species,
      ageYears.toString(),
      riskBand,
      stateCode,
      zip,
      reimbursementPercent.toString(),
      annualDeductible.toString(),
      annualLimit,
      addOns,
      basePremium.toStringAsFixed(6),
      regionalMultiplier.toStringAsFixed(6),
      riskMultiplier.toStringAsFixed(6),
      reimbursementFactor.toStringAsFixed(6),
      deductibleFactor.toStringAsFixed(6),
      annualLimitFactor.toStringAsFixed(6),
      addOnTotal.toStringAsFixed(6),
      finalMonthlyPremium.toStringAsFixed(6),
      pricingVersion,
    ];

    stdout.writeln(row.map(_csvEscape).join(','));
  }
}
