import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/pet.dart';
import '../models/risk_score.dart';

/// Eligibility result with detailed reasoning and exclusions
class EligibilityResult {
  final bool eligible;
  final String reason;
  final String? ruleViolated;
  final dynamic violatedValue;
  final List<String>
  excludedConditions; // NEW: Conditions that will be excluded from coverage
  final bool hasExclusions; // NEW: Whether this is a conditional approval

  const EligibilityResult({
    required this.eligible,
    this.reason = '',
    this.ruleViolated,
    this.violatedValue,
    this.excludedConditions = const [],
    this.hasExclusions = false,
  });

  /// Factory constructor for eligible results (no exclusions)
  factory EligibilityResult.eligible() {
    return const EligibilityResult(
      eligible: true,
      reason: 'Pet meets all underwriting requirements',
    );
  }

  /// Factory constructor for conditional approval WITH exclusions
  /// (Eligible for coverage but certain conditions are excluded)
  factory EligibilityResult.eligibleWithExclusions({
    required List<String> excludedConditions,
    String? additionalNotes,
  }) {
    return EligibilityResult(
      eligible: true,
      hasExclusions: true,
      excludedConditions: excludedConditions,
      reason:
          additionalNotes ??
          'Coverage approved with the following pre-existing condition exclusions: ${excludedConditions.join(", ")}',
    );
  }

  /// Factory constructor for ineligible results (full decline)
  factory EligibilityResult.ineligible({
    required String reason,
    String? ruleViolated,
    dynamic violatedValue,
  }) {
    return EligibilityResult(
      eligible: false,
      reason: reason,
      ruleViolated: ruleViolated,
      violatedValue: violatedValue,
    );
  }

