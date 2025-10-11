import '../models/risk_score.dart';

/// Pricing engine for generating pet insurance quotes
/// Calculates premiums based on risk score, location, and plan type
class QuoteEngine {
  // Base pricing constants
  static const double _basePrice = 35.0;
  static const double _riskMultiplierFactor = 1.5;
  
  // Regional adjustment map (by state/zip code)
  static const Map<String, double> _regionalAdjustments = {
    // Major metro areas
    'NY': 1.10, // +10% for New York
    'CA': 1.08, // +8% for California
    'MA': 1.09, // +9% for Massachusetts
    'WA': 1.07, // +7% for Washington
    'IL': 1.06, // +6% for Illinois
    'TX': 1.02, // +2% for Texas
    'FL': 1.03, // +3% for Florida
    // Default for other states
    'DEFAULT': 1.0,
  };
  
  // Multi-pet discount tiers
  static const Map<int, double> _multiPetDiscounts = {
    1: 0.0,    // No discount for single pet
    2: 0.05,   // 5% for 2 pets
    3: 0.10,   // 10% for 3 pets
    4: 0.15,   // 15% for 4+ pets
  };
  
  /// Generate quote with 3 plan options
  /// Returns List of [Plan] objects (Basic, Plus, Elite)
  List<Plan> generateQuote({
    required RiskScore riskScore,
    required String zipCode,
    int numberOfPets = 1,
    String? state,
  }) {
    // Calculate base premium with risk and regional adjustments
    final basePremium = _calculateBasePremium(
      riskScore: riskScore,
      zipCode: zipCode,
      state: state,
    );
    
    // Apply multi-pet discount
    final discountMultiplier = _getMultiPetDiscount(numberOfPets);
    final discountedPremium = basePremium * (1 - discountMultiplier);
    
    // Generate 3 plan tiers
    return [
      _generateBasicPlan(discountedPremium, numberOfPets, discountMultiplier),
      _generatePlusPlan(discountedPremium, numberOfPets, discountMultiplier),
      _generateElitePlan(discountedPremium, numberOfPets, discountMultiplier),
    ];
  }
  
  /// Calculate base premium before plan-specific adjustments
  double _calculateBasePremium({
    required RiskScore riskScore,
    required String zipCode,
    String? state,
  }) {
    // Step 1: Start with base price
    double premium = _basePrice;
    
    // Step 2: Apply risk multiplier (score/100 × 1.5)
    final riskMultiplier = (riskScore.overallScore / 100) * _riskMultiplierFactor;
    premium *= (1 + riskMultiplier);
    
    // Step 3: Apply regional adjustment
    final regionalMultiplier = _getRegionalAdjustment(state, zipCode);
    premium *= regionalMultiplier;
    
    return premium;
  }
  
  /// Get regional pricing adjustment based on state or zip code
  double _getRegionalAdjustment(String? state, String zipCode) {
    // Try state first
    if (state != null && _regionalAdjustments.containsKey(state)) {
      return _regionalAdjustments[state]!;
    }
    
    // Check for high-cost zip codes (NYC example)
    if (_isHighCostZipCode(zipCode)) {
      return _regionalAdjustments['NY']!;
    }
    
    // Default adjustment
    return _regionalAdjustments['DEFAULT']!;
  }
  
  /// Check if zip code is in high-cost area
  bool _isHighCostZipCode(String zipCode) {
    // NYC zip codes: 10001-10299, 11004-11109, etc.
    if (zipCode.startsWith('100') || zipCode.startsWith('101') || zipCode.startsWith('102')) {
      return true;
    }
    // Add more high-cost regions as needed
    return false;
  }
  
  /// Get multi-pet discount multiplier
  double _getMultiPetDiscount(int numberOfPets) {
    if (numberOfPets >= 4) {
      return _multiPetDiscounts[4]!;
    }
    return _multiPetDiscounts[numberOfPets] ?? 0.0;
  }
  
  /// Generate Basic plan
  Plan _generateBasicPlan(
    double basePremium,
    int numberOfPets,
    double discount,
  ) {
    return Plan(
      type: PlanType.basic,
      name: 'Basic Coverage',
      description: 'Essential protection for accidents and illnesses',
      monthlyPremium: basePremium * 0.85, // 85% of base
      annualDeductible: 500.0,
      coPayPercentage: 20.0,
      maxAnnualCoverage: 10000.0,
      maxLifetimeCoverage: null, // No lifetime limit
      numberOfPets: numberOfPets,
      multiPetDiscount: discount,
      features: [
        'Accidents & Illnesses',
        'Emergency Care',
        'Hospitalization',
        'Surgery',
        'Prescription Medications',
        '24/7 Vet Helpline',
      ],
      exclusions: [
        'Pre-existing conditions',
        'Wellness care',
        'Dental cleaning',
        'Breeding costs',
      ],
    );
  }
  
