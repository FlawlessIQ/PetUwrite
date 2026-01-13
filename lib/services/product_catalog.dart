// Intentionally does not import QuoteEngine to avoid import cycles.

import '../models/risk_score.dart';

/// Market-aligned product catalog (carrier-agnostic).
///
/// Notes:
/// - This defines *what we sell* (tiers, levers, add-ons, policy rules).
/// - Pricing is implemented in [QuoteEngine] as multipliers/fees.
/// - Coverage wording here is UX-oriented and not policy language.
class ProductCatalog {
  static const List<int> reimbursementOptions = [70, 80, 90];

  /// Annual deductible options (USD).
  static const List<int> annualDeductibleOptions = [100, 250, 500, 750, 1000];

  /// Annual limit options (USD). Use `null` to represent Unlimited.
  static const List<int?> annualLimitOptions = [5000, 10000, 15000, 20000, null];

  /// Availability matrix: max reimbursement (%) by risk band.
  static int maxReimbursementPercentFor(RiskLevel riskBand) {
    return switch (riskBand) {
      RiskLevel.veryHigh => 70,
      RiskLevel.high => 80,
      _ => 90,
    };
  }

  /// Availability matrix: min annual deductible (USD) by risk band.
  static int minAnnualDeductibleFor(RiskLevel riskBand) {
    return switch (riskBand) {
      RiskLevel.veryHigh => 500,
      RiskLevel.high => 250,
      _ => 100,
    };
  }

  /// Availability matrix: finite annual limits (USD) by risk band.
  static List<int> finiteAnnualLimitOptionsFor(RiskLevel riskBand) {
    return switch (riskBand) {
      RiskLevel.veryHigh => const [5000, 10000],
      RiskLevel.high => const [5000, 10000, 15000],
      _ => const [5000, 10000, 15000, 20000],
    };
  }

  /// Launch constraint: Unlimited is only offered for lower-risk, younger pets.
  ///
  /// If `ageYears` is unknown, this conservatively hides Unlimited.
  static bool allowUnlimitedAnnualLimit({
    required RiskLevel riskBand,
    required int? ageYears,
  }) {
    return ageYears != null &&
        ageYears <= 7 &&
        (riskBand == RiskLevel.low || riskBand == RiskLevel.medium);
  }

  /// Reimbursement options (%) available to a given pet.
  static List<int> reimbursementOptionsFor({required RiskLevel riskBand}) {
    final maxAllowed = maxReimbursementPercentFor(riskBand);
    return reimbursementOptions.where((v) => v <= maxAllowed).toList(growable: false);
  }

  /// Annual deductible options (USD) available to a given pet.
  static List<int> annualDeductibleOptionsFor({required RiskLevel riskBand}) {
    final minAllowed = minAnnualDeductibleFor(riskBand);
    return annualDeductibleOptions.where((v) => v >= minAllowed).toList(growable: false);
  }

  /// Annual limit options (USD) available to a given pet.
  static List<int?> annualLimitOptionsFor({
    required RiskLevel riskBand,
    required int? ageYears,
  }) {
    final finite = finiteAnnualLimitOptionsFor(riskBand);
    final allowUnlimited = allowUnlimitedAnnualLimit(riskBand: riskBand, ageYears: ageYears);

    return <int?>[
      ...finite,
      if (allowUnlimited) null,
    ];
  }

  static bool isCoverageAllowed({
    required RiskLevel riskBand,
    required int? ageYears,
    required int reimbursementPercent,
    required int annualDeductible,
    required int? annualLimit,
  }) {
    if (reimbursementPercent > maxReimbursementPercentFor(riskBand)) return false;
    if (annualDeductible < minAnnualDeductibleFor(riskBand)) return false;

    if (annualLimit == null) {
      return allowUnlimitedAnnualLimit(riskBand: riskBand, ageYears: ageYears);
    }
    return finiteAnnualLimitOptionsFor(riskBand).contains(annualLimit);
  }

  /// Waiting periods (days) – market-standard defaults.
  static const Map<String, int> defaultWaitingPeriodsDays = {
    'accident': 3,
    'illness': 14,
    // Orthopedic/Cruciate is commonly longer; waiver may apply with vet exam.
    'orthopedic': 180,
  };

