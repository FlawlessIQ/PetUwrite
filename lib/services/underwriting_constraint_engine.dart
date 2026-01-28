import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/anomaly_flag.dart';
import '../models/pet.dart';

/// Deterministic, config-driven constraint engine.
///
/// Key principles:
/// - Not validation: we never reject inputs.
/// - We emit anomaly findings with severity + confidence impacts.
/// - We separate "health risk" from "input credibility risk".
/// - The catalog is versioned and auditable (JSON asset today; can be swapped
///   for Firestore later without changing scoring logic).
class UnderwritingConstraintEngine {
  static const String defaultAssetPath =
      'assets/underwriting_constraints/breed_constraints.v1.json';

  final String version;
  final Map<String, BreedConstraint> _constraintsByBreed;
  final Map<String, String> _breedAliases;

  const UnderwritingConstraintEngine._({
    required this.version,
    required Map<String, BreedConstraint> constraintsByBreed,
    required Map<String, String> breedAliases,
  }) : _constraintsByBreed = constraintsByBreed,
       _breedAliases = breedAliases;

  /// Loads the default catalog from a bundled JSON asset.
  ///
  /// This is deterministic and auditable: the catalog is checked into source.
  static Future<UnderwritingConstraintEngine> loadDefault() async {
    final raw = await rootBundle.loadString(defaultAssetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw StateError('Invalid constraints JSON: expected object root');
    }
    return UnderwritingConstraintEngine.fromJson(
      decoded.cast<String, dynamic>(),
    );
  }

