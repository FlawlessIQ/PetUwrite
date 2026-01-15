import '../models/evidence_requirement.dart';
import '../models/risk_score.dart';
import 'integrity_gate_result.dart';

class RiskScoreSanityGuard {
  IntegrityGateResult check(RiskScore riskScore) {
    final score = riskScore.overallScore;

    if (score.isNaN || score.isInfinite || score < 0 || score > 100) {
      return const IntegrityGateResult.needMoreInfo(
        reason: 'RISK_SCORE_INVALID',
        requiredEvidence: [
          EvidenceRequirement(
            code: 'RISK_SCORE_RECALCULATE',
            title: 'Recalculate your quote',
            details:
                'We couldn\'t validate your risk score. Please restart the quote flow so we can recalculate it, then try again.',
          ),
        ],
      );
    }

    final expectedLevel = RiskScore.getRiskLevelFromScore(score);
    if (riskScore.riskLevel != expectedLevel) {
      return const IntegrityGateResult.needMoreInfo(
        reason: 'RISK_SCORE_MISMATCH',
        requiredEvidence: [
          EvidenceRequirement(
            code: 'RISK_SCORE_RECALCULATE',
            title: 'Recalculate your quote',
            details:
                'We need to recalculate your risk score before showing pricing. Please restart the quote flow and try again.',
          ),
        ],
      );
    }

    // Category scores should be bounded and non-negative (0-100).
    for (final entry in riskScore.categoryScores.entries) {
      final v = entry.value;
      if (v.isNaN || v.isInfinite || v < 0 || v > 100) {
        return IntegrityGateResult.needMoreInfo(
          reason: 'RISK_SCORE_CATEGORY_INVALID',
          requiredEvidence: [
            EvidenceRequirement(
              code: 'RISK_SCORE_RECALCULATE',
              title: 'Recalculate your quote',
              details:
                  'We couldn\'t validate the risk score component “${entry.key}”. Please restart the quote flow to recalculate.',
            ),
          ],
        );
      }
    }

    // Risk factors should be bounded.
    for (final f in riskScore.riskFactors) {
      final impact = f.impact;
      if (impact.isNaN || impact.isInfinite || impact < -100 || impact > 100) {
        return const IntegrityGateResult.needMoreInfo(
          reason: 'RISK_SCORE_FACTORS_INVALID',
          requiredEvidence: [
            EvidenceRequirement(
              code: 'RISK_SCORE_RECALCULATE',
              title: 'Recalculate your quote',
              details:
                  'We couldn\'t validate your risk factors. Please restart the quote flow and try again.',
            ),
          ],
        );
      }
    }

    return const IntegrityGateResult.pass();
  }
}