  /// Generate Plus plan
  Plan _generatePlusPlan(
    double basePremium,
    int numberOfPets,
    double discount,
  ) {
    return Plan(
      type: PlanType.plus,
      name: 'Plus Coverage',
      description: 'Comprehensive protection with wellness benefits',
      monthlyPremium: basePremium * 1.15, // 115% of base
      annualDeductible: 250.0,
      coPayPercentage: 10.0,
      maxAnnualCoverage: 15000.0,
      maxLifetimeCoverage: null,
      numberOfPets: numberOfPets,
      multiPetDiscount: discount,
      features: [
        'Everything in Basic',
        'Wellness Care (up to \$250/year)',
        'Dental Accidents & Disease',
        'Alternative Therapies',
        'Behavioral Therapy',
        'Hereditary Conditions',
        'Chronic Conditions',
        'Cancer Coverage',
      ],
      exclusions: [
        'Pre-existing conditions',
        'Cosmetic procedures',
        'Breeding costs',
      ],
    );
  }
  
  /// Generate Elite plan
  Plan _generateElitePlan(
    double basePremium,
    int numberOfPets,
    double discount,
  ) {
    return Plan(
      type: PlanType.elite,
      name: 'Elite Coverage',
      description: 'Ultimate protection with maximum benefits',
      monthlyPremium: basePremium * 1.5, // 150% of base
      annualDeductible: 100.0,
      coPayPercentage: 0.0, // 100% coverage
      maxAnnualCoverage: 25000.0,
      maxLifetimeCoverage: null,
      numberOfPets: numberOfPets,
      multiPetDiscount: discount,
      features: [
        'Everything in Plus',
        'Enhanced Wellness Care (up to \$500/year)',
        'Dental Cleaning & Preventive',
        'Exam Fees Covered',
        'Unlimited Vet Visits',
        'Specialty & Emergency Care',
        'Physical Therapy',
        'End of Life Care',
        'Cremation/Burial (up to \$1,000)',
        'Travel Protection',
        'Lost Pet Recovery',
      ],
      exclusions: [
        'Pre-existing conditions (partial coverage after 1 year)',
        'Breeding/Pregnancy',
      ],
    );
  }
  
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

/// Plan type enumeration
enum PlanType {
  basic,
  plus,
  elite,
}

/// Insurance plan model
class Plan {
  final PlanType type;
  final String name;
  final String description;
  final double monthlyPremium;
  final double annualDeductible;
  final double coPayPercentage; // 0-100
  final double maxAnnualCoverage;
  final double? maxLifetimeCoverage;
  final int numberOfPets;
  final double multiPetDiscount; // 0.0-1.0
  final List<String> features;
  final List<String> exclusions;
  
  Plan({
    required this.type,
    required this.name,
    required this.description,
    required this.monthlyPremium,
    required this.annualDeductible,
    required this.coPayPercentage,
    required this.maxAnnualCoverage,
    this.maxLifetimeCoverage,
    required this.numberOfPets,
    required this.multiPetDiscount,
    required this.features,
    required this.exclusions,
  });
  
  double get annualPremium => monthlyPremium * 12;
  
  double get discountAmount => monthlyPremium / (1 - multiPetDiscount) * multiPetDiscount;
  
  String get coveragePercentage => '${100 - coPayPercentage.toInt()}%';
  
  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'name': name,
      'description': description,
      'monthlyPremium': monthlyPremium,
      'annualDeductible': annualDeductible,
      'coPayPercentage': coPayPercentage,
      'maxAnnualCoverage': maxAnnualCoverage,
      'maxLifetimeCoverage': maxLifetimeCoverage,
      'numberOfPets': numberOfPets,
      'multiPetDiscount': multiPetDiscount,
      'features': features,
      'exclusions': exclusions,
    };
  }
  
  factory Plan.fromJson(Map<String, dynamic> json) {
    return Plan(
      type: PlanType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => PlanType.basic,
      ),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      monthlyPremium: json['monthlyPremium']?.toDouble() ?? 0.0,
      annualDeductible: json['annualDeductible']?.toDouble() ?? 0.0,
      coPayPercentage: json['coPayPercentage']?.toDouble() ?? 0.0,
      maxAnnualCoverage: json['maxAnnualCoverage']?.toDouble() ?? 0.0,
      maxLifetimeCoverage: json['maxLifetimeCoverage']?.toDouble(),
      numberOfPets: json['numberOfPets'] ?? 1,
      multiPetDiscount: json['multiPetDiscount']?.toDouble() ?? 0.0,
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
