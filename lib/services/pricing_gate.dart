class PricingGate {
  static bool isPricingAllowed(Map<String, dynamic>? routeArguments) {
    if (routeArguments == null) return false;

    final pricingEnabled = routeArguments['pricingEnabled'] == true;
    final underwritingStatus =
        routeArguments['underwritingStatus']?.toString().trim().toUpperCase();
    final integrityPassed = routeArguments['integrityPassed'] == true;

    // Fail closed: must have explicit approval AND integrity passed.
    return pricingEnabled && underwritingStatus == 'APPROVED' && integrityPassed;
  }

  static String blockReason(Map<String, dynamic>? routeArguments) {
    final raw = routeArguments?['underwritingReason']?.toString();
    final trimmed = (raw ?? '').trim();
    return trimmed.isNotEmpty ? trimmed : 'UNDERWRITING_INCOMPLETE';
  }
}
