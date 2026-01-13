import '../models/risk_score.dart';
import '../config/pricing_config.dart';
import '../models/pricing_breakdown.dart';
import 'product_catalog.dart';

/// Pricing engine for generating pet insurance quotes
/// Calculates premiums based on risk score, location, and plan type
class QuoteEngine {
  // Pricing constants are centralized in PricingConfig.
  
  /// Generate quote with Day-1 plan options (filtered by availability rules).
  List<Plan> generateQuote({
    required RiskScore riskScore,
    required String zipCode,
    int numberOfPets = 1,
    String? state,
    int? ageYears,
  }) {
    // Risk is expressed via risk bands (not linear scaling).
    final riskBand = riskScore.riskLevel;

    // Base premium = base risk rate × risk band × regional
    final regional = _getRegionalAdjustment(state, zipCode);
    final basePremiumBeforeDiscount = PricingConfig.baseRiskRate * PricingConfig.riskBandMultiplierFor(riskBand) * regional.multiplier;

    // Apply multi-pet discount
    final discount = _getMultiPetDiscount(numberOfPets);
    final discountedBasePremium = basePremiumBeforeDiscount * (1 - discount);

    final dayOneSkus = <({PlanType tier, int reimb, int ded, int? limit})>[
      (tier: PlanType.basic, reimb: 70, ded: 500, limit: 10000),
      (tier: PlanType.standard, reimb: 80, ded: 250, limit: 10000),
      (tier: PlanType.plus, reimb: 80, ded: 250, limit: 20000),
      (tier: PlanType.premium, reimb: 90, ded: 250, limit: 20000),
      (tier: PlanType.unlimited, reimb: 80, ded: 250, limit: null),
    ];

    final plans = <Plan>[];
    for (final sku in dayOneSkus) {
      if (!ProductCatalog.isCoverageAllowed(
        riskBand: riskBand,
        ageYears: ageYears,
        reimbursementPercent: sku.reimb,
        annualDeductible: sku.ded,
        annualLimit: sku.limit,
      )) {
        continue;
      }

      plans.add(
        buildPlan(
          tier: sku.tier,
          basePremium: discountedBasePremium,
          riskBand: riskBand,
          numberOfPets: numberOfPets,
          discount: discount,
          regionalMultiplier: regional.multiplier,
          regionalKey: regional.key,
          reimbursementPercent: sku.reimb,
          annualDeductible: sku.ded,
          annualLimit: sku.limit,
        ),
      );
    }

    // Safety: always return at least Basic.
    if (plans.isEmpty) {
      plans.add(
        buildPlan(
          tier: PlanType.basic,
          basePremium: discountedBasePremium,
          riskBand: riskBand,
          numberOfPets: numberOfPets,
          discount: discount,
          regionalMultiplier: regional.multiplier,
          regionalKey: regional.key,
          reimbursementPercent: 70,
          annualDeductible: 500,
          annualLimit: 10000,
        ),
      );
    }

    return plans;
  }