  /// Optional: waiver rule (UX-facing).
  static const Map<String, dynamic> orthopedicWaiverRule = {
    'eligible': true,
    'requiresVetExam': true,
    'noPriorSymptomsRequired': true,
    'waivedOrthopedicDays': 30,
  };

  /// Curable pre-existing rule (UX-facing). Carrier-dependent.
  static const Map<String, dynamic> curablePreExistingRule = {
    'supported': true,
    'monthsSymptomFreeRequired': 12,
    'requiresVetRecords': true,
    'chronicAlwaysExcludedExamples': [
      'diabetes',
      'cushing\'s disease',
      'chronic kidney disease',
      'epilepsy',
    ],
  };

  static List<String> includedFeaturesForTier(PlanType tier) {
    switch (tier) {
      case PlanType.basic:
        return const [
          'Accidents & illnesses',
          'Emergency care',
          'Hospitalization',
          'Surgery',
          'Diagnostics (x-rays, labs)',
          'Prescription medications',
          'Specialist care',
          'Hereditary & congenital (not pre-existing)',
          'Cancer coverage',
          '24/7 vet helpline',
        ];
      case PlanType.standard:
        return const [
          'Everything in Basic',
          'Exam fees covered',
          'Dental illness (with limits)',
          'Rehab/physical therapy (with limits)',
          'Behavioral therapy (with limits)',
          'Alternative therapies (with limits)',
          'End-of-life care allowance',
        ];
      case PlanType.plus:
        return const [
          'Everything in Standard',
          'Higher annual limits',
          'Higher sublimits for dental/rehab/behavioral',
          'Travel/boarding (owner hospitalized) (with limits)',
          'Priority claims experience (UX goal)',
        ];
      case PlanType.premium:
        return const [
          'Everything in Plus',
          'Highest reimbursement options',
          'Higher annual limits',
          'Enhanced claims experience (UX goal)',
        ];
      case PlanType.unlimited:
        return const [
          'Everything in Plus',
          'Unlimited annual limit',
          'Enhanced claims experience (UX goal)',
        ];
    }
  }

  static List<String> baseExclusions() {
    return const [
      'Pre-existing conditions (see curable rule if offered)',
      'Routine wellness (unless added)',
      'Breeding, pregnancy, and whelping',
      'Cosmetic procedures',
    ];
  }
}

/// Plan tiers are presets only (pricing is driven by levers + risk band).
enum PlanType {
  basic,
  standard,
  plus,
  premium,
  unlimited,
}

enum AddOnType {
  examFees,
  wellnessLite,
  wellnessPremium,
  dentalPlus,
  rehab,
  behavioral,
  prescriptionFood,
}

class AddOn {
  final AddOnType type;
  final String name;
  final String description;

  const AddOn({
    required this.type,
    required this.name,
    required this.description,
  });

  static const List<AddOn> all = [
    AddOn(
      type: AddOnType.examFees,
      name: 'Exam Fees',
      description: 'Covers eligible exam fees for covered claims.',
    ),
    AddOn(
      type: AddOnType.wellnessLite,
      name: 'Wellness Lite',
      description: 'Annual allowance for preventive care (vaccines, checkups).',
    ),
    AddOn(
      type: AddOnType.wellnessPremium,
      name: 'Wellness Premium',
      description: 'Higher annual allowance for preventive care + dental cleaning.',
    ),
    AddOn(
      type: AddOnType.dentalPlus,
      name: 'Dental Plus',
      description: 'Expanded dental illness coverage (with sublimits).',
    ),
    AddOn(
      type: AddOnType.rehab,
      name: 'Rehab & Physio',
      description: 'Physical therapy, rehab, chiropractic, acupuncture (with limits).',
    ),
    AddOn(
      type: AddOnType.behavioral,
      name: 'Behavioral Therapy',
      description: 'Behavioral consults and therapy (with limits).',
    ),
    AddOn(
      type: AddOnType.prescriptionFood,
      name: 'Prescription Food',
      description: 'Eligible prescription diets tied to a covered condition (with limits).',
    ),
  ];
}
