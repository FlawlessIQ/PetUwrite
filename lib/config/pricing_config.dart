import '../models/risk_score.dart';
import '../services/product_catalog.dart';

/// Single source of truth for pricing constants.
///
/// Constraints (from product requirements):
/// - Do not invent new pricing numbers.
/// - Centralize pricing constants here.
/// - Pricing must be deterministic and explainable.
class PricingConfig {
  /// Pricing config version (stamp into policy at bind time).
  static const String version = 'v_launch_growth_safe_2026_01';

  /// Effective date for this pricing config.
  ///
  /// Stored as an ISO string to remain `const` (and deterministic).
  static const String effectiveDateIso = '2026-01-11';

  /// Notes for internal review.
    static const String notes =
      'Launch growth-safe pricing: baseRiskRate × riskBandMultiplier × coverage relativities + add-on loads. '
      'Availability rules (max reimbursement / min deductible / limits) are enforced outside pricing math.';

  /// Base monthly risk rate (USD).
  ///
  /// Legacy source: QuoteEngine._basePrice.
  static const double baseRiskRate = 45.0;

  /// Legacy regional adjustment map (by state/zip code).
  ///
  /// Legacy source: QuoteEngine._regionalAdjustments.
  static const Map<String, double> regionalAdjustments = {
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

  /// Legacy multi-pet discount tiers.
  ///
  /// Legacy source: QuoteEngine._multiPetDiscounts.
  static const Map<int, double> multiPetDiscounts = {
    1: 0.0, // No discount for single pet
    2: 0.05, // 5% for 2 pets
    3: 0.10, // 10% for 3 pets
    4: 0.15, // 15% for 4+ pets
  };

  /// Risk band multipliers (dimensionless).
  static const Map<RiskLevel, double> riskBandMultipliers = {
    RiskLevel.low: 0.85,
    RiskLevel.medium: 1.00,
    RiskLevel.high: 1.40,
    RiskLevel.veryHigh: 1.90,
  };

  /// Coverage relativities: reimbursement percent (dimensionless).
  /// Legacy source: QuoteEngine.priceMonthlyPremium reimbursementFactor.
  static const Map<int, double> reimbursementFactors = {
    70: 0.90,
    80: 1.00,
    90: 1.15,
  };

  /// Coverage relativities: annual deductible (USD) → factor (dimensionless).
  /// Legacy source: QuoteEngine.priceMonthlyPremium deductibleFactor.
  static const Map<int, double> deductibleFactors = {
    100: 1.20,
    250: 1.05,
    500: 1.00,
    750: 0.93,
    1000: 0.88,
  };

  /// Coverage relativities: annual limit (USD) → factor (dimensionless).
  /// Use `null` to represent Unlimited.
  /// Legacy source: QuoteEngine.priceMonthlyPremium annualLimitFactor.
  static const Map<int?, double> annualLimitFactors = {
    5000: 0.90,
    10000: 1.00,
    15000: 1.12,
    20000: 1.25,
    null: 1.65, // Unlimited must be meaningfully higher.
  };

  /// Monthly loads for optional add-ons (USD).
  /// Legacy source: QuoteEngine.priceMonthlyPremium add-on fees.
  static const Map<AddOnType, double> addOnMonthlyLoads = {
    AddOnType.examFees: 5.0,
    AddOnType.wellnessLite: 8.0,
    AddOnType.wellnessPremium: 18.0,
    AddOnType.dentalPlus: 6.0,
    AddOnType.rehab: 5.0,
    AddOnType.behavioral: 4.0,
    AddOnType.prescriptionFood: 3.0,
  };

  /// Minimum monthly premium (USD).
  /// Legacy source: QuoteEngine.priceMonthlyPremium guardrail.
  static const double minMonthlyPremium = 10.0;

  /// Used when a factor key is not found.
  static const double defaultFactor = 1.0;

  static double riskBandMultiplierFor(RiskLevel riskLevel) {
    return riskBandMultipliers[riskLevel] ?? defaultFactor;
  }

  static double reimbursementFactorFor(int reimbursementPercent) {
    return reimbursementFactors[reimbursementPercent] ?? defaultFactor;
  }

  static double deductibleFactorFor(int annualDeductible) {
    return deductibleFactors[annualDeductible] ?? defaultFactor;
  }

  static double annualLimitFactorFor(int? annualLimit) {
    return annualLimitFactors[annualLimit] ?? defaultFactor;
  }

  static double addOnLoadFor(AddOnType addOn) {
    return addOnMonthlyLoads[addOn] ?? 0.0;
  }
}
