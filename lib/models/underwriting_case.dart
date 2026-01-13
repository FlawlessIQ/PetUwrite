import 'pet.dart';
import 'owner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Underwriting case lifecycle status.
enum UnderwritingCaseStatus {
  inProgress,
  submitted,
  assessed,
  referred,
  approved,
  approvedWithExclusions,
  declined,
}

String underwritingCaseStatusToString(UnderwritingCaseStatus status) {
  switch (status) {
    case UnderwritingCaseStatus.inProgress:
      return 'in_progress';
    case UnderwritingCaseStatus.submitted:
      return 'submitted';
    case UnderwritingCaseStatus.assessed:
      return 'assessed';
    case UnderwritingCaseStatus.referred:
      return 'referred';
    case UnderwritingCaseStatus.approved:
      return 'approved';
    case UnderwritingCaseStatus.approvedWithExclusions:
      return 'approved_with_exclusions';
    case UnderwritingCaseStatus.declined:
      return 'declined';
  }
}

UnderwritingCaseStatus underwritingCaseStatusFromString(String value) {
  switch (value) {
    case 'in_progress':
      return UnderwritingCaseStatus.inProgress;
    case 'submitted':
      return UnderwritingCaseStatus.submitted;
    case 'assessed':
      return UnderwritingCaseStatus.assessed;
    case 'referred':
      return UnderwritingCaseStatus.referred;
    case 'approved':
      return UnderwritingCaseStatus.approved;
    case 'approved_with_exclusions':
      return UnderwritingCaseStatus.approvedWithExclusions;
    case 'declined':
      return UnderwritingCaseStatus.declined;
    default:
      return UnderwritingCaseStatus.inProgress;
  }
}

/// Top-level underwriting case document.
class UnderwritingCase {
  final String id;
  final String userId;
  final String? quoteId;
  final String? petId;
  final Pet? petSnapshot;
  final Owner? ownerSnapshot;
  final UnderwritingCaseStatus status;
  final List<String> triggerReasons;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UnderwritingCase({
    required this.id,
    required this.userId,
    required this.status,
    required this.triggerReasons,
    required this.createdAt,
    required this.updatedAt,
    this.quoteId,
    this.petId,
    this.petSnapshot,
    this.ownerSnapshot,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'quoteId': quoteId,
      'petId': petId,
      'petSnapshot': petSnapshot?.toJson(),
      'ownerSnapshot': ownerSnapshot?.toJson(),
      'status': underwritingCaseStatusToString(status),
      'triggerReasons': triggerReasons,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UnderwritingCase.fromJson(String id, Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse((value ?? '').toString()) ?? DateTime.now();
    }

    return UnderwritingCase(
      id: id,
      userId: (json['userId'] ?? '').toString(),
      quoteId: json['quoteId']?.toString(),
      petId: json['petId']?.toString(),
      petSnapshot: json['petSnapshot'] is Map<String, dynamic>
          ? Pet.fromJson(json['petSnapshot'] as Map<String, dynamic>)
          : null,
      ownerSnapshot: json['ownerSnapshot'] is Map<String, dynamic>
          ? Owner.fromJson(json['ownerSnapshot'] as Map<String, dynamic>)
          : null,
      status: underwritingCaseStatusFromString((json['status'] ?? 'in_progress').toString()),
      triggerReasons: (json['triggerReasons'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
