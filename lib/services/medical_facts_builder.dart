import '../models/medical_condition_fact.dart';
import '../models/medical_history.dart';
import '../services/medical_condition_fact_mapper.dart';
import 'vet_history_parser.dart';

class MedicalFactsBuildResult {
  final List<MedicalConditionFact> facts;

  /// True if any upstream AI pipeline failed (e.g. vet-record AI parse).
  final bool aiFailure;

  /// True if the deterministic backstop detected a critical condition.
  final bool criticalConditionDetected;

  /// Condition codes that were explicitly presented in rule-out / uncertainty
  /// language (e.g., "rule out HCM", "possible cancer").
  ///
  /// This is used to keep underwriting self-serve (NEED_MORE_INFO) rather than
  /// declining for suspected critical conditions when the text itself indicates
  /// uncertainty.
  final Set<String> ruleOutConditionCodes;

  const MedicalFactsBuildResult({
    required this.facts,
    required this.aiFailure,
    required this.criticalConditionDetected,
    required this.ruleOutConditionCodes,
  });
}

/// Builds strict medical facts from multiple sources.
///
/// Sources (merged deterministically):
/// - User-entered condition list + user-captured facts (if present)
/// - AI extraction output (e.g. vet record parsed diagnoses)
/// - Deterministic keyword extraction from raw vet text (backstop)
///
/// Non-negotiable: this builder MUST NOT guess. Any unknown fields remain
/// `unknown` and will force underwriting to fail closed.
class MedicalFactsBuilder {
  MedicalFactsBuildResult build({
    required List<MedicalCondition> userEnteredConditions,
    Map<String, MedicalConditionFact> userFactsByConditionId = const {},
    List<VetRecordData> aiVetExtraction = const [],
    List<String> rawVetTexts = const [],
    required bool aiFailure,
  }) {
    final factsByCode = <String, MedicalConditionFact>{};

    void upsert(MedicalConditionFact fact, {required String source}) {
      final code = fact.conditionCode.trim().toUpperCase();
      if (code.isEmpty) return;
      final existing = factsByCode[code];
      if (existing == null) {
        factsByCode[code] = fact;
        return;
      }

      factsByCode[code] = _mergeFacts(existing, fact);
    }

    // (a) User-entered conditions
    for (final condition in userEnteredConditions) {
      final name = condition.name.trim();
      if (name.isEmpty) continue;

      final fromUser = userFactsByConditionId[condition.id];
      if (fromUser != null) {
        upsert(fromUser, source: 'user_fact');
        continue;
      }

      // Placeholder fact (no guessing)
      upsert(
        MedicalConditionFact(
          conditionCode: MedicalConditionFactMapper.conditionCodeFromName(name),
          severity: MedicalConditionSeverity.unknown,
          chronicity: MedicalConditionChronicity.unknown,
          confirmedBy: MedicalConditionConfirmedBy.unknown,
          status: MedicalConditionFactMapper.suggestedStatusFromLegacy(
            condition.status,
          ),
        ),
        source: 'user_condition_placeholder',
      );
    }

    // (b) AI extraction output (vet record parsing)
    for (final record in aiVetExtraction) {
      for (final d in record.diagnoses) {
        final name = d.condition.trim();
        if (name.isEmpty) continue;

        upsert(
          MedicalConditionFact(
            conditionCode: MedicalConditionFactMapper.conditionCodeFromName(name),
            severity: MedicalConditionSeverity.unknown,
            chronicity: MedicalConditionChronicity.unknown,
            confirmedBy: MedicalConditionConfirmedBy.unknown,
            status: MedicalConditionFactMapper.suggestedStatusFromLegacy(d.status),
          ),
          source: 'ai_vet_diagnosis',
        );
      }

      for (final t in record.treatments) {
        final name = t.diagnosis.trim();
        if (name.isEmpty) continue;

        upsert(
          MedicalConditionFact(
            conditionCode: MedicalConditionFactMapper.conditionCodeFromName(name),
            severity: MedicalConditionSeverity.unknown,
            chronicity: MedicalConditionChronicity.unknown,
            confirmedBy: MedicalConditionConfirmedBy.unknown,
            status: MedicalConditionStatus.confirmed,
          ),
          source: 'ai_vet_treatment',
        );
      }
    }

    // (c) Deterministic backstop from raw vet text
    var criticalDetected = false;
    final ruleOutCodes = <String>{};
    for (final text in rawVetTexts) {
      final extracted = _extractFactsFromVetText(text, ruleOutCodes: ruleOutCodes);
      for (final f in extracted) {
        if (_isDeterministicCriticalCode(f.conditionCode) &&
            f.status == MedicalConditionStatus.confirmed) {
          criticalDetected = true;
        }
        upsert(f, source: 'vet_text_backstop');
      }
    }

    final facts = factsByCode.values.toList()
      ..sort((a, b) => a.conditionCode.compareTo(b.conditionCode));

    return MedicalFactsBuildResult(
      facts: facts,
      aiFailure: aiFailure,
      criticalConditionDetected: criticalDetected,
      ruleOutConditionCodes: ruleOutCodes,
    );
  }

