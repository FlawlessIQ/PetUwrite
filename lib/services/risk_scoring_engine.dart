import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pet.dart';
import '../models/owner.dart';
import '../models/risk_score.dart';
import '../models/explainability_data.dart';
import '../models/anomaly_flag.dart';
import '../models/underwriting_exclusion.dart';
import '../ai/ai_service.dart';
import 'vet_history_parser.dart';
import 'underwriting_rules_engine.dart';
import 'underwriting_constraint_engine.dart';
import 'underwriting_risk_synthesis.dart';

/// Result of risk scoring including eligibility determination
class RiskScoringResult {
  final RiskScore riskScore;
  final EligibilityResult eligibilityResult;

  const RiskScoringResult({
    required this.riskScore,
    required this.eligibilityResult,
  });

  /// Convenience getter to check if pet is eligible
  bool get isEligible => eligibilityResult.eligible;

  /// Convenience getter for rejection reason (if ineligible)
  String? get rejectionReason =>
      eligibilityResult.eligible ? null : eligibilityResult.reason;

  /// Convenience getter to check if there are exclusions (conditional approval)
  bool get hasExclusions =>
      (riskScore.exclusions != null && riskScore.exclusions!.isNotEmpty) ||
      eligibilityResult.hasExclusions;

  /// Convenience getter for excluded conditions list
  List<String> get excludedConditions => eligibilityResult.excludedConditions;

  /// Structured underwriting exclusions (rare, targeted, deterministic).
  List<UnderwritingExclusion> get exclusions =>
      riskScore.exclusions ?? const <UnderwritingExclusion>[];
}

/// Engine for calculating risk scores for pet insurance underwriting
/// Combines traditional actuarial scoring with AI-powered analysis
class RiskScoringEngine {
  final AIService _aiService;
  final FirebaseFirestore _firestore;
  final UnderwritingRulesEngine _rulesEngine;
  final Future<UnderwritingConstraintEngine> _constraintEngine;

  RiskScoringEngine({
    required AIService aiService,
    FirebaseFirestore? firestore,
    UnderwritingRulesEngine? rulesEngine,
    UnderwritingConstraintEngine? constraintEngine,
  }) : _aiService = aiService,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _rulesEngine =
           rulesEngine ??
           UnderwritingRulesEngine(
             firestore: firestore ?? FirebaseFirestore.instance,
           ),
       _constraintEngine = constraintEngine == null
           ? UnderwritingConstraintEngine.loadDefault()
           : Future.value(constraintEngine);

