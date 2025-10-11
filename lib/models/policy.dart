import 'quote.dart';

/// Model class representing an insurance policy
class Policy {
  final String id;
  final String policyNumber;
  final String ownerId;
  final String petId;
  final String quoteId;
  final CoveragePlan plan;
  final DateTime issuedAt;
  final DateTime effectiveDate;
  final DateTime expirationDate;
  final PolicyStatus status;
  final PaymentSchedule paymentSchedule;
  final List<Claim> claims;
  
  Policy({
    required this.id,
    required this.policyNumber,
    required this.ownerId,
    required this.petId,
    required this.quoteId,
    required this.plan,
    required this.issuedAt,
    required this.effectiveDate,
    required this.expirationDate,
    required this.status,
    required this.paymentSchedule,
    this.claims = const [],
  });
  
  bool get isActive => status == PolicyStatus.active && 
      DateTime.now().isAfter(effectiveDate) && 
      DateTime.now().isBefore(expirationDate);
  
  double get totalClaimsAmount => 
      claims.fold(0.0, (sum, claim) => sum + claim.paidAmount);
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'policyNumber': policyNumber,
      'ownerId': ownerId,
      'petId': petId,
      'quoteId': quoteId,
      'plan': plan.toJson(),
      'issuedAt': issuedAt.toIso8601String(),
      'effectiveDate': effectiveDate.toIso8601String(),
      'expirationDate': expirationDate.toIso8601String(),
      'status': status.toString(),
      'paymentSchedule': paymentSchedule.toString(),
      'claims': claims.map((c) => c.toJson()).toList(),
    };
  }
  
  factory Policy.fromJson(Map<String, dynamic> json) {
    return Policy(
      id: json['id'] as String,
      policyNumber: json['policyNumber'] as String,
      ownerId: json['ownerId'] as String,
      petId: json['petId'] as String,
      quoteId: json['quoteId'] as String,
      plan: CoveragePlan.fromJson(json['plan'] as Map<String, dynamic>),
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      effectiveDate: DateTime.parse(json['effectiveDate'] as String),
      expirationDate: DateTime.parse(json['expirationDate'] as String),
      status: PolicyStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => PolicyStatus.pending,
      ),
      paymentSchedule: PaymentSchedule.values.firstWhere(
        (e) => e.toString() == json['paymentSchedule'],
        orElse: () => PaymentSchedule.monthly,
      ),
      claims: (json['claims'] as List<dynamic>?)
          ?.map((c) => Claim.fromJson(c as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

/// Enum for policy status
enum PolicyStatus {
  pending,
  active,
  suspended,
  cancelled,
  expired,
}

/// Enum for payment schedule
enum PaymentSchedule {
  monthly,
  quarterly,
  annually,
}

/// Model class for insurance claims
class Claim {
  final String id;
  final String policyId;
  final DateTime submittedAt;
  final DateTime incidentDate;
  final String description;
  final double claimedAmount;
  final double approvedAmount;
  final double paidAmount;
  final ClaimStatus status;
  final List<String> documentUrls;
  
  Claim({
    required this.id,
    required this.policyId,
    required this.submittedAt,
    required this.incidentDate,
    required this.description,
    required this.claimedAmount,
    required this.approvedAmount,
    required this.paidAmount,
    required this.status,
    this.documentUrls = const [],
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'policyId': policyId,
      'submittedAt': submittedAt.toIso8601String(),
      'incidentDate': incidentDate.toIso8601String(),
      'description': description,
      'claimedAmount': claimedAmount,
      'approvedAmount': approvedAmount,
      'paidAmount': paidAmount,
      'status': status.toString(),
      'documentUrls': documentUrls,
    };
  }
  
  factory Claim.fromJson(Map<String, dynamic> json) {
    return Claim(
      id: json['id'] as String,
      policyId: json['policyId'] as String,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      incidentDate: DateTime.parse(json['incidentDate'] as String),
      description: json['description'] as String,
      claimedAmount: (json['claimedAmount'] as num).toDouble(),
      approvedAmount: (json['approvedAmount'] as num).toDouble(),
      paidAmount: (json['paidAmount'] as num).toDouble(),
      status: ClaimStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => ClaimStatus.pending,
      ),
      documentUrls: (json['documentUrls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
    );
  }
}

/// Enum for claim status
enum ClaimStatus {
  pending,
  underReview,
  approved,
  rejected,
  paid,
}