  factory UnderwritingConstraintEngine.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] ?? 'unknown').toString();

    final aliasesRaw = json['breedAliases'];
    final aliases = <String, String>{};
    if (aliasesRaw is Map) {
      for (final entry in aliasesRaw.entries) {
        aliases[_normalize(entry.key.toString())] =
            _normalize(entry.value.toString());
      }
    }

    final byBreed = <String, BreedConstraint>{};
    final constraintsRaw = json['breedConstraints'];
    if (constraintsRaw is Map) {
      for (final entry in constraintsRaw.entries) {
        final key = _normalize(entry.key.toString());
        if (entry.value is Map) {
          byBreed[key] = BreedConstraint.fromJson(
            (entry.value as Map).cast<String, dynamic>(),
          );
        }
      }
    }

    return UnderwritingConstraintEngine._(
      version: version,
      constraintsByBreed: byBreed,
      breedAliases: aliases,
    );
  }

  BreedConstraint? constraintFor({required String breed}) {
    final normalized = _normalize(breed);
    final resolved = _breedAliases[normalized] ?? normalized;
    return _constraintsByBreed[resolved];
  }

  ({double minLbs, double maxLbs})? _tryParseWeightRangeFromBreedLabel(
    String breedLabel,
  ) {
    // Examples:
    // - "Mixed - Small (0–25 lbs)"
    // - "Mixed - Medium (25-60 lb)"
    // - "Mixed - Large (60 — 100 lbs)"
    final match = RegExp(
      r'\(\s*(\d+(?:\.\d+)?)\s*[-–—]\s*(\d+(?:\.\d+)?)\s*lb?s?\s*\)',
      caseSensitive: false,
    ).firstMatch(breedLabel);
    if (match == null) return null;

    final min = double.tryParse(match.group(1) ?? '');
    final max = double.tryParse(match.group(2) ?? '');
    if (min == null || max == null) return null;
    if (!min.isFinite || !max.isFinite) return null;
    if (min < 0 || max <= 0) return null;

    final a = min <= max ? min : max;
    final b = min <= max ? max : min;
    if (b <= 0) return null;
    return (minLbs: a, maxLbs: b);
  }

  UnderwritingConstraintAssessment assess({required Pet pet}) {
    final findings = <AnomalyFlag>[];
    final riskFactors = <String>[];
    final reviewTriggers = <String>[];

    final weightKg = pet.weight;
    final weightLbs = _kgToLbs(weightKg);

    final breedConstraint = constraintFor(breed: pet.breed);
    if (breedConstraint == null) {
      // Unknown breed: attempt fallback from labels like "Mixed - Small (0–25 lbs)".
      final parsed = _tryParseWeightRangeFromBreedLabel(pet.breed);
      if (parsed == null) {
        // Truly unknown: no deterministic constraint. Keep confidence neutral.
        return UnderwritingConstraintAssessment(
          catalogVersion: version,
          anomalyFindings: const [],
          riskFactors: const [],
          reviewTriggers: const [],
          confidenceScore: 1.0,
          credibilityRiskScore: 0.0,
          riskMultiplier: 1.0,
          audit: {
            'catalogVersion': version,
            'breed': pet.breed,
            'species': pet.species,
            'weightKg': weightKg,
            'weightLbs': weightLbs,
            'constraintSource': 'none',
          },
        );
      }

      final derivedMaxHealthy = parsed.maxLbs;
      final derivedAnomalyThreshold = derivedMaxHealthy * 1.5;
      final derivedCriticalThreshold = derivedMaxHealthy * 2.0;

      // Treat derived range as a constraint catalog entry (weight only).
      final derivedConstraint = BreedConstraint(
        species: pet.species.trim().toLowerCase(),
        typicalWeightLbs: <num>[parsed.minLbs, parsed.maxLbs],
        maxHealthyWeightLbs: derivedMaxHealthy,
        anomalyThresholdLbs: derivedAnomalyThreshold,
        expectedLifespanYears: const <num>[],
        highRiskTraits: const <String>[],
        severityScaling: true,
      );

      final weightFinding = _assessWeight(
        breed: _normalize(pet.breed),
        weightLbs: weightLbs,
        constraint: derivedConstraint,
        criticalThresholdLbs: derivedCriticalThreshold,
      );
      if (weightFinding != null) {
        findings.add(weightFinding);
        riskFactors.add('Breed-weight mismatch');
        if (weightFinding.severity == AnomalySeverity.critical) {
          reviewTriggers.add('POST_BIND_REVIEW');
          reviewTriggers.add('POSSIBLE_MISREPORTING');
        }
      }

      // Confidence score compounds.
      var confidence = 1.0;
      for (final f in findings) {
        confidence *= (1.0 - f.confidenceImpact.clamp(0.0, 1.0));
      }
      confidence = confidence.clamp(0.0, 1.0);

      final combinedSeverity = _combinedSeverity(findings);
      final credibilityRiskScore =
          (100.0 * (1.0 - _expNeg(2.2 * combinedSeverity))).clamp(0.0, 100.0);
      final riskMultiplier = 1.0 + 1.3 * _pow(combinedSeverity, 1.6);

      return UnderwritingConstraintAssessment(
        catalogVersion: version,
        anomalyFindings: findings,
        riskFactors: riskFactors.toSet().toList(growable: false),
        reviewTriggers: reviewTriggers.toSet().toList(growable: false),
        confidenceScore: confidence,
        credibilityRiskScore: credibilityRiskScore,
        riskMultiplier: riskMultiplier,
        audit: {
          'catalogVersion': version,
          'breed': pet.breed,
          'species': pet.species,
          'weightKg': weightKg,
          'weightLbs': weightLbs,
          'constraintSource': 'derived_range',
          'breedConstraint': {
            'typicalWeightLbsMin': derivedConstraint.typicalWeightLbsMin,
            'typicalWeightLbsMax': derivedConstraint.typicalWeightLbsMax,
            'maxHealthyWeightLbs': derivedConstraint.maxHealthyWeightLbs,
            'anomalyThresholdLbs': derivedConstraint.anomalyThresholdLbs,
            'criticalThresholdLbs': derivedCriticalThreshold,
            'derivedFrom': 'breed_label_range',
          },
        },
      );
    }

    // Cross-field: breed vs species conflict.
    final speciesNorm = pet.species.trim().toLowerCase();
    if (breedConstraint.species.isNotEmpty &&
        speciesNorm != breedConstraint.species) {
      findings.add(
        const AnomalyFlag(
          type: AnomalyFlagType.breedConflict,
          severity: AnomalySeverity.high,
          confidenceImpact: 0.22,
          explanation:
              'Breed is not typically associated with the reported species.',
        ),
      );
      riskFactors.add('Breed-species conflict');
    }

    // Weight constraints (catalog values are lbs; Pet.weight is kg).
    final weightFinding = _assessWeight(
      breed: _normalize(pet.breed),
      weightLbs: weightLbs,
      constraint: breedConstraint,
    );
    if (weightFinding != null) {
      findings.add(weightFinding);
      riskFactors.add('Breed-weight mismatch');

      if (weightFinding.severity == AnomalySeverity.critical) {
        reviewTriggers.add('POST_BIND_REVIEW');
        reviewTriggers.add('POSSIBLE_MISREPORTING');
      }
    }

    // Age vs expected lifespan constraints.
    final ageYears = pet.ageInYears;
    final ageFinding = _assessAge(
      breed: _normalize(pet.breed),
      ageYears: ageYears,
      constraint: breedConstraint,
    );
    if (ageFinding != null) {
      findings.add(ageFinding);
      riskFactors.add('Age-lifespan mismatch');
      if (ageFinding.severity.index >= AnomalySeverity.high.index) {
        reviewTriggers.add('POST_BIND_REVIEW');
      }
    }

    // If multiple anomalies exist, explicitly flag owner reporting risk.
    if (findings.length >= 2) {
      final combined = _combinedSeverity(findings);
      final sev = combined >= 0.85
          ? AnomalySeverity.critical
          : combined >= 0.55
              ? AnomalySeverity.high
              : AnomalySeverity.medium;

      findings.add(
        AnomalyFlag(
          type: AnomalyFlagType.ownerReportingRisk,
          severity: sev,
          confidenceImpact: sev == AnomalySeverity.critical
              ? 0.18
              : sev == AnomalySeverity.high
                  ? 0.12
                  : 0.06,
          explanation:
              'Multiple inconsistencies detected; input credibility risk increased.',
        ),
      );
      riskFactors.add('Input credibility risk');
      if (sev.index >= AnomalySeverity.high.index) {
        reviewTriggers.add('POST_BIND_REVIEW');
      }
    }

    // Confidence score compounds (do NOT take min; compound as uncertainty).
    var confidence = 1.0;
    for (final f in findings) {
      confidence *= (1.0 - f.confidenceImpact.clamp(0.0, 1.0));
    }
    confidence = confidence.clamp(0.0, 1.0);

    // Credibility risk is the complement of confidence, but non-linear so
    // extreme anomalies are penalized more than mere rarity.
    final combinedSeverity = _combinedSeverity(findings);
    // Maps combinedSeverity in [0,1] to a 0-100 credibility risk curve.
    final credibilityRiskScore =
        (100.0 * (1.0 - _expNeg(2.2 * combinedSeverity))).clamp(0.0, 100.0);

    // Non-linear risk multiplier used in synthesis.
    final riskMultiplier = 1.0 + 1.3 * _pow(combinedSeverity, 1.6);

    return UnderwritingConstraintAssessment(
      catalogVersion: version,
      anomalyFindings: findings,
      riskFactors: riskFactors.toSet().toList(growable: false),
      reviewTriggers: reviewTriggers.toSet().toList(growable: false),
      confidenceScore: confidence,
      credibilityRiskScore: credibilityRiskScore,
      riskMultiplier: riskMultiplier,
      audit: {
        'catalogVersion': version,
        'breed': pet.breed,
        'species': pet.species,
        'weightKg': weightKg,
        'weightLbs': weightLbs,
        'constraintSource': 'catalog',
        'breedConstraint': {
          'typicalWeightLbsMin': breedConstraint.typicalWeightLbsMin,
          'typicalWeightLbsMax': breedConstraint.typicalWeightLbsMax,
          'maxHealthyWeightLbs': breedConstraint.maxHealthyWeightLbs,
          'anomalyThresholdLbs': breedConstraint.anomalyThresholdLbs,
          'expectedLifespanYearsMin': breedConstraint.expectedLifespanYearsMin,
          'expectedLifespanYearsMax': breedConstraint.expectedLifespanYearsMax,
          'highRiskTraits': breedConstraint.highRiskTraits,
          'severityScaling': breedConstraint.severityScaling,
        },
      },
    );
  }

  AnomalyFlag? _assessWeight({
    required String breed,
    required double weightLbs,
    required BreedConstraint constraint,
    double? criticalThresholdLbs,
  }) {
    const toleranceLbs = 0.25;
    // Confidence bands:
    // - Outside typical range: LOW.
    // - Above maxHealthy: MEDIUM/HIGH.
    // - Above anomalyThreshold: CRITICAL (with severity scaling).
    final typicalMin = constraint.typicalWeightLbsMin;
    final typicalMax = constraint.typicalWeightLbsMax;
    final maxHealthy = constraint.maxHealthyWeightLbs;
    final anomalyThreshold = constraint.anomalyThresholdLbs;
    final criticalThreshold =
      (criticalThresholdLbs ?? anomalyThreshold).clamp(1.0, 9999.0);

    if (weightLbs <= 0) {
      return const AnomalyFlag(
        type: AnomalyFlagType.weightOutlier,
        severity: AnomalySeverity.high,
        confidenceImpact: 0.22,
        explanation: 'Reported weight is non-positive.',
      );
    }

    if (weightLbs >= (typicalMin - toleranceLbs) &&
        weightLbs <= (typicalMax + toleranceLbs)) {
      return null;
    }

    if (weightLbs < typicalMin) {
      // Underweight can be legitimate; treat as mild credibility + health risk.
      return AnomalyFlag(
        type: AnomalyFlagType.weightOutlier,
        severity: AnomalySeverity.low,
        confidenceImpact: 0.05,
        explanation:
            'Reported weight is below typical range for breed (reported ${weightLbs.toStringAsFixed(1)} lbs; typical $typicalMin–$typicalMax).',
      );
    }

    // Over typical.
    if (weightLbs <= maxHealthy) {
      return AnomalyFlag(
        type: AnomalyFlagType.weightOutlier,
        severity: AnomalySeverity.low,
        confidenceImpact: 0.05,
        explanation:
            'Reported weight is above typical range but still plausible for breed (reported ${weightLbs.toStringAsFixed(1)} lbs; typical $typicalMin–$typicalMax).',
      );
    }

    if (weightLbs <= anomalyThreshold) {
      final over = (weightLbs - maxHealthy).clamp(0.0, 9999.0);
      final span = (anomalyThreshold - maxHealthy).clamp(1.0, 9999.0);
      final t = (over / span).clamp(0.0, 1.0);
      final sev = t < 0.33
          ? AnomalySeverity.medium
          : t < 0.8
              ? AnomalySeverity.high
              : AnomalySeverity.high;

      final impact =
          sev == AnomalySeverity.medium ? 0.12 : 0.22; // deterministic

      return AnomalyFlag(
        type: AnomalyFlagType.weightOutlier,
        severity: sev,
        confidenceImpact: impact,
        explanation:
            'Reported weight exceeds expected maximum for breed (reported ${weightLbs.toStringAsFixed(1)} lbs; expected max healthy ~$maxHealthy lbs).',
      );
    }

    // If using a derived critical threshold (e.g. 2.0× maxHealthy), allow a
    // "very high" band between anomalyThreshold and criticalThreshold.
    if (criticalThresholdLbs != null && weightLbs < criticalThreshold) {
      return AnomalyFlag(
        type: AnomalyFlagType.weightOutlier,
        severity: AnomalySeverity.high,
        confidenceImpact: 0.22,
        explanation:
            'Reported weight is far above expected maximum for breed (reported ${weightLbs.toStringAsFixed(1)} lbs; expected max healthy ~$maxHealthy lbs).',
      );
    }

    // Critical outlier: penalize biological implausibility strongly.
    final ratio = weightLbs / maxHealthy;
    final scaledImpact = (0.28 + (ratio - 1.0) * 0.02).clamp(0.28, 0.55);

    return AnomalyFlag(
      type: AnomalyFlagType.weightOutlier,
      severity: AnomalySeverity.critical,
      confidenceImpact: scaledImpact,
      explanation:
          'Reported weight is >${ratio.toStringAsFixed(1)}× expected maximum for breed (reported ${weightLbs.toStringAsFixed(1)} lbs; expected max healthy ~$maxHealthy lbs).',
    );
  }

  AnomalyFlag? _assessAge({
    required String breed,
    required int ageYears,
    required BreedConstraint constraint,
  }) {
    final min = constraint.expectedLifespanYearsMin;
    final max = constraint.expectedLifespanYearsMax;

    if (ageYears < 0) {
      return const AnomalyFlag(
        type: AnomalyFlagType.ageMismatch,
        severity: AnomalySeverity.high,
        confidenceImpact: 0.22,
        explanation: 'Reported age is negative.',
      );
    }

    // Being below min lifespan is not a mismatch; it's expected.
    if (ageYears <= max) return null;

    final over = ageYears - max;
    if (over <= 1) {
      return AnomalyFlag(
        type: AnomalyFlagType.ageMismatch,
        severity: AnomalySeverity.low,
        confidenceImpact: 0.05,
        explanation:
            'Reported age is slightly above typical lifespan range (reported $ageYears years; expected $min–$max).',
      );
    }

    if (over <= 4) {
      return AnomalyFlag(
        type: AnomalyFlagType.ageMismatch,
        severity: AnomalySeverity.high,
        confidenceImpact: 0.22,
        explanation:
            'Reported age is above expected lifespan range (reported $ageYears years; expected $min–$max).',
      );
    }

    return AnomalyFlag(
      type: AnomalyFlagType.ageMismatch,
      severity: AnomalySeverity.critical,
      confidenceImpact: 0.35,
      explanation:
          'Reported age is far above expected lifespan range (reported $ageYears years; expected $min–$max).',
    );
  }
}