  /// Calculate comprehensive risk score for a pet
  /// Combines traditional actuarial methods with AI-powered analysis
  /// Automatically stores result in Firestore if quoteId is provided
  Future<RiskScore> calculateRiskScore({
    required Pet pet,
    required Owner owner,
    VetRecordData? vetHistory,
    Map<String, dynamic>? additionalData,
    String? quoteId,
  }) async {
    final riskFactors = <RiskFactor>[];
    final categoryScores = <String, double>{};

    // Calculate age-based risk
    final ageScore = _calculateAgeRisk(pet, riskFactors);
    categoryScores['age'] = ageScore;

    // Calculate breed-based risk
    final breedScore = _calculateBreedRisk(pet, riskFactors);
    categoryScores['breed'] = breedScore;

    // Calculate pre-existing condition risk
    final preExistingScore = _calculatePreExistingConditionRisk(
      pet,
      riskFactors,
    );
    categoryScores['preExisting'] = preExistingScore;

    // Calculate medical history risk if vet records available
    if (vetHistory != null) {
      final medicalHistoryScore = _calculateMedicalHistoryRisk(
        vetHistory,
        riskFactors,
      );
      categoryScores['medicalHistory'] = medicalHistoryScore;
    }

    // Calculate lifestyle risk
    final lifestyleScore = _calculateLifestyleRisk(
      pet,
      additionalData,
      riskFactors,
    );
    categoryScores['lifestyle'] = lifestyleScore;

    // Calculate overall score (weighted average)
    final physiologicalScore = _calculateOverallScore(categoryScores);

    // Deterministic constraints & anomaly detection (NOT validation rejection)
    // This is non-negotiable: implausible inputs must materially affect pricing.
    final constraintAssessment = (await _constraintEngine).assess(pet: pet);

    // Deterministic logging for audit/debug (avoid PII; keep to pet inputs).
    final audit = constraintAssessment.audit;
    if (audit != null) {
      // ignore: avoid_print
      print(
        '[ConstraintAudit] breed=${audit['breed']} species=${audit['species']} weightLbs=${(audit['weightLbs'] as num?)?.toStringAsFixed(1)} confidence=${constraintAssessment.confidenceScore.toStringAsFixed(3)} riskMultiplier=${constraintAssessment.riskMultiplier.toStringAsFixed(3)} findings=${constraintAssessment.anomalyFindings.length}',
      );
      final bc = audit['breedConstraint'];
      if (bc is Map) {
        final critical = bc['criticalThresholdLbs'];
        // ignore: avoid_print
        print(
          '[ConstraintAudit] typical=${bc['typicalWeightLbsMin']}–${bc['typicalWeightLbsMax']} maxHealthy=${bc['maxHealthyWeightLbs']} anomalyThreshold=${bc['anomalyThresholdLbs']}${critical == null ? '' : ' criticalThreshold=$critical'}',
        );
      }
      for (final f in constraintAssessment.anomalyFindings) {
        // ignore: avoid_print
        print(
          '[ConstraintAuditFinding] type=${f.type.name} severity=${f.severity.name} impact=${f.confidenceImpact.toStringAsFixed(3)}',
        );
      }
    }

    // Add credibility track (0-100) as an explicit parallel risk dimension.
    categoryScores['credibility'] = constraintAssessment.credibilityRiskScore;

    // Convert anomaly findings into risk factors for explainability.
    for (final anomaly in constraintAssessment.anomalyFindings) {
      riskFactors.add(
        RiskFactor(
          category: 'credibility',
          description: _anomalyToRiskFactorDescription(anomaly),
          impact: _anomalyImpactToRiskFactorPoints(anomaly),
          severity: _anomalySeverityToRiskFactorSeverity(anomaly.severity),
        ),
      );
    }

    // Synthesize final score from physiological + credibility, with a
    // non-linear multiplier for biological implausibility.
    final overallScore = UnderwritingRiskSynthesis.synthesizeFinalScore(
      physiologicalRiskScore: physiologicalScore,
      credibilityRiskScore: constraintAssessment.credibilityRiskScore,
      riskMultiplier: constraintAssessment.riskMultiplier,
      anomalyFindings: constraintAssessment.anomalyFindings,
    );

    // Get AI-powered analysis and enhanced risk assessment.
    // Fail-soft: AI enriches explainability, but deterministic scoring must
    // always return a result (carrier-grade / audit-safe).
    String? aiAnalysis;
    try {
      aiAnalysis = await _getAIRiskAnalysis(
        pet: pet,
        owner: owner,
        vetHistory: vetHistory,
        traditionalScore: overallScore,
        categoryScores: categoryScores,
        riskFactors: riskFactors,
      );
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ RiskScoringEngine AI analysis failed (continuing): $e');
      aiAnalysis = null;
      riskFactors.add(
        RiskFactor(
          category: 'system',
          description:
              'AI analysis unavailable; quote generated from deterministic underwriting rules.',
          impact: 0,
          severity: Severity.low,
        ),
      );
    }

    // Some AI paths fail-soft internally and return empty output; treat that as unavailable.
    if ((aiAnalysis ?? '').trim().isEmpty) {
      aiAnalysis = null;
    }

    if (aiAnalysis == null) {
      // Ensure we surface the AI outage in explainability.
      final alreadyLogged = riskFactors.any(
        (f) =>
            f.category == 'system' &&
            f.description.toLowerCase().contains('ai analysis unavailable'),
      );
      if (!alreadyLogged) {
        riskFactors.add(
          RiskFactor(
            category: 'system',
            description:
                'AI analysis unavailable; quote generated from deterministic underwriting rules.',
            impact: 0,
            severity: Severity.low,
          ),
        );
      }
    }

    // Determine risk level
    final riskLevel = RiskScore.getRiskLevelFromScore(overallScore);

    final quoteVelocity = additionalData?['quoteVelocity'];
    final bool suspiciousQuoteVelocity =
        quoteVelocity is Map && quoteVelocity['suspicious'] == true;
    if (suspiciousQuoteVelocity) {
      final attempts10m = quoteVelocity['attempts10m'];
      final attempts1h = quoteVelocity['attempts1h'];
      riskFactors.add(
        RiskFactor(
          category: 'behavioral',
          description:
              'Rapid repeat quote attempts detected (10m=$attempts10m, 1h=$attempts1h).',
          impact: 0,
          severity: Severity.medium,
        ),
      );
    }

    final mergedReviewTriggers = <String>{
      ...constraintAssessment.reviewTriggers,
      if (aiAnalysis == null) 'AI_ANALYSIS_UNAVAILABLE',
      if (suspiciousQuoteVelocity) 'QUOTE_VELOCITY_SUSPECTED',
    }.toList(growable: false);

    var riskScore = RiskScore(
      id: _generateId(),
      petId: pet.id,
      calculatedAt: DateTime.now(),
      overallScore: overallScore,
      riskLevel: riskLevel,
      categoryScores: categoryScores,
      riskFactors: riskFactors,
      aiAnalysis: aiAnalysis,
      confidenceScore: constraintAssessment.confidenceScore,
      physiologicalRiskScore: physiologicalScore,
      credibilityRiskScore: constraintAssessment.credibilityRiskScore,
      constraintRiskMultiplier: constraintAssessment.riskMultiplier,
      anomalyFindings: constraintAssessment.anomalyFindings
          .map((f) => f.toJson())
          .toList(growable: false),
      reviewTriggers: mergedReviewTriggers,
      constraintAudit: constraintAssessment.audit,
    );

    // ✅ CHECK ELIGIBILITY AGAINST UNDERWRITING RULES (deterministic only)
    // Medical conditions must be evaluated from strict medical facts, not strings.
    final eligibilityResult = await _rulesEngine.checkEligibilityDeterministic(
      pet: pet,
      riskScore: riskScore,
    );

    // Apply exclusions AFTER anomaly detection + eligibility, but BEFORE
    // pricing/explanation surfaces finalize.
    final exclusions = _buildUnderwritingExclusions(
      pet: pet,
      constraintAssessment: constraintAssessment,
      eligibilityResult: eligibilityResult,
    );

    final requiredEvidenceCodes = _buildRequiredEvidenceCodes(
      constraintAssessment: constraintAssessment,
    );

    final bool hasExtraUnderwritingSignals =
        exclusions.isNotEmpty || requiredEvidenceCodes.isNotEmpty;
    if (hasExtraUnderwritingSignals) {
      riskScore = RiskScore(
        id: riskScore.id,
        petId: riskScore.petId,
        calculatedAt: riskScore.calculatedAt,
        overallScore: riskScore.overallScore,
        riskLevel: riskScore.riskLevel,
        categoryScores: riskScore.categoryScores,
        riskFactors: riskScore.riskFactors,
        aiAnalysis: riskScore.aiAnalysis,
        confidenceScore: riskScore.confidenceScore,
        physiologicalRiskScore: riskScore.physiologicalRiskScore,
        credibilityRiskScore: riskScore.credibilityRiskScore,
        constraintRiskMultiplier: riskScore.constraintRiskMultiplier,
        anomalyFindings: riskScore.anomalyFindings,
        reviewTriggers: riskScore.reviewTriggers,
        constraintAudit: riskScore.constraintAudit,
        exclusions: exclusions,
        requiredEvidenceCodes: requiredEvidenceCodes.isEmpty
            ? null
            : requiredEvidenceCodes,
      );

      // ignore: avoid_print
      print(
        '[ExclusionAudit] applied=${exclusions.length} types=${exclusions.map((e) => e.type.name).toSet().join(',')} triggers=${exclusions.map((e) => e.triggerReason).toSet().join(',')}',
      );

      if (requiredEvidenceCodes.isNotEmpty) {
        // ignore: avoid_print
        print(
          '[EvidenceAudit] codes=${requiredEvidenceCodes.toSet().join(',')}',
        );
      }
    }

    // Generate explainability data (kept deterministic, independent of AI).
    final explainability = _generateExplainabilityData(
      quoteId: quoteId ?? 'unknown',
      pet: pet,
      owner: owner,
      vetHistory: vetHistory,
      categoryScores: categoryScores,
      riskFactors: riskFactors,
      finalScore: overallScore,
      additionalData: additionalData,
    );

    print(
      '🧾 RiskScoringEngine eligibility: eligible=${eligibilityResult.eligible} hasExclusions=${eligibilityResult.hasExclusions} excluded=${eligibilityResult.excludedConditions.isEmpty ? '(none)' : eligibilityResult.excludedConditions.join(', ')} rule=${eligibilityResult.ruleViolated ?? '(none)'}',
    );

    // Store in Firestore if quoteId provided
    if (quoteId != null) {
      await storeRiskScore(quoteId: quoteId, riskScore: riskScore);
      await storeExplainability(
        quoteId: quoteId,
        explainability: explainability,
      );

      // ✅ STORE ELIGIBILITY RESULT
      await _storeEligibilityStatus(
        quoteId: quoteId,
        eligibilityResult: eligibilityResult,
      );

      // ✅ LOG ELIGIBILITY CHECK FOR AUDIT TRAIL
      await _rulesEngine.storeEligibilityResult(quoteId, eligibilityResult);
    }

    return riskScore;
  }

  static const double _anomalyExclusionConfidenceThreshold = 0.80;

