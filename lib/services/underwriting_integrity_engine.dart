import '../models/medical_condition_fact.dart';
import '../models/underwriting_assessment.dart';
import '../models/underwriting_status.dart';
import '../models/pet.dart';
import '../models/risk_score.dart';
import '../models/evidence_requirement.dart';
import 'evidence_requirements_engine.dart';
import 'diagnostic_timing_guard.dart';
import 'integrity_gate_result.dart';
import 'pet_identity_matcher.dart';
import 'risk_score_sanity_guard.dart';
import 'underwriting_decision_engine.dart';
import 'underwriting_rules_engine.dart';
import 'vet_history_parser.dart';
import 'vet_record_integrity_guard.dart';

enum VetDocumentReuseAction { pass, needMoreInfo, decline }

class VetDocumentReuseCheckResult {
  final VetDocumentReuseAction action;
  final String reason;
  final List<String> matchedCaseIds;

  const VetDocumentReuseCheckResult._({
    required this.action,
    required this.reason,
    required this.matchedCaseIds,
  });

  const VetDocumentReuseCheckResult.pass()
      : this._(
          action: VetDocumentReuseAction.pass,
          reason: 'OK',
          matchedCaseIds: const [],
        );

  const VetDocumentReuseCheckResult.needMoreInfo({
    required String reason,
    required List<String> matchedCaseIds,
  }) : this._(
          action: VetDocumentReuseAction.needMoreInfo,
          reason: reason,
          matchedCaseIds: matchedCaseIds,
        );

  const VetDocumentReuseCheckResult.decline({
    required String reason,
    required List<String> matchedCaseIds,
  }) : this._(
          action: VetDocumentReuseAction.decline,
          reason: reason,
          matchedCaseIds: matchedCaseIds,
        );
}

/// Enforces underwriting integrity invariants.
///
/// - AI may enrich facts, but can never decide outcomes.
/// - Underwriting must fail closed.
/// - Pricing is enabled ONLY when underwritingStatus == APPROVED.
class UnderwritingIntegrityEngine {
  static const Set<String> deterministicCriticalCodes = {
    'HCM',
    'CHF',
    'ACTIVE_CANCER',
    'CKD_STAGE_3_PLUS',
  };
  static const int defaultAiFailureDeclineThreshold = 2;

  final UnderwritingRulesEngine? _rulesEngine;
  final UnderwritingDecisionEngine _decisionEngine;
  final EvidenceRequirementsEngine _evidenceEngine;
  final DateTime Function() _now;
  final Future<VetDocumentReuseCheckResult> Function({
    required List<String> vetDocumentHashes,
    String? underwritingCaseId,
  })?
  _vetDocumentReuseCheck;
  final Future<EligibilityResult> Function({
    required Pet pet,
    required RiskScore riskScore,
  })? _deterministicEligibility;

  UnderwritingIntegrityEngine({
    UnderwritingRulesEngine? rulesEngine,
    UnderwritingDecisionEngine? decisionEngine,
    EvidenceRequirementsEngine? evidenceEngine,
    Future<VetDocumentReuseCheckResult> Function({
      required List<String> vetDocumentHashes,
      String? underwritingCaseId,
    })?
    vetDocumentReuseCheck,
    DateTime Function()? now,
    Future<EligibilityResult> Function({
      required Pet pet,
      required RiskScore riskScore,
    })?
    deterministicEligibility,
  })  : _deterministicEligibility = deterministicEligibility,
        _rulesEngine = rulesEngine ??
            (deterministicEligibility == null ? UnderwritingRulesEngine() : null),
        _decisionEngine = decisionEngine ?? UnderwritingDecisionEngine(),
        _evidenceEngine = evidenceEngine ?? EvidenceRequirementsEngine(),
        _vetDocumentReuseCheck = vetDocumentReuseCheck,
        _now = now ?? DateTime.now;

