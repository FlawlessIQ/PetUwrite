import 'policy_exclusion.dart';

enum UnderwritingOutcome {
  approve,
  approveWithExclusions,
  refer,
  decline,
}

String underwritingOutcomeToString(UnderwritingOutcome outcome) {
  switch (outcome) {
    case UnderwritingOutcome.approve:
      return 'approve';
    case UnderwritingOutcome.approveWithExclusions:
      return 'approve_with_exclusions';
    case UnderwritingOutcome.refer:
      return 'refer';
    case UnderwritingOutcome.decline:
      return 'decline';
  }
}

UnderwritingOutcome underwritingOutcomeFromString(String value) {
  switch (value) {
    case 'approve':
      return UnderwritingOutcome.approve;
    case 'approve_with_exclusions':
      return UnderwritingOutcome.approveWithExclusions;
    case 'refer':
      return UnderwritingOutcome.refer;
    case 'decline':
      return UnderwritingOutcome.decline;
    default:
      return UnderwritingOutcome.refer;
  }
}

class UnderwritingPricingAdjustments {
  final double premiumMultiplier;
  final double deductibleAdjustment;
  final int waitingPeriodDays;

  const UnderwritingPricingAdjustments({
    required this.premiumMultiplier,
    required this.deductibleAdjustment,
    required this.waitingPeriodDays,
  });

  factory UnderwritingPricingAdjustments.defaultAdjustments() {
    return const UnderwritingPricingAdjustments(
      premiumMultiplier: 1.0,
      deductibleAdjustment: 0.0,
      waitingPeriodDays: 0,
    );
  }

  factory UnderwritingPricingAdjustments.fromJson(Map<String, dynamic> json) {
    return UnderwritingPricingAdjustments(
      premiumMultiplier: (json['premiumMultiplier'] as num?)?.toDouble() ?? 1.0,
      deductibleAdjustment: (json['deductibleAdjustment'] as num?)?.toDouble() ?? 0.0,
      waitingPeriodDays: (json['waitingPeriodDays'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'premiumMultiplier': premiumMultiplier,
      'deductibleAdjustment': deductibleAdjustment,
      'waitingPeriodDays': waitingPeriodDays,
    };
  }
}

class UnderwritingDecision {
  final UnderwritingOutcome outcome;
  final List<String> reasonCodes;
  final List<PolicyExclusion> exclusions;
  final UnderwritingPricingAdjustments pricingAdjustments;
  final DateTime decidedAt;
  final String decidedBy; // "system" | "manual"
  final int version;

  const UnderwritingDecision({
    required this.outcome,
    required this.reasonCodes,
    required this.exclusions,
    required this.pricingAdjustments,
    required this.decidedAt,
    required this.decidedBy,
    required this.version,
  });

  Map<String, dynamic> toJson() {
    return {
      'outcome': underwritingOutcomeToString(outcome),
      'reasonCodes': reasonCodes,
      'exclusions': exclusions.map((e) => e.toJson()).toList(),
      'pricingAdjustments': pricingAdjustments.toJson(),
      'decidedAt': decidedAt.toIso8601String(),
      'decidedBy': decidedBy,
      'version': version,
    };
  }

  factory UnderwritingDecision.fromJson(Map<String, dynamic> json) {
    return UnderwritingDecision(
      outcome: underwritingOutcomeFromString((json['outcome'] ?? 'refer').toString()),
      reasonCodes: (json['reasonCodes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      exclusions: (json['exclusions'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(PolicyExclusion.fromJson)
              .toList() ??
          const [],
      pricingAdjustments: json['pricingAdjustments'] is Map<String, dynamic>
          ? UnderwritingPricingAdjustments.fromJson(json['pricingAdjustments'] as Map<String, dynamic>)
          : UnderwritingPricingAdjustments.defaultAdjustments(),
      decidedAt: DateTime.tryParse((json['decidedAt'] ?? '').toString()) ?? DateTime.now(),
      decidedBy: (json['decidedBy'] ?? 'system').toString(),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }
}