  List<UnderwritingExclusion> _buildUnderwritingExclusions({
    required Pet pet,
    required UnderwritingConstraintAssessment constraintAssessment,
    required EligibilityResult eligibilityResult,
  }) {
    final out = <UnderwritingExclusion>[];

    // Intake-derived congenital exclusions (explicit customer-entered facts).
    // We keep these structured + auditable and do not depend on anomaly gating.
    final congenitalConditions =
        pet.medicalConditions
            ?.where((c) => c.isCongenital)
            .map((c) => c.name.trim())
            .where((n) => n.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    for (final conditionName in congenitalConditions) {
      out.add(
        UnderwritingExclusion(
          type: UnderwritingExclusionType.congenital,
          scope: conditionName,
          triggerReason: 'INTAKE:CONGENITAL',
          effectiveAt: UnderwritingExclusionEffectiveAt.bind,
          reviewable: true,
          explanation:
              '$conditionName is excluded from coverage as a congenital condition.',
        ),
      );
    }

    // Breed-linked respiratory exclusions for brachycephalic/high-risk breeds.
    // Deterministic, catalog-free: uses existing breed risk notes.
    if (pet.species.trim().toLowerCase() == 'dog') {
      final breedRisk = _getBreedRiskData(pet.breed);
      final notes = (breedRisk['notes'] ?? '').toString().toLowerCase();
      final bool respiratoryTrait =
          notes.contains('brachy') ||
          notes.contains('respiratory') ||
          notes.contains('breathing');
      if (breedRisk['isHighRisk'] == true && respiratoryTrait) {
        out.add(
          const UnderwritingExclusion(
            type: UnderwritingExclusionType.breedLinked,
            scope: 'respiratory',
            triggerReason: 'BREED_TRAIT:RESPIRATORY',
            effectiveAt: UnderwritingExclusionEffectiveAt.bind,
            reviewable: false,
            explanation:
                'Respiratory conditions may be excluded based on breed-linked airway risk.',
          ),
        );
      }
    }

    // Rules-driven exclusions (pre-existing conditions) remain first-class.
    if (eligibilityResult.excludedConditions.isNotEmpty) {
      final ruleId = (eligibilityResult.ruleViolated ?? 'EXCLUDABLE_CONDITION')
          .toString()
          .trim();

      for (final condition in eligibilityResult.excludedConditions) {
        final name = condition.trim();
        if (name.isEmpty) continue;

        out.add(
          UnderwritingExclusion(
            type: UnderwritingExclusionType.preExisting,
            scope: name,
            triggerReason: 'RULE:$ruleId',
            effectiveAt: UnderwritingExclusionEffectiveAt.bind,
            reviewable: true,
            explanation:
                '$name is excluded from coverage due to a pre-existing condition.',
          ),
        );
      }
    }

    // Anomaly-derived exclusions (rare, targeted). Never blanket.
    final confidence = constraintAssessment.confidenceScore;
    if (confidence < _anomalyExclusionConfidenceThreshold) {
      for (final anomaly in constraintAssessment.anomalyFindings) {
        final sev = anomaly.severity;
        if (sev != AnomalySeverity.high && sev != AnomalySeverity.critical) {
          continue;
        }

        final exclusion = _tryMapAnomalyToTargetedExclusion(
          pet: pet,
          anomaly: anomaly,
        );
        if (exclusion == null) continue;

        // De-dupe by (type, scope, triggerReason) to keep exclusions rare.
        final key =
            '${exclusion.type.name}|${exclusion.scope}|${exclusion.triggerReason}';
        final seen = out
            .map((e) => '${e.type.name}|${e.scope}|${e.triggerReason}')
            .toSet();
        if (seen.contains(key)) continue;

        out.add(exclusion);
      }
    }

    return out;
  }

  UnderwritingExclusion? _tryMapAnomalyToTargetedExclusion({
    required Pet pet,
    required AnomalyFlag anomaly,
  }) {
    switch (anomaly.type) {
      case AnomalyFlagType.weightOutlier:
        return UnderwritingExclusion(
          type: UnderwritingExclusionType.anomalyDerived,
          scope: 'orthopedic',
          triggerReason: 'ANOMALY:${anomaly.type.name.toUpperCase()}',
          effectiveAt: UnderwritingExclusionEffectiveAt.bind,
          reviewable: true,
          explanation:
              'Orthopedic conditions are excluded based on an unusual size/weight profile until reviewed.',
        );
      case AnomalyFlagType.ageMismatch:
        return UnderwritingExclusion(
          type: UnderwritingExclusionType.anomalyDerived,
          scope: 'age-related',
          triggerReason: 'ANOMALY:${anomaly.type.name.toUpperCase()}',
          effectiveAt: UnderwritingExclusionEffectiveAt.postBind,
          reviewable: true,
          explanation:
              'Age-related conditions are excluded based on an unusual age profile until reviewed.',
        );
      case AnomalyFlagType.breedConflict:
        return UnderwritingExclusion(
          type: UnderwritingExclusionType.breedLinked,
          scope: 'hereditary',
          triggerReason: 'ANOMALY:${anomaly.type.name.toUpperCase()}',
          effectiveAt: UnderwritingExclusionEffectiveAt.postBind,
          reviewable: true,
          explanation:
              'Hereditary conditions are excluded until breed/species details are verified.',
        );
      case AnomalyFlagType.ownerReportingRisk:
        // Keep anomaly-derived exclusions narrow: only apply when we can map to
        // a specific, customer-explainable coverage area.
        return null;
    }
  }

  List<String> _buildRequiredEvidenceCodes({
    required UnderwritingConstraintAssessment constraintAssessment,
  }) {
    final out = <String>[];
    final confidence = constraintAssessment.confidenceScore;
    if (confidence >= _anomalyExclusionConfidenceThreshold) {
      return out;
    }

    for (final anomaly in constraintAssessment.anomalyFindings) {
      final sev = anomaly.severity;
      if (sev != AnomalySeverity.high && sev != AnomalySeverity.critical) {
        continue;
      }

      switch (anomaly.type) {
        case AnomalyFlagType.weightOutlier:
          out.add('VERIFY_WEIGHT');
          break;
        case AnomalyFlagType.ageMismatch:
          out.add('VERIFY_AGE');
          break;
        case AnomalyFlagType.breedConflict:
          out.add('VERIFY_BREED_SPECIES');
          break;
        case AnomalyFlagType.ownerReportingRisk:
          out.add('VERIFY_INTAKE');
          break;
      }
    }

    // De-dupe while preserving order.
    final seen = <String>{};
    final deduped = <String>[];
    for (final code in out) {
      if (seen.add(code)) deduped.add(code);
    }
    return deduped;
  }

  /// Calculate risk score WITH eligibility check
  /// Returns both RiskScore and EligibilityResult for easy handling in UI
  ///
  /// Use this method when you need to check eligibility and show UI feedback
  ///
  /// Example:
  /// ```dart
  /// final result = await riskEngine.calculateRiskScoreWithEligibility(...);
  /// if (!result.isEligible) {
  ///   showDialog(..., content: Text(result.rejectionReason));
  ///   return;
  /// }
  /// // Continue to plan selection with result.riskScore
  /// ```
  Future<RiskScoringResult> calculateRiskScoreWithEligibility({
    required Pet pet,
    required Owner owner,
    VetRecordData? vetHistory,
    Map<String, dynamic>? additionalData,
    String? quoteId,
  }) async {
    // Calculate risk score (eligibility is checked internally)
    final riskScore = await calculateRiskScore(
      pet: pet,
      owner: owner,
      vetHistory: vetHistory,
      additionalData: additionalData,
      quoteId: quoteId,
    );

    // Re-check eligibility to return in result
    final eligibilityResult = await _rulesEngine.checkEligibilityDeterministic(
      pet: pet,
      riskScore: riskScore,
    );

    print(
      '🧾 RiskScoringEngine eligibility (returning): eligible=${eligibilityResult.eligible} hasExclusions=${eligibilityResult.hasExclusions}',
    );

    return RiskScoringResult(
      riskScore: riskScore,
      eligibilityResult: eligibilityResult,
    );
  }

  /// Call external AI API to get enhanced risk analysis
  /// Returns AI-generated insights, risk factors, and recommendations
  Future<String> _getAIRiskAnalysis({
    required Pet pet,
    required Owner owner,
    VetRecordData? vetHistory,
    required double traditionalScore,
    required Map<String, double> categoryScores,
    required List<RiskFactor> riskFactors,
  }) async {
    try {
      final prompt = _buildAIPrompt(
        pet: pet,
        owner: owner,
        vetHistory: vetHistory,
        traditionalScore: traditionalScore,
        categoryScores: categoryScores,
        riskFactors: riskFactors,
      );

      // Get AI response
      final aiResponse = await _aiService.generateText(
        prompt,
        options: {
          'temperature': 0.3, // Lower temperature for more consistent analysis
          'max_tokens': 800,
        },
      );

      print('✅ AI Risk Analysis completed');

      // Parse and structure the AI response
      final structuredAnalysis = _parseAIResponse(aiResponse, traditionalScore);

      return structuredAnalysis;
    } catch (e) {
      print('⚠️ AI Risk Analysis failed: $e');
      // Fail closed: do not fabricate fallback narrative.
      // Underwriting must fail closed when AI extraction/analysis is required.
      return '';
    }
  }

  /// Parse AI response and extract structured data
  String _parseAIResponse(String aiResponse, double traditionalScore) {
    try {
      // Try to extract JSON if present
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(aiResponse);
      if (jsonMatch != null) {
        final jsonStr = jsonMatch.group(0)!;
        final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
        return _buildStructuredAnalysis(parsed, traditionalScore);
      }

      // If no JSON found, return raw response with header
      return '''
AI-Enhanced Risk Analysis:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$aiResponse

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Traditional Risk Score: ${traditionalScore.toStringAsFixed(1)}/100
''';
    } catch (e) {
      print('⚠️ Failed to parse AI response: $e');
      // Return raw response if parsing fails
      return aiResponse;
    }
  }

  /// Build structured analysis from parsed AI data.
  ///
  /// Underwriting eligibility, pricing, and plan availability must be decided
  /// deterministically elsewhere.
  String _buildStructuredAnalysis(
    Map<String, dynamic> data,
    double traditionalScore,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('AI-Enhanced Risk Analysis');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    final riskLevel = RiskScore.getRiskLevelFromScore(traditionalScore);
    buffer.writeln('📊 RISK ASSESSMENT');
    buffer.writeln('   Risk Score: ${traditionalScore.toStringAsFixed(1)}/100');
    buffer.writeln('   Risk Level: ${riskLevel.name.toUpperCase()}');
    if (data['confidence_level'] != null) {
      buffer.writeln('   Confidence: ${data['confidence_level']}%');
    }
    buffer.writeln();

    if (data['top_risk_categories'] is List) {
      buffer.writeln('🔴 TOP RISK CATEGORIES');
      final categories = data['top_risk_categories'] as List;
      for (var i = 0; i < categories.length && i < 5; i++) {
        buffer.writeln('   ${i + 1}. ${categories[i]}');
      }
      buffer.writeln();
    }

    if (data['red_flags'] is List) {
      final redFlags = data['red_flags'] as List;
      if (redFlags.isNotEmpty) {
        buffer.writeln('🚩 RED FLAGS');
        for (final flag in redFlags) {
          buffer.writeln('   ⚠️ $flag');
        }
        buffer.writeln();
      }
    }

    if (data['breed_specific_risks'] != null) {
      buffer.writeln('🐾 BREED-SPECIFIC RISKS');
      buffer.writeln('   ${data['breed_specific_risks']}');
      buffer.writeln();
    }

    if (data['geographic_factors'] != null) {
      buffer.writeln('📍 GEOGRAPHIC FACTORS');
      buffer.writeln('   ${data['geographic_factors']}');
      buffer.writeln();
    }

    if (data['claim_probability_12mo'] != null) {
      buffer.writeln('📈 CLAIM PROBABILITY (12 Months)');
      buffer.writeln('   ${data['claim_probability_12mo']}% likelihood');
      buffer.writeln();
    }

    if (data['preventive_care_recommendations'] is List) {
      buffer.writeln('✨ PREVENTIVE CARE RECOMMENDATIONS');
      final recommendations = data['preventive_care_recommendations'] as List;
      for (var i = 0; i < recommendations.length && i < 5; i++) {
        buffer.writeln('   ${i + 1}. ${recommendations[i]}');
      }
      buffer.writeln();
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    return buffer.toString();
  }

  /// Build the AI prompt for risk analysis.
  ///
  /// IMPORTANT: AI must never determine eligibility, pricing, or plan availability.
  String _buildAIPrompt({
    required Pet pet,
    required Owner owner,
    VetRecordData? vetHistory,
    required double traditionalScore,
    required Map<String, double> categoryScores,
    required List<RiskFactor> riskFactors,
  }) {
    final vetHistoryText = vetHistory != null
        ? '''
Medical History:
- Vaccinations: ${vetHistory.vaccinations.length} records
- Treatments: ${vetHistory.treatments.length} records
- Surgeries: ${vetHistory.surgeries.length} surgeries
- Medications: ${vetHistory.medications.length} medications
- Allergies: ${vetHistory.allergies.join(', ')}
- Last Checkup: ${vetHistory.lastCheckup ?? 'Unknown'}
'''
        : 'No medical history available';

    // Calculate age in months for rules check
    final ageInMonths = (pet.ageInYears * 12).round();

    return '''
Given this pet's profile and veterinary history, provide a comprehensive insurance risk assessment.

PET PROFILE:
- Name: ${pet.name}
- Species: ${pet.species}
- Breed: ${pet.breed}
- Age: ${pet.ageInYears} years ($ageInMonths months)
- Gender: ${pet.gender}
- Weight: ${pet.weight} kg
- Neutered: ${pet.isNeutered ? 'Yes' : 'No'}
- Pre-existing Conditions: ${pet.preExistingConditions.isEmpty ? 'None' : pet.preExistingConditions.join(', ')}

OWNER LOCATION:
- Zip Code: ${owner.address.zipCode}
- State: ${owner.address.state}
- City: ${owner.address.city}

$vetHistoryText

TRADITIONAL RISK ASSESSMENT:
- Overall Risk Score: ${traditionalScore.toStringAsFixed(1)}/100
- Category Breakdown:
${categoryScores.entries.map((e) => '  - ${e.key}: ${e.value.toStringAsFixed(1)}/100').join('\n')}
- Identified Risk Factors:
${riskFactors.map((f) => '  - ${f.description} (Impact: ${f.impact.toStringAsFixed(1)}, Severity: ${f.severity})').join('\n')}

ANALYSIS REQUEST:
Provide a structured JSON-compatible response with:

1. **top_risk_categories**: List of 3-5 specific concerns
2. **red_flags**: Any critical concerns to highlight
3. **breed_specific_risks**: Health issues common to ${pet.breed}
4. **geographic_factors**: Climate, diseases, vet costs for ${owner.address.state}
5. **preventive_care_recommendations**: 3-5 actionable recommendations
6. **claim_probability_12mo**: Percentage likelihood (0-100%)
7. **confidence_level**: Your confidence in this summary (0-100%)

IMPORTANT:
- Do NOT provide eligibility decisions.
- Do NOT recommend pricing, deductibles, limits, or plans.
- Only summarize and organize risk factors.
''';
  }

  /// Store risk score in Firestore under quotes/{quoteId}/risk_score
  Future<void> storeRiskScore({
    required String quoteId,
    required RiskScore riskScore,
  }) async {
    try {
      await _firestore
          .collection('quotes')
          .doc(quoteId)
          .collection('risk_score')
          .doc(riskScore.id)
          .set(riskScore.toJson());

      // Also update the main quote document with a reference
      await _firestore.collection('quotes').doc(quoteId).update({
        'riskScoreId': riskScore.id,
        'riskScore': riskScore.overallScore,
        'riskLevel': riskScore.riskLevel.toString(),
        if (riskScore.confidenceScore != null)
          'confidenceScore': riskScore.confidenceScore,
        if (riskScore.credibilityRiskScore != null)
          'credibilityRiskScore': riskScore.credibilityRiskScore,
        if (riskScore.constraintRiskMultiplier != null)
          'constraintRiskMultiplier': riskScore.constraintRiskMultiplier,
        if (riskScore.anomalyFindings != null)
          'anomalyFindings': riskScore.anomalyFindings,
        if (riskScore.reviewTriggers != null)
          'reviewTriggers': riskScore.reviewTriggers,
        if (riskScore.constraintAudit != null)
          'constraintAudit': riskScore.constraintAudit,
        if (riskScore.exclusions != null)
          'exclusions': riskScore.exclusions!.map((e) => e.toJson()).toList(),
        if (riskScore.requiredEvidenceCodes != null)
          'requiredEvidenceCodes': riskScore.requiredEvidenceCodes,
        'lastRiskAssessment': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw RiskScoringException('Failed to store risk score in Firestore: $e');
    }
  }

  /// Store explainability data in Firestore under quotes/{quoteId}/explainability
  Future<void> storeExplainability({
    required String quoteId,
    required ExplainabilityData explainability,
  }) async {
    try {
      await _firestore
          .collection('quotes')
          .doc(quoteId)
          .collection('explainability')
          .doc(explainability.id)
          .set(explainability.toJson());
    } catch (e) {
      throw RiskScoringException(
        'Failed to store explainability data in Firestore: $e',
      );
    }
  }

  /// Store eligibility status in Firestore
  /// Updates the quote document with eligibility determination
  Future<void> _storeEligibilityStatus({
    required String quoteId,
    required EligibilityResult eligibilityResult,
  }) async {
    try {
      await _firestore.collection('quotes').doc(quoteId).update({
        'eligibility': {
          'status': eligibilityResult.eligible ? 'eligible' : 'declined',
          'reason': eligibilityResult.reason,
          'ruleViolated': eligibilityResult.ruleViolated,
          'violatedValue': eligibilityResult.violatedValue,
          'timestamp': FieldValue.serverTimestamp(),
        },
      });

      print(
        eligibilityResult.eligible
            ? '✅ Pet is eligible for coverage'
            : '❌ Pet declined: ${eligibilityResult.reason}',
      );
    } catch (e) {
      print('⚠️ Warning: Failed to store eligibility status: $e');
      // Don't throw - eligibility check succeeded, storage is just logging
    }
  }

  /// Generate explainability data with feature contributions
  ExplainabilityData _generateExplainabilityData({
    required String quoteId,
    required Pet pet,
    required Owner owner,
    VetRecordData? vetHistory,
    required Map<String, double> categoryScores,
    required List<RiskFactor> riskFactors,
    required double finalScore,
    Map<String, dynamic>? additionalData,
  }) {
    final contributions = <FeatureContribution>[];
    const double baselineScore = 50.0; // Neutral starting point

    // Age contributions
    final age = pet.ageInYears;
    if (age < 1) {
      contributions.add(
        FeatureContribution(
          feature: 'Puppy/Kitten (< 1 year)',
          impact: 5.0,
          notes: 'Young pets have higher accident risk',
          category: 'age',
        ),
      );
    } else if (age >= 1 && age <= 3) {
      contributions.add(
        FeatureContribution(
          feature: 'Young Adult (1-3 years)',
          impact: -5.0,
          notes: 'Lowest risk age group',
          category: 'age',
        ),
      );
    } else if (age >= 4 && age <= 7) {
      contributions.add(
        FeatureContribution(
          feature: 'Adult (4-7 years)',
          impact: 0.0,
          notes: 'Average risk age group',
          category: 'age',
        ),
      );
    } else if (age >= 8 && age <= 10) {
      contributions.add(
        FeatureContribution(
          feature: 'Senior (8-10 years)',
          impact: 10.0,
          notes: 'Increased risk for age-related conditions',
          category: 'age',
        ),
      );
    } else {
      contributions.add(
        FeatureContribution(
          feature: 'Geriatric (10+ years)',
          impact: 20.0,
          notes: 'High risk for chronic conditions and cancer',
          category: 'age',
        ),
      );
    }

    // Breed contributions
    final breedRiskData = _getBreedRiskData(pet.breed);
    if (breedRiskData['isHighRisk'] == true) {
      contributions.add(
        FeatureContribution(
          feature: '${pet.breed} (High-Risk Breed)',
          impact: 12.0,
          notes: breedRiskData['notes'] as String,
          category: 'breed',
        ),
      );
    } else if (breedRiskData['isLowRisk'] == true) {
      contributions.add(
        FeatureContribution(
          feature: '${pet.breed} (Low-Risk Breed)',
          impact: -8.0,
          notes: breedRiskData['notes'] as String,
          category: 'breed',
        ),
      );
    } else {
      contributions.add(
        FeatureContribution(
          feature: '${pet.breed} (Average Risk)',
          impact: 0.0,
          notes: 'No significant breed-specific risk factors',
          category: 'breed',
        ),
      );
    }

    // Pre-existing conditions
    if (pet.preExistingConditions.isNotEmpty) {
      final conditionCount = pet.preExistingConditions.length;
      final impact = conditionCount * 8.0;
      contributions.add(
        FeatureContribution(
          feature: 'Pre-existing Conditions ($conditionCount)',
          impact: impact,
          notes: pet.preExistingConditions.join(', '),
          category: 'medical',
        ),
      );
    } else {
      contributions.add(
        FeatureContribution(
          feature: 'No Pre-existing Conditions',
          impact: -5.0,
          notes: 'Clean health history',
          category: 'medical',
        ),
      );
    }

    // Neutered status
    if (pet.isNeutered) {
      contributions.add(
        FeatureContribution(
          feature: 'Spayed/Neutered',
          impact: -3.0,
          notes: 'Reduced risk of certain cancers and behavioral issues',
          category: 'lifestyle',
        ),
      );
    } else {
      contributions.add(
        FeatureContribution(
          feature: 'Not Neutered',
          impact: 4.0,
          notes: 'Higher risk of reproductive cancers',
          category: 'lifestyle',
        ),
      );
    }

    // Weight (if available)
    if (pet.weight > 0) {
      final idealWeight = _getIdealWeightRange(pet.breed, pet.species);
      if (pet.weight > idealWeight['max']! * 1.2) {
        contributions.add(
          FeatureContribution(
            feature: 'Overweight (${pet.weight} kg)',
            impact: 6.0,
            notes: 'Obesity increases risk of diabetes and joint issues',
            category: 'lifestyle',
          ),
        );
      } else if (pet.weight < idealWeight['min']! * 0.8) {
        contributions.add(
          FeatureContribution(
            feature: 'Underweight (${pet.weight} kg)',
            impact: 5.0,
            notes: 'May indicate underlying health issues',
            category: 'lifestyle',
          ),
        );
      }
    }

    // Medical history
    if (vetHistory != null) {
      // Vaccination status
      if (vetHistory.vaccinations.isEmpty) {
        contributions.add(
          FeatureContribution(
            feature: 'No Vaccination Records',
            impact: 8.0,
            notes: 'Increased risk of preventable diseases',
            category: 'medical',
          ),
        );
      } else if (vetHistory.vaccinations.length >= 3) {
        contributions.add(
          FeatureContribution(
            feature: 'Up-to-date Vaccinations',
            impact: -4.0,
            notes: 'Good preventive care',
            category: 'medical',
          ),
        );
      }

      // Surgery history
      if (vetHistory.surgeries.isNotEmpty) {
        contributions.add(
          FeatureContribution(
            feature: 'Previous Surgeries (${vetHistory.surgeries.length})',
            impact: vetHistory.surgeries.length * 3.0,
            notes: 'History of surgical interventions',
            category: 'medical',
          ),
        );
      }

      // Chronic medications
      if (vetHistory.medications.length >= 2) {
        contributions.add(
          FeatureContribution(
            feature: 'Multiple Medications (${vetHistory.medications.length})',
            impact: vetHistory.medications.length * 4.0,
            notes: 'Ongoing chronic conditions requiring management',
            category: 'medical',
          ),
        );
      }

      // Allergies
      if (vetHistory.allergies.isNotEmpty) {
        contributions.add(
          FeatureContribution(
            feature: 'Known Allergies (${vetHistory.allergies.length})',
            impact: vetHistory.allergies.length * 2.0,
            notes: vetHistory.allergies.join(', '),
            category: 'medical',
          ),
        );
      }

      // Regular checkups
      if (vetHistory.lastCheckup != null) {
        final daysSinceCheckup = DateTime.now()
            .difference(vetHistory.lastCheckup!)
            .inDays;
        if (daysSinceCheckup <= 365) {
          contributions.add(
            FeatureContribution(
              feature: 'Recent Checkup (<1 year)',
              impact: -3.0,
              notes: 'Regular preventive care',
              category: 'lifestyle',
            ),
          );
        } else if (daysSinceCheckup > 730) {
          contributions.add(
            FeatureContribution(
              feature: 'No Recent Checkup (>2 years)',
              impact: 5.0,
              notes: 'Lack of preventive care',
              category: 'lifestyle',
            ),
          );
        }
      }
    }

    // Geographic risk factors
    final geoRisk = _getGeographicRiskFactor(owner.address.state);
    if (geoRisk != 0) {
      contributions.add(
        FeatureContribution(
          feature: 'Location: ${owner.address.state}',
          impact: geoRisk,
          notes: geoRisk > 0
              ? 'Higher veterinary costs in this region'
              : 'Lower veterinary costs in this region',
          category: 'geographic',
        ),
      );
    }

    // Additional data factors
    if (additionalData != null) {
      if (additionalData['indoor'] == false) {
        contributions.add(
          FeatureContribution(
            feature: 'Outdoor Pet',
            impact: 6.0,
            notes: 'Higher risk of injuries and infections',
            category: 'lifestyle',
          ),
        );
      } else if (additionalData['indoor'] == true) {
        contributions.add(
          FeatureContribution(
            feature: 'Indoor Pet',
            impact: -2.0,
            notes: 'Lower risk of accidents and infectious diseases',
            category: 'lifestyle',
          ),
        );
      }

      if (additionalData['hasInsurance'] == true) {
        contributions.add(
          FeatureContribution(
            feature: 'Previous Insurance',
            impact: -5.0,
            notes: 'Demonstrates commitment to pet healthcare',
            category: 'lifestyle',
          ),
        );
      }
    }

    // Create summary
    final totalPositiveImpact = contributions
        .where((c) => c.impact > 0)
        .fold(0.0, (sum, c) => sum + c.impact);
    final totalNegativeImpact = contributions
        .where((c) => c.impact < 0)
        .fold(0.0, (sum, c) => sum + c.impact);

    final topRiskFactors =
        (contributions.where((c) => c.impact > 0).toList()
              ..sort((a, b) => b.impact.compareTo(a.impact)))
            .take(3)
            .map(
              (c) =>
                  '- ${c.feature}: +${c.impact.toStringAsFixed(1)} (${c.notes})',
            )
            .join('\n');

    final topProtectiveFactors =
        (contributions.where((c) => c.impact < 0).toList()
              ..sort((a, b) => a.impact.compareTo(b.impact)))
            .take(3)
            .map(
              (c) =>
                  '- ${c.feature}: ${c.impact.toStringAsFixed(1)} (${c.notes})',
            )
            .join('\n');

    final summary =
        '''
Risk Score Breakdown:
- Baseline Score: ${baselineScore.toStringAsFixed(1)}
- Total Risk-Increasing Factors: +${totalPositiveImpact.toStringAsFixed(1)}
- Total Risk-Decreasing Factors: ${totalNegativeImpact.toStringAsFixed(1)}
- Final Score: ${finalScore.toStringAsFixed(1)}

Top Risk Factors:
$topRiskFactors

Top Protective Factors:
$topProtectiveFactors
''';

    return ExplainabilityData(
      id: _generateId(),
      quoteId: quoteId,
      createdAt: DateTime.now(),
      baselineScore: baselineScore,
      contributions: contributions,
      finalScore: finalScore,
      overallSummary: summary,
    );
  }

  /// Get geographic risk factor based on state
  double _getGeographicRiskFactor(String state) {
    const highCostStates = ['CA', 'NY', 'MA', 'WA', 'CT'];
    const lowCostStates = ['MS', 'AR', 'OK', 'WV', 'KY'];

    if (highCostStates.contains(state)) {
      return 4.0;
    } else if (lowCostStates.contains(state)) {
      return -2.0;
    }
    return 0.0;
  }

  /// Get breed-specific risk data
  Map<String, dynamic> _getBreedRiskData(String breed) {
    // High-risk breeds
    const highRiskBreeds = {
      'German Shepherd': 'Prone to hip dysplasia and digestive issues',
      'Golden Retriever': 'High cancer risk (60%+ lifetime risk)',
      'Labrador Retriever': 'Obesity and joint problems common',
      'Bulldog': 'Respiratory issues and skin problems',
      'French Bulldog': 'Brachycephalic syndrome and spinal issues',
      'Rottweiler': 'Joint problems and cancer risk',
      'Great Dane': 'Heart disease and bloat risk',
      'Boxer': 'High cancer risk and heart conditions',
      'Doberman': 'Heart disease and von Willebrand disease',
      'Persian Cat': 'Kidney disease and breathing problems',
      'Maine Coon': 'Heart disease (HCM) common',
      'Ragdoll': 'Heart disease risk',
    };

    // Low-risk breeds
    const lowRiskBreeds = {
      'Australian Cattle Dog': 'Generally healthy with good longevity',
      'Border Collie': 'Fewer genetic health issues',
      'Australian Shepherd': 'Generally robust health',
      'Poodle': 'Long lifespan with fewer issues',
      'Mixed Breed': 'Hybrid vigor reduces genetic disease risk',
      'Domestic Shorthair Cat': 'Robust health',
      'Siamese Cat': 'Generally healthy breed',
    };

    final breedLower = breed.toLowerCase();

    for (final entry in highRiskBreeds.entries) {
      if (breedLower.contains(entry.key.toLowerCase())) {
        return {'isHighRisk': true, 'isLowRisk': false, 'notes': entry.value};
      }
    }

    for (final entry in lowRiskBreeds.entries) {
      if (breedLower.contains(entry.key.toLowerCase())) {
        return {'isHighRisk': false, 'isLowRisk': true, 'notes': entry.value};
      }
    }

    return {
      'isHighRisk': false,
      'isLowRisk': false,
      'notes': 'Average breed risk',
    };
  }

  /// Get ideal weight range for breed
  Map<String, double> _getIdealWeightRange(String breed, String species) {
    // Simplified - in production, use comprehensive breed database
    if (species.toLowerCase() == 'dog') {
      if (breed.contains('Great Dane') || breed.contains('Mastiff')) {
        return {'min': 50.0, 'max': 90.0};
      } else if (breed.contains('Labrador') || breed.contains('Golden')) {
        return {'min': 25.0, 'max': 36.0};
      } else if (breed.contains('Chihuahua') || breed.contains('Yorkie')) {
        return {'min': 1.0, 'max': 3.0};
      }
      return {'min': 10.0, 'max': 30.0}; // Average dog
    } else {
      return {'min': 3.0, 'max': 6.0}; // Average cat
    }
  }

  /// Retrieve risk score from Firestore
  Future<RiskScore?> getRiskScore({
    required String quoteId,
    String? riskScoreId,
  }) async {
    try {
      if (riskScoreId != null) {
        // Get specific risk score by ID
        final doc = await _firestore
            .collection('quotes')
            .doc(quoteId)
            .collection('risk_score')
            .doc(riskScoreId)
            .get();

        if (doc.exists) {
          return RiskScore.fromJson(doc.data()!);
        }
      } else {
        // Get the most recent risk score
        final querySnapshot = await _firestore
            .collection('quotes')
            .doc(quoteId)
            .collection('risk_score')
            .orderBy('calculatedAt', descending: true)
            .limit(1)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          return RiskScore.fromJson(querySnapshot.docs.first.data());
        }
      }

      return null;
    } catch (e) {
      throw RiskScoringException(
        'Failed to retrieve risk score from Firestore: $e',
      );
    }
  }

  double _calculateAgeRisk(Pet pet, List<RiskFactor> riskFactors) {
    final age = pet.ageInYears;
    double score = 0;
    Severity severity = Severity.low;

    if (age < 1) {
      score = 25;
      severity = Severity.low;
      riskFactors.add(
        RiskFactor(
          category: 'age',
          description: 'Puppy/kitten - higher accident risk',
          impact: 2.5,
          severity: severity,
        ),
      );
    } else if (age < 3) {
      score = 15;
      severity = Severity.low;
      riskFactors.add(
        RiskFactor(
          category: 'age',
          description: 'Young pet - optimal health period',
          impact: 1.5,
          severity: severity,
        ),
      );
    } else if (age < 7) {
      score = 30;
      severity = Severity.low;
      riskFactors.add(
        RiskFactor(
          category: 'age',
          description: 'Adult pet - good health expected',
          impact: 3.0,
          severity: severity,
        ),
      );
    } else if (age < 10) {
      score = 50;
      severity = Severity.medium;
      riskFactors.add(
        RiskFactor(
          category: 'age',
          description: 'Senior pet - increased health risks',
          impact: 5.0,
          severity: severity,
        ),
      );
    } else {
      score = 75;
      severity = Severity.high;
      riskFactors.add(
        RiskFactor(
          category: 'age',
          description: 'Geriatric pet - high health risk',
          impact: 7.5,
          severity: severity,
        ),
      );
    }

    return score;
  }

  double _calculateBreedRisk(Pet pet, List<RiskFactor> riskFactors) {
    // High-risk breeds database
    final highRiskBreeds = {
      'German Shepherd': 55.0,
      'Bulldog': 70.0,
      'Great Dane': 65.0,
      'Rottweiler': 60.0,
      'Persian Cat': 50.0,
      'Maine Coon': 45.0,
    };

    final breed = pet.breed;
    final score = highRiskBreeds[breed] ?? 30.0;

    if (highRiskBreeds.containsKey(breed)) {
      riskFactors.add(
        RiskFactor(
          category: 'breed',
          description: '$breed has known breed-specific health issues',
          impact: (score - 30) / 10,
          severity: score > 60 ? Severity.high : Severity.medium,
        ),
      );
    }

    return score;
  }

  double _calculatePreExistingConditionRisk(
    Pet pet,
    List<RiskFactor> riskFactors,
  ) {
    if (pet.preExistingConditions.isEmpty) {
      return 0;
    }

    // Critical conditions that should trigger automatic high risk or denial
    const criticalConditions = [
      'cancer',
      'tumor',
      'leukemia',
      'lymphoma',
      'epilepsy',
      'kidney failure',
      'liver disease',
      'heart murmur',
      'diabetes', // uncontrolled
    ];

    // Check for critical conditions
    double score = 0;
    bool hasCriticalCondition = false;

    for (final condition in pet.preExistingConditions) {
      final conditionLower = condition.toLowerCase();

      // Check if this is a critical condition
      final isCritical = criticalConditions.any(
        (critical) => conditionLower.contains(critical),
      );

      if (isCritical) {
        hasCriticalCondition = true;
        // Critical conditions get VERY high scores to trigger denial
        score += 65.0; // Increased from 40 to ensure 90+ with multiplier
        riskFactors.add(
          RiskFactor(
            category: 'preExisting',
            description: 'CRITICAL: Pre-existing $condition',
            impact: 8.0,
            severity: Severity.critical,
          ),
        );
      } else {
        // Non-critical conditions get moderate scores
        score += 15.0;
        riskFactors.add(
          RiskFactor(
            category: 'preExisting',
            description: 'Pre-existing condition: $condition',
            impact: 1.5,
            severity: Severity.high,
          ),
        );
      }
    }

    // If multiple critical conditions, add even more risk
    if (hasCriticalCondition && pet.preExistingConditions.length > 1) {
      score += 20.0;
      riskFactors.add(
        RiskFactor(
          category: 'preExisting',
          description: 'Multiple conditions including critical ones',
          impact: 2.0,
          severity: Severity.critical,
        ),
      );
    }

    return score.clamp(0, 100);
  }

  double _calculateMedicalHistoryRisk(
    VetRecordData vetHistory,
    List<RiskFactor> riskFactors,
  ) {
    double score = 0;

    // Recent treatments increase risk
    final recentTreatments = vetHistory.treatments
        .where((t) => DateTime.now().difference(t.date).inDays < 365)
        .length;

    if (recentTreatments > 3) {
      score += 30;
      riskFactors.add(
        RiskFactor(
          category: 'medicalHistory',
          description:
              'Multiple recent treatments ($recentTreatments in past year)',
          impact: 3.0,
          severity: Severity.medium,
        ),
      );
    }

    // Surgeries increase risk
    if (vetHistory.surgeries.isNotEmpty) {
      score += vetHistory.surgeries.length * 10.0;
      riskFactors.add(
        RiskFactor(
          category: 'medicalHistory',
          description: '${vetHistory.surgeries.length} previous surgeries',
          impact: vetHistory.surgeries.length.toDouble(),
          severity: Severity.medium,
        ),
      );
    }

    // Chronic medications increase risk
    final chronicMeds = vetHistory.medications
        .where((m) => m.endDate == null || m.endDate!.isAfter(DateTime.now()))
        .length;

    if (chronicMeds > 0) {
      score += chronicMeds * 15.0;
      riskFactors.add(
        RiskFactor(
          category: 'medicalHistory',
          description: '$chronicMeds ongoing medications',
          impact: chronicMeds * 1.5,
          severity: Severity.medium,
        ),
      );
    }

    return score.clamp(0, 100);
  }

  double _calculateLifestyleRisk(
    Pet pet,
    Map<String, dynamic>? additionalData,
    List<RiskFactor> riskFactors,
  ) {
    double score = 20; // Base score

    // Weight-based risk
    final idealWeight = _getIdealWeight(pet.species, pet.breed);
    final weightDiff = (pet.weight - idealWeight).abs();

    if (weightDiff > idealWeight * 0.2) {
      score += 15;
      riskFactors.add(
        RiskFactor(
          category: 'lifestyle',
          description: 'Weight significantly different from ideal',
          impact: 1.5,
          severity: Severity.medium,
        ),
      );
    }

    // Neutering status (unneutered can have higher risk)
    if (!pet.isNeutered) {
      score += 10;
      riskFactors.add(
        RiskFactor(
          category: 'lifestyle',
          description: 'Not neutered - increased health risks',
          impact: 1.0,
          severity: Severity.low,
        ),
      );
    }

    return score;
  }

  double _calculateOverallScore(Map<String, double> categoryScores) {
    // Weighted average of category scores
    final weights = {
      'age': 0.25,
      'breed': 0.25,
      'preExisting': 0.25, // Increased weight for pre-existing conditions
      'medicalHistory': 0.15,
      'lifestyle': 0.10,
    };

    double totalScore = 0;
    double totalWeight = 0;

    categoryScores.forEach((category, score) {
      final weight = weights[category] ?? 0.1;
      totalScore += score * weight;
      totalWeight += weight;
    });

    final baseScore = totalWeight > 0 ? totalScore / totalWeight : 50.0;

    // ⚠️ CRITICAL RISK MULTIPLIERS
    // Apply severe penalty for high-risk combinations
    double multiplier = 1.0;
    final ageScore = categoryScores['age'] ?? 0;
    final preExistingScore = categoryScores['preExisting'] ?? 0;

    // Senior pet (age > 60) with serious pre-existing conditions (score > 40)
    if (ageScore >= 60 && preExistingScore >= 40) {
      // This is a critical combination (e.g., cancer + old age)
      multiplier = 1.4; // Boost score by 40%
    } else if (ageScore >= 50 && preExistingScore >= 30) {
      // Moderate high-risk combination
      multiplier = 1.2; // Boost score by 20%
    }

    final finalScore = (baseScore * multiplier).clamp(0.0, 100.0);
    return finalScore;
  }

  double _getIdealWeight(String species, String breed) {
    // Simplified ideal weight database
    if (species.toLowerCase() == 'dog') {
      if (breed.contains('Great Dane')) return 70.0;
      if (breed.contains('German Shepherd')) return 35.0;
      if (breed.contains('Bulldog')) return 25.0;
      return 20.0; // Default dog weight
    } else if (species.toLowerCase() == 'cat') {
      if (breed.contains('Maine Coon')) return 7.0;
      return 4.5; // Default cat weight
    }
    return 15.0; // Generic default
  }

  String _anomalyToRiskFactorDescription(AnomalyFlag anomaly) {
    final prefix = switch (anomaly.type) {
      AnomalyFlagType.weightOutlier => 'Weight anomaly',
      AnomalyFlagType.ageMismatch => 'Age anomaly',
      AnomalyFlagType.breedConflict => 'Breed/species anomaly',
      AnomalyFlagType.ownerReportingRisk => 'Input credibility risk',
    };
    return '$prefix: ${anomaly.explanation}'.trim();
  }

  double _anomalyImpactToRiskFactorPoints(AnomalyFlag anomaly) {
    // RiskFactor.impact is expected to be in roughly [-10, +10].
    // Anomalies only ever increase risk (positive impact), but we keep it
    // bounded to avoid swamping other explainability factors.
    final typeWeight = switch (anomaly.type) {
      AnomalyFlagType.weightOutlier => 1.20,
      AnomalyFlagType.breedConflict => 1.10,
      AnomalyFlagType.ageMismatch => 1.00,
      AnomalyFlagType.ownerReportingRisk => 0.90,
    };

    final base = anomaly.severity.score * 8.0;
    final points = (base * typeWeight).clamp(0.5, 10.0);
    return points;
  }

  Severity _anomalySeverityToRiskFactorSeverity(AnomalySeverity severity) {
    return switch (severity) {
      AnomalySeverity.low => Severity.low,
      AnomalySeverity.medium => Severity.medium,
      AnomalySeverity.high => Severity.high,
      AnomalySeverity.critical => Severity.critical,
    };
  }

  String _generateId() {
    return 'risk_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Exception thrown when risk scoring operations fail
class RiskScoringException implements Exception {
  final String message;

  RiskScoringException(this.message);

  @override
  String toString() => 'RiskScoringException: $message';
}
