import '../config/pricing_config.dart';
import 'risk_score.dart';

/// Traceable pricing breakdown for a quoted plan.
///
/// This is designed to be:
/// - Deterministic (purely derived from config + inputs)
/// - Explainable (captures every factor and add-on load)
/// - Persistable (JSON-safe)
class PricingBreakdown {
  final String pricingVersion;
  final String effectiveDateIso;

  final double baseRiskRate;
  final RiskLevel riskBand;
  final double riskBandMultiplier;

  /// Regional multiplier applied to the base risk rate.
  final double regionalMultiplier;

  /// Regional key used (e.g. state code, "NYC_ZIP", or "DEFAULT").
  final String regionalKey;

  /// Multi-pet discount as a fraction (0.0-1.0).
  final double multiPetDiscount;

  /// Base premium after risk+region and after multi-pet discount.
  final double pricingBasePremium;

  final int reimbursementPercent;
  final double reimbursementFactor;

  final int annualDeductible;
  final double deductibleFactor;

  /// `null` means Unlimited.
  final int? annualLimit;
  final double annualLimitFactor;

  /// Requested levers before availability coercion (if any).
  ///
  /// `requestedAnnualLimit == null` means the request was Unlimited.
  final int? requestedReimbursementPercent;
  final int? requestedAnnualDeductible;
  final int? requestedAnnualLimit;

  /// Whether any lever was coerced due to availability rules.
  final bool wasCoerced;

  /// Human-readable reasons explaining why coercion occurred.
  final List<String> coercionReasons;

  /// Map of add-on name (enum name) → monthly load (USD).
  final Map<String, double> addOnMonthlyLoads;

  /// Premium before add-ons/minimum, after multiplicative factors.
  final double premiumBeforeAddOns;

  /// Sum of add-on monthly loads.
  final double addOnTotal;

  /// Whether the minimum premium guardrail was applied.
  final bool minPremiumApplied;

  /// Final monthly premium (USD).
  final double finalMonthlyPremium;

  const PricingBreakdown({
    required this.pricingVersion,
    required this.effectiveDateIso,
    required this.baseRiskRate,
    required this.riskBand,
    required this.riskBandMultiplier,
    required this.regionalMultiplier,
    required this.regionalKey,
    required this.multiPetDiscount,
    required this.pricingBasePremium,
    required this.reimbursementPercent,
    required this.reimbursementFactor,
    required this.annualDeductible,
    required this.deductibleFactor,
    required this.annualLimit,
    required this.annualLimitFactor,
    this.requestedReimbursementPercent,
    this.requestedAnnualDeductible,
    this.requestedAnnualLimit,
    this.wasCoerced = false,
    this.coercionReasons = const [],
    required this.addOnMonthlyLoads,
    required this.premiumBeforeAddOns,
    required this.addOnTotal,
    required this.minPremiumApplied,
    required this.finalMonthlyPremium,
  });

  Map<String, dynamic> toJson() {
    return {
      'pricingVersion': pricingVersion,
      'effectiveDateIso': effectiveDateIso,
      'baseRiskRate': baseRiskRate,
      'riskBand': riskBand.name,
      'riskBandMultiplier': riskBandMultiplier,
      'regionalMultiplier': regionalMultiplier,
      'regionalKey': regionalKey,
      'multiPetDiscount': multiPetDiscount,
      'pricingBasePremium': pricingBasePremium,
      'reimbursementPercent': reimbursementPercent,
      'reimbursementFactor': reimbursementFactor,
      'annualDeductible': annualDeductible,
      'deductibleFactor': deductibleFactor,
      'annualLimit': annualLimit,
      'annualLimitFactor': annualLimitFactor,
      'requestedReimbursementPercent': requestedReimbursementPercent,
      'requestedAnnualDeductible': requestedAnnualDeductible,
      'requestedAnnualLimit': requestedAnnualLimit,
      'wasCoerced': wasCoerced,
      'coercionReasons': coercionReasons,
      'addOnMonthlyLoads': addOnMonthlyLoads,
      'premiumBeforeAddOns': premiumBeforeAddOns,
      'addOnTotal': addOnTotal,
      'minPremiumApplied': minPremiumApplied,
      'finalMonthlyPremium': finalMonthlyPremium,
    };
  }