  /// Build a plan for a tier, using selected levers.
  ///
  /// `annualLimit` of `null` means Unlimited.
  Plan buildPlan({
    required PlanType tier,
    required double basePremium,
    required RiskLevel riskBand,
    required int numberOfPets,
    required double discount,
    required double regionalMultiplier,
    required String regionalKey,
    int? ageYears,
    int reimbursementPercent = 80,
    int annualDeductible = 250,
    int? annualLimit = 10000,
    List<AddOnType> addOns = const [],
  }) {
    final int requestedReimbursement = reimbursementPercent;
    final int requestedDeductible = annualDeductible;
    final int? requestedLimit = annualLimit;

    int coerceReimbursement(int requested) {
      final allowed = ProductCatalog.reimbursementOptionsFor(riskBand: riskBand);
      if (allowed.isEmpty) return requested;
      if (allowed.contains(requested)) return requested;
      final sorted = [...allowed]..sort();
      // Choose greatest allowed <= requested, else smallest allowed.
      for (final v in sorted.reversed) {
        if (v <= requested) return v;
      }
      return sorted.first;
    }

    int coerceDeductible(int requested) {
      final allowed = ProductCatalog.annualDeductibleOptionsFor(riskBand: riskBand);
      if (allowed.isEmpty) return requested;
      if (allowed.contains(requested)) return requested;
      final sorted = [...allowed]..sort();
      // Deductible: choose smallest allowed >= requested, else largest allowed.
      for (final v in sorted) {
        if (v >= requested) return v;
      }
      return sorted.last;
    }

    int? coerceAnnualLimit(int? requested) {
      final allowed = ProductCatalog.annualLimitOptionsFor(riskBand: riskBand, ageYears: ageYears);
      if (allowed.isEmpty) return requested;
      if (allowed.contains(requested)) return requested;

      final finite = allowed.whereType<int>().toList()..sort();
      if (finite.isEmpty) return null;

      if (requested == null) {
        // Unlimited requested but not allowed → max finite.
        return finite.last;
      }

      // Choose greatest allowed <= requested, else smallest allowed.
      for (final v in finite.reversed) {
        if (v <= requested) return v;
      }
      return finite.first;
    }

    final coercedReimbursement = coerceReimbursement(reimbursementPercent);
    final coercedDeductible = coerceDeductible(annualDeductible);
    final coercedAnnualLimit = coerceAnnualLimit(annualLimit);

    final List<String> coercionReasons = <String>[];
    if (coercedReimbursement != requestedReimbursement) {
      coercionReasons.add(
        'Requested reimbursement ${requestedReimbursement}% is not available for ${riskBand.name} risk; coerced to ${coercedReimbursement}%.',
      );
    }
    if (coercedDeductible != requestedDeductible) {
      coercionReasons.add(
        'Requested deductible $requestedDeductible is not available for ${riskBand.name} risk; coerced to $coercedDeductible.',
      );
    }
    if (coercedAnnualLimit != requestedLimit) {
      final String requestedLimitLabel = requestedLimit == null ? 'Unlimited' : requestedLimit.toString();
      final String coercedLimitLabel = coercedAnnualLimit == null ? 'Unlimited' : coercedAnnualLimit.toString();
      coercionReasons.add(
        'Requested annual limit $requestedLimitLabel is not available for ${riskBand.name} risk${ageYears == null ? '' : ' at age $ageYears'}; coerced to $coercedLimitLabel.',
      );
    }
    final bool wasCoerced = coercionReasons.isNotEmpty;

    final tierLabel = switch (tier) {
      PlanType.basic => 'Basic',
      PlanType.standard => 'Standard',
      PlanType.plus => 'Plus',
      PlanType.premium => 'Premium',
      PlanType.unlimited => 'Unlimited',
    };

    final description = switch (tier) {
      PlanType.basic => 'Essential protection for accidents and illnesses',
      PlanType.standard => 'Balanced coverage for most pets',
      PlanType.plus => 'Higher annual limit with popular options',
      PlanType.premium => 'Highest reimbursement with strong protection',
      PlanType.unlimited => 'Unlimited annual limit for eligible pets',
    };

    final annualLimitValue = coercedAnnualLimit == null ? double.infinity : coercedAnnualLimit.toDouble();

    final pricingBreakdown = quotePricingBreakdown(
      basePremium: basePremium,
      riskBand: riskBand,
      regionalMultiplier: regionalMultiplier,
      regionalKey: regionalKey,
      multiPetDiscount: discount,
      reimbursementPercent: coercedReimbursement,
      annualDeductible: coercedDeductible,
      annualLimit: coercedAnnualLimit,
      requestedReimbursementPercent: requestedReimbursement,
      requestedAnnualDeductible: requestedDeductible,
      requestedAnnualLimit: requestedLimit,
      wasCoerced: wasCoerced,
      coercionReasons: coercionReasons,
      addOns: addOns,
    );

    final features = <String>[
      ...ProductCatalog.includedFeaturesForTier(tier),
      if (addOns.contains(AddOnType.wellnessLite)) 'Wellness Lite add-on',
      if (addOns.contains(AddOnType.wellnessPremium)) 'Wellness Premium add-on',
      if (addOns.contains(AddOnType.examFees)) 'Exam fees add-on',
      if (addOns.contains(AddOnType.dentalPlus)) 'Dental Plus add-on',
      if (addOns.contains(AddOnType.rehab)) 'Rehab & physio add-on',
      if (addOns.contains(AddOnType.behavioral)) 'Behavioral therapy add-on',
      if (addOns.contains(AddOnType.prescriptionFood)) 'Prescription food add-on',
    ];

    final exclusions = <String>[...ProductCatalog.baseExclusions()];

    return Plan(
      type: tier,
      name: tierLabel,
      description: description,
      pricingBasePremium: basePremium,
      monthlyPremium: pricingBreakdown.finalMonthlyPremium,
      annualDeductible: coercedDeductible.toDouble(),
      coPayPercentage: (100 - coercedReimbursement).toDouble(),
      maxAnnualCoverage: annualLimitValue,
      isUnlimitedAnnualCoverage: coercedAnnualLimit == null,
      maxLifetimeCoverage: null,
      numberOfPets: numberOfPets,
      multiPetDiscount: discount,
      reimbursementPercent: coercedReimbursement,
      selectedAddOns: addOns.map((e) => e.name).toList(),
      riskBand: riskBand,
      pricingBreakdown: pricingBreakdown,
      waitingPeriodsDays: Map<String, dynamic>.from(ProductCatalog.defaultWaitingPeriodsDays),
      policyRules: {
        'orthopedicWaiver': ProductCatalog.orthopedicWaiverRule,
        'curablePreExisting': ProductCatalog.curablePreExistingRule,
      },
      features: features,
      exclusions: exclusions,
    );
  }