class UnderwritingConstraintAssessment {
  final String catalogVersion;
  final List<String> riskFactors;
  final List<AnomalyFlag> anomalyFindings;
  final double confidenceScore; // 0-1
  final List<String> reviewTriggers;

  /// 0-100: separate track from physiological/medical risk.
  final double credibilityRiskScore;

  /// Non-linear multiplier to apply to pricing/risk synthesis.
  final double riskMultiplier;

  /// Deterministic, JSON-safe snapshot of inputs and constraints used.
  ///
  /// This is intended for:
  /// - Quote/case persistence
  /// - Audit logs
  /// - Debugging premium deltas driven by implausible inputs
  final Map<String, dynamic>? audit;

  const UnderwritingConstraintAssessment({
    required this.catalogVersion,
    required this.riskFactors,
    required this.anomalyFindings,
    required this.reviewTriggers,
    required this.confidenceScore,
    required this.credibilityRiskScore,
    required this.riskMultiplier,
    this.audit,
  });

  Map<String, dynamic> toJson() {
    return {
      'catalogVersion': catalogVersion,
      'riskFactors': riskFactors,
      'anomalyFindings': anomalyFindings.map((f) => f.toJson()).toList(),
      'confidenceScore': confidenceScore,
      'reviewTriggers': reviewTriggers,
      'credibilityRiskScore': credibilityRiskScore,
      'riskMultiplier': riskMultiplier,
      if (audit != null) 'audit': audit,
    };
  }
}