  /// Convert to JSON for storage/logging
  Map<String, dynamic> toJson() {
    return {
      'eligible': eligible,
      'reason': reason,
      if (ruleViolated != null) 'ruleViolated': ruleViolated,
      if (violatedValue != null) 'violatedValue': violatedValue,
      'hasExclusions': hasExclusions,
      if (excludedConditions.isNotEmpty)
        'excludedConditions': excludedConditions,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}

/// Underwriting Rules Engine
///
/// Determines pet eligibility based on admin-defined rules in Firestore.
/// Rules are stored in: `admin_settings/underwriting_rules`
///
/// Usage:
/// ```dart
/// final engine = UnderwritingRulesEngine();
/// final result = await engine.checkEligibility(pet, riskScore, conditions);
/// if (!result.eligible) {
///   print('Ineligible: ${result.reason}');
/// }
/// ```
class UnderwritingRulesEngine {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _functions;
  final bool _enablePublicCallable;

  // Cache rules to avoid excessive Firestore reads
  Map<String, dynamic>? _cachedRules;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 15);

  UnderwritingRulesEngine({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    bool enablePublicCallable = true,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions,
       _enablePublicCallable = enablePublicCallable;

  String _summarizeConditions(List<String> conditions, {int max = 6}) {
    if (conditions.isEmpty) return '(none)';
    final trimmed = conditions
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    if (trimmed.isEmpty) return '(none)';
    final head = trimmed.take(max).join(', ');
    return trimmed.length > max ? '$head … (+${trimmed.length - max})' : head;
  }

  /// Load underwriting rules from Firestore
  ///
  /// Expects document structure:
  /// ```
  /// admin_settings/underwriting_rules:
  ///   maxRiskScore: 85
  ///   minAgeMonths: 2
  ///   maxAgeYears: 14
  ///   excludedBreeds: ['Wolf Hybrid', 'Pit Bull', ...]
  ///   criticalConditions: ['cancer', 'terminal illness', ...]
  ///   enabled: true
  /// ```
  Future<Map<String, dynamic>> getRules() async {
    // Return cached rules if still valid
    if (_cachedRules != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedRules!;
    }

    // First try: public callable (works for unauthenticated quote flows).
    // Falls back to Firestore direct read (useful in dev / when rules are readable).
    if (_enablePublicCallable) {
      try {
        final callable = (_functions ?? FirebaseFunctions.instance)
            .httpsCallable('getUnderwritingRulesPublic');
        final result = await callable.call();

        final raw = result.data;
        final Map<String, dynamic> rules = raw is Map
            ? raw.map((key, value) => MapEntry(key.toString(), value))
            : <String, dynamic>{};

        final completeRules = {
          ..._getDefaultRules(),
          ...rules,
          'rulesAvailable': true,
        };

        _cachedRules = completeRules;
        _cacheTimestamp = DateTime.now();

        print(
          '📚 Underwriting rules loaded (source=callable, enabled=${completeRules['enabled']}, excludedBreeds=${(completeRules['excludedBreeds'] as List?)?.length ?? 0}, critical=${(completeRules['criticalConditions'] as List?)?.length ?? 0}, excludable=${(completeRules['excludableConditions'] as List?)?.length ?? 0})',
        );

        return completeRules;
      } catch (e) {
        // Ignore and try Firestore next.
        print(
          'ℹ️ getUnderwritingRulesPublic unavailable, falling back to Firestore: $e',
        );
      }
    }

    try {
      final docSnapshot = await _firestore
          .collection('admin_settings')
          .doc('underwriting_rules')
          .get();

      if (!docSnapshot.exists) {
        print('⚠️ Underwriting rules not found; underwriting will fail closed');
        return {
          ..._getDefaultRules(),
          'rulesAvailable': false,
        };
      }

      final rules = docSnapshot.data() ?? {};

      // Merge with defaults to ensure all required fields exist
      final completeRules = {
        ..._getDefaultRules(),
        ...rules,
        'rulesAvailable': true,
      };

      // Update cache
      _cachedRules = completeRules;
      _cacheTimestamp = DateTime.now();

      print(
        '📚 Underwriting rules loaded (source=firestore, enabled=${completeRules['enabled']}, excludedBreeds=${(completeRules['excludedBreeds'] as List?)?.length ?? 0}, critical=${(completeRules['criticalConditions'] as List?)?.length ?? 0}, excludable=${(completeRules['excludableConditions'] as List?)?.length ?? 0})',
      );

      return completeRules;
    } catch (e) {
      print('❌ Error loading underwriting rules: $e');
      return {
        ..._getDefaultRules(),
        'rulesAvailable': false,
      };
    }
  }

  /// Default rules fallback
  Map<String, dynamic> _getDefaultRules() {
    return {
      'maxRiskScore': 90,
      'minAgeMonths': 2, // 2 months minimum
      'maxAgeYears': 14, // 14 years maximum
      'excludedBreeds': <String>[
        'Wolf Hybrid',
        'Wolf Dog',
        'Pit Bull Terrier',
        'American Pit Bull Terrier',
        'Staffordshire Bull Terrier',
        'Presa Canario',
        'Dogo Argentino',
      ],
      'criticalConditions': <String>[
        'cancer',
        'terminal illness',
        'end stage kidney disease',
        'end stage liver disease',
        'congestive heart failure',
        'malignant tumor',
        'terminal cancer',
        'metastatic cancer',
      ],
      // Conditions that are typically excluded as pre-existing (conditional
      // approval) rather than full declines.
      'excludableConditions': <String>[
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
      ],
      'enabled': true,
      // When rules cannot be fetched, we mark them unavailable and fail closed.
      'rulesAvailable': false,
    };
  }

  /// Clear cached rules (useful for testing or after admin updates)
  void clearCache() {
    _cachedRules = null;
    _cacheTimestamp = null;
  }

  /// Check pet eligibility against underwriting rules
  ///
  /// Returns [EligibilityResult] with detailed reasoning
  ///
  /// Example:
  /// ```dart
  /// final result = await engine.checkEligibility(
  ///   pet,
  ///   riskScore,
  ///   ['arthritis', 'allergies'],
  /// );
  /// ```
  Future<EligibilityResult> checkEligibility(
    Pet pet,
    RiskScore riskScore,
    List<String> conditions,
  ) async {
    print(
      '🧾 Underwriting checkEligibility start: pet=${pet.name} breed=${pet.breed} score=${riskScore.overallScore.toStringAsFixed(1)} conditions=${_summarizeConditions(conditions)}',
    );

    // Load rules
    final rules = await getRules();

    final rulesAvailable = rules['rulesAvailable'] == true;

    // Check if rules engine is enabled
    if (rules['enabled'] == false) {
      print('⚠️ Underwriting rules engine is disabled; failing closed');
      return EligibilityResult.ineligible(
        reason: 'Underwriting rules are temporarily unavailable. We can\'t complete underwriting right now.',
        ruleViolated: 'RULES_UNAVAILABLE',
      );
    }

    if (!rulesAvailable) {
      print('⚠️ Underwriting rules unavailable; failing closed');
      return EligibilityResult.ineligible(
        reason: 'Underwriting rules are temporarily unavailable. We can\'t complete underwriting right now.',
        ruleViolated: 'RULES_UNAVAILABLE',
      );
    }

    // 1. Check risk score threshold
    final maxRiskScore = rules['maxRiskScore'] as int? ?? 90;
    if (riskScore.overallScore > maxRiskScore) {
      final result = EligibilityResult.ineligible(
        reason:
            'Risk score of ${riskScore.overallScore.toStringAsFixed(1)} '
            'exceeds maximum allowed score of $maxRiskScore. '
            'This pet requires manual underwriting review.',
        ruleViolated: 'maxRiskScore',
        violatedValue: riskScore.overallScore,
      );

      print(
        '🧾 Underwriting checkEligibility result: eligible=false rule=maxRiskScore value=${riskScore.overallScore}',
      );

      return result;
    }

    // 2. Check excluded breeds
    final excludedBreeds =
        (rules['excludedBreeds'] as List?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        [];

    final petBreedLower = pet.breed.toLowerCase();
    for (final excludedBreed in excludedBreeds) {
      if (petBreedLower.contains(excludedBreed) ||
          excludedBreed.contains(petBreedLower)) {
        final result = EligibilityResult.ineligible(
          reason:
              'The breed "${pet.breed}" is not eligible for coverage '
              'under our current underwriting guidelines. '
              'Please contact our underwriting team for alternative options.',
          ruleViolated: 'excludedBreeds',
          violatedValue: pet.breed,
        );

        print(
          '🧾 Underwriting checkEligibility result: eligible=false rule=excludedBreeds value=${pet.breed}',
        );

        return result;
      }
    }

    // 3. Check critical conditions (DECLINE) vs excludable conditions (EXCLUDE)
    final criticalConditions =
        (rules['criticalConditions'] as List?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        [];

    final excludableConditions =
        (rules['excludableConditions'] as List?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        [];

    final List<String> conditionsToExclude = [];

    for (final condition in conditions) {
      final conditionLower = condition.toLowerCase();

      // Check if it's a CRITICAL condition (auto-decline)
      for (final critical in criticalConditions) {
        if (conditionLower.contains(critical) ||
            critical.contains(conditionLower)) {
          final result = EligibilityResult.ineligible(
            reason:
                'The condition "$condition" is classified as a critical '
                'pre-existing condition and cannot be covered at this time. '
                'Our team can discuss alternative coverage options.',
            ruleViolated: 'criticalConditions',
            violatedValue: condition,
          );

          print(
            '🧾 Underwriting checkEligibility result: eligible=false rule=criticalConditions value=$condition',
          );

          return result;
        }
      }

      // Check if it's an EXCLUDABLE condition (conditional approval)
      for (final excludable in excludableConditions) {
        if (conditionLower.contains(excludable) ||
            excludable.contains(conditionLower)) {
          conditionsToExclude.add(condition);
          break;
        }
      }
    }

    // 4. Check minimum age
    final minAgeMonths = rules['minAgeMonths'] as int? ?? 2;
    final petAgeInMonths = _calculateAgeInMonths(pet.dateOfBirth);

    if (petAgeInMonths < minAgeMonths) {
      final yearsMonths = _formatAge(minAgeMonths);
      final result = EligibilityResult.ineligible(
        reason:
            '${pet.name} is too young for coverage. '
            'Pets must be at least $yearsMonths old. '
            'Current age: ${_formatAge(petAgeInMonths)}.',
        ruleViolated: 'minAgeMonths',
        violatedValue: petAgeInMonths,
      );

      print(
        '🧾 Underwriting checkEligibility result: eligible=false rule=minAgeMonths value=$petAgeInMonths',
      );

      return result;
    }

    // 5. Check maximum age
    final maxAgeYears = rules['maxAgeYears'] as int? ?? 14;
    final maxAgeMonths = maxAgeYears * 12;
    if (petAgeInMonths > maxAgeMonths) {
      final result = EligibilityResult.ineligible(
        reason:
            '${pet.name} is above the maximum age for new coverage. '
            'Pets must be under $maxAgeYears years old to enroll. '
            'Current age: ${_formatAge(petAgeInMonths)}.',
        ruleViolated: 'maxAgeYears',
        violatedValue: petAgeInMonths,
      );

      print(
        '🧾 Underwriting checkEligibility result: eligible=false rule=maxAgeYears value=$petAgeInMonths',
      );

      return result;
    }

    // All checks passed - return eligible (with exclusions if any)
    if (conditionsToExclude.isNotEmpty) {
      final result = EligibilityResult.eligibleWithExclusions(
        excludedConditions: conditionsToExclude,
      );

      print(
        '🧾 Underwriting checkEligibility result: eligible=true exclusions=${_summarizeConditions(conditionsToExclude)}',
      );

      return result;
    }

    final result = EligibilityResult.eligible();
    print(
      '🧾 Underwriting checkEligibility result: eligible=true exclusions=(none)',
    );
    return result;
  }

  /// Deterministic eligibility check that ignores condition strings.
  ///
  /// Medical conditions must be evaluated from strict medical facts elsewhere.
  Future<EligibilityResult> checkEligibilityDeterministic({
    required Pet pet,
    required RiskScore riskScore,
  }) async {
    // Delegate to the same rules, but with an empty conditions list.
    return checkEligibility(pet, riskScore, const <String>[]);
  }

  /// Batch check eligibility for multiple pets
  Future<Map<String, EligibilityResult>> checkBatchEligibility(
    List<Pet> pets,
    Map<String, RiskScore> riskScores,
    Map<String, List<String>> conditionsMap,
  ) async {
    final results = <String, EligibilityResult>{};

    for (final pet in pets) {
      final petId = pet.id;
      final riskScore = riskScores[petId];
      final conditions = conditionsMap[petId] ?? [];

      if (riskScore == null) {
        results[petId] = EligibilityResult.ineligible(
          reason: 'Risk score not available for ${pet.name}',
          ruleViolated: 'missing_risk_score',
        );
        continue;
      }

      results[petId] = await checkEligibility(pet, riskScore, conditions);
    }

    return results;
  }

  /// Pre-check eligibility before full risk calculation
  /// (Useful for early rejection to save API costs)
  Future<EligibilityResult> quickCheck(Pet pet, List<String> conditions) async {
    final rules = await getRules();

    final rulesAvailable = rules['rulesAvailable'] == true;

    if (rules['enabled'] == false) {
      return EligibilityResult.ineligible(
        reason: 'Underwriting rules are temporarily unavailable. We can\'t complete underwriting right now.',
        ruleViolated: 'RULES_UNAVAILABLE',
      );
    }

    if (!rulesAvailable) {
      return EligibilityResult.ineligible(
        reason: 'Underwriting rules are temporarily unavailable. We can\'t complete underwriting right now.',
        ruleViolated: 'RULES_UNAVAILABLE',
      );
    }

    // Check excluded breeds
    final excludedBreeds =
        (rules['excludedBreeds'] as List?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        [];

    final petBreedLower = pet.breed.toLowerCase();
    for (final excludedBreed in excludedBreeds) {
      if (petBreedLower.contains(excludedBreed) ||
          excludedBreed.contains(petBreedLower)) {
        return EligibilityResult.ineligible(
          reason: 'The breed "${pet.breed}" is not eligible for coverage.',
          ruleViolated: 'excludedBreeds',
          violatedValue: pet.breed,
        );
      }
    }

    // Check critical conditions
    final criticalConditions =
        (rules['criticalConditions'] as List?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        [];

    for (final condition in conditions) {
      final conditionLower = condition.toLowerCase();
      for (final critical in criticalConditions) {
        if (conditionLower.contains(critical) ||
            critical.contains(conditionLower)) {
          return EligibilityResult.ineligible(
            reason: 'The condition "$condition" cannot be covered.',
            ruleViolated: 'criticalConditions',
            violatedValue: condition,
          );
        }
      }
    }

    // Check age limits
    final minAgeMonths = rules['minAgeMonths'] as int? ?? 2;
    final maxAgeYears = rules['maxAgeYears'] as int? ?? 14;
    final maxAgeMonths = maxAgeYears * 12;
    final petAgeInMonths = _calculateAgeInMonths(pet.dateOfBirth);

    if (petAgeInMonths < minAgeMonths) {
      return EligibilityResult.ineligible(
        reason:
            '${pet.name} is too young for coverage (minimum: ${_formatAge(minAgeMonths)}).',
        ruleViolated: 'minAgeMonths',
        violatedValue: petAgeInMonths,
      );
    }

    if (petAgeInMonths > maxAgeMonths) {
      return EligibilityResult.ineligible(
        reason:
            '${pet.name} is too old for new coverage (maximum: $maxAgeYears years).',
        ruleViolated: 'maxAgeYears',
        violatedValue: petAgeInMonths,
      );
    }

    return EligibilityResult.eligible();
  }

  /// Store eligibility result in Firestore for audit trail
  Future<void> storeEligibilityResult(
    String quoteId,
    EligibilityResult result,
  ) async {
    try {
      await _firestore
          .collection('quotes')
          .doc(quoteId)
          .collection('eligibility_checks')
          .add(result.toJson());
    } catch (e) {
      print('❌ Error storing eligibility result: $e');
    }
  }

  /// Calculate age in months from date of birth
  int _calculateAgeInMonths(DateTime dateOfBirth) {
    final now = DateTime.now();
    final years = now.year - dateOfBirth.year;
    final months = now.month - dateOfBirth.month;
    final days = now.day - dateOfBirth.day;

    int totalMonths = (years * 12) + months;

    // Adjust if the day hasn't been reached yet
    if (days < 0) {
      totalMonths--;
    }

    return totalMonths;
  }

  /// Format age in months to readable string
  String _formatAge(int months) {
    if (months < 12) {
      return '$months ${months == 1 ? 'month' : 'months'}';
    }

    final years = months ~/ 12;
    final remainingMonths = months % 12;

    if (remainingMonths == 0) {
      return '$years ${years == 1 ? 'year' : 'years'}';
    }

    return '$years ${years == 1 ? 'year' : 'years'} and '
        '$remainingMonths ${remainingMonths == 1 ? 'month' : 'months'}';
  }

  /// Get eligibility statistics for admin dashboard
  Future<Map<String, dynamic>> getEligibilityStats({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _firestore.collectionGroup('eligibility_checks');

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();

      int totalChecks = snapshot.docs.length;
      int eligible = 0;
      int ineligible = 0;
      final rejectionReasons = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['eligible'] == true) {
          eligible++;
        } else {
          ineligible++;
          final reason = data['ruleViolated'] as String? ?? 'unknown';
          rejectionReasons[reason] = (rejectionReasons[reason] ?? 0) + 1;
        }
      }

      return {
        'totalChecks': totalChecks,
        'eligible': eligible,
        'ineligible': ineligible,
        'eligibilityRate': totalChecks > 0 ? (eligible / totalChecks * 100) : 0,
        'rejectionReasons': rejectionReasons,
        'period': {
          'start': startDate?.toIso8601String(),
          'end': endDate?.toIso8601String(),
        },
      };
    } catch (e) {
      print('❌ Error calculating eligibility stats: $e');
      return {'error': e.toString()};
    }
  }
}
