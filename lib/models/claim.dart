import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a comprehensive insurance claim filed by a policyholder
/// Supports AI-assisted decision making, human oversight, and full claim lifecycle
class Claim {
  final String claimId;
  final String policyId;
  final String ownerId;
  final String petId;
  final DateTime incidentDate;
  final ClaimType claimType;
  final double claimAmount;
  final String currency;
  final String description;
  final List<String>
  attachments; // URLs to uploaded documents (vet records, receipts, photos)

  // AI Decision Support
  final double? aiConfidenceScore; // 0.0 - 1.0
  final AIDecision? aiDecision;
  final Map<String, dynamic>?
  aiReasoningExplanation; // SHAP-style explainability

  // Human Override
  final Map<String, dynamic>?
  humanOverride; // { overriddenBy, overrideReason, overrideTimestamp }

  // Claim Status & Lifecycle
  final ClaimStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? settledAt;

  // Advisory Lock for Concurrent Review (10-minute timeout)
  final String? reviewLockedBy; // Admin user ID holding the lock
  final DateTime? reviewLockedAt; // When the lock was acquired

  Claim({
    required this.claimId,
    required this.policyId,
    required this.ownerId,
    required this.petId,
    required this.incidentDate,
    required this.claimType,
    required this.claimAmount,
    this.currency = 'USD',
    required this.description,
    this.attachments = const [],
    this.aiConfidenceScore,
    this.aiDecision,
    this.aiReasoningExplanation,
    this.humanOverride,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.settledAt,
    this.reviewLockedBy,
    this.reviewLockedAt,
  });

  /// Create Claim from Firestore document
  factory Claim.fromMap(Map<String, dynamic> map, String documentId) {
    return Claim(
      claimId: documentId,
      policyId: map['policyId'] as String,
      ownerId: map['ownerId'] as String,
      petId: map['petId'] as String,
      incidentDate: (map['incidentDate'] as Timestamp).toDate(),
      claimType: ClaimType.fromString(map['claimType'] as String),
      claimAmount: (map['claimAmount'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'USD',
      description: map['description'] as String,
      attachments: List<String>.from(map['attachments'] as List? ?? []),
      aiConfidenceScore: map['aiConfidenceScore'] as double?,
      aiDecision: map['aiDecision'] != null
          ? AIDecision.fromString(map['aiDecision'] as String)
          : null,
      aiReasoningExplanation:
          map['aiReasoningExplanation'] as Map<String, dynamic>?,
      humanOverride: map['humanOverride'] as Map<String, dynamic>?,
      status: ClaimStatus.fromString(map['status'] as String),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      settledAt: map['settledAt'] != null
          ? (map['settledAt'] as Timestamp).toDate()
          : null,
      reviewLockedBy: map['reviewLockedBy'] as String?,
      reviewLockedAt: map['reviewLockedAt'] != null
          ? (map['reviewLockedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert Claim to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'policyId': policyId,
      'ownerId': ownerId,
      'petId': petId,
      'incidentDate': Timestamp.fromDate(incidentDate),
      'claimType': claimType.value,
      'claimAmount': claimAmount,
      'currency': currency,
      'description': description,
      'attachments': attachments,
      'aiConfidenceScore': aiConfidenceScore,
      'aiDecision': aiDecision?.value,
      'aiReasoningExplanation': aiReasoningExplanation,
      'humanOverride': humanOverride,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'settledAt': settledAt != null ? Timestamp.fromDate(settledAt!) : null,
      'reviewLockedBy': reviewLockedBy,
      'reviewLockedAt': reviewLockedAt != null
          ? Timestamp.fromDate(reviewLockedAt!)
          : null,
    };
  }

  /// Convert to JSON string
  String toJson() => json.encode(toMap());

  /// Create from JSON string
  factory Claim.fromJson(String source) {
    final map = json.decode(source) as Map<String, dynamic>;
    return Claim.fromMap(map, map['claimId'] as String);
  }

  /// Copy with method for updates
  Claim copyWith({
    String? claimId,
    String? policyId,
    String? ownerId,
    String? petId,
    DateTime? incidentDate,
    ClaimType? claimType,
    double? claimAmount,
    String? currency,
    String? description,
    List<String>? attachments,
    double? aiConfidenceScore,
    AIDecision? aiDecision,
    Map<String, dynamic>? aiReasoningExplanation,
    Map<String, dynamic>? humanOverride,
    ClaimStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? settledAt,
    String? reviewLockedBy,
    DateTime? reviewLockedAt,
    bool clearReviewLock = false,
  }) {
    return Claim(
      claimId: claimId ?? this.claimId,
      policyId: policyId ?? this.policyId,
      ownerId: ownerId ?? this.ownerId,
      petId: petId ?? this.petId,
      incidentDate: incidentDate ?? this.incidentDate,
      claimType: claimType ?? this.claimType,
      claimAmount: claimAmount ?? this.claimAmount,
      currency: currency ?? this.currency,
      description: description ?? this.description,
      attachments: attachments ?? this.attachments,
      aiConfidenceScore: aiConfidenceScore ?? this.aiConfidenceScore,
      aiDecision: aiDecision ?? this.aiDecision,
      aiReasoningExplanation:
          aiReasoningExplanation ?? this.aiReasoningExplanation,
      humanOverride: humanOverride ?? this.humanOverride,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settledAt: settledAt ?? this.settledAt,
      reviewLockedBy: clearReviewLock
          ? null
          : (reviewLockedBy ?? this.reviewLockedBy),
      reviewLockedAt: clearReviewLock
          ? null
          : (reviewLockedAt ?? this.reviewLockedAt),
    );
  }

  /// Check if claim is currently locked for review
  bool get isReviewLocked {
    if (reviewLockedBy == null || reviewLockedAt == null) return false;

    // Lock expires after 10 minutes
    final lockExpiry = reviewLockedAt!.add(const Duration(minutes: 10));
    return DateTime.now().isBefore(lockExpiry);
  }

  /// Check if claim lock has expired
  bool get hasExpiredLock {
    if (reviewLockedBy == null || reviewLockedAt == null) return false;

    final lockExpiry = reviewLockedAt!.add(const Duration(minutes: 10));
    return DateTime.now().isAfter(lockExpiry);
  }

  /// Check if claim was overridden by human
  bool get hasHumanOverride =>
      humanOverride != null && humanOverride!.isNotEmpty;

  /// Check if AI made a decision
  bool get hasAIDecision => aiDecision != null;

  /// Get final decision (human override takes precedence)
  String get finalDecision {
    if (hasHumanOverride) {
      return 'Human Override: ${humanOverride!['decision'] ?? 'Unknown'}';
    }
    if (hasAIDecision) {
      return 'AI: ${aiDecision!.displayName}';
    }
    return 'Pending';
  }
}

/// Claim type enum
enum ClaimType {
  accident('accident'),
  illness('illness'),
  wellness('wellness');

  final String value;
  const ClaimType(this.value);

  static ClaimType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'accident':
        return ClaimType.accident;
      case 'illness':
        return ClaimType.illness;
      case 'wellness':
        return ClaimType.wellness;
      default:
        throw ArgumentError('Invalid claim type: $value');
    }
  }

  String get displayName {
    switch (this) {
      case ClaimType.accident:
        return 'Accident';
      case ClaimType.illness:
        return 'Illness';
      case ClaimType.wellness:
        return 'Wellness';
    }
  }
}

/// Claim status enum
enum ClaimStatus {
  draft('draft'),
  submitted('submitted'),
  processing('processing'),
  awaitingInfo('awaiting_info'),
  settling('settling'), // Intermediate state for payout processing lock
  settled('settled'),
  denied('denied'),
  cancelled('cancelled');

  final String value;
  const ClaimStatus(this.value);

  static ClaimStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'draft':
        return ClaimStatus.draft;
      case 'submitted':
        return ClaimStatus.submitted;
      case 'awaiting_info':
      case 'awaiting-info':
      case 'needs_info':
      case 'needs-info':
      case 'awaiting_documents':
      case 'awaiting-documents':
        return ClaimStatus.awaitingInfo;
      case 'pending':
      case 'in_review':
      case 'in-review':
      case 'review':
      case 'processing':
        return ClaimStatus.processing;
      case 'approved':
        // Backwards-compatible: older docs may mark approval directly.
        // Prefer 'settling' (payment in progress) semantics.
        return ClaimStatus.settling;
      case 'settling':
        return ClaimStatus.settling;
      case 'paid':
      case 'completed':
      case 'settled':
        return ClaimStatus.settled;
      case 'rejected':
      case 'denied':
        return ClaimStatus.denied;
      case 'cancelled':
      case 'canceled':
        return ClaimStatus.cancelled;
      default:
        // Be defensive: treat unknown statuses as processing.
        return ClaimStatus.processing;
    }
  }

