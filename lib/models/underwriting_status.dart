// Underwriting status used to gate pricing and plan availability.
//
// Fail closed:
// - INCOMPLETE: missing required medical facts
// - NEED_MORE_INFO: self-serve path (missing/uncertain evidence)
// - DECLINED: deterministic decline (fully automated)
// - DENIED: deterministic disqualification (hard deny)
// - APPROVED: safe to price

enum UnderwritingStatus { approved, incomplete, needMoreInfo, declined, denied }

String underwritingStatusToString(UnderwritingStatus status) {
  return switch (status) {
    UnderwritingStatus.approved => 'APPROVED',
    UnderwritingStatus.incomplete => 'INCOMPLETE',
    UnderwritingStatus.needMoreInfo => 'NEED_MORE_INFO',
    UnderwritingStatus.declined => 'DECLINED',
    UnderwritingStatus.denied => 'DENIED',
  };
}

UnderwritingStatus underwritingStatusFromString(String raw) {
  final v = raw.trim().toUpperCase();
  return switch (v) {
    'APPROVED' => UnderwritingStatus.approved,
    'INCOMPLETE' => UnderwritingStatus.incomplete,
    // Backwards-compat: legacy manual-review state now maps to self-serve.
    'MANUAL_REVIEW' => UnderwritingStatus.needMoreInfo,
    'NEED_MORE_INFO' => UnderwritingStatus.needMoreInfo,
    'DECLINED' => UnderwritingStatus.declined,
    'DENIED' => UnderwritingStatus.denied,
    // Fail closed.
    _ => UnderwritingStatus.needMoreInfo,
  };
}