  PricingBreakdown quotePricingBreakdown({
    required double basePremium,
    required RiskLevel riskBand,
    required double regionalMultiplier,
    required String regionalKey,
    required double multiPetDiscount,
    required int reimbursementPercent,
    required int annualDeductible,
    required int? annualLimit,
    int? requestedReimbursementPercent,
    int? requestedAnnualDeductible,
    int? requestedAnnualLimit,
    bool wasCoerced = false,
    List<String> coercionReasons = const [],
    required List<AddOnType> addOns,
  }) {
    final riskBandMultiplier = PricingConfig.riskBandMultiplierFor(riskBand);
    final reimbursementFactor = PricingConfig.reimbursementFactorFor(reimbursementPercent);
    final deductibleFactor = PricingConfig.deductibleFactorFor(annualDeductible);
    final annualLimitFactor = PricingConfig.annualLimitFactorFor(annualLimit);

    final premiumBeforeAddOns = basePremium * reimbursementFactor * deductibleFactor * annualLimitFactor;

    final Map<String, double> addOnMonthlyLoads = {
      for (final addOn in addOns) addOn.name: PricingConfig.addOnLoadFor(addOn),
    };
    final addOnTotal = addOnMonthlyLoads.values.fold<double>(0.0, (sum, v) => sum + v);

    final premiumWithAddOns = premiumBeforeAddOns + addOnTotal;
    final minApplied = premiumWithAddOns < PricingConfig.minMonthlyPremium;
    final finalPremium = minApplied ? PricingConfig.minMonthlyPremium : premiumWithAddOns;

    return PricingBreakdown(
      pricingVersion: PricingConfig.version,
      effectiveDateIso: PricingConfig.effectiveDateIso,
      baseRiskRate: PricingConfig.baseRiskRate,
      riskBand: riskBand,
      riskBandMultiplier: riskBandMultiplier,
      regionalMultiplier: regionalMultiplier,
      regionalKey: regionalKey,
      multiPetDiscount: multiPetDiscount,
      pricingBasePremium: basePremium,
      reimbursementPercent: reimbursementPercent,
      reimbursementFactor: reimbursementFactor,
      annualDeductible: annualDeductible,
      deductibleFactor: deductibleFactor,
      annualLimit: annualLimit,
      annualLimitFactor: annualLimitFactor,
      requestedReimbursementPercent: requestedReimbursementPercent,
      requestedAnnualDeductible: requestedAnnualDeductible,
      requestedAnnualLimit: requestedAnnualLimit,
      wasCoerced: wasCoerced,
      coercionReasons: coercionReasons,
      addOnMonthlyLoads: addOnMonthlyLoads,
      premiumBeforeAddOns: premiumBeforeAddOns,
      addOnTotal: addOnTotal,
      minPremiumApplied: minApplied,
      finalMonthlyPremium: finalPremium,
    );
  }

  _RegionalAdjustment _getRegionalAdjustment(String? state, String zipCode) {
    // Try state first
    if (state != null && PricingConfig.regionalAdjustments.containsKey(state)) {
      return _RegionalAdjustment(key: state, multiplier: PricingConfig.regionalAdjustments[state]!);
    }

    // Check for high-cost zip codes (NYC example)
    if (_isHighCostZipCode(zipCode)) {
      return _RegionalAdjustment(key: 'NYC_ZIP', multiplier: PricingConfig.regionalAdjustments['NY']!);
    }

    // Default adjustment
    return _RegionalAdjustment(key: 'DEFAULT', multiplier: PricingConfig.regionalAdjustments['DEFAULT']!);
  }

