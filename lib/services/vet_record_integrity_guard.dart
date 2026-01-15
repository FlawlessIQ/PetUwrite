import '../models/evidence_requirement.dart';
import 'integrity_gate_result.dart';

class VetRecordIntegrityGuard {
  static const Set<String> freeEmailDomains = {
    'gmail.com',
    'yahoo.com',
    'outlook.com',
    'hotmail.com',
    'icloud.com',
    'aol.com',
    'proton.me',
    'protonmail.com',
  };

  IntegrityGateResult check({required List<String> rawVetTexts}) {
    if (rawVetTexts.isEmpty) return const IntegrityGateResult.pass();

    final joined = rawVetTexts.join('\n');
    final t = joined.toLowerCase();

    // Basic clinic header / contact presence heuristic.
    final hasClinicSignal = RegExp(
      r'\b(veterinary|animal\s+hospital|vet\s+clinic|clinic|hospital|dvm|vmd|phone|fax|address|www\.|http)\b',
    ).hasMatch(t);

    final emails = _extractEmails(joined);
    final hasPhone = RegExp(
      r'\b\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b',
    ).hasMatch(t);

    // If there are no clear clinic/contact signals, fail closed.
    if (!hasClinicSignal && emails.isEmpty && !hasPhone) {
      return const IntegrityGateResult.needMoreInfo(
        reason: 'VET_RECORD_INTEGRITY_INSUFFICIENT_HEADER',
        requiredEvidence: [
          EvidenceRequirement(
            code: 'VET_RECORD_WITH_CLINIC_HEADER',
            title: 'Upload a vet record with clinic header',
            details:
                'Please upload a record page that includes the clinic header/contact info (clinic name, phone/address) so we can validate the document source.',
          ),
        ],
      );
    }

    // Free-email domain check (soft fail -> need more info).
    for (final email in emails) {
      final domain = email.split('@').last.toLowerCase();
      if (freeEmailDomains.contains(domain)) {
        return const IntegrityGateResult.needMoreInfo(
          reason: 'VET_RECORD_FREE_EMAIL_DETECTED',
          requiredEvidence: [
            EvidenceRequirement(
              code: 'VET_RECORD_OFFICIAL_CONTACT',
              title: 'Upload an official clinic record',
              details:
                  'Your record appears to include a free email address. Please upload an official clinic record (clinic letterhead, invoice, or SOAP note) that includes the clinic contact details.',
            ),
          ],
        );
      }
    }

    return const IntegrityGateResult.pass();
  }

  List<String> _extractEmails(String raw) {
    final matches = RegExp(
      r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
    ).allMatches(raw);

    final out = <String>{};
    for (final m in matches) {
      final s = m.group(0);
      if (s == null) continue;
      out.add(s.trim());
    }

    return out.toList();
  }
}
