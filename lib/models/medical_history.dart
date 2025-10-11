/// Medical history models for detailed underwriting
/// 
/// These models capture comprehensive medical information about pets
/// for accurate risk assessment and underwriting decisions.
library;

/// Represents a diagnosed medical condition
class MedicalCondition {
  final String id;
  final String name;
  final DateTime diagnosisDate;
  final String status; // 'active', 'resolved', 'managed', 'stable'
  final String? treatment;
  final String? notes;
  final String? veterinarian;
  final DateTime? lastCheckup;

  MedicalCondition({
    required this.id,
    required this.name,
    required this.diagnosisDate,
    required this.status,
    this.treatment,
    this.notes,
    this.veterinarian,
    this.lastCheckup,
  });

  factory MedicalCondition.fromJson(Map<String, dynamic> json) {
    return MedicalCondition(
      id: json['id'] as String,
      name: json['name'] as String,
      diagnosisDate: DateTime.parse(json['diagnosisDate'] as String),
      status: json['status'] as String,
      treatment: json['treatment'] as String?,
      notes: json['notes'] as String?,
      veterinarian: json['veterinarian'] as String?,
      lastCheckup: json['lastCheckup'] != null 
          ? DateTime.parse(json['lastCheckup'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'diagnosisDate': diagnosisDate.toIso8601String(),
      'status': status,
      'treatment': treatment,
      'notes': notes,
      'veterinarian': veterinarian,
      'lastCheckup': lastCheckup?.toIso8601String(),
    };
  }

  MedicalCondition copyWith({
    String? id,
    String? name,
    DateTime? diagnosisDate,
    String? status,
    String? treatment,
    String? notes,
    String? veterinarian,
    DateTime? lastCheckup,
  }) {
    return MedicalCondition(
      id: id ?? this.id,
      name: name ?? this.name,
      diagnosisDate: diagnosisDate ?? this.diagnosisDate,
      status: status ?? this.status,
      treatment: treatment ?? this.treatment,
      notes: notes ?? this.notes,
      veterinarian: veterinarian ?? this.veterinarian,
      lastCheckup: lastCheckup ?? this.lastCheckup,
    );
  }

  bool get isActive => status == 'active';
  bool get isResolved => status == 'resolved';
  bool get isManaged => status == 'managed' || status == 'stable';
}

/// Represents a medication the pet is taking
class Medication {
  final String id;
  final String name;
  final String dosage;
  final String frequency; // 'daily', 'twice daily', 'weekly', etc.
  final DateTime startDate;
  final DateTime? endDate;
  final String? prescribedBy;
  final String? purpose;
  final bool isOngoing;

  Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.prescribedBy,
    this.purpose,
    this.isOngoing = true,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'] as String,
      name: json['name'] as String,
      dosage: json['dosage'] as String,
      frequency: json['frequency'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null 
          ? DateTime.parse(json['endDate'] as String)
          : null,
      prescribedBy: json['prescribedBy'] as String?,
      purpose: json['purpose'] as String?,
      isOngoing: json['isOngoing'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'prescribedBy': prescribedBy,
      'purpose': purpose,
      'isOngoing': isOngoing,
    };
  }

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    String? prescribedBy,
    String? purpose,
    bool? isOngoing,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      prescribedBy: prescribedBy ?? this.prescribedBy,
      purpose: purpose ?? this.purpose,
      isOngoing: isOngoing ?? this.isOngoing,
    );
  }
}

/// Represents a veterinary visit or examination
class VetVisit {
  final String id;
  final DateTime visitDate;
  final String veterinarian;
  final String clinic;
  final String visitType; // 'checkup', 'emergency', 'surgery', 'follow-up', 'vaccination'
  final String? diagnosis;
  final String? treatment;
  final String? notes;
  final List<String>? procedures;
  final double? cost;

  VetVisit({
    required this.id,
    required this.visitDate,
    required this.veterinarian,
    required this.clinic,
    required this.visitType,
    this.diagnosis,
    this.treatment,
    this.notes,
    this.procedures,
    this.cost,
  });

  factory VetVisit.fromJson(Map<String, dynamic> json) {
    return VetVisit(
      id: json['id'] as String,
      visitDate: DateTime.parse(json['visitDate'] as String),
      veterinarian: json['veterinarian'] as String,
      clinic: json['clinic'] as String,
      visitType: json['visitType'] as String,
      diagnosis: json['diagnosis'] as String?,
      treatment: json['treatment'] as String?,
      notes: json['notes'] as String?,
      procedures: json['procedures'] != null
          ? List<String>.from(json['procedures'] as List)
          : null,
      cost: json['cost'] as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visitDate': visitDate.toIso8601String(),
      'veterinarian': veterinarian,
      'clinic': clinic,
      'visitType': visitType,
      'diagnosis': diagnosis,
      'treatment': treatment,
      'notes': notes,
      'procedures': procedures,
      'cost': cost,
    };
  }