  String get displayName {
    switch (this) {
      case ClaimStatus.draft:
        return 'Draft';
      case ClaimStatus.submitted:
        return 'Submitted';
      case ClaimStatus.processing:
        return 'Processing';
      case ClaimStatus.awaitingInfo:
        return 'Awaiting Info';
      case ClaimStatus.settling:
        return 'Settling';
      case ClaimStatus.settled:
        return 'Settled';
      case ClaimStatus.denied:
        return 'Denied';
      case ClaimStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// AI decision enum
enum AIDecision {
  approve('approve'),
  deny('deny'),
  escalate('escalate'),
  needsInfo('needs_info');

  final String value;
  const AIDecision(this.value);

  static AIDecision fromString(String value) {
    switch (value.toLowerCase()) {
      case 'approve':
        return AIDecision.approve;
      case 'deny':
        return AIDecision.deny;
      case 'escalate':
        return AIDecision.escalate;
      case 'needs_info':
      case 'needs-info':
        return AIDecision.needsInfo;
      default:
        throw ArgumentError('Invalid AI decision: $value');
    }
  }

  String get displayName {
    switch (this) {
      case AIDecision.approve:
        return 'Approve';
      case AIDecision.deny:
        return 'Deny';
      case AIDecision.escalate:
        return 'Escalate';
      case AIDecision.needsInfo:
        return 'Needs Info';
    }
  }
}

/// Get reference to claims collection with converter
CollectionReference<Claim> getClaimsCollection() {
  return FirebaseFirestore.instance
      .collection('claims')
      .withConverter<Claim>(
        fromFirestore: (snapshot, _) =>
            Claim.fromMap(snapshot.data()!, snapshot.id),
        toFirestore: (claim, _) => claim.toMap(),
      );
}

/// Get reference to a specific claim document with converter
DocumentReference<Claim> getClaimDocument(String claimId) {
  return getClaimsCollection().doc(claimId);
}