class BreedConstraint {
  final String species;
  final List<num> typicalWeightLbs;
  final num _maxHealthyWeightLbs;
  final num _anomalyThresholdLbs;
  final List<num> expectedLifespanYears;
  final List<String> highRiskTraits;
  final bool severityScaling;

  const BreedConstraint({
    required this.species,
    required this.typicalWeightLbs,
    required num maxHealthyWeightLbs,
    required num anomalyThresholdLbs,
    required this.expectedLifespanYears,
    required this.highRiskTraits,
    required this.severityScaling,
  }) : _maxHealthyWeightLbs = maxHealthyWeightLbs,
       _anomalyThresholdLbs = anomalyThresholdLbs;

  double get typicalWeightLbsMin =>
      typicalWeightLbs.isNotEmpty ? typicalWeightLbs.first.toDouble() : 0.0;
  double get typicalWeightLbsMax => typicalWeightLbs.length >= 2
      ? typicalWeightLbs[1].toDouble()
      : typicalWeightLbs.isNotEmpty
          ? typicalWeightLbs.first.toDouble()
          : 0.0;

  double get maxHealthyWeightLbs => _maxHealthyWeightLbs.toDouble();
  double get anomalyThresholdLbs => _anomalyThresholdLbs.toDouble();

  int get expectedLifespanYearsMin => expectedLifespanYears.isNotEmpty
      ? expectedLifespanYears.first.toInt()
      : 0;
  int get expectedLifespanYearsMax => expectedLifespanYears.length >= 2
      ? expectedLifespanYears[1].toInt()
      : expectedLifespanYears.isNotEmpty
          ? expectedLifespanYears.first.toInt()
          : 0;

