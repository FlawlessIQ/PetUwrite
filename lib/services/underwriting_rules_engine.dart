import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pet.dart';
import '../models/risk_score.dart';

/// Eligibility result with detailed reasoning
class EligibilityResult {
  final bool eligible;
  final String reason;
  final String? ruleViolated;
  final dynamic violatedValue;

  const EligibilityResult({
    required this.eligible,
    this.reason = '',
    this.ruleViolated,
    this.violatedValue,
  });

  /// Factory constructor for eligible results
  factory EligibilityResult.eligible() {
    return const EligibilityResult(
      eligible: true,
      reason: 'Pet meets all underwriting requirements',
    );
  }

  /// Factory constructor for ineligible results
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
  
  // Cache rules to avoid excessive Firestore reads
  Map<String, dynamic>? _cachedRules;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 15);

  UnderwritingRulesEngine({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

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

    try {
      final docSnapshot = await _firestore
          .collection('admin_settings')
          .doc('underwriting_rules')
          .get();

      if (!docSnapshot.exists) {
        print('⚠️ Underwriting rules not found, using defaults');
        return _getDefaultRules();
      }

      final rules = docSnapshot.data() ?? {};
      
      // Merge with defaults to ensure all required fields exist
      final completeRules = {
        ..._getDefaultRules(),
        ...rules,
      };

      // Update cache
      _cachedRules = completeRules;
      _cacheTimestamp = DateTime.now();

      return completeRules;
    } catch (e) {
      print('❌ Error loading underwriting rules: $e');
      return _getDefaultRules();
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
      'enabled': true,
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
    // Load rules
    final rules = await getRules();

    // Check if rules engine is enabled
    if (rules['enabled'] == false) {
      print('ℹ️ Underwriting rules engine is disabled, approving by default');
      return EligibilityResult.eligible();
    }

    // 1. Check risk score threshold
    final maxRiskScore = rules['maxRiskScore'] as int? ?? 90;
    if (riskScore.overallScore > maxRiskScore) {
      return EligibilityResult.ineligible(
        reason: 'Risk score of ${riskScore.overallScore.toStringAsFixed(1)} '
            'exceeds maximum allowed score of $maxRiskScore. '
            'This pet requires manual underwriting review.',
        ruleViolated: 'maxRiskScore',
        violatedValue: riskScore.overallScore,
      );
    }

    // 2. Check excluded breeds
    final excludedBreeds = (rules['excludedBreeds'] as List?)
        ?.map((e) => e.toString().toLowerCase())
        .toList() ?? [];
    
    final petBreedLower = pet.breed.toLowerCase();
    for (final excludedBreed in excludedBreeds) {
      if (petBreedLower.contains(excludedBreed) ||
          excludedBreed.contains(petBreedLower)) {
        return EligibilityResult.ineligible(
          reason: 'The breed "${pet.breed}" is not eligible for coverage '
              'under our current underwriting guidelines. '
              'Please contact our underwriting team for alternative options.',
          ruleViolated: 'excludedBreeds',
          violatedValue: pet.breed,
        );
      }
    }

    // 3. Check critical conditions
    final criticalConditions = (rules['criticalConditions'] as List?)
        ?.map((e) => e.toString().toLowerCase())
        .toList() ?? [];
    
    for (final condition in conditions) {
      final conditionLower = condition.toLowerCase();
      for (final critical in criticalConditions) {
        if (conditionLower.contains(critical) ||
            critical.contains(conditionLower)) {
          return EligibilityResult.ineligible(
            reason: 'The condition "$condition" is classified as a critical '
                'pre-existing condition and cannot be covered at this time. '
                'Our team can discuss alternative coverage options.',
            ruleViolated: 'criticalConditions',
            violatedValue: condition,
          );
        }
      }
    }

    // 4. Check minimum age
    final minAgeMonths = rules['minAgeMonths'] as int? ?? 2;
    final petAgeInMonths = _calculateAgeInMonths(pet.dateOfBirth);
    
    if (petAgeInMonths < minAgeMonths) {
      final yearsMonths = _formatAge(minAgeMonths);
      return EligibilityResult.ineligible(
        reason: '${pet.name} is too young for coverage. '
            'Pets must be at least $yearsMonths old. '
            'Current age: ${_formatAge(petAgeInMonths)}.',
        ruleViolated: 'minAgeMonths',
        violatedValue: petAgeInMonths,
      );
    }

    // 5. Check maximum age
    final maxAgeYears = rules['maxAgeYears'] as int? ?? 14;
    final maxAgeMonths = maxAgeYears * 12;
    if (petAgeInMonths > maxAgeMonths) {
      return EligibilityResult.ineligible(
        reason: '${pet.name} is above the maximum age for new coverage. '
            'Pets must be under $maxAgeYears years old to enroll. '
            'Current age: ${_formatAge(petAgeInMonths)}.',
        ruleViolated: 'maxAgeYears',
        violatedValue: petAgeInMonths,
      );
    }

    // All checks passed
    return EligibilityResult.eligible();
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

    if (rules['enabled'] == false) {
      return EligibilityResult.eligible();
    }

    // Check excluded breeds
    final excludedBreeds = (rules['excludedBreeds'] as List?)
        ?.map((e) => e.toString().toLowerCase())
        .toList() ?? [];
    
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
    final criticalConditions = (rules['criticalConditions'] as List?)
        ?.map((e) => e.toString().toLowerCase())
        .toList() ?? [];
    
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
        reason: '${pet.name} is too young for coverage (minimum: ${_formatAge(minAgeMonths)}).',
        ruleViolated: 'minAgeMonths',
        violatedValue: petAgeInMonths,
      );
    }

    if (petAgeInMonths > maxAgeMonths) {
      return EligibilityResult.ineligible(
        reason: '${pet.name} is too old for new coverage (maximum: $maxAgeYears years).',
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
      return {
        'error': e.toString(),
      };
    }
  }
}
