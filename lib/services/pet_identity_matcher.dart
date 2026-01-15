import '../models/evidence_requirement.dart';
import '../models/pet.dart';
import 'integrity_gate_result.dart';

class PetIdentityMatcher {
  IntegrityGateResult check({
    required Pet pet,
    required List<String> rawVetTexts,
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();

    if (rawVetTexts.isEmpty) return const IntegrityGateResult.pass();

    final extractedSpecies = _extractSpecies(rawVetTexts);
    if (extractedSpecies != null) {
      final petSpecies = pet.species.trim().toLowerCase();
      if (petSpecies.isNotEmpty && petSpecies != extractedSpecies) {
        // Hard mismatch => deterministic decline.
        return const IntegrityGateResult.decline(
          reason: 'PET_IDENTITY_SPECIES_MISMATCH',
        );
      }
    }

    final extractedName = _extractPetName(rawVetTexts);
    if (extractedName != null) {
      final petName = pet.name.trim();
      if (petName.isNotEmpty) {
        final ok = _namesRoughlyMatch(petName, extractedName);
        if (!ok) {
          return IntegrityGateResult.needMoreInfo(
            reason: 'PET_IDENTITY_NAME_MISMATCH',
            requiredEvidence: [
              EvidenceRequirement(
                code: 'PET_IDENTITY_CONFIRMATION',
                title: 'Upload a record showing your pet\'s name',
                details:
                    'Please upload a veterinary record page that clearly shows your pet\'s name and the clinic header so we can match the record to your application.',
              ),
            ],
          );
        }
      }
    }

    final extractedAgeYears = _extractAgeYears(rawVetTexts, referenceNow);
    if (extractedAgeYears != null) {
      final petAgeYears = _ageYears(pet.dateOfBirth, referenceNow);
      final diff = (petAgeYears - extractedAgeYears).abs();
      if (diff >= 2) {
        return const IntegrityGateResult.needMoreInfo(
          reason: 'PET_IDENTITY_AGE_MISMATCH',
          requiredEvidence: [
            EvidenceRequirement(
              code: 'PET_IDENTITY_CONFIRMATION',
              title: 'Upload a record showing DOB/age',
              details:
                  'Please upload a record page that clearly shows your pet\'s DOB or age so we can confirm identity.',
            ),
          ],
        );
      }
    }

    return const IntegrityGateResult.pass();
  }

  String? _extractSpecies(List<String> rawVetTexts) {
    for (final raw in rawVetTexts) {
      final t = raw.toLowerCase();
      if (t.trim().isEmpty) continue;

      // Strong signals.
      if (RegExp(r'\b(species\s*[:\-]\s*cat|feline)\b').hasMatch(t) ||
          RegExp(r'\bcat\b').hasMatch(t) && RegExp(r'\bfeline\b').hasMatch(t)) {
        return 'cat';
      }
      if (RegExp(r'\b(species\s*[:\-]\s*dog|canine)\b').hasMatch(t) ||
          RegExp(r'\bdog\b').hasMatch(t) && RegExp(r'\bcanine\b').hasMatch(t)) {
        return 'dog';
      }

      // Weaker signals: standalone canine/feline.
      if (RegExp(r'\bfeline\b').hasMatch(t)) return 'cat';
      if (RegExp(r'\bcanine\b').hasMatch(t)) return 'dog';
    }

    return null;
  }

  String? _extractPetName(List<String> rawVetTexts) {
    for (final raw in rawVetTexts) {
      final lines = raw.split(RegExp(r'[\r\n]+'));
      for (final line in lines) {
        final m = RegExp(
          r"\b(patient|pet\s*name|name)\s*[:\-]\s*([A-Za-z][A-Za-z'\- ]{1,30})\b",
          caseSensitive: false,
        ).firstMatch(line);
        if (m != null) {
          final candidate = (m.group(2) ?? '').trim();
          if (candidate.isNotEmpty) return candidate;
        }
      }
    }
    return null;
  }

  int? _extractAgeYears(List<String> rawVetTexts, DateTime now) {
    for (final raw in rawVetTexts) {
      final t = raw.toLowerCase();
      final m = RegExp(r'\bage\s*[:\-]\s*(\d{1,2})\s*(years|yrs|y)\b').firstMatch(t);
      if (m != null) {
        final v = int.tryParse(m.group(1) ?? '');
        if (v != null) return v;
      }

      // If DOB exists, we can compute an approximate age.
      final dob = _extractDob(raw);
      if (dob != null) {
        final age = _ageYears(dob, now);
        return age;
      }
    }
    return null;
  }

  DateTime? _extractDob(String raw) {
    // Very conservative: only accept clear DOB markers.
    final m = RegExp(
      r'\b(dob|date\s*of\s*birth)\s*[:\-]\s*(\d{4}[\-/]\d{2}[\-/]\d{2})\b',
      caseSensitive: false,
    ).firstMatch(raw);
    if (m == null) return null;

    final s = (m.group(2) ?? '').replaceAll('/', '-');
    return DateTime.tryParse(s);
  }

  int _ageYears(DateTime dob, DateTime now) {
    var years = now.year - dob.year;
    final beforeBirthday =
        (now.month < dob.month) || (now.month == dob.month && now.day < dob.day);
    if (beforeBirthday) years -= 1;
    if (years < 0) years = 0;
    return years;
  }

  bool _namesRoughlyMatch(String a, String b) {
    final na = _normalize(a);
    final nb = _normalize(b);
    if (na.isEmpty || nb.isEmpty) return true;
    if (na == nb) return true;
    if (na.contains(nb) || nb.contains(na)) return true;

    final d = _levenshtein(na, nb);
    final maxLen = na.length > nb.length ? na.length : nb.length;
    // Allow small typos.
    if (maxLen <= 5) return d <= 1;
    if (maxLen <= 10) return d <= 2;
    return d <= 3;
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z]"), '')
        .trim();
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final m = s.length;
    final n = t.length;
    final prev = List<int>.generate(n + 1, (j) => j);
    final curr = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = s.codeUnitAt(i - 1) == t.codeUnitAt(j - 1) ? 0 : 1;
        final del = prev[j] + 1;
        final ins = curr[j - 1] + 1;
        final sub = prev[j - 1] + cost;
        curr[j] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
      }
      for (var j = 0; j <= n; j++) {
        prev[j] = curr[j];
      }
    }

    return prev[n];
  }
}
