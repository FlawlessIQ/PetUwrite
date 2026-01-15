import '../models/medical_condition_fact.dart';

class MedicalConditionFactMapper {
  /// Best-effort canonicalization from a free-text condition name.
  ///
  /// This MUST be deterministic. It is allowed to be conservative.
  static String conditionCodeFromName(String name) {
    final raw = name.trim();
    if (raw.isEmpty) return '';

    final n = raw.toLowerCase();

    bool hasAny(Iterable<RegExp> patterns) {
      for (final p in patterns) {
        if (p.hasMatch(n)) return true;
      }
      return false;
    }

    final ruleOutPatterns = <RegExp>[
      RegExp(r'\brule\s*out\b'),
      RegExp(r'\br\/o\b'),
      RegExp(r'\bcannot\s*rule\s*out\b'),
      RegExp(r'\bpossible\b'),
      RegExp(r'\bsuspect\b'),
      RegExp(r'\bconcern\s*for\b'),
      RegExp(r'\bevaluate\s*for\b'),
      RegExp(r'\brecommend\b.*\becho\b'),
    ];

    final benignMassPatterns = <RegExp>[
      RegExp(r'\bbenign\b'),
      RegExp(r'\blipoma\b'),
      RegExp(r'\bcyst\b'),
      RegExp(r'\bsebaceous\b'),
      RegExp(r'\bhyperplasia\b'),
      RegExp(r'\bwart\b'),
      RegExp(r'\bskin\s*tag\b'),
    ];

    final malignantCancerPatterns = <RegExp>[
      RegExp(r'\bmalignant\b'),
      RegExp(r'\bmetastatic\b'),
      RegExp(r'\bcarcinoma\b'),
      RegExp(r'\bsarcoma\b'),
      RegExp(r'\blymphoma\b'),
      RegExp(r'\badenocarcinoma\b'),
      RegExp(r'\bosteosarcoma\b'),
      RegExp(r'\bhemangiosarcoma\b'),
    ];

    final hasRuleOut = hasAny(ruleOutPatterns);

    // Critical deterministic codes
    if (RegExp(r'\bhcm\b').hasMatch(n) ||
        n.contains('hypertrophic cardiomyopathy')) {
      return 'HCM';
    }

    if (RegExp(r'\bchf\b').hasMatch(n) ||
        n.contains('congestive heart failure') ||
        n.contains('heart failure')) {
      return 'CHF';
    }

    // Cancer / masses:
    // - Never treat "tumor" as cancer by itself (too many benign cases).
    // - Only map to ACTIVE_CANCER when strong malignant language exists.
    // - If benign language exists, map to MASS_OR_TUMOR.
    // - If rule-out language exists, avoid ACTIVE_CANCER.
    final mentionsMass = RegExp(r'\b(mass|tumou?r|neoplasm|nodule|lesion)\b')
        .hasMatch(n);
    final mentionsCancerWord = RegExp(r'\bcancer\b').hasMatch(n);
    final isBenignMass = mentionsMass && hasAny(benignMassPatterns);
    final isMalignantCancer = hasAny(malignantCancerPatterns);

    if (isBenignMass) {
      return 'MASS_OR_TUMOR';
    }

    if (!hasRuleOut && isMalignantCancer) {
      return 'ACTIVE_CANCER';
    }

    // If cancer is mentioned but ambiguous (rule-out / suspected / generic),
    // fail closed by NOT mapping to critical cancer.
    if (mentionsCancerWord || mentionsMass) {
      return 'MASS_OR_TUMOR';
    }

    // CKD stage 3+ (including IRIS staging). Do NOT let rule-out language
    // escalate to confirmed critical status elsewhere.
    if (RegExp(r'\b(ckd|chronic kidney disease|renal (failure|disease))\b')
            .hasMatch(n) &&
        (RegExp(r'\bstage\s*(3|iii|4|iv|5|v)\b').hasMatch(n) ||
            RegExp(r'\biris\s*stage\s*(3|iii|4|iv|5|v)\b').hasMatch(n))) {
      return 'CKD_STAGE_3_PLUS';
    }

    // Generic deterministic fallback: normalize to an upper snake-like token.
    final cleaned = raw
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return cleaned.isEmpty ? 'UNKNOWN_CONDITION' : cleaned;
  }

  static MedicalConditionStatus suggestedStatusFromLegacy(String legacy) {
    final v = legacy.trim().toLowerCase();
    if (v == 'resolved') return MedicalConditionStatus.resolved;
    if (v == 'active' || v == 'managed' || v == 'stable') {
      return MedicalConditionStatus.confirmed;
    }
    return MedicalConditionStatus.unknown;
  }
}
