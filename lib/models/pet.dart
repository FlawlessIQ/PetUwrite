import 'medical_history.dart';

/// Model class representing a pet in the underwriting system
class Pet {
  final String id;
  final String name;
  final String species; // 'dog', 'cat', etc.
  final String breed;
  final DateTime dateOfBirth;
  final String gender;
  final double weight; // in kg
  final bool isNeutered;
  final List<String> preExistingConditions; // Legacy field for backward compatibility
  final String? microchipNumber;
  
  // Enhanced medical history fields
  final List<MedicalCondition>? medicalConditions;
  final List<Medication>? medications;
  final List<String>? allergies;
  final List<VetVisit>? vetHistory;
  final VetRecords? uploadedRecords;
  final bool? isReceivingTreatment;
  
  Pet({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.dateOfBirth,
    required this.gender,
    required this.weight,
    required this.isNeutered,
    this.preExistingConditions = const [],
    this.microchipNumber,
    this.medicalConditions,
    this.medications,
    this.allergies,
    this.vetHistory,
    this.uploadedRecords,
    this.isReceivingTreatment,
  });
  
  int get ageInYears {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || 
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'breed': breed,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'gender': gender,
      'weight': weight,
      'isNeutered': isNeutered,
      'preExistingConditions': preExistingConditions,
      'microchipNumber': microchipNumber,
      'medicalConditions': medicalConditions?.map((c) => c.toJson()).toList(),
      'medications': medications?.map((m) => m.toJson()).toList(),
      'allergies': allergies,
      'vetHistory': vetHistory?.map((v) => v.toJson()).toList(),
      'uploadedRecords': uploadedRecords?.toJson(),
      'isReceivingTreatment': isReceivingTreatment,
    };
  }
  
  factory Pet.fromJson(Map<String, dynamic> json) {
    // Helper to safely get String with fallback
    String getString(String key, String fallback) {
      final value = json[key];
      if (value == null) return fallback;
      return value.toString();
    }
    
    // Helper to safely parse DateTime
    DateTime getDateTime(String key) {
      final value = json[key];
      if (value == null) {
        // Check if age is provided instead
        final age = json['age'];
        if (age != null) {
          final ageInt = age is int ? age : int.tryParse(age.toString()) ?? 1;
          return DateTime.now().subtract(Duration(days: ageInt * 365));
        }
        // Default to 1 year old if no date or age provided
        return DateTime.now().subtract(const Duration(days: 365));
      }
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          // If parsing fails, check for age field
          final age = json['age'];
          if (age != null) {
            final ageInt = age is int ? age : int.tryParse(age.toString()) ?? 1;
            return DateTime.now().subtract(Duration(days: ageInt * 365));
          }
          return DateTime.now().subtract(const Duration(days: 365));
        }
      }
      // Fallback
      return DateTime.now().subtract(const Duration(days: 365));
    }
    
    // Helper to safely get double
    double getDouble(String key, double fallback) {
      final value = json[key];
      if (value == null) return fallback;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }
    
    // Helper to safely get bool
    bool getBool(String key, bool fallback) {
      final value = json[key];
      if (value == null) return fallback;
      if (value is bool) return value;
      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }
      return fallback;
    }
    
    return Pet(
      id: getString('id', 'pet_${DateTime.now().millisecondsSinceEpoch}'),
      name: getString('name', getString('petName', 'Unknown')),
      species: getString('species', 'dog'),
      breed: getString('breed', 'Mixed Breed'),
      dateOfBirth: getDateTime('dateOfBirth'),
      gender: getString('gender', 'unknown'),
      weight: getDouble('weight', 10.0),
      isNeutered: getBool('isNeutered', getBool('neutered', false)),
      preExistingConditions: (json['preExistingConditions'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      microchipNumber: json['microchipNumber']?.toString(),
      medicalConditions: json['medicalConditions'] != null
          ? (json['medicalConditions'] as List)
              .map((c) => MedicalCondition.fromJson(c as Map<String, dynamic>))
              .toList()
          : null,
      medications: json['medications'] != null
          ? (json['medications'] as List)
              .map((m) => Medication.fromJson(m as Map<String, dynamic>))
              .toList()
          : null,
      allergies: json['allergies'] != null
          ? List<String>.from(json['allergies'] as List)
          : null,
      vetHistory: json['vetHistory'] != null
          ? (json['vetHistory'] as List)
              .map((v) => VetVisit.fromJson(v as Map<String, dynamic>))
              .toList()
          : null,
      uploadedRecords: json['uploadedRecords'] != null
          ? VetRecords.fromJson(json['uploadedRecords'] as Map<String, dynamic>)
          : null,
      isReceivingTreatment: json['isReceivingTreatment'] as bool?,
    );
  }
  
  Pet copyWith({
    String? id,
    String? name,
    String? species,
    String? breed,
    DateTime? dateOfBirth,
    String? gender,
    double? weight,
    bool? isNeutered,
    List<String>? preExistingConditions,
    String? microchipNumber,
    List<MedicalCondition>? medicalConditions,
    List<Medication>? medications,
    List<String>? allergies,
    List<VetVisit>? vetHistory,
    VetRecords? uploadedRecords,
    bool? isReceivingTreatment,
  }) {
    return Pet(
      id: id ?? this.id,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      weight: weight ?? this.weight,
      isNeutered: isNeutered ?? this.isNeutered,
      preExistingConditions: preExistingConditions ?? this.preExistingConditions,
      microchipNumber: microchipNumber ?? this.microchipNumber,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      medications: medications ?? this.medications,
      allergies: allergies ?? this.allergies,
      vetHistory: vetHistory ?? this.vetHistory,
      uploadedRecords: uploadedRecords ?? this.uploadedRecords,
      isReceivingTreatment: isReceivingTreatment ?? this.isReceivingTreatment,
    );
  }
  
  // Helper getters for medical history
  bool get hasDetailedMedicalHistory =>
      medicalConditions != null && medicalConditions!.isNotEmpty;
  
  bool get hasActiveMedications =>
      medications != null && medications!.any((m) => m.isOngoing);
  
  bool get hasVetRecords =>
      uploadedRecords != null && uploadedRecords!.files.isNotEmpty;
  
  int get numberOfActiveConditions =>
      medicalConditions?.where((c) => c.isActive).length ?? 0;
}