  Future<UnderwritingAssessment> assess({
    required Pet pet,
    required RiskScore riskScore,
    required List<MedicalConditionFact> medicalFacts,
    required bool medicalFactsRequired,
    required bool aiFailure,
    int aiFailureCount = 0,
    Set<String> ruleOutConditionCodes = const {},
    bool userFailedToProvideRequiredEvidence = false,
    int aiFailureDeclineThreshold = defaultAiFailureDeclineThreshold,
    List<String> vetDocumentHashes = const [],
    String? underwritingCaseId,
    List<VetRecordData> aiVetExtractionForIntegrity = const [],
    List<String> rawVetTextsForIntegrity = const [],
  }) async {
    // If user has already been asked for evidence and still cannot provide it,
    // deterministically decline (zero-touch outcome).
    if (userFailedToProvideRequiredEvidence) {
      final eligibility = EligibilityResult.ineligible(
        reason: 'Required evidence not provided',
        ruleViolated: 'REQUIRED_EVIDENCE_NOT_PROVIDED',
      );
      final decision = _decisionEngine.buildFromEligibility(
        eligibility: eligibility,
      );
      return UnderwritingAssessment(
        underwritingStatus: UnderwritingStatus.declined,
        pricingEnabled: false,
        reason: 'REQUIRED_EVIDENCE_NOT_PROVIDED',
        decision: decision,
      );
    }

    // Deterministic vet record integrity + identity + timing checks.
    // These must run before using vet-derived signals to deny/decline, so we
    // don't deny based on records that don't match the applicant pet.
    final hasVetContext = vetDocumentHashes.any((h) => h.trim().isNotEmpty) ||
        rawVetTextsForIntegrity.any((t) => t.trim().isNotEmpty) ||
        aiVetExtractionForIntegrity.isNotEmpty;

    // Deterministic risk score sanity check (anti-tampering).
    final riskCheck = RiskScoreSanityGuard().check(riskScore);
    if (riskCheck.action == IntegrityGateAction.needMoreInfo) {
      return UnderwritingAssessment(
        underwritingStatus: UnderwritingStatus.needMoreInfo,
        pricingEnabled: false,
        reason: riskCheck.reason,
        requiredEvidence: riskCheck.requiredEvidence,
      );
    }

    if (hasVetContext) {
      final now = _now();

      final petIdentity = PetIdentityMatcher().check(
        pet: pet,
        rawVetTexts: rawVetTextsForIntegrity,
        now: now,
      );
      if (petIdentity.action == IntegrityGateAction.decline) {
        final eligibility = EligibilityResult.ineligible(
          reason: 'Pet identity mismatch',
          ruleViolated: 'PET_IDENTITY_MISMATCH',
        );
        final decision = _decisionEngine.buildFromEligibility(
          eligibility: eligibility,
        );
        return UnderwritingAssessment(
          underwritingStatus: UnderwritingStatus.declined,
          pricingEnabled: false,
          reason: petIdentity.reason,
          decision: decision,
        );
      }

      final integrity = VetRecordIntegrityGuard().check(
        rawVetTexts: rawVetTextsForIntegrity,
      );

      final timing = DiagnosticTimingGuard().check(
        aiVetExtraction: aiVetExtractionForIntegrity,
        rawVetTexts: rawVetTextsForIntegrity,
        now: now,
      );

      final needMoreInfo = <IntegrityGateResult>[];
      if (petIdentity.action == IntegrityGateAction.needMoreInfo) {
        needMoreInfo.add(petIdentity);
      }
      if (integrity.action == IntegrityGateAction.needMoreInfo) {
        needMoreInfo.add(integrity);
      }
      if (timing.action == IntegrityGateAction.needMoreInfo) {
        needMoreInfo.add(timing);
      }

      if (needMoreInfo.isNotEmpty) {
        final combinedEvidence = <EvidenceRequirement>[];
        for (final r in needMoreInfo) {
          combinedEvidence.addAll(r.requiredEvidence);
        }

        // Also include medical-evidence requirements (if applicable) so the user
        // can resolve everything in a single self-serve loop.
        combinedEvidence.addAll(
          _evidenceEngine.build(
            medicalFacts: medicalFacts,
            ruleOutConditionCodes: ruleOutConditionCodes,
            medicalFactsRequired: medicalFactsRequired,
            aiFailure: aiFailure,
          ),
        );

        final deduped = _dedupeEvidenceByCode(combinedEvidence);
        final reason = needMoreInfo.length == 1
            ? needMoreInfo.first.reason
            : 'INTEGRITY_CHECKS_REQUIRED';

        return UnderwritingAssessment(
          underwritingStatus: UnderwritingStatus.needMoreInfo,
          pricingEnabled: false,
          reason: reason,
          requiredEvidence: deduped,
        );
      }
    }

    // Deterministic document integrity / reuse check (fraud / abuse guard).
    // Fail closed: if a reuse check indicates risk (or can’t be performed),
    // we block pricing and require additional evidence.
    final normalizedHashes = vetDocumentHashes
        .map((h) => h.trim())
        .where((h) => h.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (_vetDocumentReuseCheck != null && normalizedHashes.isNotEmpty) {
      final reuse = await _vetDocumentReuseCheck(
        vetDocumentHashes: normalizedHashes,
        underwritingCaseId: underwritingCaseId,
      );

      if (reuse.action == VetDocumentReuseAction.decline) {
        final eligibility = EligibilityResult.ineligible(
          reason: 'Vet document reuse detected',
          ruleViolated: 'VET_DOCUMENT_REUSE',
        );
        final decision = _decisionEngine.buildFromEligibility(
          eligibility: eligibility,
        );
        return UnderwritingAssessment(
          underwritingStatus: UnderwritingStatus.declined,
          pricingEnabled: false,
          reason: reuse.reason,
          decision: decision,
        );
      }

      if (reuse.action == VetDocumentReuseAction.needMoreInfo) {
        final requiredEvidence = <EvidenceRequirement>[
          const EvidenceRequirement(
            code: 'VET_DOCUMENT_INTEGRITY',
            title: 'Upload a different veterinary record',
            details:
                'Please upload a different record (a different visit date, a different clinic document, or additional pages). If you have trouble, ask your vet clinic to send records directly or provide an official statement of your pet’s history.',
          ),
        ];

        return UnderwritingAssessment(
          underwritingStatus: UnderwritingStatus.needMoreInfo,
          pricingEnabled: false,
          reason: reuse.reason,
          requiredEvidence: requiredEvidence,
        );
      }
    }

    // Deterministic critical rule check (runs without Firestore/AI).
    // This must run even if other required medical fields are missing.
    for (final fact in medicalFacts) {
      final code = fact.conditionCode.trim().toUpperCase();
      if (deterministicCriticalCodes.contains(code) &&
          fact.status == MedicalConditionStatus.confirmed) {
        // Explicit audit log for invariants.
        // ignore: avoid_print
        print(
          '🧾 UnderwritingIntegrityEngine: CRITICAL_CONDITION_DETECTED code=$code => DENIED',
        );
        final eligibility = EligibilityResult.ineligible(
          reason: 'Critical confirmed condition: $code',
          ruleViolated: 'DETERMINISTIC_CRITICAL_CONDITION',
          violatedValue: code,
        );

        final decision = _decisionEngine.buildFromEligibility(
          eligibility: eligibility,
        );

        return UnderwritingAssessment(
          underwritingStatus: UnderwritingStatus.denied,
          pricingEnabled: false,
          reason: 'CRITICAL_CONDITION_$code',
          decision: decision,
        );
      }
    }

    // Suspected/unknown critical condition => deterministic decline,
    // unless it is explicitly presented as rule-out/uncertain language.
    for (final fact in medicalFacts) {
      final code = fact.conditionCode.trim().toUpperCase();
      if (!deterministicCriticalCodes.contains(code)) continue;
      if (ruleOutConditionCodes.contains(code)) continue;
      if (fact.status == MedicalConditionStatus.suspected ||
          fact.status == MedicalConditionStatus.unknown) {
        final eligibility = EligibilityResult.ineligible(
          reason: 'Suspected/unknown critical condition: $code',
          ruleViolated: 'SUSPECTED_CRITICAL_CONDITION',
          violatedValue: code,
        );

        final decision = _decisionEngine.buildFromEligibility(
          eligibility: eligibility,
        );

        return UnderwritingAssessment(
          underwritingStatus: UnderwritingStatus.declined,
          pricingEnabled: false,
          reason: 'SUSPECTED_CRITICAL_CONDITION',
          decision: decision,
        );
      }
    }

    // Fail closed when upstream AI pipelines fail, but ONLY after deterministic
    // critical checks so we still deny on confirmed critical conditions.
    if (aiFailure) {
      // ignore: avoid_print
      final shouldDecline = aiFailureCount >= aiFailureDeclineThreshold;
      print(
        '🧾 UnderwritingIntegrityEngine: AI_FAILED count=$aiFailureCount threshold=$aiFailureDeclineThreshold => '
        '${shouldDecline ? 'DECLINED' : 'NEED_MORE_INFO'}',
      );

      if (shouldDecline) {
        final eligibility = EligibilityResult.ineligible(
          reason: 'AI failure persisted',
          ruleViolated: 'AI_FAILURE_PERSISTED',
        );
        final decision = _decisionEngine.buildFromEligibility(
          eligibility: eligibility,
        );
        return UnderwritingAssessment(
          underwritingStatus: UnderwritingStatus.declined,
          pricingEnabled: false,
          reason: 'AI_FAILURE_PERSISTED',
          decision: decision,
        );
      }

      final requiredEvidence = _evidenceEngine.build(
        medicalFacts: medicalFacts,
        ruleOutConditionCodes: ruleOutConditionCodes,
        medicalFactsRequired: medicalFactsRequired,
        aiFailure: aiFailure,
      );

      return UnderwritingAssessment(
        underwritingStatus: UnderwritingStatus.needMoreInfo,
        pricingEnabled: false,
        reason: 'AI_FAILURE',
        requiredEvidence: requiredEvidence,
      );
    }

    if (medicalFactsRequired) {
      if (medicalFacts.isEmpty) {
        final requiredEvidence = _evidenceEngine.build(
          medicalFacts: medicalFacts,
          ruleOutConditionCodes: ruleOutConditionCodes,
          medicalFactsRequired: medicalFactsRequired,
          aiFailure: aiFailure,
        );

        return UnderwritingAssessment(
          underwritingStatus: UnderwritingStatus.needMoreInfo,
          pricingEnabled: false,
          reason: 'MISSING_OR_UNCERTAIN_MEDICAL_FACTS',
          requiredEvidence: requiredEvidence,
        );
      }
    }

    // Any unknown/suspected status requires self-serve evidence (fail closed).
    final hasUncertainStatus = medicalFacts.any(
      (f) => f.status == MedicalConditionStatus.unknown ||
          f.status == MedicalConditionStatus.suspected,
    );
    if (hasUncertainStatus) {
      final requiredEvidence = _evidenceEngine.build(
        medicalFacts: medicalFacts,
        ruleOutConditionCodes: ruleOutConditionCodes,
        medicalFactsRequired: medicalFactsRequired,
        aiFailure: aiFailure,
      );

      return UnderwritingAssessment(
        underwritingStatus: UnderwritingStatus.needMoreInfo,
        pricingEnabled: false,
        reason: 'MISSING_OR_UNCERTAIN_MEDICAL_FACTS',
        requiredEvidence: requiredEvidence,
      );
    }

    if (medicalFactsRequired) {
      final incomplete = medicalFacts.where((f) => !f.isComplete).toList();
      if (incomplete.isNotEmpty) {
        final requiredEvidence = _evidenceEngine.build(
          medicalFacts: medicalFacts,
          ruleOutConditionCodes: ruleOutConditionCodes,
          medicalFactsRequired: medicalFactsRequired,
          aiFailure: aiFailure,
        );

        return UnderwritingAssessment(
          underwritingStatus: UnderwritingStatus.needMoreInfo,
          pricingEnabled: false,
          reason: 'MISSING_OR_UNCERTAIN_MEDICAL_FACTS',
          requiredEvidence: requiredEvidence,
        );
      }
    }

    // Deterministic exclusions: any confirmed non-critical condition is excluded.
    final exclusions = <String>[];
    for (final fact in medicalFacts) {
      final code = fact.conditionCode.trim().toUpperCase();
      if (code.isEmpty) continue;
      if (deterministicCriticalCodes.contains(code)) continue;
      if (fact.status == MedicalConditionStatus.confirmed) {
        exclusions.add(code);
      }
    }

    // Non-medical deterministic rules (age/breed/risk thresholds).
    // Condition-based checks inside this rules engine must not be relied on.
    // We pass an empty list intentionally.
    //
    // If rules are unavailable/disabled, we fail closed (decline).
    final eligibility = await (_deterministicEligibility != null
      ? _deterministicEligibility(pet: pet, riskScore: riskScore)
      : _rulesEngine!.checkEligibilityDeterministic(
        pet: pet,
        riskScore: riskScore,
        ));

    if (eligibility.ruleViolated == 'RULES_UNAVAILABLE') {
      final eligibilityDecline = EligibilityResult.ineligible(
        reason: 'Underwriting rules unavailable',
        ruleViolated: 'RULES_UNAVAILABLE',
      );
      final decision = _decisionEngine.buildFromEligibility(
        eligibility: eligibilityDecline,
      );
      return UnderwritingAssessment(
        underwritingStatus: UnderwritingStatus.declined,
        pricingEnabled: false,
        reason: 'RULES_UNAVAILABLE',
        decision: decision,
      );
    }

    // If the user disclosed conditions (medical facts required), we do not
    // allow approval based solely on customer-entered condition data.
    // Deterministically require verifiable vet documentation, but do not mask
    // more specific outcomes (rules unavailable, AI failure, uncertainty).
    if (medicalFactsRequired &&
        medicalFacts.isNotEmpty &&
        eligibility.eligible &&
        !hasVetContext) {
      return const UnderwritingAssessment(
        underwritingStatus: UnderwritingStatus.needMoreInfo,
        pricingEnabled: false,
        reason: 'VET_RECORDS_REQUIRED',
        requiredEvidence: [
          EvidenceRequirement(
            code: 'PROVIDE_MEDICAL_HISTORY',
            title: 'Provide medical history records',
            details:
                'Upload vet records that list diagnoses, medications, and any relevant lab or imaging results.',
          ),
        ],
      );
    }

    final EligibilityResult finalEligibility;
    if (!eligibility.eligible) {
      finalEligibility = eligibility;
    } else if (exclusions.isNotEmpty) {
      finalEligibility = EligibilityResult.eligibleWithExclusions(
        excludedConditions: exclusions,
      );
    } else {
      finalEligibility = EligibilityResult.eligible();
    }

    final decision = _decisionEngine.buildFromEligibility(
      eligibility: finalEligibility,
    );

    final status = finalEligibility.eligible
        ? UnderwritingStatus.approved
        : UnderwritingStatus.denied;

    return UnderwritingAssessment(
      underwritingStatus: status,
      pricingEnabled: status == UnderwritingStatus.approved,
      reason: finalEligibility.eligible
          ? (exclusions.isNotEmpty ? 'APPROVED_WITH_EXCLUSIONS' : 'APPROVED')
          : (finalEligibility.ruleViolated ?? 'DENIED'),
      decision: decision,
    );
  }

  List<EvidenceRequirement> _dedupeEvidenceByCode(List<EvidenceRequirement> inList) {
    final seen = <String, EvidenceRequirement>{};
    for (final e in inList) {
      final code = e.code.trim().toUpperCase();
      if (code.isEmpty) continue;
      seen.putIfAbsent(code, () => e);
    }
    return seen.values.toList(growable: false);
  }
}
