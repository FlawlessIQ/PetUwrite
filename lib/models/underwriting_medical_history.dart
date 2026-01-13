/// Underwriting medical condition captured during intake.
class UnderwritingCondition {
  final String name;
  final String? diagnosisMonthYear; // e.g. "2022-03" or "2022"
  final bool isResolved;
  final bool isManaged;
  final String? treatmentStatus; // free text or controlled in UI
  final List<String> meds;
  final String? lastSymptomsMonthYear;
  final String? notes;

  const UnderwritingCondition({
    required this.name,
    this.diagnosisMonthYear,
    required this.isResolved,
    required this.isManaged,
    this.treatmentStatus,
    this.meds = const [],
    this.lastSymptomsMonthYear,
    this.notes,
  });

  factory UnderwritingCondition.fromJson(Map<String, dynamic> json) {
    return UnderwritingCondition(
      name: (json['name'] ?? '').toString(),
      diagnosisMonthYear: json['diagnosisMonthYear']?.toString(),
      isResolved: json['isResolved'] == true,
      isManaged: json['isManaged'] == true,
      treatmentStatus: json['treatmentStatus']?.toString(),
      meds: (json['meds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      lastSymptomsMonthYear: json['lastSymptomsMonthYear']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'diagnosisMonthYear': diagnosisMonthYear,
      'isResolved': isResolved,
      'isManaged': isManaged,
      'treatmentStatus': treatmentStatus,
      'meds': meds,
      'lastSymptomsMonthYear': lastSymptomsMonthYear,
      'notes': notes,
    };
  }
}

/// Medical history captured for an underwriting case.
class UnderwritingMedicalHistory {
  final List<UnderwritingCondition> conditions;
  final String? lastVetVisitMonthYear;
  final String? vetClinicName;
  final bool? consentToRetrieveRecords;
  final bool userAttestation;
  final DateTime? attestedAt;

  const UnderwritingMedicalHistory({
    required this.conditions,
    this.lastVetVisitMonthYear,
    this.vetClinicName,
    this.consentToRetrieveRecords,
    required this.userAttestation,
    this.attestedAt,
  });

  factory UnderwritingMedicalHistory.empty() {
    return const UnderwritingMedicalHistory(
      conditions: [],
      userAttestation: false,
    );
  }

  factory UnderwritingMedicalHistory.fromJson(Map<String, dynamic> json) {
    return UnderwritingMedicalHistory(
      conditions: (json['conditions'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(UnderwritingCondition.fromJson)
              .toList() ??
          const [],
      lastVetVisitMonthYear: json['lastVetVisitMonthYear']?.toString(),
      vetClinicName: json['vetClinicName']?.toString(),
      consentToRetrieveRecords: json['consentToRetrieveRecords'] as bool?,
      userAttestation: json['userAttestation'] == true,
      attestedAt: json['attestedAt'] != null
          ? DateTime.tryParse(json['attestedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conditions': conditions.map((c) => c.toJson()).toList(),
      'lastVetVisitMonthYear': lastVetVisitMonthYear,
      'vetClinicName': vetClinicName,
      'consentToRetrieveRecords': consentToRetrieveRecords,
      'userAttestation': userAttestation,
      'attestedAt': attestedAt?.toIso8601String(),
    };
  }
}