  VetVisit copyWith({
    String? id,
    DateTime? visitDate,
    String? veterinarian,
    String? clinic,
    String? visitType,
    String? diagnosis,
    String? treatment,
    String? notes,
    List<String>? procedures,
    double? cost,
  }) {
    return VetVisit(
      id: id ?? this.id,
      visitDate: visitDate ?? this.visitDate,
      veterinarian: veterinarian ?? this.veterinarian,
      clinic: clinic ?? this.clinic,
      visitType: visitType ?? this.visitType,
      diagnosis: diagnosis ?? this.diagnosis,
      treatment: treatment ?? this.treatment,
      notes: notes ?? this.notes,
      procedures: procedures ?? this.procedures,
      cost: cost ?? this.cost,
    );
  }

  bool get isEmergency => visitType == 'emergency';
  bool get isSurgery => visitType == 'surgery';
  bool get isRoutine => visitType == 'checkup' || visitType == 'vaccination';
}

/// Represents uploaded veterinary records
class VetRecords {
  final String id;
  final List<VetRecordFile> files;
  final DateTime uploadedAt;
  final bool isParsed;
  final Map<String, dynamic>? parsedData;
  final String? notes;

  VetRecords({
    required this.id,
    required this.files,
    required this.uploadedAt,
    this.isParsed = false,
    this.parsedData,
    this.notes,
  });

  factory VetRecords.fromJson(Map<String, dynamic> json) {
    return VetRecords(
      id: json['id'] as String,
      files: (json['files'] as List)
          .map((f) => VetRecordFile.fromJson(f as Map<String, dynamic>))
          .toList(),
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      isParsed: json['isParsed'] as bool? ?? false,
      parsedData: json['parsedData'] as Map<String, dynamic>?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'files': files.map((f) => f.toJson()).toList(),
      'uploadedAt': uploadedAt.toIso8601String(),
      'isParsed': isParsed,
      'parsedData': parsedData,
      'notes': notes,
    };
  }
}

/// Represents a single veterinary record file
class VetRecordFile {
  final String id;
  final String fileName;
  final String fileType; // 'pdf', 'image', 'document'
  final String? url;
  final int? sizeBytes;

  VetRecordFile({
    required this.id,
    required this.fileName,
    required this.fileType,
    this.url,
    this.sizeBytes,
  });

  factory VetRecordFile.fromJson(Map<String, dynamic> json) {
    return VetRecordFile(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      fileType: json['fileType'] as String,
      url: json['url'] as String?,
      sizeBytes: json['sizeBytes'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileName': fileName,
      'fileType': fileType,
      'url': url,
      'sizeBytes': sizeBytes,
    };
  }
}

/// Complete medical history for a pet
class CompleteMedicalHistory {
  final List<MedicalCondition> conditions;
  final List<Medication> medications;
  final List<String> allergies;
  final List<VetVisit> vetVisits;
  final VetRecords? uploadedRecords;
  final DateTime? lastVetVisit;
  final bool isVaccinated;
  final DateTime? lastVaccinationDate;

  CompleteMedicalHistory({
    this.conditions = const [],
    this.medications = const [],
    this.allergies = const [],
    this.vetVisits = const [],
    this.uploadedRecords,
    this.lastVetVisit,
    this.isVaccinated = false,
    this.lastVaccinationDate,
  });

  factory CompleteMedicalHistory.fromJson(Map<String, dynamic> json) {
    return CompleteMedicalHistory(
      conditions: json['conditions'] != null
          ? (json['conditions'] as List)
              .map((c) => MedicalCondition.fromJson(c as Map<String, dynamic>))
              .toList()
          : [],
      medications: json['medications'] != null
          ? (json['medications'] as List)
              .map((m) => Medication.fromJson(m as Map<String, dynamic>))
              .toList()
          : [],
      allergies: json['allergies'] != null
          ? List<String>.from(json['allergies'] as List)
          : [],
      vetVisits: json['vetVisits'] != null
          ? (json['vetVisits'] as List)
              .map((v) => VetVisit.fromJson(v as Map<String, dynamic>))
              .toList()
          : [],
      uploadedRecords: json['uploadedRecords'] != null
          ? VetRecords.fromJson(json['uploadedRecords'] as Map<String, dynamic>)
          : null,
      lastVetVisit: json['lastVetVisit'] != null
          ? DateTime.parse(json['lastVetVisit'] as String)
          : null,
      isVaccinated: json['isVaccinated'] as bool? ?? false,
      lastVaccinationDate: json['lastVaccinationDate'] != null
          ? DateTime.parse(json['lastVaccinationDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conditions': conditions.map((c) => c.toJson()).toList(),
      'medications': medications.map((m) => m.toJson()).toList(),
      'allergies': allergies,
      'vetVisits': vetVisits.map((v) => v.toJson()).toList(),
      'uploadedRecords': uploadedRecords?.toJson(),
      'lastVetVisit': lastVetVisit?.toIso8601String(),
      'isVaccinated': isVaccinated,
      'lastVaccinationDate': lastVaccinationDate?.toIso8601String(),
    };
  }

  // Helper getters
  List<MedicalCondition> get activeConditions =>
      conditions.where((c) => c.isActive).toList();
  
  List<Medication> get activeMedications =>
      medications.where((m) => m.isOngoing).toList();
  
  int get totalVetVisits => vetVisits.length;
  
  bool get hasEmergencyVisits =>
      vetVisits.any((v) => v.isEmergency);
  
  bool get hasSurgeryHistory =>
      vetVisits.any((v) => v.isSurgery);
}