  bool _isHighCostZipCode(String zipCode) {
    // NYC zip codes: 10001-10299, 11004-11109, etc.
    if (zipCode.startsWith('100') || zipCode.startsWith('101') || zipCode.startsWith('102')) {
      return true;
    }
    // Add more high-cost regions as needed
    return false;
  }

  double _getMultiPetDiscount(int numberOfPets) {
    if (numberOfPets >= 4) {
      return PricingConfig.multiPetDiscounts[4]!;
    }
    return PricingConfig.multiPetDiscounts[numberOfPets] ?? 0.0;
  }
  
  // Legacy plan generators removed in favor of buildPlan + ProductCatalog.
  
  /// Calculate annual cost for a plan
  double calculateAnnualCost(Plan plan) {
    return plan.monthlyPremium * 12;
  }
  
  /// Calculate estimated out-of-pocket cost for a claim
  double calculateOutOfPocket({
    required Plan plan,
    required double claimAmount,
  }) {
    // Amount after deductible
    final afterDeductible = (claimAmount - plan.annualDeductible).clamp(0.0, double.infinity);
    
    // Co-pay amount
    final coPayAmount = afterDeductible * (plan.coPayPercentage / 100);
    
    // Total out of pocket = deductible + co-pay
    return plan.annualDeductible + coPayAmount;
  }
  
  /// Calculate insurance coverage amount for a claim
  double calculateCoverageAmount({
    required Plan plan,
    required double claimAmount,
  }) {
    final outOfPocket = calculateOutOfPocket(
      plan: plan,
      claimAmount: claimAmount,
    );
    
    final coverage = (claimAmount - outOfPocket).clamp(0.0, plan.maxAnnualCoverage);
    return coverage;
  }
  
  /// Compare plans side by side
  PlanComparison comparePlans(List<Plan> plans) {
    return PlanComparison(
      plans: plans,
      scenarios: [
        ClaimScenario(
          description: 'Minor Illness (e.g., ear infection)',
          claimAmount: 500.0,
        ),
        ClaimScenario(
          description: 'Major Surgery (e.g., ACL repair)',
          claimAmount: 5000.0,
        ),
        ClaimScenario(
          description: 'Serious Emergency (e.g., hit by car)',
          claimAmount: 10000.0,
        ),
      ],
    );
  }
}

class _RegionalAdjustment {
  final String key;
  final double multiplier;

  const _RegionalAdjustment({
    required this.key,
    required this.multiplier,
  });
}

/// Insurance plan model
class Plan {
  final PlanType type;
  final String name;
  final String description;
  /// Internal: the base monthly premium (after risk/region/multipet) used for repricing.
  final double pricingBasePremium;
  final double monthlyPremium;
  final double annualDeductible;
  final double coPayPercentage; // 0-100
  final double maxAnnualCoverage;
  final bool isUnlimitedAnnualCoverage;
  final double? maxLifetimeCoverage;
  final int numberOfPets;
  final double multiPetDiscount; // 0.0-1.0
  final int reimbursementPercent;
  final List<String> selectedAddOns;
  final RiskLevel riskBand;
  final PricingBreakdown? pricingBreakdown;
  final Map<String, dynamic>? waitingPeriodsDays;
  final Map<String, dynamic>? policyRules;
  final List<String> features;
  final List<String> exclusions;
  
  Plan({
    required this.type,
    required this.name,
    required this.description,
    required this.pricingBasePremium,
    required this.monthlyPremium,
    required this.annualDeductible,
    required this.coPayPercentage,
    required this.maxAnnualCoverage,
    this.isUnlimitedAnnualCoverage = false,
    this.maxLifetimeCoverage,
    required this.numberOfPets,
    required this.multiPetDiscount,
    this.reimbursementPercent = 80,
    this.selectedAddOns = const [],
    this.riskBand = RiskLevel.medium,
    this.pricingBreakdown,
    this.waitingPeriodsDays,
    this.policyRules,
    required this.features,
    required this.exclusions,
  });
  
  double get annualPremium => monthlyPremium * 12;
  
  double get discountAmount {
    if (multiPetDiscount <= 0) return 0.0;
    if (multiPetDiscount >= 1) return monthlyPremium;
    return monthlyPremium / (1 - multiPetDiscount) * multiPetDiscount;
  }
  
