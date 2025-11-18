import 'package:flutter/material.dart';
import '../models/pet.dart';
import '../models/medical_history.dart';
import '../theme/clovara_theme.dart';
import 'plan_selection_screen.dart';

/// Comprehensive medical underwriting screen
/// 
/// Collects detailed medical history for pets with pre-existing conditions
/// Shown between AI analysis and plan selection for high-risk cases
class MedicalUnderwritingScreen extends StatefulWidget {
  final Pet pet;
  final dynamic riskScore;
  final Map<String, dynamic>? quoteData;

  const MedicalUnderwritingScreen({
    super.key,
    required this.pet,
    required this.riskScore,
    this.quoteData,
  });

  @override
  State<MedicalUnderwritingScreen> createState() => _MedicalUnderwritingScreenState();
}

class _MedicalUnderwritingScreenState extends State<MedicalUnderwritingScreen> 
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  int _currentStep = 0;
  final int _totalSteps = 3;
  
  // Medical history data
  List<MedicalCondition> _conditions = [];
  List<Medication> _medications = [];
  List<String> _allergies = [];
  List<VetVisit> _vetVisits = [];
  
  // Form controllers
  final _allergyController = TextEditingController();
  
  // Condition form controllers
  final _conditionNameController = TextEditingController();
  final _conditionTreatmentController = TextEditingController();
  final _conditionNotesController = TextEditingController();
  DateTime? _conditionDiagnosisDate;
  String _conditionStatus = 'active';
  
  // Medication form controllers
  final _medicationNameController = TextEditingController();
  final _medicationDosageController = TextEditingController();
  final _medicationFrequencyController = TextEditingController();
  final _medicationPurposeController = TextEditingController();
  DateTime? _medicationStartDate;
  bool _medicationIsOngoing = true;
  
  // Vet visit form controllers
  final _vetNameController = TextEditingController();
  final _clinicNameController = TextEditingController();
  final _visitDiagnosisController = TextEditingController();
  final _visitTreatmentController = TextEditingController();
  DateTime? _visitDate;
  String _visitType = 'checkup';
  
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
    _initializeFromPet();
  }
  
  void _initializeFromPet() {
    // Pre-populate with basic condition data if available
    if (widget.pet.preExistingConditions.isNotEmpty) {
      for (final conditionName in widget.pet.preExistingConditions) {
        if (conditionName != 'Pre-existing condition reported') {
          _conditions.add(MedicalCondition(
            id: 'cond_${DateTime.now().millisecondsSinceEpoch}',
            name: conditionName,
            diagnosisDate: DateTime.now().subtract(const Duration(days: 365)),
            status: 'active',
          ));
        }
      }
    }
    
    // Copy existing medical data if available
    if (widget.pet.medicalConditions != null) {
      _conditions = List.from(widget.pet.medicalConditions!);
    }
    if (widget.pet.medications != null) {
      _medications = List.from(widget.pet.medications!);
    }
    if (widget.pet.allergies != null) {
      _allergies = List.from(widget.pet.allergies!);
    }
    if (widget.pet.vetHistory != null) {
      _vetVisits = List.from(widget.pet.vetHistory!);
    }
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    _allergyController.dispose();
    _conditionNameController.dispose();
    _conditionTreatmentController.dispose();
    _conditionNotesController.dispose();
    _medicationNameController.dispose();
    _medicationDosageController.dispose();
    _medicationFrequencyController.dispose();
    _medicationPurposeController.dispose();
    _vetNameController.dispose();
    _clinicNameController.dispose();
    _visitDiagnosisController.dispose();
    _visitTreatmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildModernHeader(),
            _buildProgressIndicator(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildConditionsStep(),
                    _buildMedicationsAndAllergiesStep(),
                    _buildVetHistoryStep(),
                  ],
                ),
              ),
            ),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ClovaraColors.forest,
            ClovaraColors.forest.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: ClovaraColors.forest.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: ClovaraColors.clover.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ClovaraColors.clover.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pets,
                        color: ClovaraColors.clover,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.pet.name,
                        style: ClovaraTypography.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Medical History',
              style: ClovaraTypography.h2.copyWith(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Help us understand ${widget.pet.name}\'s health better',
              style: ClovaraTypography.body.copyWith(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isActive = index == _currentStep;
              final isCompleted = index < _currentStep;
              
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        height: 6,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: isCompleted || isActive
                              ? LinearGradient(
                                  colors: [
                                    ClovaraColors.clover,
                                    ClovaraColors.clover.withOpacity(0.8),
                                  ],
                                )
                              : null,
                          color: !(isCompleted || isActive) 
                              ? const Color(0xFFE0E0E0) 
                              : null,
                        ),
                      ),
                    ),
                    if (index < _totalSteps - 1) const SizedBox(width: 12),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getStepTitle(_currentStep),
                    style: ClovaraTypography.h3.copyWith(
                      color: ClovaraColors.forest,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStepDescription(_currentStep),
                    style: ClovaraTypography.body.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: ClovaraColors.clover.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: ClovaraColors.clover.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '${_currentStep + 1}/$_totalSteps',
                  style: ClovaraTypography.h3.copyWith(
                    color: ClovaraColors.clover,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Medical Conditions';
      case 1:
        return 'Medications & Allergies';
      case 2:
        return 'Veterinary History';
      default:
        return '';
    }
  }

  String _getStepDescription(int step) {
    switch (step) {
      case 0:
        return 'Current or past health conditions';
      case 1:
        return 'Treatment and known sensitivities';
      case 2:
        return 'Recent veterinary care';
      default:
        return '';
    }
  }

  Widget _buildConditionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_conditions.isEmpty)
            _buildEmptyState(
              icon: Icons.favorite_outline,
              title: 'No conditions yet',
              message: 'Add any medical conditions ${widget.pet.name} has or had',
            )
          else
            ..._conditions.map((condition) => _buildConditionCard(condition)),
          const SizedBox(height: 20),
          _buildModernAddButton(
            label: 'Add Medical Condition',
            icon: Icons.add_rounded,
            onPressed: _showAddConditionDialog,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMedicationsAndAllergiesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Medications Section
          Text(
            'Current Medications',
            style: ClovaraTypography.h3.copyWith(
              color: ClovaraColors.forest,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          if (_medications.isEmpty)
            _buildEmptyState(
              icon: Icons.medication_outlined,
              title: 'No medications yet',
              message: 'Add medications ${widget.pet.name} is currently taking',
            )
          else
            ..._medications.map((med) => _buildMedicationCard(med)),
          const SizedBox(height: 16),
          _buildModernAddButton(
            label: 'Add Medication',
            icon: Icons.add_rounded,
            onPressed: _showAddMedicationDialog,
          ),
          const SizedBox(height: 32),
          
          // Allergies Section
          Text(
            'Known Allergies',
            style: ClovaraTypography.h3.copyWith(
              color: ClovaraColors.forest,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          if (_allergies.isEmpty)
            _buildEmptyState(
              icon: Icons.warning_amber_rounded,
              title: 'No allergies recorded',
              message: 'List any known allergies or sensitivities',
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _allergies.map((allergy) => _buildModernAllergyChip(allergy)).toList(),
            ),
          const SizedBox(height: 16),
          _buildModernAddButton(
            label: 'Add Allergy',
            icon: Icons.add_rounded,
            onPressed: _showAddAllergyDialog,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildVetHistoryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_vetVisits.isEmpty)
            _buildEmptyState(
              icon: Icons.local_hospital_outlined,
              title: 'No visits recorded',
              message: 'Add recent veterinary visits and examinations',
            )
          else
            ..._vetVisits.map((visit) => _buildVetVisitCard(visit)),
          const SizedBox(height: 20),
          _buildModernAddButton(
            label: 'Add Vet Visit',
            icon: Icons.add_rounded,
            onPressed: _showAddVetVisitDialog,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ClovaraColors.clover.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 40,
              color: ClovaraColors.clover,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: ClovaraTypography.h3.copyWith(
              color: ClovaraColors.forest,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: ClovaraTypography.body.copyWith(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAddButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ClovaraColors.clover.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: ClovaraColors.clover.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ClovaraColors.clover.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: ClovaraColors.clover,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: ClovaraTypography.h3.copyWith(
                color: ClovaraColors.clover,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionCard(MedicalCondition condition) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(condition.status).withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(condition.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.medical_services_rounded,
                  color: _getStatusColor(condition.status),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      condition.name,
                      style: ClovaraTypography.h3.copyWith(
                        color: ClovaraColors.forest,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(condition.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            condition.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(condition.status),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(condition.diagnosisDate),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                onPressed: () => _removeCondition(condition),
                tooltip: 'Remove',
              ),
            ],
          ),
          if (condition.treatment != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.healing_rounded,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      condition.treatment!,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicationCard(Medication medication) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4A90E2).withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: Color(0xFF4A90E2),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            medication.name,
                            style: ClovaraTypography.h3.copyWith(
                              color: ClovaraColors.forest,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (medication.isOngoing)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'ONGOING',
                              style: TextStyle(
                                color: const Color(0xFF4CAF50),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${medication.dosage} • ${medication.frequency}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                onPressed: () => _removeMedication(medication),
                tooltip: 'Remove',
              ),
            ],
          ),
          if (medication.purpose != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      medication.purpose!,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernAllergyChip(String allergy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF9800).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9800).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: const Color(0xFFFF9800),
          ),
          const SizedBox(width: 8),
          Text(
            allergy,
            style: TextStyle(
              color: ClovaraColors.forest,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _removeAllergy(allergy),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVetVisitCard(VetVisit visit) {
    final visitColor = _getVisitTypeColor(visit.visitType);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: visitColor.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: visitColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getVisitTypeIcon(visit.visitType),
                  color: visitColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: visitColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            visit.visitType.toUpperCase(),
                            style: TextStyle(
                              color: visitColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(visit.visitDate),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      visit.clinic,
                      style: ClovaraTypography.h3.copyWith(
                        color: ClovaraColors.forest,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dr. ${visit.veterinarian}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                onPressed: () => _removeVetVisit(visit),
                tooltip: 'Remove',
              ),
            ],
          ),
          if (visit.diagnosis != null || visit.treatment != null) ...[
            const SizedBox(height: 16),
            if (visit.diagnosis != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.assignment_rounded,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Diagnosis',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            visit.diagnosis!,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (visit.treatment != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.healing_rounded,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Treatment',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            visit.treatment!,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.red;
      case 'managed':
      case 'stable':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getVisitTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'emergency':
        return Colors.red;
      case 'surgery':
        return Colors.purple;
      case 'checkup':
      case 'vaccination':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _getVisitTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'emergency':
        return Icons.emergency;
      case 'surgery':
        return Icons.medical_services;
      case 'vaccination':
        return Icons.vaccines;
      default:
        return Icons.local_hospital;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ClovaraColors.forest.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _previousStep,
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.arrow_back_ios_rounded,
                              color: ClovaraColors.forest,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Back',
                              style: ClovaraTypography.h3.copyWith(
                                color: ClovaraColors.forest,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              flex: _currentStep > 0 ? 2 : 1,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ClovaraColors.clover,
                      ClovaraColors.clover.withOpacity(0.9),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: ClovaraColors.clover.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _currentStep < _totalSteps - 1 ? _nextStep : _complete,
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep < _totalSteps - 1 ? 'Continue' : 'Complete & View Plans',
                            style: ClovaraTypography.h3.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _fadeController.reverse().then((_) {
        setState(() {
          _currentStep++;
        });
        _pageController.jumpToPage(_currentStep);
        _fadeController.forward();
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _fadeController.reverse().then((_) {
        setState(() {
          _currentStep--;
        });
        _pageController.jumpToPage(_currentStep);
        _fadeController.forward();
      });
    }
  }

  void _complete() {
    // Create updated pet with medical history
    final updatedPet = widget.pet.copyWith(
      medicalConditions: _conditions,
      medications: _medications,
      allergies: _allergies,
      vetHistory: _vetVisits,
      isReceivingTreatment: _medications.any((m) => m.isOngoing),
    );

    // Navigate to plan selection with updated pet data
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const PlanSelectionScreen(),
        settings: RouteSettings(
          arguments: {
            'petData': updatedPet.toJson(),
            'pet': updatedPet,
            'riskScore': widget.riskScore,
            ...?widget.quoteData,
          },
        ),
      ),
    );
  }

  // Dialog methods
  void _showAddConditionDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildConditionDialog(),
    );
  }

  void _showAddMedicationDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildMedicationDialog(),
    );
  }

  void _showAddAllergyDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildAllergyDialog(),
    );
  }

  void _showAddVetVisitDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildVetVisitDialog(),
    );
  }

  Widget _buildConditionDialog() {
    return AlertDialog(
      title: const Text('Add Medical Condition'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _conditionNameController,
              decoration: const InputDecoration(
                labelText: 'Condition Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Diagnosis Date'),
              subtitle: Text(_conditionDiagnosisDate != null 
                  ? _formatDate(_conditionDiagnosisDate!)
                  : 'Select date'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _conditionDiagnosisDate = date);
                  Navigator.pop(context);
                  _showAddConditionDialog();
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _conditionStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: ['active', 'managed', 'stable', 'resolved']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _conditionStatus = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _conditionTreatmentController,
              decoration: const InputDecoration(
                labelText: 'Treatment',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _conditionNotesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _clearConditionForm();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_conditionNameController.text.isNotEmpty && 
                _conditionDiagnosisDate != null) {
              _addCondition();
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildMedicationDialog() {
    return AlertDialog(
      title: const Text('Add Medication'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _medicationNameController,
              decoration: const InputDecoration(
                labelText: 'Medication Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _medicationDosageController,
              decoration: const InputDecoration(
                labelText: 'Dosage *',
                hintText: 'e.g., 75mg',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _medicationFrequencyController,
              decoration: const InputDecoration(
                labelText: 'Frequency *',
                hintText: 'e.g., twice daily',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _medicationPurposeController,
              decoration: const InputDecoration(
                labelText: 'Purpose',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Ongoing'),
              value: _medicationIsOngoing,
              onChanged: (value) {
                setState(() => _medicationIsOngoing = value ?? true);
                Navigator.pop(context);
                _showAddMedicationDialog();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _clearMedicationForm();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_medicationNameController.text.isNotEmpty &&
                _medicationDosageController.text.isNotEmpty &&
                _medicationFrequencyController.text.isNotEmpty) {
              _addMedication();
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildAllergyDialog() {
    return AlertDialog(
      title: const Text('Add Allergy'),
      content: TextField(
        controller: _allergyController,
        decoration: const InputDecoration(
          labelText: 'Allergy',
          hintText: 'e.g., Penicillin, Chicken',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () {
            _allergyController.clear();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_allergyController.text.isNotEmpty) {
              _addAllergy();
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  Widget _buildVetVisitDialog() {
    return AlertDialog(
      title: const Text('Add Vet Visit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Visit Date'),
              subtitle: Text(_visitDate != null 
                  ? _formatDate(_visitDate!)
                  : 'Select date'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _visitDate = date);
                  Navigator.pop(context);
                  _showAddVetVisitDialog();
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _visitType,
              decoration: const InputDecoration(
                labelText: 'Visit Type',
                border: OutlineInputBorder(),
              ),
              items: ['checkup', 'emergency', 'surgery', 'follow-up', 'vaccination']
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _visitType = value);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _vetNameController,
              decoration: const InputDecoration(
                labelText: 'Veterinarian *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _clinicNameController,
              decoration: const InputDecoration(
                labelText: 'Clinic Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _visitDiagnosisController,
              decoration: const InputDecoration(
                labelText: 'Diagnosis/Reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _visitTreatmentController,
              decoration: const InputDecoration(
                labelText: 'Treatment',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _clearVetVisitForm();
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_visitDate != null &&
                _vetNameController.text.isNotEmpty &&
                _clinicNameController.text.isNotEmpty) {
              _addVetVisit();
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  // Add/Remove methods
  void _addCondition() {
    setState(() {
      _conditions.add(MedicalCondition(
        id: 'cond_${DateTime.now().millisecondsSinceEpoch}',
        name: _conditionNameController.text,
        diagnosisDate: _conditionDiagnosisDate!,
        status: _conditionStatus,
        treatment: _conditionTreatmentController.text.isEmpty 
            ? null 
            : _conditionTreatmentController.text,
        notes: _conditionNotesController.text.isEmpty 
            ? null 
            : _conditionNotesController.text,
      ));
    });
    _clearConditionForm();
  }

  void _removeCondition(MedicalCondition condition) {
    setState(() {
      _conditions.remove(condition);
    });
  }

  void _clearConditionForm() {
    _conditionNameController.clear();
    _conditionTreatmentController.clear();
    _conditionNotesController.clear();
    _conditionDiagnosisDate = null;
    _conditionStatus = 'active';
  }

  void _addMedication() {
    setState(() {
      _medications.add(Medication(
        id: 'med_${DateTime.now().millisecondsSinceEpoch}',
        name: _medicationNameController.text,
        dosage: _medicationDosageController.text,
        frequency: _medicationFrequencyController.text,
        startDate: _medicationStartDate ?? DateTime.now(),
        purpose: _medicationPurposeController.text.isEmpty 
            ? null 
            : _medicationPurposeController.text,
        isOngoing: _medicationIsOngoing,
      ));
    });
    _clearMedicationForm();
  }

  void _removeMedication(Medication medication) {
    setState(() {
      _medications.remove(medication);
    });
  }

  void _clearMedicationForm() {
    _medicationNameController.clear();
    _medicationDosageController.clear();
    _medicationFrequencyController.clear();
    _medicationPurposeController.clear();
    _medicationStartDate = null;
    _medicationIsOngoing = true;
  }

  void _addAllergy() {
    setState(() {
      _allergies.add(_allergyController.text);
    });
    _allergyController.clear();
  }

  void _removeAllergy(String allergy) {
    setState(() {
      _allergies.remove(allergy);
    });
  }

  void _addVetVisit() {
    setState(() {
      _vetVisits.add(VetVisit(
        id: 'visit_${DateTime.now().millisecondsSinceEpoch}',
        visitDate: _visitDate!,
        veterinarian: _vetNameController.text,
        clinic: _clinicNameController.text,
        visitType: _visitType,
        diagnosis: _visitDiagnosisController.text.isEmpty 
            ? null 
            : _visitDiagnosisController.text,
        treatment: _visitTreatmentController.text.isEmpty 
            ? null 
            : _visitTreatmentController.text,
      ));
    });
    _clearVetVisitForm();
  }

  void _removeVetVisit(VetVisit visit) {
    setState(() {
      _vetVisits.remove(visit);
    });
  }

  void _clearVetVisitForm() {
    _vetNameController.clear();
    _clinicNameController.clear();
    _visitDiagnosisController.clear();
    _visitTreatmentController.clear();
    _visitDate = null;
    _visitType = 'checkup';
  }
}