  bool _isDeterministicCriticalCode(String code) {
    final c = code.trim().toUpperCase();
    return c == 'HCM' || c == 'CHF' || c == 'ACTIVE_CANCER' || c == 'CKD_STAGE_3_PLUS';
  }

  MedicalConditionFact _mergeFacts(
    MedicalConditionFact a,
    MedicalConditionFact b,
  ) {
    // Deterministic precedence rules:
    // - Prefer confirmed over suspected/unknown.
    // - Prefer non-unknown for other fields.

    MedicalConditionStatus bestStatus(MedicalConditionStatus x, MedicalConditionStatus y) {
      int rank(MedicalConditionStatus s) {
        return switch (s) {
          MedicalConditionStatus.confirmed => 4,
          MedicalConditionStatus.resolved => 3,
          MedicalConditionStatus.suspected => 2,
          MedicalConditionStatus.unknown => 1,
        };
      }

      return rank(y) > rank(x) ? y : x;
    }

    return MedicalConditionFact(
      conditionCode: a.conditionCode.trim().isNotEmpty ? a.conditionCode : b.conditionCode,
      severity: a.severity != MedicalConditionSeverity.unknown ? a.severity : b.severity,
      chronicity:
          a.chronicity != MedicalConditionChronicity.unknown ? a.chronicity : b.chronicity,
      confirmedBy:
          a.confirmedBy != MedicalConditionConfirmedBy.unknown ? a.confirmedBy : b.confirmedBy,
      status: bestStatus(a.status, b.status),
    );
  }