  factory PricingBreakdown.fromJson(Map<String, dynamic> json) {
    RiskLevel parseRiskBand(String? value) {
      final raw = (value ?? '').trim();
      for (final v in RiskLevel.values) {
        if (v.name == raw) return v;
        if ('RiskLevel.${v.name}' == raw) return v;
      }
      return RiskLevel.medium;
    }

    String parsePricingVersion(dynamic value) {
      if (value == null) return PricingConfig.version;
      return value.toString();
    }

    List<String> parseCoercionReasons(dynamic value) {
      if (value is List) {
        return value.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList(growable: false);
      }
      return const [];
    }

    final addOnLoadsRaw = json['addOnMonthlyLoads'];
    final Map<String, double> addOnLoads = addOnLoadsRaw is Map
        ? addOnLoadsRaw.map(
            (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble() ?? 0.0),
          )
        : <String, double>{};

    return PricingBreakdown(
      pricingVersion: parsePricingVersion(json['pricingVersion']),
      effectiveDateIso: (json['effectiveDateIso'] ?? PricingConfig.effectiveDateIso).toString(),
      baseRiskRate: (json['baseRiskRate'] as num?)?.toDouble() ?? PricingConfig.baseRiskRate,
      riskBand: parseRiskBand(json['riskBand']?.toString()),
      riskBandMultiplier: (json['riskBandMultiplier'] as num?)?.toDouble() ?? PricingConfig.defaultFactor,
      regionalMultiplier: (json['regionalMultiplier'] as num?)?.toDouble() ?? PricingConfig.defaultFactor,
      regionalKey: (json['regionalKey'] ?? 'DEFAULT').toString(),
      multiPetDiscount: (json['multiPetDiscount'] as num?)?.toDouble() ?? 0.0,
      pricingBasePremium: (json['pricingBasePremium'] as num?)?.toDouble() ?? 0.0,
      reimbursementPercent: (json['reimbursementPercent'] as num?)?.toInt() ?? 80,
      reimbursementFactor: (json['reimbursementFactor'] as num?)?.toDouble() ?? PricingConfig.defaultFactor,
      annualDeductible: (json['annualDeductible'] as num?)?.toInt() ?? 500,
      deductibleFactor: (json['deductibleFactor'] as num?)?.toDouble() ?? PricingConfig.defaultFactor,
      annualLimit: json['annualLimit'] == null ? null : (json['annualLimit'] as num?)?.toInt(),
      annualLimitFactor: (json['annualLimitFactor'] as num?)?.toDouble() ?? PricingConfig.defaultFactor,
      requestedReimbursementPercent: (json['requestedReimbursementPercent'] as num?)?.toInt(),
      requestedAnnualDeductible: (json['requestedAnnualDeductible'] as num?)?.toInt(),
      // If the key exists and is null, this still represents "requested unlimited".
      requestedAnnualLimit: json.containsKey('requestedAnnualLimit')
          ? (json['requestedAnnualLimit'] == null ? null : (json['requestedAnnualLimit'] as num?)?.toInt())
          : null,
      wasCoerced: json['wasCoerced'] == true,
      coercionReasons: parseCoercionReasons(json['coercionReasons']),
      addOnMonthlyLoads: addOnLoads,
      premiumBeforeAddOns: (json['premiumBeforeAddOns'] as num?)?.toDouble() ?? 0.0,
      addOnTotal: (json['addOnTotal'] as num?)?.toDouble() ?? 0.0,
      minPremiumApplied: json['minPremiumApplied'] == true,
      finalMonthlyPremium: (json['finalMonthlyPremium'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
