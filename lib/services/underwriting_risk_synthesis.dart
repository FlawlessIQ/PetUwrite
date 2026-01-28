import '../models/anomaly_flag.dart';

/// Pure functions to synthesize underwriting risk.
///
/// Why this exists:
/// - Keeps the non-linear, deterministic guardrails testable without Firestore/AI.
/// - Separates "physiological risk" from "input credibility risk".
class UnderwritingRiskSynthesis {
  /// Produces a final 0-100 score from:
  /// - physiologicalRiskScore: traditional actuarial/medical scoring (0-100)
  /// - credibilityRiskScore: deterministic anomaly-based scoring (0-100)
  /// - riskMultiplier: non-linear multiplier from anomaly severity
  ///
  /// Design intent:
  /// - Biological implausibility should increase pricing more than mere rarity.
  /// - Edge cases remain possible, but become lower-confidence and higher review.
  static double synthesizeFinalScore({
    required double physiologicalRiskScore,
    required double credibilityRiskScore,
    required double riskMultiplier,
    required List<AnomalyFlag> anomalyFindings,
  }) {
    final phys = physiologicalRiskScore.clamp(0.0, 100.0);
    final cred = credibilityRiskScore.clamp(0.0, 100.0);

    // Weighted synthesis: physiological dominates, credibility is a separate
    // parallel track that can still materially move the final outcome.
    final weighted = (phys * 0.78) + (cred * 0.22);

    // Additional non-linear uplift for critical implausibility.
    final hasCritical = anomalyFindings.any(
      (f) => f.severity == AnomalySeverity.critical,
    );

    final multiplier = riskMultiplier.clamp(1.0, 2.5);
    final uplift = hasCritical ? (multiplier - 1.0) * 35.0 : (multiplier - 1.0) * 18.0;

    return (weighted + uplift).clamp(0.0, 100.0);
  }
}
