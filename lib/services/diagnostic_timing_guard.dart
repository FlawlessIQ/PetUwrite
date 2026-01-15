import '../models/evidence_requirement.dart';
import 'integrity_gate_result.dart';
import 'vet_history_parser.dart';

class DiagnosticTimingGuard {
  static const int staleRecordMaxDays = 730; // ~24 months

  IntegrityGateResult check({
    required List<VetRecordData> aiVetExtraction,
    required List<String> rawVetTexts,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();

    final pendingPhrases = _containsPendingDiagnostics(rawVetTexts);

    final mostRecent = _mostRecentDate(aiVetExtraction);
    if (mostRecent == null) {
      // If they uploaded a record but we cannot determine recency, fail closed.
      if (rawVetTexts.any((t) => t.trim().isNotEmpty) || aiVetExtraction.isNotEmpty) {
        return const IntegrityGateResult.needMoreInfo(
          reason: 'VET_RECORD_DATE_MISSING',
          requiredEvidence: [
            EvidenceRequirement(
              code: 'RECENT_VET_RECORD',
              title: 'Upload a record with a visit date',
              details:
                  'Please upload a veterinary record that clearly shows the visit date (e.g., an invoice/soap note with a date header).',
            ),
          ],
        );
      }

      return const IntegrityGateResult.pass();
    }

    final ageDays = referenceNow.difference(mostRecent).inDays;
    if (ageDays > staleRecordMaxDays) {
      return const IntegrityGateResult.needMoreInfo(
        reason: 'VET_RECORD_TOO_OLD',
        requiredEvidence: [
          EvidenceRequirement(
            code: 'RECENT_VET_RECORD',
            title: 'Upload a more recent vet record',
            details:
                'Please upload a more recent veterinary record (within the last 24 months) so we can complete underwriting.',
          ),
        ],
      );
    }

    if (pendingPhrases) {
      return const IntegrityGateResult.needMoreInfo(
        reason: 'DIAGNOSTIC_RESULTS_PENDING',
        requiredEvidence: [
          EvidenceRequirement(
            code: 'DIAGNOSTIC_RESULTS',
            title: 'Upload final diagnostic results',
            details:
                'Your records suggest test results are pending. Please upload the final results (lab report, imaging report, pathology, or specialist report) so we can complete underwriting.',
          ),
        ],
      );
    }

    return const IntegrityGateResult.pass();
  }

  DateTime? _mostRecentDate(List<VetRecordData> records) {
    DateTime? best;
    void consider(DateTime? d) {
      if (d == null) return;
      if (best == null || d.isAfter(best!)) best = d;
    }

    for (final r in records) {
      consider(r.lastCheckup);
      for (final d in r.diagnoses) {
        consider(d.date);
      }
      for (final t in r.treatments) {
        consider(t.date);
      }
      for (final s in r.surgeries) {
        consider(s.date);
      }
      for (final m in r.medications) {
        consider(m.startDate);
        consider(m.endDate);
      }
      for (final v in r.vaccinations) {
        consider(v.date);
        consider(v.expiryDate);
      }
    }

    return best;
  }

  bool _containsPendingDiagnostics(List<String> rawVetTexts) {
    for (final raw in rawVetTexts) {
      final t = raw.toLowerCase();
      if (t.trim().isEmpty) continue;

      if (RegExp(
        r'\b(pending|awaiting\s+results|results\s+pending|send\s*out|sent\s+out|biopsy\s+pending|pathology\s+pending|culture\s+pending|labs?\s+pending|recheck\s+pending)\b',
      ).hasMatch(t)) {
        return true;
      }
    }
    return false;
  }
}