  factory BreedConstraint.fromJson(Map<String, dynamic> json) {
    return BreedConstraint(
      species: (json['species'] ?? '').toString().trim().toLowerCase(),
      typicalWeightLbs: (json['typicalWeightLbs'] as List?)
              ?.whereType<num>()
              .toList(growable: false) ??
          const <num>[],
      maxHealthyWeightLbs: (json['maxHealthyWeightLbs'] as num?) ?? 0,
      anomalyThresholdLbs: (json['anomalyThresholdLbs'] as num?) ?? 0,
      expectedLifespanYears: (json['expectedLifespanYears'] as List?)
              ?.whereType<num>()
              .toList(growable: false) ??
          const <num>[],
      highRiskTraits: (json['highRiskTraits'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      severityScaling: (json['severityScaling'] as bool?) ?? true,
    );
  }
}

String _normalize(String input) {
  final lower = input.trim().toLowerCase();
  // Collapse whitespace and remove obvious punctuation.
  return lower
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

double _kgToLbs(double kg) => kg * 2.2046226218;

double _combinedSeverity(List<AnomalyFlag> flags) {
  if (flags.isEmpty) return 0.0;
  // Compound severity so multiple medium issues add up.
  var combined = 0.0;
  for (final f in flags) {
    combined = 1.0 - (1.0 - combined) * (1.0 - f.severity.score);
  }
  return combined.clamp(0.0, 1.0);
}

// Lightweight math helpers (avoid importing dart:math for determinism/simplicity).
double _pow(double base, double exp) {
  // exp is small and fixed (1.6). Use exp(ln(base)*exp).
  if (base <= 0) return 0;
  return _exp(_ln(base) * exp);
}

double _expNeg(double x) => _exp(-x);

double _exp(double x) => double.parse((x.isFinite ? x : 0.0).toStringAsExponential(20)).isNaN
    ? 1.0
    : _expSeries(x);

// Simple exp approximation good enough for scoring curves.
double _expSeries(double x) {
  // Clamp to keep series stable.
  final z = x.clamp(-8.0, 8.0);
  var term = 1.0;
  var sum = 1.0;
  for (var i = 1; i <= 18; i++) {
    term *= z / i;
    sum += term;
  }
  return sum;
}

// Natural log approximation using change of base with a few Newton iterations.
double _ln(double x) {
  if (x <= 0) return double.negativeInfinity;
  // Initial guess.
  var y = 0.0;
  // Scale x to near 1 for stability.
  var z = x;
  while (z > 1.5) {
    z /= 2;
    y += 0.69314718056;
  }
  while (z < 0.75) {
    z *= 2;
    y -= 0.69314718056;
  }
  // Newton-Raphson on ln(z).
  var t = 0.0;
  for (var i = 0; i < 8; i++) {
    final e = _expSeries(t);
    t -= (e - z) / e;
  }
  return y + t;
}