  String get coveragePercentage => '${100 - coPayPercentage.toInt()}%';
  
  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'name': name,
      'description': description,
      'pricingBasePremium': pricingBasePremium,
      'monthlyPremium': monthlyPremium,
      'annualDeductible': annualDeductible,
      'coPayPercentage': coPayPercentage,
      'maxAnnualCoverage': isUnlimitedAnnualCoverage ? null : maxAnnualCoverage,
      'isUnlimitedAnnualCoverage': isUnlimitedAnnualCoverage,
      'maxLifetimeCoverage': maxLifetimeCoverage,
      'numberOfPets': numberOfPets,
      'multiPetDiscount': multiPetDiscount,
      'reimbursementPercent': reimbursementPercent,
      'selectedAddOns': selectedAddOns,
      'riskBand': riskBand.name,
      'pricingBreakdown': pricingBreakdown?.toJson(),
      'waitingPeriodsDays': waitingPeriodsDays,
      'policyRules': policyRules,
      'features': features,
      'exclusions': exclusions,
    };
  }
  
  factory Plan.fromJson(Map<String, dynamic> json) {
    final isUnlimited = json['isUnlimitedAnnualCoverage'] == true;
    final maxAnnualRaw = json['maxAnnualCoverage'];

    RiskLevel parseRiskBand(String? value) {
      final raw = (value ?? '').trim();
      for (final v in RiskLevel.values) {
        if (v.name == raw) return v;
        if ('RiskLevel.${v.name}' == raw) return v;
      }
      return RiskLevel.medium;
    }

    final pricingBreakdownRaw = json['pricingBreakdown'];
    final PricingBreakdown? pricingBreakdown = pricingBreakdownRaw is Map
        ? PricingBreakdown.fromJson(pricingBreakdownRaw.cast<String, dynamic>())
        : null;

    return Plan(
      type: PlanType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => PlanType.basic,
      ),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      pricingBasePremium: json['pricingBasePremium']?.toDouble() ?? (json['monthlyPremium']?.toDouble() ?? 0.0),
      monthlyPremium: json['monthlyPremium']?.toDouble() ?? 0.0,
      annualDeductible: json['annualDeductible']?.toDouble() ?? 0.0,
      coPayPercentage: json['coPayPercentage']?.toDouble() ?? 0.0,
      maxAnnualCoverage: isUnlimited
          ? double.infinity
          : (maxAnnualRaw is num ? maxAnnualRaw.toDouble() : 0.0),
      isUnlimitedAnnualCoverage: isUnlimited,
      maxLifetimeCoverage: json['maxLifetimeCoverage']?.toDouble(),
      numberOfPets: json['numberOfPets'] ?? 1,
      multiPetDiscount: json['multiPetDiscount']?.toDouble() ?? 0.0,
      reimbursementPercent: json['reimbursementPercent'] ?? (100 - (json['coPayPercentage'] ?? 20)).toInt(),
      selectedAddOns: List<String>.from(json['selectedAddOns'] ?? const []),
      riskBand: parseRiskBand(json['riskBand']?.toString()),
      pricingBreakdown: pricingBreakdown,
      waitingPeriodsDays: (json['waitingPeriodsDays'] as Map?)?.cast<String, dynamic>(),
      policyRules: (json['policyRules'] as Map?)?.cast<String, dynamic>(),
      features: List<String>.from(json['features'] ?? []),
      exclusions: List<String>.from(json['exclusions'] ?? []),
    );
  }
}

/// Claim scenario for comparison
class ClaimScenario {
  final String description;
  final double claimAmount;
  
  ClaimScenario({
    required this.description,
    required this.claimAmount,
  });
}

/// Plan comparison helper
class PlanComparison {
  final List<Plan> plans;
  final List<ClaimScenario> scenarios;
  
  PlanComparison({
    required this.plans,
    required this.scenarios,
  });
  
  /// Get coverage breakdown for a scenario
  Map<Plan, Map<String, double>> getCoverageBreakdown(ClaimScenario scenario) {
    final engine = QuoteEngine();
    final breakdown = <Plan, Map<String, double>>{};
    
    for (final plan in plans) {
      final outOfPocket = engine.calculateOutOfPocket(
        plan: plan,
        claimAmount: scenario.claimAmount,
      );
      
      final coverage = engine.calculateCoverageAmount(
        plan: plan,
        claimAmount: scenario.claimAmount,
      );
      
      breakdown[plan] = {
        'claimAmount': scenario.claimAmount,
        'deductible': plan.annualDeductible,
        'coPay': outOfPocket - plan.annualDeductible,
        'outOfPocket': outOfPocket,
        'coverage': coverage,
      };
    }
    
    return breakdown;
  }
}
