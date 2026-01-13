/// Lightweight breed size guide used for UX validation.
///
/// Goal: catch obvious mismatches (e.g., Irish Wolfhound at 20lbs) without
/// blocking legitimate edge cases.
class BreedSizeGuide {
  /// Returns an expected adult weight range in pounds for common breeds.
  ///
  /// Notes:
  /// - This is intentionally conservative and incomplete.
  /// - Mixed/unknown breeds return null.
  static ({double minLbs, double maxLbs})? expectedAdultWeightLbs(String? breedRaw) {
    final breed = _normalize(breedRaw);
    if (breed == null) return null;

    // Avoid overconfident validation for mixed breeds.
    if (breed.contains('mixed')) return null;

    // Giant breeds
    if (_matches(breed, ['irish wolfhound'])) return (minLbs: 100, maxLbs: 180);
    if (_matches(breed, ['great dane'])) return (minLbs: 100, maxLbs: 200);
    if (_matches(breed, ['mastiff', 'english mastiff'])) return (minLbs: 120, maxLbs: 230);
    if (_matches(breed, ['saint bernard', 'st bernard'])) return (minLbs: 120, maxLbs: 200);
    if (_matches(breed, ['newfoundland'])) return (minLbs: 100, maxLbs: 150);

    // Large breeds
    if (_matches(breed, ['german shepherd', 'gsd'])) return (minLbs: 50, maxLbs: 90);
    if (_matches(breed, ['golden retriever'])) return (minLbs: 55, maxLbs: 85);
    if (_matches(breed, ['labrador retriever', 'labrador'])) return (minLbs: 55, maxLbs: 90);
    if (_matches(breed, ['rottweiler'])) return (minLbs: 80, maxLbs: 135);
    if (_matches(breed, ['boxer'])) return (minLbs: 50, maxLbs: 80);
    if (_matches(breed, ['doberman', 'doberman pinscher'])) return (minLbs: 65, maxLbs: 100);
    if (_matches(breed, ['siberian husky', 'husky'])) return (minLbs: 35, maxLbs: 60);

    // Medium/small (a few common ones)
    if (_matches(breed, ['beagle'])) return (minLbs: 18, maxLbs: 30);
    if (_matches(breed, ['dachshund'])) return (minLbs: 11, maxLbs: 32);
    if (_matches(breed, ['chihuahua'])) return (minLbs: 3, maxLbs: 8);
    if (_matches(breed, ['poodle'])) return (minLbs: 8, maxLbs: 70); // highly variable

    // Cats (breed-specific weights are less useful here)
    return null;
  }

  static String? _normalize(String? input) {
    final raw = input?.trim();
    if (raw == null || raw.isEmpty) return null;

    var s = raw.toLowerCase();
    s = s.replaceAll(RegExp(r'[^a-z\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.isEmpty ? null : s;
  }

  static bool _matches(String normalizedBreed, List<String> needles) {
    for (final needle in needles) {
      final n = needle.toLowerCase();
      if (normalizedBreed.contains(n)) return true;
    }
    return false;
  }
}