  List<MedicalConditionFact> _extractFactsFromVetText(
    String raw, {
    required Set<String> ruleOutCodes,
  }) {
    final text = raw.toLowerCase();
    if (text.trim().isEmpty) return const [];

    final facts = <MedicalConditionFact>[];

    bool containsEchoEvidence(String t) {
      return RegExp(r'\b(echo|echocardiogram|echocardio)\b').hasMatch(t);
    }

    bool containsConfirmLanguage(String t) {
      return RegExp(
        r'\b(consistent with|findings are consistent with|diagnosed|diagnosis|confirms|shows|evidence of)\b',
      ).hasMatch(t);
    }

    bool containsRuleOutLanguage(String t) {
      return RegExp(
        r'\b(rule\s*out|r\/o|possible|suspect|concern for|cannot\s*rule\s*out|evaluate for|recommend\s+echo|echo\s+recommended)\b',
      ).hasMatch(t);
    }

    bool hasRuleOutNear(String t, int index, {int window = 80}) {
      final start = (index - window) < 0 ? 0 : (index - window);
      final end = (index + window) > t.length ? t.length : (index + window);
      return containsRuleOutLanguage(t.substring(start, end));
    }

    // HCM strict confirmation criteria:
    // - HCM signal present
    // - echo evidence keyword present
    // - confirmation phrase present
    // - no rule-out/uncertainty phrases near diagnosis
    final hcmMatch = RegExp(r'\bhcm\b|hypertrophic cardiomyopathy')
        .firstMatch(text);

    if (hcmMatch != null) {
      final idx = hcmMatch.start;
      final hasEcho = containsEchoEvidence(text);
      final hasConfirm = containsConfirmLanguage(text);
      final hasRuleOut = hasRuleOutNear(text, idx);

      if (hasRuleOut) ruleOutCodes.add('HCM');

      final status = (hasEcho && hasConfirm && !hasRuleOut)
          ? MedicalConditionStatus.confirmed
          : MedicalConditionStatus.suspected;

      facts.add(
        MedicalConditionFact(
          conditionCode: 'HCM',
          severity: MedicalConditionSeverity.unknown,
          chronicity: MedicalConditionChronicity.unknown,
          confirmedBy: MedicalConditionConfirmedBy.unknown,
          status: status,
        ),
      );
    }

    // Murmur alone is NOT a confirmed critical condition.
    if (text.contains('murmur')) {
      // If HCM was detected above and confirmed, keep murmur as separate suspected signal.
      facts.add(
        const MedicalConditionFact(
          conditionCode: 'HEART_MURMUR',
          severity: MedicalConditionSeverity.unknown,
          chronicity: MedicalConditionChronicity.unknown,
          confirmedBy: MedicalConditionConfirmedBy.unknown,
          status: MedicalConditionStatus.suspected,
        ),
      );
    }

    // CHF strict-ish:
    // Confirm only with explicit CHF/heart failure + confirmation language,
    // and no nearby rule-out.
    final chfMatch = RegExp(r'\bchf\b|congestive heart failure|heart failure')
        .firstMatch(text);
    if (chfMatch != null) {
      final idx = chfMatch.start;
      final hasConfirm = containsConfirmLanguage(text) ||
          RegExp(r'\bdx\b').hasMatch(text) ||
          RegExp(r'\bdiagnos').hasMatch(text);
      final hasRuleOut = hasRuleOutNear(text, idx);

      if (hasRuleOut) ruleOutCodes.add('CHF');

      facts.add(
        MedicalConditionFact(
          conditionCode: 'CHF',
          severity: MedicalConditionSeverity.unknown,
          chronicity: MedicalConditionChronicity.unknown,
          confirmedBy: MedicalConditionConfirmedBy.unknown,
          status: (!hasRuleOut && hasConfirm)
              ? MedicalConditionStatus.confirmed
              : MedicalConditionStatus.suspected,
        ),
      );
    }

    // CKD stage 3+ (stage 3/4/5, including IRIS). Confirm only with
    // confirmation language and no nearby rule-out language.
    final ckdMatch = RegExp(
      r'(ckd|chronic kidney disease|renal (failure|disease)).{0,40}(stage\s*(3|iii|4|iv|5|v)|iris\s*stage\s*(3|iii|4|iv|5|v))',
    ).firstMatch(text);
    if (ckdMatch != null) {
      final idx = ckdMatch.start;
      final hasConfirm = containsConfirmLanguage(text) ||
          RegExp(r'\bdx\b').hasMatch(text) ||
          RegExp(r'\bdiagnos').hasMatch(text) ||
          RegExp(r'\bconfirmed\b').hasMatch(text);
      final hasRuleOut = hasRuleOutNear(text, idx);

      if (hasRuleOut) ruleOutCodes.add('CKD_STAGE_3_PLUS');

      facts.add(
        MedicalConditionFact(
          conditionCode: 'CKD_STAGE_3_PLUS',
          severity: MedicalConditionSeverity.unknown,
          chronicity: MedicalConditionChronicity.unknown,
          confirmedBy: MedicalConditionConfirmedBy.unknown,
          status: (!hasRuleOut && hasConfirm)
              ? MedicalConditionStatus.confirmed
              : MedicalConditionStatus.suspected,
        ),
      );
    }

    // Cancer (critical) should never be inferred from "tumor".
    // Confirm only when strong malignant language exists and no rule-out.
    final benignBlock = RegExp(
      r'\b(benign|lipoma|cyst|sebaceous|hyperplasia)\b',
    ).hasMatch(text);
    final malignantSignal = RegExp(
      r'\b(malignant|metastatic|carcinoma|sarcoma|lymphoma|adenocarcinoma|osteosarcoma|hemangiosarcoma)\b',
    ).hasMatch(text);
    final cancerMatch = RegExp(
      r'\b(cancer|carcinoma|sarcoma|lymphoma|adenocarcinoma|osteosarcoma|hemangiosarcoma)\b',
    ).firstMatch(text);

    if (cancerMatch != null && malignantSignal && !benignBlock) {
      final idx = cancerMatch.start;
      final hasRuleOut = hasRuleOutNear(text, idx);
      final hasConfirm = containsConfirmLanguage(text) ||
          RegExp(r'\bbiopsy\b').hasMatch(text) ||
          RegExp(r'\bconfirmed\b').hasMatch(text) ||
          RegExp(r'\bdiagnos').hasMatch(text);

      if (hasRuleOut) ruleOutCodes.add('ACTIVE_CANCER');

      facts.add(
        MedicalConditionFact(
          conditionCode: 'ACTIVE_CANCER',
          severity: MedicalConditionSeverity.unknown,
          chronicity: MedicalConditionChronicity.unknown,
          confirmedBy: MedicalConditionConfirmedBy.unknown,
          status: (!hasRuleOut && hasConfirm)
              ? MedicalConditionStatus.confirmed
              : MedicalConditionStatus.suspected,
        ),
      );
    }

    return facts;
  }
}
