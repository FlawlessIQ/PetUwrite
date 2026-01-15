import '../models/evidence_requirement.dart';
import '../models/medical_condition_fact.dart';

/// Deterministically generates required evidence for self-serve underwriting.
///
/// This is intentionally conservative (fail-closed): if we cannot confirm a
/// condition safely, we request additional evidence instead of pricing.
class EvidenceRequirementsEngine {
  List<EvidenceRequirement> build({
    required List<MedicalConditionFact> medicalFacts,
    Set<String> ruleOutConditionCodes = const {},
    required bool medicalFactsRequired,
    required bool aiFailure,
  }) {
    final requirementsByCode = <String, EvidenceRequirement>{};

    void add(EvidenceRequirement r) {
      requirementsByCode.putIfAbsent(r.code, () => r);
    }

    if (aiFailure) {
      add(
        const EvidenceRequirement(
          code: 'REUPLOAD_CLEAR_VET_RECORDS',
          title: 'Re-upload clear vet records',
          details:
              'Upload a readable PDF or clear, well-lit photos of the full report (including diagnosis and assessment sections).',
        ),
      );
    }

    if (medicalFactsRequired && medicalFacts.isEmpty) {
      add(
        const EvidenceRequirement(
          code: 'PROVIDE_MEDICAL_HISTORY',
          title: 'Provide medical history records',
          details:
              'Upload vet records that list diagnoses, medications, and any relevant lab or imaging results.',
        ),
      );
    }

    for (final fact in medicalFacts) {
      final code = fact.conditionCode.trim().toUpperCase();
      final isRuleOut = ruleOutConditionCodes.contains(code);

      final isUncertain =
          fact.status == MedicalConditionStatus.suspected ||
          fact.status == MedicalConditionStatus.unknown;
      if (!isUncertain && !isRuleOut) continue;

      switch (code) {
        case 'HCM':
          add(
            const EvidenceRequirement(
              code: 'ECHO_REPORT',
              title: 'Echocardiogram report',
              details:
                  'Upload an echocardiogram (echo) report confirming or excluding HCM, ideally from a cardiologist.',
            ),
          );
          break;
        case 'CHF':
          add(
            const EvidenceRequirement(
              code: 'CARDIAC_WORKUP',
              title: 'Cardiac workup documentation',
              details:
                  'Upload cardiology notes and diagnostics (e.g., echo and chest radiographs) confirming or excluding CHF.',
            ),
          );
          break;
        case 'CKD_STAGE_3_PLUS':
          add(
            const EvidenceRequirement(
              code: 'RECENT_KIDNEY_LABS',
              title: 'Recent kidney labs (IRIS staging)',
              details:
                  'Upload recent bloodwork/urinalysis with IRIS staging or values sufficient to stage kidney disease.',
            ),
          );
          break;
        case 'ACTIVE_CANCER':
          add(
            const EvidenceRequirement(
              code: 'PATHOLOGY_REPORT',
              title: 'Pathology / biopsy report',
              details:
                  'Upload pathology/biopsy or oncology notes confirming whether cancer is present and its type/stage.',
            ),
          );
          break;
        default:
          add(
            EvidenceRequirement(
              code: 'VET_DIAGNOSIS_NOTE_$code',
              title: 'Veterinary diagnosis documentation',
              details:
                  'Upload documentation confirming whether "$code" is diagnosed and active (exam notes, discharge summary, or problem list).',
            ),
          );
      }
    }

    final sorted = requirementsByCode.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    return sorted;
  }
}
