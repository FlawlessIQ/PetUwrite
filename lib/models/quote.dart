import 'risk_score.dart';

/// Model class representing an insurance quote
class Quote {
  final String id;
  final String petId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<CoveragePlan> availablePlans;
  final RiskScore riskScore;
  final QuoteStatus status;
  
  Quote({
    required this.id,
    required this.petId,
    required this.createdAt,
    required this.expiresAt,
    required this.availablePlans,
    required this.riskScore,
    required this.status,
  });
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  CoveragePlan? get basicPlan => 
      availablePlans.firstWhere((p) => p.tier == PlanTier.basic, orElse: () => availablePlans.first);
  
  CoveragePlan? get premiumPlan => 
      availablePlans.firstWhere((p) => p.tier == PlanTier.premium, orElse: () => availablePlans.first);
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'availablePlans': availablePlans.map((p) => p.toJson()).toList(),
      'riskScore': riskScore.toJson(),
      'status': status.toString(),
    };
  }
  
  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'] as String,
      petId: json['petId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      availablePlans: (json['availablePlans'] as List<dynamic>)
          .map((p) => CoveragePlan.fromJson(p as Map<String, dynamic>))
          .toList(),
      riskScore: RiskScore.fromJson(json['riskScore'] as Map<String, dynamic>),
      status: QuoteStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => QuoteStatus.pending,
      ),
    );
  }
}

/// Enum for quote status
enum QuoteStatus {
  pending,
  approved,
  rejected,
  expired,
}

/// Enum for plan tiers
enum PlanTier {
  basic,
  standard,
  premium,
}

/// Model class for insurance coverage plans
class CoveragePlan {
  final String id;
  final String name;
  final PlanTier tier;
  final double monthlyPremium;
  final double annualDeductible;
  final double reimbursementPercentage; // 70%, 80%, 90%
  final double annualLimit;
  final List<String> coveredConditions;
  final List<String> exclusions;
  final bool includesWellness;
  final bool includesDental;
  
  CoveragePlan({
    required this.id,
    required this.name,
    required this.tier,
    required this.monthlyPremium,
    required this.annualDeductible,
    required this.reimbursementPercentage,
    required this.annualLimit,
    required this.coveredConditions,
    required this.exclusions,
    this.includesWellness = false,
    this.includesDental = false,
  });
  
  double get annualPremium => monthlyPremium * 12;
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tier': tier.toString(),
      'monthlyPremium': monthlyPremium,
      'annualDeductible': annualDeductible,
      'reimbursementPercentage': reimbursementPercentage,
      'annualLimit': annualLimit,
      'coveredConditions': coveredConditions,
      'exclusions': exclusions,
      'includesWellness': includesWellness,
      'includesDental': includesDental,
    };
  }
  
  factory CoveragePlan.fromJson(Map<String, dynamic> json) {
    return CoveragePlan(
      id: json['id'] as String,
      name: json['name'] as String,
      tier: PlanTier.values.firstWhere(
        (e) => e.toString() == json['tier'],
        orElse: () => PlanTier.basic,
      ),
      monthlyPremium: (json['monthlyPremium'] as num).toDouble(),
      annualDeductible: (json['annualDeductible'] as num).toDouble(),
      reimbursementPercentage: (json['reimbursementPercentage'] as num).toDouble(),
      annualLimit: (json['annualLimit'] as num).toDouble(),
      coveredConditions: (json['coveredConditions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      exclusions: (json['exclusions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      includesWellness: json['includesWellness'] as bool? ?? false,
      includesDental: json['includesDental'] as bool? ?? false,
    );
  }
}
