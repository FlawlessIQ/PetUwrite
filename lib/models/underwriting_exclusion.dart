enum UnderwritingExclusionType {
  preExisting,
  congenital,
  anomalyDerived,
  breedLinked,
}

enum UnderwritingExclusionEffectiveAt { bind, postBind }

/// Structured underwriting exclusion.
///
/// This is intentionally separate from [PolicyExclusion] (which represents
/// bound-policy exclusions) so we can capture underwriting intent + triggers.
class UnderwritingExclusion {
  final UnderwritingExclusionType type;

  /// Coverage scope being excluded (e.g., orthopedic, respiratory, hereditary).
  final String scope;

  /// Deterministic trigger source (rule id or anomaly finding id).
  final String triggerReason;

  /// When the exclusion becomes effective.
  final UnderwritingExclusionEffectiveAt effectiveAt;

  /// Whether an audited exception control can remove this exclusion.
  final bool reviewable;

  /// Plain-language explanation suitable for customer-facing surfaces.
  final String explanation;

  const UnderwritingExclusion({
    required this.type,
    required this.scope,
    required this.triggerReason,
    required this.effectiveAt,
    required this.reviewable,
    required this.explanation,
  });

  /// Converts this underwriting exclusion into the existing PolicyExclusion
  /// JSON shape used by checkout/payment flows.
  ///
  /// This does not lose auditability because the full underwriting exclusion
  /// is still stored in quote output via [toJson].
  Map<String, dynamic> toPolicyExclusionJson({DateTime? effectiveDate}) {
    final now = effectiveDate ?? DateTime.now();
    final name = scope.trim().isEmpty ? 'Coverage exclusion' : scope.trim();
    final notes = '${explanation.trim()} (trigger=$triggerReason)';

    return {
      'conditionName': _titleCase(name),
      'scope': type == UnderwritingExclusionType.preExisting
          ? 'condition'
          : 'body_system',
      'effectiveDate': now.toIso8601String(),
      'notes': notes,
    };
  }

  String _titleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;

    // Keep simple + deterministic; don't attempt locale-sensitive casing.
    return trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) {
          if (w.length == 1) return w.toUpperCase();
          return w.substring(0, 1).toUpperCase() + w.substring(1);
        })
        .join(' ');
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'scope': scope,
      'triggerReason': triggerReason,
      'effectiveAt': effectiveAt.name,
      'reviewable': reviewable,
      'explanation': explanation,
    };
  }

  factory UnderwritingExclusion.fromJson(Map<String, dynamic> json) {
    UnderwritingExclusionType parseType(Object? raw) {
      final s = (raw ?? '').toString().trim();
      for (final t in UnderwritingExclusionType.values) {
        if (t.name == s) return t;
        if (t.name.toLowerCase() == s.toLowerCase()) return t;
      }
      return UnderwritingExclusionType.preExisting;
    }

    UnderwritingExclusionEffectiveAt parseEffectiveAt(Object? raw) {
      final s = (raw ?? '').toString().trim();
      for (final e in UnderwritingExclusionEffectiveAt.values) {
        if (e.name == s) return e;
        if (e.name.toLowerCase() == s.toLowerCase()) return e;
      }
      return UnderwritingExclusionEffectiveAt.bind;
    }

    return UnderwritingExclusion(
      type: parseType(json['type']),
      scope: (json['scope'] ?? '').toString(),
      triggerReason: (json['triggerReason'] ?? '').toString(),
      effectiveAt: parseEffectiveAt(json['effectiveAt']),
      reviewable: json['reviewable'] == true,
      explanation: (json['explanation'] ?? '').toString(),
    );
  }
}
