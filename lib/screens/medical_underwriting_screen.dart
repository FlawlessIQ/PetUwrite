import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ai/ai_service.dart';
import '../models/owner.dart';
import '../models/pet.dart';
import '../models/medical_history.dart';
import '../models/risk_score.dart';
import '../models/underwriting_case.dart';
import '../models/underwriting_decision.dart';
import '../models/underwriting_medical_history.dart';
import '../models/policy_exclusion.dart';
import '../models/underwriting_status.dart';
import '../services/underwriting_case_service.dart';
import '../services/marketing_attribution_service.dart';
import '../services/underwriting_integrity_engine.dart';
import '../services/medical_facts_builder.dart';
import '../services/medical_condition_fact_mapper.dart';
import '../services/vet_history_parser.dart' hide Medication;
import '../services/vet_document_reuse_detector.dart';
import '../services/user_session_service.dart';
import '../services/draft_service.dart';
import '../ui/components/save_resume_dialog.dart';
import '../theme/clovara_theme.dart';
import '../ui/components/clovara_logo.dart';
import '../widgets/underwriting_disclosure_dialog.dart';
import '../ui/components/max_width.dart';
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
  State<MedicalUnderwritingScreen> createState() =>
      _MedicalUnderwritingScreenState();
}

class _VetAutofillResult {
  final int conditionsAdded;
  final int medicationsAdded;
  final int vetVisitsAdded;
  final int allergiesAdded;

  const _VetAutofillResult({
    required this.conditionsAdded,
    required this.medicationsAdded,
    required this.vetVisitsAdded,
    required this.allergiesAdded,
  });
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
  bool _conditionIsCongenital = false;

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

  bool _isUploadingVetRecord = false;
  String? _vetUploadStatus;

  static const Set<String> _genericQuoteConditionLabels = {
    'allergies / skin',
    'joint / mobility',
    'digestive',
    'heart',
    'cancer',
    'diabetes',
    'thyroid',
    'kidney / urinary',
    'other',
  };

  // Raw vet text backstop for deterministic keyword extraction.
  final List<String> _rawVetTexts = [];

  // Keep a copy of parsed AI vet extraction (if available).
  final List<VetRecordData> _aiVetExtraction = [];
  final List<String> _vetDocumentHashes = [];

  bool _aiVetParseFailed = false;

  // Self-serve, zero-human underwriting state.
  bool _needsMoreInfo = false;
  List<Map<String, dynamic>> _requiredEvidenceJson = const [];
  bool _autoReassessInProgress = false;

  Future<void> _autoReassessAfterUpload() async {
    if (!_needsMoreInfo) return;
    if (_autoReassessInProgress) return;
    if (_isUploadingVetRecord) return;

    _autoReassessInProgress = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      _complete();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    } finally {
      _autoReassessInProgress = false;
    }
  }

  // We keep a local, mutable copy of route args so we can attach a newly
  // created underwritingCaseId during this screen (e.g. for uploads).
  late Map<String, dynamic> _routeArguments;
  String? _underwritingCaseId;

  // Conditions that generally require additional medical details before we can
  // responsibly show plans (e.g., chronic or historically high-impact).
  static const Set<String> _highDetailConditions = {
    'Diabetes',
    'Heart Disease',
    'Kidney Disease',
    'Cancer (history)',
    'Hip Dysplasia',
    'Arthritis',
  };

  // Deterministic loop-breaker: after N unresolved NEED_MORE_INFO cycles,
  // we decline (zero-human flow, prevents infinite retries).
  static const int _maxNeedMoreInfoAttempts = 3;

  // NOTE: We intentionally do not ask customers to self-determine clinical
  // facts like severity/chronicity. When more detail is needed, underwriting
  // deterministically requests verifiable evidence (vet records).

  @override
  void initState() {
    super.initState();
    _routeArguments = {...?widget.quoteData};
    _underwritingCaseId = widget.quoteData?['underwritingCaseId']?.toString();
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
          _upsertMedicalCondition(
            MedicalCondition(
              id: 'cond_${DateTime.now().millisecondsSinceEpoch}',
              name: conditionName,
              diagnosisDate: DateTime.now().subtract(const Duration(days: 365)),
              status: 'active',
            ),
          );
        }
      }
    }

    // Copy existing medical data if available
    if (widget.pet.medicalConditions != null) {
      _conditions = List.from(widget.pet.medicalConditions!);
      _dedupeConditionsInPlace();
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

  String _normalizeConditionNameForKey(String value) {
    var v = value.toLowerCase().trim();
    if (v.isEmpty) return '';

    // Expand common abbreviations seen in vet records.
    v = v
        .replaceAll('ccl', 'cranial cruciate ligament')
        .replaceAll('acl', 'anterior cruciate ligament');

    // Replace punctuation with spaces.
    v = v.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    v = v.replaceAll(RegExp(r'\s+'), ' ').trim();

    return v;
  }

  /// Creates a deduplication key for conditions.
  ///
  /// Goal: treat "ruptured cruciate ligament" and
  /// "cranial cruciate ligament rupture (right stifle)" as the same condition.
  ///
  /// This is intentionally conservative: it removes laterality and severity
  /// descriptors but keeps core medical terms.
  String _conditionDedupKey(String name) {
    final normalized = _normalizeConditionNameForKey(name);
    if (normalized.isEmpty) return '';

    const stopwords = <String>{
      // General descriptors
      'suspected',
      'possible',
      'likely',
      'history',
      'hx',
      'chronic',
      'acute',
      'recurrent',
      'previous',
      'prior',
      'old',
      'new',
      'mild',
      'moderate',
      'severe',
      'partial',
      'complete',
      'resolved',
      'stable',
      'managed',
      // Injury descriptors
      'rupture',
      'ruptured',
      'tear',
      'torn',
      'injury',
      'injured',
      'sprain',
      'strain',
      // Laterality / anatomy qualifiers
      'left',
      'right',
      'bilateral',
      'cranial',
      'caudal',
      'anterior',
      'posterior',
      'stifle',
      'knee',
      'joint',
      'leg',
      'hind',
      'front',
      // Noise tokens
      'status',
      'post',
      'op',
      'postop',
      'postoperative',
      'sp',
    };

    final tokens =
        normalized
            .split(' ')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .where((t) => t.length > 2)
            .where((t) => !stopwords.contains(t))
            .toSet()
            .toList()
          ..sort();

    return tokens.join(' ');
  }

  String? _conditionFamilyKey(String name) {
    final normalized = _normalizeConditionNameForKey(name);
    if (normalized.isEmpty) return null;

    bool hasAny(List<String> tokens) =>
        tokens.any((token) => normalized.contains(token));

    if (hasAny(const [
      'joint',
      'mobility',
      'orthopedic',
      'arthritis',
      'arthritic',
      'hip',
      'elbow',
      'stifle',
      'patella',
      'patellar',
      'luxation',
      'cruciate',
      'ligament',
      'lameness',
      'limping',
      'dysplasia',
    ])) {
      return 'orthopedic_joint_mobility';
    }

    if (hasAny(const [
      'allerg',
      'skin',
      'dermat',
      'itch',
      'otitis',
      'ear infection',
      'hot spot',
      'rash',
    ])) {
      return 'allergies_skin';
    }

    if (hasAny(const [
      'digest',
      'gastro',
      'gi ',
      'vomit',
      'diarr',
      'pancrea',
      'ibd',
      'stomach',
      'intestinal',
    ])) {
      return 'digestive';
    }

    if (hasAny(const ['cardiac', 'heart', 'murmur', 'chf', 'cardiomyopathy'])) {
      return 'heart';
    }

    if (hasAny(const [
      'cancer',
      'tumor',
      'tumour',
      'lymphoma',
      'carcinoma',
      'sarcoma',
      'mass',
    ])) {
      return 'cancer';
    }

    if (hasAny(const ['diabetes', 'diabetic'])) {
      return 'diabetes';
    }

    if (hasAny(const ['thyroid', 'hyperthyroid', 'hypothyroid'])) {
      return 'thyroid';
    }

    if (hasAny(const [
      'kidney',
      'renal',
      'urinary',
      'bladder',
      'uti',
      'cystitis',
    ])) {
      return 'kidney_urinary';
    }

    return null;
  }

  bool _isGenericConditionLabel(String name) {
    final normalized = _normalizeConditionNameForKey(name);
    return _genericQuoteConditionLabels.contains(normalized);
  }

  bool _shouldTreatAsSameCondition(String existingName, String incomingName) {
    final existingFamily = _conditionFamilyKey(existingName);
    final incomingFamily = _conditionFamilyKey(incomingName);
    if (existingFamily != null && existingFamily == incomingFamily) {
      return true;
    }

    final existingCode = MedicalConditionFactMapper.conditionCodeFromName(
      existingName,
    );
    final incomingCode = MedicalConditionFactMapper.conditionCodeFromName(
      incomingName,
    );
    return existingCode.isNotEmpty && existingCode == incomingCode;
  }

  bool _isPlaceholderDiagnosisDate(DateTime date) {
    // Quote-flow seeded conditions default to roughly "one year ago".
    final now = DateTime.now();
    final diffDays = now.difference(date).inDays.abs();
    return (diffDays - 365).abs() <= 3;
  }

  /// Upsert a condition into `_conditions`.
  /// If a "duplicate" exists (based on dedup key), we merge into the existing
  /// item and prefer the more detailed name.
  bool _upsertMedicalCondition(MedicalCondition incoming) {
    return _upsertMedicalConditionInto(_conditions, incoming);
  }

  bool _upsertMedicalConditionInto(
    List<MedicalCondition> conditions,
    MedicalCondition incoming,
  ) {
    final incomingName = incoming.name.trim();
    if (incomingName.isEmpty) return false;

    final incomingKey = _conditionDedupKey(incomingName);
    final incomingNorm = _normalizeConditionNameForKey(incomingName);

    int index = -1;
    for (var i = 0; i < conditions.length; i++) {
      final existingName = conditions[i].name.trim();
      if (existingName.isEmpty) continue;
      final existingKey = _conditionDedupKey(existingName);
      if (incomingKey.isNotEmpty && existingKey.isNotEmpty) {
        if (incomingKey == existingKey ||
            _shouldTreatAsSameCondition(existingName, incomingName)) {
          index = i;
          break;
        }
      } else {
        if (_normalizeConditionNameForKey(existingName) == incomingNorm ||
            _shouldTreatAsSameCondition(existingName, incomingName)) {
          index = i;
          break;
        }
      }
    }

    if (index == -1) {
      conditions.add(incoming);
      return true;
    }

    final existing = conditions[index];

    final existingName = existing.name.trim();
    final existingIsGeneric = _isGenericConditionLabel(existingName);
    final incomingIsGeneric = _isGenericConditionLabel(incomingName);
    final shouldReplaceName =
        (existingIsGeneric && !incomingIsGeneric) ||
        (!incomingIsGeneric && incomingName.length > (existingName.length + 6));

    DateTime diagnosisDate = existing.diagnosisDate;
    if (_isPlaceholderDiagnosisDate(existing.diagnosisDate) &&
        !_isPlaceholderDiagnosisDate(incoming.diagnosisDate)) {
      diagnosisDate = incoming.diagnosisDate;
    } else {
      diagnosisDate = existing.diagnosisDate.isBefore(incoming.diagnosisDate)
          ? existing.diagnosisDate
          : incoming.diagnosisDate;
    }

    final merged = existing.copyWith(
      name: shouldReplaceName ? incomingName : existing.name,
      diagnosisDate: diagnosisDate,
      status: (existing.status == 'resolved' || existing.status == 'managed')
          ? existing.status
          : incoming.status,
      isCongenital: existing.isCongenital || incoming.isCongenital,
      treatment:
          (existing.treatment == null || existing.treatment!.trim().isEmpty)
          ? incoming.treatment
          : existing.treatment,
      notes: (existing.notes == null || existing.notes!.trim().isEmpty)
          ? incoming.notes
          : existing.notes,
      veterinarian: existing.veterinarian ?? incoming.veterinarian,
      lastCheckup: existing.lastCheckup ?? incoming.lastCheckup,
    );

    conditions[index] = merged;
    return false;
  }

  void _dedupeConditionsInPlace() {
    final original = List<MedicalCondition>.from(_conditions);
    final deduped = <MedicalCondition>[];
    for (final condition in original) {
      _upsertMedicalConditionInto(deduped, condition);
    }
    _conditions = deduped;
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
      backgroundColor: ClovaraColors.mist,
      body: SafeArea(
        child: Column(
          children: [
            _buildCompactHeader(),
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

  Widget _buildCompactHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: ClovaraColors.forest,
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
                const ClovaraLogo(size: ClovaraLogoSize.small, showText: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medical History',
                        style: ClovaraTypography.h3.copyWith(
                          color: ClovaraColors.forest,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.pet.name} · ${_getStepTitle(_currentStep)}',
                        style: ClovaraTypography.bodySmall.copyWith(
                          color: ClovaraColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: ClovaraColors.clover.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Step ${_currentStep + 1} of $_totalSteps',
                    style: ClovaraTypography.label.copyWith(
                      color: ClovaraColors.clover,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildProgressBar(),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
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
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isCompleted || isActive
                        ? ClovaraColors.clover
                        : ClovaraColors.border,
                  ),
                ),
              ),
              if (index < _totalSteps - 1) const SizedBox(width: 8),
            ],
          ),
        );
      }),
    );
  }

  // Progress indicator is now integrated into _buildCompactHeader via _buildProgressBar.

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

  Widget _buildConditionsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVetRecordUploadCard(),
            const SizedBox(height: 16),
            if (_conditions.isEmpty)
              _buildEmptyState(
                icon: Icons.favorite_outline,
                title: 'No conditions yet',
                message:
                    'Add any medical conditions ${widget.pet.name} has or had',
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
      ),
    );
  }

  Widget _buildMedicationsAndAllergiesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medications Section
            Text(
              'Current Medications',
              style: ClovaraTypography.h3.copyWith(
                color: ClovaraColors.forest,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_medications.isEmpty)
              _buildEmptyState(
                icon: Icons.medication_outlined,
                title: 'No medications yet',
                message:
                    'Add medications ${widget.pet.name} is currently taking',
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
                children: _allergies
                    .map((allergy) => _buildModernAllergyChip(allergy))
                    .toList(),
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
      ),
    );
  }

  Widget _buildVetHistoryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVetRecordUploadCard(),
            const SizedBox(height: 16),
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
      ),
    );
  }

  Widget _buildVetRecordUploadCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: ClovaraColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ClovaraColors.clover.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.upload_file_rounded,
                    color: ClovaraColors.clover,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload vet records',
                        style: ClovaraTypography.body.copyWith(
                          color: ClovaraColors.forest,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Add PDFs or photos (vet letters, discharge notes, invoices).',
                        style: ClovaraTypography.bodySmall.copyWith(
                          color: ClovaraColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isUploadingVetRecord
                        ? null
                        : _uploadVetRecordPdfs,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClovaraColors.forest,
                      side: BorderSide(color: ClovaraColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isUploadingVetRecord
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Choose PDF(s)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isUploadingVetRecord
                        ? null
                        : _uploadVetRecordImages,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClovaraColors.forest,
                      side: BorderSide(color: ClovaraColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isUploadingVetRecord
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add photo(s)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isUploadingVetRecord
                    ? null
                    : (kIsWeb ? null : _takeVetRecordPhoto),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ClovaraColors.forest,
                  side: BorderSide(color: ClovaraColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  kIsWeb ? 'Take photo (not supported on web)' : 'Take photo',
                ),
              ),
            ),
            if (_vetUploadStatus != null) ...[
              const SizedBox(height: 12),
              _buildVetUploadStatusBanner(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVetUploadStatusBanner() {
    final message = _vetUploadStatus;
    if (message == null || message.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final lower = message.toLowerCase();
    final isError = lower.contains('failed') || lower.contains('error');
    final isSuccess =
        !isError &&
        (lower.contains('applied') ||
            lower.contains('uploaded') ||
            lower.contains('parsed'));
    final accent = isError
        ? ClovaraColors.error
        : _isUploadingVetRecord
        ? ClovaraColors.clover
        : isSuccess
        ? ClovaraColors.success
        : ClovaraColors.forest;
    final background = isError
        ? ClovaraColors.error.withOpacity(0.08)
        : _isUploadingVetRecord
        ? ClovaraColors.clover.withOpacity(0.06)
        : isSuccess
        ? ClovaraColors.success.withOpacity(0.08)
        : ClovaraColors.mist;
    final title = isError
        ? 'We hit a problem with this upload'
        : _isUploadingVetRecord
        ? 'Parsing vet records...'
        : isSuccess
        ? 'Vet record update complete'
        : 'Vet record status';
    final icon = isError
        ? Icons.error_outline_rounded
        : _isUploadingVetRecord
        ? Icons.hourglass_top_rounded
        : Icons.check_circle_outline_rounded;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isUploadingVetRecord)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                )
              else
                Icon(icon, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ClovaraTypography.body.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: ClovaraTypography.body.copyWith(
                        color: Colors.grey.shade800,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isUploadingVetRecord) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: const LinearProgressIndicator(minHeight: 5),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _uploadVetRecordPdfs() async {
    setState(() {
      _isUploadingVetRecord = true;
      _vetUploadStatus = null;
    });

    bool looksEmpty(VetRecordData parsed) {
      return parsed.diagnoses.isEmpty &&
          parsed.treatments.isEmpty &&
          parsed.medications.isEmpty &&
          parsed.vaccinations.isEmpty &&
          parsed.surgeries.isEmpty &&
          parsed.allergies.isEmpty &&
          parsed.previousClaims.isEmpty &&
          parsed.lastCheckup == null;
    }

    try {
      setState(() {
        _vetUploadStatus = 'Opening file picker…';
      });

      final result = await FilePicker.platform
          .pickFiles(
            type: FileType.custom,
            allowedExtensions: const ['pdf'],
            withData: true,
            allowMultiple: true,
          )
          .timeout(const Duration(seconds: 20), onTimeout: () => null);

      if (result == null || result.files.isEmpty) {
        if (!mounted) return;
        setState(() => _isUploadingVetRecord = false);
        return;
      }

      final parser = VetHistoryParser(aiService: GPTService());
      final caseId = await _ensureUnderwritingCaseId();
      final petId = widget.pet.id;

      var totalConditions = 0;
      var totalMedications = 0;
      var totalVisits = 0;
      var totalAllergies = 0;
      final failures = <String, String>{};

      String shorten(String value, {int max = 120}) {
        final v = value.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (v.length <= max) return v;
        return '${v.substring(0, max)}…';
      }

      for (var i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        final bytes = file.bytes;
        if (bytes == null) {
          failures[file.name] = 'No bytes available from picker';
          continue;
        }

        if (!mounted) return;
        setState(() {
          _vetUploadStatus =
              'Uploading and parsing PDF ${i + 1}/${result.files.length}: ${file.name}…';
        });

        try {
          final result = await parser.parseUploadedPdfBytesForCaseLenient(
            pdfBytes: Uint8List.fromList(bytes),
            caseId: caseId,
            petId: petId,
            filename: file.name,
          );

          // Backstop keyword extraction always uses extractedText.
          _rawVetTexts.add(result.extractedText);
          // If AI parse succeeded, keep structured extraction too.
          _aiVetExtraction.add(result.parsedData);
          if (result.documentHash.trim().isNotEmpty) {
            _vetDocumentHashes.add(result.documentHash);
          }
          if (result.aiFailed) _aiVetParseFailed = true;

          final autofill = looksEmpty(result.parsedData)
              ? const _VetAutofillResult(
                  conditionsAdded: 0,
                  medicationsAdded: 0,
                  vetVisitsAdded: 0,
                  allergiesAdded: 0,
                )
              : _applyVetRecordAutofill(result.parsedData);

          totalConditions += autofill.conditionsAdded;
          totalMedications += autofill.medicationsAdded;
          totalVisits += autofill.vetVisitsAdded;
          totalAllergies += autofill.allergiesAdded;
        } catch (e) {
          failures[file.name] = shorten(e.toString());
          _aiVetParseFailed = true;
        }
      }

      if (!mounted) return;
      setState(() {
        var failureNote = '';
        if (failures.isNotEmpty) {
          final example = failures.entries.first;
          failureNote =
              ' (${failures.length} file(s) failed; e.g. ${example.key}: ${example.value})';
        }
        _vetUploadStatus =
            'Vet records applied: $totalConditions condition(s), '
            '$totalMedications medication(s), '
            '$totalVisits visit(s), '
            '$totalAllergies allergy item(s)$failureNote.';
        _isUploadingVetRecord = false;
      });

      await _autoReassessAfterUpload();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vetUploadStatus = 'Upload failed: $e';
        _isUploadingVetRecord = false;
        _aiVetParseFailed = true;
      });
    }
  }

  Future<void> _uploadVetRecordImages() async {
    setState(() {
      _isUploadingVetRecord = true;
      _vetUploadStatus = null;
    });

    bool looksEmpty(VetRecordData parsed) {
      return parsed.diagnoses.isEmpty &&
          parsed.treatments.isEmpty &&
          parsed.medications.isEmpty &&
          parsed.vaccinations.isEmpty &&
          parsed.surgeries.isEmpty &&
          parsed.allergies.isEmpty &&
          parsed.previousClaims.isEmpty &&
          parsed.lastCheckup == null;
    }

    try {
      setState(() {
        _vetUploadStatus = 'Opening image picker…';
      });

      final result = await FilePicker.platform
          .pickFiles(
            type: FileType.custom,
            allowedExtensions: const ['png', 'jpg', 'jpeg'],
            withData: true,
            allowMultiple: true,
          )
          .timeout(const Duration(seconds: 20), onTimeout: () => null);

      if (result == null || result.files.isEmpty) {
        if (!mounted) return;
        setState(() => _isUploadingVetRecord = false);
        return;
      }

      final parser = VetHistoryParser(aiService: GPTService());
      final caseId = await _ensureUnderwritingCaseId();
      final petId = widget.pet.id;

      var totalConditions = 0;
      var totalMedications = 0;
      var totalVisits = 0;
      var totalAllergies = 0;
      final failures = <String, String>{};

      String shorten(String value, {int max = 120}) {
        final v = value.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (v.length <= max) return v;
        return '${v.substring(0, max)}…';
      }

      for (var i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        final bytes = file.bytes;
        if (bytes == null) {
          failures[file.name] = 'No bytes available from picker';
          continue;
        }

        if (!mounted) return;
        setState(() {
          _vetUploadStatus =
              'Uploading and parsing image ${i + 1}/${result.files.length}: ${file.name}…';
        });

        try {
          final result = await parser.parseUploadedImageBytesForCaseLenient(
            imageBytes: Uint8List.fromList(bytes),
            caseId: caseId,
            petId: petId,
            filename: file.name,
          );

          _rawVetTexts.add(result.extractedText);
          _aiVetExtraction.add(result.parsedData);
          if (result.documentHash.trim().isNotEmpty) {
            _vetDocumentHashes.add(result.documentHash);
          }
          if (result.aiFailed) _aiVetParseFailed = true;

          final autofill = looksEmpty(result.parsedData)
              ? const _VetAutofillResult(
                  conditionsAdded: 0,
                  medicationsAdded: 0,
                  vetVisitsAdded: 0,
                  allergiesAdded: 0,
                )
              : _applyVetRecordAutofill(result.parsedData);

          totalConditions += autofill.conditionsAdded;
          totalMedications += autofill.medicationsAdded;
          totalVisits += autofill.vetVisitsAdded;
          totalAllergies += autofill.allergiesAdded;
        } catch (e) {
          failures[file.name] = shorten(e.toString());
          _aiVetParseFailed = true;
        }
      }

      if (!mounted) return;
      setState(() {
        var failureNote = '';
        if (failures.isNotEmpty) {
          final example = failures.entries.first;
          failureNote =
              ' (${failures.length} file(s) failed; e.g. ${example.key}: ${example.value})';
        }
        _vetUploadStatus =
            'Vet photos applied: $totalConditions condition(s), '
            '$totalMedications medication(s), '
            '$totalVisits visit(s), '
            '$totalAllergies allergy item(s)$failureNote.';
        _isUploadingVetRecord = false;
      });

      await _autoReassessAfterUpload();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vetUploadStatus = 'Upload failed: $e';
        _isUploadingVetRecord = false;
        _aiVetParseFailed = true;
      });
    }
  }

  Future<void> _takeVetRecordPhoto() async {
    setState(() {
      _isUploadingVetRecord = true;
      _vetUploadStatus = null;
    });

    bool looksEmpty(VetRecordData parsed) {
      return parsed.diagnoses.isEmpty &&
          parsed.treatments.isEmpty &&
          parsed.medications.isEmpty &&
          parsed.vaccinations.isEmpty &&
          parsed.surgeries.isEmpty &&
          parsed.allergies.isEmpty &&
          parsed.previousClaims.isEmpty &&
          parsed.lastCheckup == null;
    }

    try {
      final picker = ImagePicker();
      setState(() {
        _vetUploadStatus = 'Opening camera…';
      });

      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo == null) {
        if (!mounted) return;
        setState(() => _isUploadingVetRecord = false);
        return;
      }

      final bytes = await photo.readAsBytes();

      final parser = VetHistoryParser(aiService: GPTService());
      final caseId = await _ensureUnderwritingCaseId();
      final petId = widget.pet.id;

      setState(() {
        _vetUploadStatus = 'Uploading and parsing photo…';
      });

      final result = await parser.parseUploadedImageBytesForCaseLenient(
        imageBytes: Uint8List.fromList(bytes),
        caseId: caseId,
        petId: petId,
        filename: photo.name,
      );

      _rawVetTexts.add(result.extractedText);
      _aiVetExtraction.add(result.parsedData);
      if (result.documentHash.trim().isNotEmpty) {
        _vetDocumentHashes.add(result.documentHash);
      }
      if (result.aiFailed) _aiVetParseFailed = true;

      if (!mounted) return;

      final autofill = looksEmpty(result.parsedData)
          ? const _VetAutofillResult(
              conditionsAdded: 0,
              medicationsAdded: 0,
              vetVisitsAdded: 0,
              allergiesAdded: 0,
            )
          : _applyVetRecordAutofill(result.parsedData);

      setState(() {
        _vetUploadStatus = looksEmpty(result.parsedData)
            ? 'Photo uploaded. Thanks — we’ll process it shortly.'
            : 'Photo parsed and applied: '
                  '${autofill.conditionsAdded} condition(s), '
                  '${autofill.medicationsAdded} medication(s), '
                  '${autofill.vetVisitsAdded} visit(s), '
                  '${autofill.allergiesAdded} allergy item(s).';
        _isUploadingVetRecord = false;
      });

      await _autoReassessAfterUpload();
    } on VetHistoryParseException catch (e) {
      if (!mounted) return;
      setState(() {
        _vetUploadStatus =
            'Photo uploaded, but auto-fill failed. Please try uploading a clearer image or a PDF. (${e.toString()})';
        _isUploadingVetRecord = false;
        _aiVetParseFailed = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vetUploadStatus = 'Camera upload failed: $e';
        _isUploadingVetRecord = false;
        _aiVetParseFailed = true;
      });
    }
  }

  _VetAutofillResult _applyVetRecordAutofill(VetRecordData parsed) {
    String norm(String value) => value.trim().toLowerCase();

    final existingMedications = _medications.map((m) => norm(m.name)).toSet();
    final existingAllergies = _allergies.map(norm).toSet();
    final existingVisitKeys = <String>{
      for (final v in _vetVisits)
        '${v.visitDate.toIso8601String().substring(0, 10)}|'
            '${norm(v.diagnosis ?? '')}|'
            '${norm(v.visitType)}',
    };

    var conditionsAdded = 0;
    var medicationsAdded = 0;
    var vetVisitsAdded = 0;
    var allergiesAdded = 0;

    debugPrint(
      '[MedicalHistoryApply] Autofill input: '
      '${parsed.diagnoses.length} diagnoses, '
      '${parsed.treatments.length} treatments, '
      '${parsed.medications.length} medications, '
      '${parsed.vaccinations.length} vaccinations',
    );

    for (final d in parsed.diagnoses) {
      final condition = (d.condition).trim();
      if (condition.isEmpty) continue;

      final statusRaw = norm(d.status);
      final status = statusRaw == 'resolved'
          ? 'resolved'
          : statusRaw == 'chronic'
          ? 'managed'
          : 'active';

      final added = _upsertMedicalCondition(
        MedicalCondition(
          id: 'ai_cond_${DateTime.now().millisecondsSinceEpoch}_$conditionsAdded',
          name: condition,
          diagnosisDate: d.date,
          status: status,
          notes: d.notes,
        ),
      );
      if (added) conditionsAdded++;
    }

    if (parsed.diagnoses.isEmpty) {
      for (final t in parsed.treatments) {
        final condition = (t.diagnosis).trim();
        if (condition.isEmpty) continue;
        final added = _upsertMedicalCondition(
          MedicalCondition(
            id: 'ai_cond_${DateTime.now().millisecondsSinceEpoch}_$conditionsAdded',
            name: condition,
            diagnosisDate: t.date,
            status: 'active',
            treatment: t.treatment.trim().isEmpty ? null : t.treatment.trim(),
            notes: t.notes,
          ),
        );
        if (added) conditionsAdded++;
      }
    }

    for (final m in parsed.medications) {
      final name = (m.name).trim();
      if (name.isEmpty) continue;
      final key = norm(name);
      if (existingMedications.contains(key)) continue;

      final dosage = (m.dosage).trim();
      _medications.add(
        Medication(
          id: 'ai_med_${DateTime.now().millisecondsSinceEpoch}_$medicationsAdded',
          name: name,
          dosage: dosage.isEmpty ? 'Unknown' : dosage,
          frequency: 'as directed',
          startDate: m.startDate,
          endDate: m.endDate,
          purpose: m.purpose,
          isOngoing: m.endDate == null,
        ),
      );
      existingMedications.add(key);
      medicationsAdded++;
    }

    for (final a in parsed.allergies) {
      final value = a.trim();
      if (value.isEmpty) continue;
      final key = norm(value);
      if (existingAllergies.contains(key)) continue;
      _allergies.add(value);
      existingAllergies.add(key);
      allergiesAdded++;
    }

    void addVisit({
      required DateTime date,
      required String visitType,
      String? diagnosis,
      String? treatment,
      String? notes,
      String? veterinarian,
      String? clinic,
      List<String>? procedures,
    }) {
      final key =
          '${date.toIso8601String().substring(0, 10)}|${norm(diagnosis ?? '')}|${norm(visitType)}';
      if (existingVisitKeys.contains(key)) return;

      _vetVisits.add(
        VetVisit(
          id: 'ai_visit_${DateTime.now().millisecondsSinceEpoch}_$vetVisitsAdded',
          visitDate: date,
          veterinarian: (veterinarian ?? '').trim().isEmpty
              ? 'From vet record'
              : veterinarian!.trim(),
          clinic: (clinic ?? '').trim().isEmpty
              ? 'From vet record'
              : clinic!.trim(),
          visitType: visitType,
          diagnosis: diagnosis?.trim().isEmpty == true
              ? null
              : diagnosis?.trim(),
          treatment: treatment?.trim().isEmpty == true
              ? null
              : treatment?.trim(),
          notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
          procedures: procedures,
        ),
      );
      existingVisitKeys.add(key);
      vetVisitsAdded++;
    }

    for (final t in parsed.treatments) {
      addVisit(
        date: t.date,
        visitType: 'checkup',
        diagnosis: t.diagnosis,
        treatment: t.treatment,
        notes: t.notes,
      );
    }

    for (final v in parsed.vaccinations) {
      addVisit(
        date: v.date,
        visitType: 'vaccination',
        diagnosis: 'Vaccination: ${v.name}',
        notes: v.expiryDate != null
            ? 'Expiry: ${v.expiryDate!.toIso8601String().substring(0, 10)}'
            : null,
        veterinarian: v.veterinarian,
      );
    }

    for (final s in parsed.surgeries) {
      addVisit(
        date: s.date,
        visitType: 'surgery',
        diagnosis: s.procedure,
        notes: [
          if ((s.complications ?? '').trim().isNotEmpty)
            'Complications: ${s.complications}',
          if ((s.outcome ?? '').trim().isNotEmpty) 'Outcome: ${s.outcome}',
        ].join(' · '),
      );
    }

    if (parsed.lastCheckup != null) {
      addVisit(
        date: parsed.lastCheckup!,
        visitType: 'checkup',
        diagnosis: 'Routine checkup',
      );
    }

    debugPrint(
      '[MedicalHistoryApply] Autofill result: '
      '$conditionsAdded conditions, $medicationsAdded medications, '
      '$vetVisitsAdded visits, $allergiesAdded allergies added',
    );

    return _VetAutofillResult(
      conditionsAdded: conditionsAdded,
      medicationsAdded: medicationsAdded,
      vetVisitsAdded: vetVisitsAdded,
      allergiesAdded: allergiesAdded,
    );
  }

  Future<void> _ensureAuthenticatedSession() async {
    final existing = FirebaseAuth.instance.currentUser;
    if (existing != null) return;

    // Underwriting should work without an explicit sign-in. We use Anonymous
    // Auth to secure Storage/Firestore writes without asking the customer to
    // create an account until checkout.
    await FirebaseAuth.instance.signInAnonymously();
  }

  Owner? _tryGetOwnerFromRouteArgs() {
    final owner = _routeArguments['owner'];
    if (owner is Owner) return owner;
    if (owner is Map<String, dynamic>) {
      try {
        return Owner.fromJson(owner);
      } catch (_) {
        return null;
      }
    }
    if (owner is Map) {
      try {
        return Owner.fromJson(owner.cast<String, dynamic>());
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  List<String> _buildUnderwritingTriggerReasons() {
    final reasons = <String>[];

    final hasDeclaredConditions =
        widget.pet.preExistingConditions.isNotEmpty &&
        widget.pet.preExistingConditions.any(
          (c) => c.trim().isNotEmpty && c != 'None',
        );
    if (hasDeclaredConditions) reasons.add('pre_existing_conditions');

    final hasExclusions =
        _routeArguments['hasExclusions'] == true ||
        (_routeArguments['excludedConditions'] is List &&
            (_routeArguments['excludedConditions'] as List).isNotEmpty);
    if (hasExclusions) reasons.add('rule_exclusions');

    if (_routeArguments['needsMedicalUnderwriting'] == true) {
      reasons.add('needs_medical_underwriting');
    }

    if (reasons.isEmpty) reasons.add('medical_history_review');
    return reasons;
  }

  Future<String> _ensureUnderwritingCaseId() async {
    final existing = _underwritingCaseId;
    if (existing != null && existing.isNotEmpty) return existing;

    try {
      await _ensureAuthenticatedSession();
    } catch (e) {
      throw Exception('Unable to start secure session: $e');
    }

    final owner = _tryGetOwnerFromRouteArgs();
    if (owner == null) {
      throw Exception(
        'Unable to create underwriting case (missing owner data)',
      );
    }

    setState(() {
      _vetUploadStatus = 'Preparing secure upload…';
    });

    final service = UnderwritingCaseService();
    final caseId = await service.createCase(
      pet: widget.pet,
      owner: owner,
      quoteId: _routeArguments['quoteId']?.toString(),
      triggerReasons: _buildUnderwritingTriggerReasons(),
    );

    if (!mounted) return caseId;
    setState(() {
      _underwritingCaseId = caseId;
      _routeArguments['underwritingCaseId'] = caseId;
    });
    return caseId;
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ClovaraColors.clover.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: ClovaraColors.clover),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: ClovaraTypography.h3.copyWith(
                color: ClovaraColors.forest,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: ClovaraTypography.bodySmall.copyWith(
                color: ClovaraColors.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAddButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: ClovaraColors.clover,
          side: BorderSide(
            color: ClovaraColors.clover.withOpacity(0.3),
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionCard(MedicalCondition condition) {
    final isOther = condition.name.trim().toLowerCase() == 'other';
    final statusColor = _getStatusColor(condition.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: statusColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.medical_services_rounded,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        condition.name,
                        style: ClovaraTypography.body.copyWith(
                          color: ClovaraColors.forest,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isOther) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Tap Edit to enter the specific condition name.',
                          style: ClovaraTypography.bodySmall.copyWith(
                            color: ClovaraColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildStatusChip(
                            condition.status.toUpperCase(),
                            statusColor,
                          ),
                          if (isOther)
                            _buildStatusChip(
                              'NEEDS DETAILS',
                              ClovaraColors.warning,
                            ),
                          Text(
                            _formatDate(condition.diagnosisDate),
                            style: ClovaraTypography.bodySmall.copyWith(
                              color: ClovaraColors.slate,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  color: ClovaraColors.slate,
                  onPressed: () => _showEditConditionDialog(condition),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: ClovaraColors.slate,
                  onPressed: () => _removeCondition(condition),
                  tooltip: 'Remove',
                ),
              ],
            ),
            if (condition.treatment != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ClovaraColors.mist,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.healing_rounded,
                      size: 16,
                      color: ClovaraColors.slate,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        condition.treatment!,
                        style: ClovaraTypography.bodySmall.copyWith(
                          color: ClovaraColors.slate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildMedicationCard(Medication medication) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: ClovaraColors.info.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ClovaraColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.medication_rounded,
                    color: ClovaraColors.info,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              medication.name,
                              style: ClovaraTypography.body.copyWith(
                                color: ClovaraColors.forest,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (medication.isOngoing)
                            _buildStatusChip('ONGOING', ClovaraColors.success),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${medication.dosage} • ${medication.frequency}',
                        style: ClovaraTypography.bodySmall.copyWith(
                          color: ClovaraColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  color: ClovaraColors.slate,
                  onPressed: () => _showEditMedicationDialog(medication),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: ClovaraColors.slate,
                  onPressed: () => _removeMedication(medication),
                  tooltip: 'Remove',
                ),
              ],
            ),
            if (medication.purpose != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ClovaraColors.mist,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: ClovaraColors.slate,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        medication.purpose!,
                        style: ClovaraTypography.bodySmall.copyWith(
                          color: ClovaraColors.slate,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModernAllergyChip(String allergy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ClovaraColors.warning.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: ClovaraColors.warning,
          ),
          const SizedBox(width: 8),
          Text(
            allergy,
            style: ClovaraTypography.bodySmall.copyWith(
              color: ClovaraColors.forest,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _removeAllergy(allergy),
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: ClovaraColors.slate,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVetVisitCard(VetVisit visit) {
    final visitColor = _getVisitTypeColor(visit.visitType);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: visitColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: visitColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getVisitTypeIcon(visit.visitType),
                    color: visitColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildStatusChip(
                            visit.visitType.toUpperCase(),
                            visitColor,
                          ),
                          Text(
                            _formatDate(visit.visitDate),
                            style: ClovaraTypography.bodySmall.copyWith(
                              color: ClovaraColors.slate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        visit.clinic,
                        style: ClovaraTypography.body.copyWith(
                          color: ClovaraColors.forest,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Dr. ${visit.veterinarian}',
                        style: ClovaraTypography.bodySmall.copyWith(
                          color: ClovaraColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  color: ClovaraColors.slate,
                  onPressed: () => _showEditVetVisitDialog(visit),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: ClovaraColors.slate,
                  onPressed: () => _removeVetVisit(visit),
                  tooltip: 'Remove',
                ),
              ],
            ),
            if (visit.diagnosis != null || visit.treatment != null) ...[
              const SizedBox(height: 12),
              if (visit.diagnosis != null)
                _buildDetailRow(
                  icon: Icons.assignment_rounded,
                  label: 'Diagnosis',
                  value: visit.diagnosis!,
                ),
              if (visit.diagnosis != null && visit.treatment != null)
                const SizedBox(height: 8),
              if (visit.treatment != null)
                _buildDetailRow(
                  icon: Icons.healing_rounded,
                  label: 'Treatment',
                  value: visit.treatment!,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ClovaraColors.mist,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: ClovaraColors.slate),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: ClovaraTypography.label.copyWith(
                    color: ClovaraColors.slate,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: ClovaraTypography.bodySmall.copyWith(
                    color: ClovaraColors.slate,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return ClovaraColors.error;
      case 'managed':
      case 'stable':
        return ClovaraColors.warning;
      case 'resolved':
        return ClovaraColors.success;
      default:
        return ClovaraColors.slate;
    }
  }

  Color _getVisitTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'emergency':
        return ClovaraColors.error;
      case 'surgery':
        return ClovaraColors.info;
      case 'checkup':
      case 'vaccination':
        return ClovaraColors.success;
      default:
        return ClovaraColors.info;
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
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      child: SafeArea(
        top: false,
        child: MaxWidth(
          child: Row(
            children: [
              if (_currentStep > 0) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _previousStep,
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClovaraColors.forest,
                      side: BorderSide(color: ClovaraColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: _currentStep > 0 ? 2 : 1,
                child: ElevatedButton(
                  onPressed: _currentStep < _totalSteps - 1
                      ? _nextStep
                      : _complete,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentStep < _totalSteps - 1
                            ? 'Continue'
                            : 'Complete & View Plans',
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      if (!_validateBeforeContinuing()) return;
      _fadeController.reverse().then((_) {
        setState(() {
          _currentStep++;
        });
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
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
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _fadeController.forward();
      });
    }
  }

  void _complete() async {
    if (!_validateBeforeContinuing(isCompleting: true)) return;

    final riskScore = widget.riskScore;
    if (riskScore is! RiskScore) {
      _showBlockingValidationDialog(
        title: 'Underwriting incomplete',
        message:
            'We can\'t show plans yet because a risk score is missing. Please try again.',
      );
      return;
    }

    // We do not block on customer-entered clinical facts.
    // Underwriting will deterministically request evidence if needed.

    // Create updated pet with medical history
    final updatedPet = widget.pet.copyWith(
      medicalConditions: _conditions,
      medications: _medications,
      allergies: _allergies,
      vetHistory: _vetVisits,
      isReceivingTreatment: _medications.any((m) => m.isOngoing),
    );

    String? caseId =
        _underwritingCaseId ??
        _routeArguments['underwritingCaseId']?.toString() ??
        widget.quoteData?['underwritingCaseId']?.toString();

    // Underwriting should be completable without an explicit sign-in.
    // If we have owner data available, create a case (anonymous-auth if needed)
    // so we can persist history/decision and pass the caseId to checkout.
    if (caseId == null || caseId.isEmpty) {
      final owner = _tryGetOwnerFromRouteArgs();
      if (owner != null) {
        try {
          caseId = await _ensureUnderwritingCaseId();
        } catch (_) {
          // If we can't create a case (e.g. anonymous auth disabled), we still
          // allow the user to proceed to plans.
        }
      }
    }

    UnderwritingDecision? computedDecision;
    List<PolicyExclusion>? computedExclusions;
    Map<String, dynamic>? computedSnapshot;
    UnderwritingStatus? computedStatus;
    String? computedReason;
    bool integrityPassed = false;
    List<Map<String, dynamic>> computedRequiredEvidence = const [];
    Set<String> computedRuleOutCodes = const {};
    var computedAiFailureCount = 0;

    // Always compute a deterministic decision when we have a RiskScore.
    // Persist it to an underwriting case only when a caseId exists.
    try {
      final factsBuilder = MedicalFactsBuilder();
      final built = factsBuilder.build(
        userEnteredConditions: _conditions,
        aiVetExtraction: List<VetRecordData>.from(_aiVetExtraction),
        rawVetTexts: List<String>.from(_rawVetTexts),
        aiFailure: _aiVetParseFailed,
      );

      computedRuleOutCodes = built.ruleOutConditionCodes;

      final vetDocumentHashes =
          _vetDocumentHashes
              .map((h) => h.trim())
              .where((h) => h.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      // Track AI failure across underwriting attempts so we can deterministically
      // decline on persistent/unrecoverable failures.
      final rawCount = _routeArguments['aiFailureCount'];
      computedAiFailureCount = rawCount is int
          ? rawCount
          : int.tryParse((rawCount ?? '').toString()) ?? 0;
      if (built.aiFailure) {
        computedAiFailureCount = computedAiFailureCount + 1;
      }

      final integrityEngine = UnderwritingIntegrityEngine(
        vetDocumentReuseCheck:
            ({required vetDocumentHashes, underwritingCaseId}) async {
              final detector = VetDocumentReuseDetector();
              return detector.check(
                vetDocumentHashes: vetDocumentHashes,
                underwritingCaseId: underwritingCaseId,
              );
            },
      );
      debugPrint(
        '[UnderwritingBridge] Calling integrity engine: '
        '${built.facts.length} facts, '
        '${_aiVetExtraction.length} vet extractions, '
        'aiFailure=${built.aiFailure}, '
        'ruleOutCodes=$computedRuleOutCodes',
      );
      var assessment = await integrityEngine.assess(
        pet: updatedPet,
        riskScore: riskScore,
        medicalFacts: built.facts,
        medicalFactsRequired: built.facts.isNotEmpty,
        aiFailure: built.aiFailure,
        aiFailureCount: computedAiFailureCount,
        ruleOutConditionCodes: computedRuleOutCodes,
        vetDocumentHashes: vetDocumentHashes,
        underwritingCaseId: caseId,
        aiVetExtractionForIntegrity: List<VetRecordData>.from(_aiVetExtraction),
        rawVetTextsForIntegrity: List<String>.from(_rawVetTexts),
      );
      debugPrint(
        '[UnderwritingBridge] Assessment result: '
        'status=${assessment.underwritingStatus}, '
        'reason=${assessment.reason}, '
        'evidence=${assessment.requiredEvidence.map((e) => e.code).toList()}',
      );

      // Deterministic escalation for repeated unresolved NEED_MORE_INFO.
      // We persist the counter in local route args to keep behavior stable
      // within this client session.
      if (assessment.underwritingStatus == UnderwritingStatus.needMoreInfo &&
          assessment.requiredEvidence.isNotEmpty) {
        final evidenceCodes =
            assessment.requiredEvidence
                .map((e) => e.code)
                .where((c) => c.trim().isNotEmpty)
                .toSet()
                .toList(growable: false)
              ..sort();

        int nextAttempts;

        // Prefer persistent case storage when we have a caseId.
        if (caseId != null && caseId.isNotEmpty) {
          try {
            nextAttempts = await UnderwritingCaseService()
                .incrementNeedMoreInfoAttempts(
                  caseId: caseId,
                  reason: assessment.reason,
                  requiredEvidenceCodes: evidenceCodes,
                );
          } catch (_) {
            // Fall back to local counter if case updates fail.
            final rawAttempts = _routeArguments['needMoreInfoAttempts'];
            final previousAttempts = rawAttempts is int
                ? rawAttempts
                : int.tryParse((rawAttempts ?? '').toString()) ?? 0;
            nextAttempts = previousAttempts + 1;
          }
        } else {
          final rawAttempts = _routeArguments['needMoreInfoAttempts'];
          final previousAttempts = rawAttempts is int
              ? rawAttempts
              : int.tryParse((rawAttempts ?? '').toString()) ?? 0;
          nextAttempts = previousAttempts + 1;
        }

        _routeArguments['needMoreInfoAttempts'] = nextAttempts;
        _routeArguments['lastNeedMoreInfoReason'] = assessment.reason;
        _routeArguments['lastNeedMoreInfoEvidenceCodes'] = evidenceCodes;

        if (nextAttempts >= _maxNeedMoreInfoAttempts) {
          assessment = await integrityEngine.assess(
            pet: updatedPet,
            riskScore: riskScore,
            medicalFacts: built.facts,
            medicalFactsRequired: built.facts.isNotEmpty,
            aiFailure: built.aiFailure,
            aiFailureCount: computedAiFailureCount,
            ruleOutConditionCodes: computedRuleOutCodes,
            userFailedToProvideRequiredEvidence: true,
            vetDocumentHashes: vetDocumentHashes,
            underwritingCaseId: caseId,
            aiVetExtractionForIntegrity: List<VetRecordData>.from(
              _aiVetExtraction,
            ),
            rawVetTextsForIntegrity: List<String>.from(_rawVetTexts),
          );
          _routeArguments['needMoreInfoAttempts'] = 0;
          _routeArguments.remove('lastNeedMoreInfoReason');
          _routeArguments.remove('lastNeedMoreInfoEvidenceCodes');
        }
      } else {
        _routeArguments['needMoreInfoAttempts'] = 0;
        _routeArguments.remove('lastNeedMoreInfoReason');

        if (caseId != null && caseId.isNotEmpty) {
          try {
            await UnderwritingCaseService().resetNeedMoreInfoAttempts(
              caseId: caseId,
            );
          } catch (_) {
            // Do not block underwriting completion if the counter can't reset.
          }
        }
      }

      computedDecision = assessment.decision;
      computedExclusions = assessment.decision?.exclusions;
      computedStatus = assessment.underwritingStatus;
      computedReason = assessment.reason;
      integrityPassed =
          assessment.underwritingStatus == UnderwritingStatus.approved;
      computedRequiredEvidence = assessment.requiredEvidence
          .map((e) => e.toJson())
          .toList(growable: false);

      computedSnapshot = {
        'caseId': caseId,
        if (assessment.decision != null)
          'decision': assessment.decision!.toJson(),
        'underwritingStatus': underwritingStatusToString(
          assessment.underwritingStatus,
        ),
        'reason': assessment.reason,
        if (computedRequiredEvidence.isNotEmpty)
          'requiredEvidence': computedRequiredEvidence,
        'medicalFacts': built.facts.map((f) => f.toJson()).toList(),
        'aiFailure': built.aiFailure,
        'aiFailureCount': computedAiFailureCount,
        'criticalConditionDetected': built.criticalConditionDetected,
        if (vetDocumentHashes.isNotEmpty)
          'vetDocumentHashes': vetDocumentHashes,
        if (computedRuleOutCodes.isNotEmpty)
          'ruleOutConditionCodes': computedRuleOutCodes.toList()..sort(),
        'capturedAt': DateTime.now().toIso8601String(),
        'source': (caseId != null && caseId.isNotEmpty)
            ? 'underwriting_case'
            : 'medical_underwriting_client',
      };

      // Audit self-serve loops and deterministic escalations when we have a case.
      if (caseId != null && caseId.isNotEmpty) {
        try {
          final service = UnderwritingCaseService();
          final rawAttempts = _routeArguments['needMoreInfoAttempts'];
          final attempts = rawAttempts is int
              ? rawAttempts
              : int.tryParse((rawAttempts ?? '').toString()) ?? 0;

          if (assessment.underwritingStatus ==
              UnderwritingStatus.needMoreInfo) {
            await service.logEvent(caseId, 'need_more_info', {
              'reason': assessment.reason,
              'attempt': attempts,
              'requiredEvidenceCodes': assessment.requiredEvidence
                  .map((e) => e.code)
                  .toList(growable: false),
              'loggedAt': DateTime.now().toIso8601String(),
            });
          }

          if (assessment.reason == 'REQUIRED_EVIDENCE_NOT_PROVIDED') {
            await service.logEvent(caseId, 'required_evidence_not_provided', {
              'attempt': attempts,
              'loggedAt': DateTime.now().toIso8601String(),
            });
          }
        } catch (_) {
          // Do not block navigation on audit log failures.
        }
      }

      // Disclosure acknowledgement is required for declines or exclusions,
      // even when we cannot persist an underwriting case.
      final decisionForDisclosure = assessment.decision;
      if (decisionForDisclosure != null &&
          (decisionForDisclosure.outcome == UnderwritingOutcome.decline ||
              decisionForDisclosure.outcome ==
                  UnderwritingOutcome.approveWithExclusions)) {
        final acknowledged = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => UnderwritingDisclosureDialog(
            decision: decisionForDisclosure,
            petName: updatedPet.name,
          ),
        );

        if (acknowledged != true) {
          return;
        }
      }
    } catch (_) {
      _showBlockingValidationDialog(
        title: 'Underwriting incomplete',
        message:
            'We can\'t show plans yet because underwriting could not be completed. Please try again.',
      );
      return;
    }

    if (caseId != null && caseId.isNotEmpty) {
      try {
        final service = UnderwritingCaseService();
        final uwConditions = _conditions
            .where((c) => c.name.trim().isNotEmpty)
            .map(
              (c) => UnderwritingCondition(
                name: c.name,
                diagnosisMonthYear:
                    '${c.diagnosisDate.year.toString().padLeft(4, '0')}-${c.diagnosisDate.month.toString().padLeft(2, '0')}',
                isResolved: c.isResolved,
                isManaged:
                    (c.treatment ?? '').trim().isNotEmpty ||
                    c.status == 'managed' ||
                    c.status == 'stable',
                treatmentStatus: c.status,
                meds: const [],
                notes: c.notes,
              ),
            )
            .toList();

        await service.saveMedicalHistory(
          caseId,
          UnderwritingMedicalHistory(
            conditions: uwConditions,
            vetClinicName: _clinicNameController.text.trim().isEmpty
                ? null
                : _clinicNameController.text.trim(),
            userAttestation: false,
          ),
        );

        // Best-effort marketing attribution
        MarketingAttributionService().trackUnderwritingSubmittedOnce(
          underwritingCaseId: caseId,
        );

        if (computedDecision != null) {
          await service.saveDecision(caseId, computedDecision);

          switch (computedDecision.outcome) {
            case UnderwritingOutcome.approve:
              await service.updateStatus(
                caseId,
                UnderwritingCaseStatus.approved,
              );
              break;
            case UnderwritingOutcome.approveWithExclusions:
              await service.updateStatus(
                caseId,
                UnderwritingCaseStatus.approvedWithExclusions,
              );
              break;
            case UnderwritingOutcome.decline:
              await service.updateStatus(
                caseId,
                UnderwritingCaseStatus.declined,
              );
              break;
            case UnderwritingOutcome.refer:
              await service.updateStatus(
                caseId,
                UnderwritingCaseStatus.referred,
              );
              break;
          }

          if (computedDecision.outcome == UnderwritingOutcome.decline ||
              computedDecision.outcome ==
                  UnderwritingOutcome.approveWithExclusions) {
            await service
                .logEvent(caseId, 'underwriting_disclosure_acknowledged', {
                  'outcome': underwritingOutcomeToString(
                    computedDecision.outcome,
                  ),
                  'reasonCodes': computedDecision.reasonCodes,
                  'exclusionsCount': computedDecision.exclusions.length,
                  'acknowledgedAt': DateTime.now().toIso8601String(),
                });
          }
        }
      } catch (_) {
        // Do not block navigation on save failures.
      }
    }

    if (computedStatus != UnderwritingStatus.approved) {
      // Save & revisit support: persist the underwriting case locally when we
      // need more information, so the user can come back later to upload docs.
      if (computedStatus == UnderwritingStatus.needMoreInfo) {
        final saveCaseId = caseId;
        if (saveCaseId != null && saveCaseId.isNotEmpty) {
          try {
            await UserSessionService().savePendingUnderwriting(
              underwritingCaseId: saveCaseId,
              petName: updatedPet.name,
              riskScore: riskScore,
              reason: computedReason,
              requiredEvidence: computedRequiredEvidence,
            );
          } catch (_) {
            // Don't block the flow if local save fails.
          }

          // Persist a server-side draft under an anonymous session so the user
          // can resume on another device without explicit signup.
          try {
            await DraftService().upsertUnderwritingDraft(
              underwritingCaseId: saveCaseId,
              petName: updatedPet.name,
              riskScore: riskScore,
              reason: computedReason,
              requiredEvidence: computedRequiredEvidence,
            );
          } catch (_) {
            // Ignore; local save is the fallback.
          }
        }
      } else {
        // Terminal outcomes should not be resumable.
        try {
          await UserSessionService().clearPendingUnderwriting();
        } catch (_) {
          // Ignore.
        }
      }

      // Persist NEED_MORE_INFO requirements so re-upload triggers auto re-check.
      if (computedStatus == UnderwritingStatus.needMoreInfo) {
        setState(() {
          _needsMoreInfo = true;
          _requiredEvidenceJson = computedRequiredEvidence;
        });
      } else {
        setState(() {
          _needsMoreInfo = false;
          _requiredEvidenceJson = const [];
        });
      }

      final title = computedStatus == UnderwritingStatus.denied
          ? 'Application declined'
          : computedStatus == UnderwritingStatus.needMoreInfo
          ? 'More information needed'
          : 'Application declined';

      final evidenceLines = computedRequiredEvidence
          .map((e) => (e['title'] ?? '').toString().trim())
          .where((t) => t.isNotEmpty)
          .map((t) => '• $t')
          .join('\n');

      final message = computedStatus == UnderwritingStatus.denied
          ? 'Based on the information provided, we can\'t offer a new policy right now.'
          : computedStatus == UnderwritingStatus.needMoreInfo
          ? ('We can\'t show plans yet because we need more medical information to complete underwriting.'
                '\n\nYou can upload the requested documents now, or finish later.'
                '${evidenceLines.isNotEmpty ? "\n\nPlease provide:\n$evidenceLines" : ''}')
          : 'Based on the information provided, we can\'t offer a new policy right now.';

      _showBlockingValidationDialog(
        title: title,
        message: message,
        secondaryLabel: computedStatus == UnderwritingStatus.needMoreInfo
            ? 'Finish later'
            : null,
        onSecondary: computedStatus == UnderwritingStatus.needMoreInfo
            ? () {
                Navigator.pop(context);
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            : null,
        tertiaryLabel: computedStatus == UnderwritingStatus.needMoreInfo
            ? 'Save resume code'
            : null,
        onTertiary: computedStatus == UnderwritingStatus.needMoreInfo
            ? () {
                unawaited(_copyResumeCodeToClipboard());
              }
            : null,
      );
      return;
    }

    // Approved: clear any prior NEED_MORE_INFO state.
    if (_needsMoreInfo || _requiredEvidenceJson.isNotEmpty) {
      setState(() {
        _needsMoreInfo = false;
        _requiredEvidenceJson = const [];
      });
    }

    // Underwriting completed successfully; clear any saved follow-up.
    try {
      await UserSessionService().clearPendingUnderwriting();
    } catch (_) {
      // Ignore.
    }

    // Navigate to plan selection with explicit pricing approval.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const PlanSelectionScreen(),
        settings: RouteSettings(
          arguments: {
            'petData': updatedPet.toJson(),
            'pet': updatedPet,
            'riskScore': riskScore,
            'pricingEnabled': true,
            'underwritingStatus': underwritingStatusToString(computedStatus),
            'underwritingReason': computedReason,
            'integrityPassed': integrityPassed,
            if (computedRequiredEvidence.isNotEmpty)
              'requiredEvidence': computedRequiredEvidence,
            'aiFailureCount': computedAiFailureCount,
            if (computedSnapshot['vetDocumentHashes'] != null)
              'vetDocumentHashes': computedSnapshot['vetDocumentHashes'],
            if (computedExclusions != null)
              'exclusions': computedExclusions.map((e) => e.toJson()).toList(),
            'underwritingSnapshot': computedSnapshot,
            if (caseId != null && caseId.isNotEmpty)
              'underwritingCaseId': caseId,
            ...?widget.quoteData,
          },
        ),
      ),
    );
  }

  bool _validateBeforeContinuing({bool isCompleting = false}) {
    final petHasDeclaredConditions =
        widget.pet.preExistingConditions.isNotEmpty &&
        widget.pet.preExistingConditions.any(
          (c) => c.trim().isNotEmpty && c != 'None',
        );

    // If the pet has declared conditions, we should not allow skipping the
    // medical history entirely.
    if (petHasDeclaredConditions && _conditions.isEmpty) {
      _showBlockingValidationDialog(
        title: 'Add condition details',
        message:
            'Please confirm at least one condition so Clovara can check ${widget.pet.name}\'s history accurately.',
      );
      return false;
    }

    final requiresMoreDetail = _requiresSupportingDetails();

    // Step 1 (medications/allergies): ensure we capture at least one supporting
    // detail for high-detail conditions or actively-treated cases.
    if (!isCompleting && _currentStep == 1 && requiresMoreDetail) {
      final hasTreatmentDetail = _conditions.any((c) {
        final treatment = (c.treatment ?? '').trim();
        final notes = (c.notes ?? '').trim();
        return treatment.isNotEmpty || notes.isNotEmpty;
      });

      if (_medications.isEmpty && !hasTreatmentDetail) {
        _showBlockingValidationDialog(
          title: 'More details needed',
          message:
              'Before we can continue, please add a medication (if any) or a quick treatment/notes summary so we can underwrite ${widget.pet.name}\'s condition(s).',
        );
        return false;
      }
    }

    // Step 2 (vet history) / completing: require at least one verifiable support
    // signal (vet visit or medication) for chronic/high-detail conditions.
    if ((isCompleting || _currentStep == 2) && requiresMoreDetail) {
      if (_vetVisits.isEmpty && _medications.isEmpty) {
        _showBlockingValidationDialog(
          title: 'Vet visit or medication required',
          message:
              'Please add at least one vet visit or medication entry so we can properly evaluate ${widget.pet.name}\'s condition(s) before showing plans.',
        );
        return false;
      }
    }

    return true;
  }

  bool _requiresSupportingDetails() {
    final declared = widget.pet.preExistingConditions
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty && c != 'Pre-existing condition reported')
        .toSet();

    final hasHighDetailCondition = declared.any(_highDetailConditions.contains);

    final petData = widget.quoteData?['petData'];
    final receivingTreatmentAnswer = petData is Map<String, dynamic>
        ? petData['isReceivingTreatment']
        : null;

    final bool saysReceivingTreatment =
        receivingTreatmentAnswer == true ||
        (receivingTreatmentAnswer is String &&
            receivingTreatmentAnswer.toLowerCase() == 'managed');

    return hasHighDetailCondition || saysReceivingTreatment;
  }

  void _showBlockingValidationDialog({
    required String title,
    required String message,
    String? primaryLabel,
    VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    String? tertiaryLabel,
    VoidCallback? onTertiary,
  }) {
    if (!mounted) return;

    final resolvedPrimaryLabel = primaryLabel ?? 'OK';

    unawaited(
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            if (tertiaryLabel != null && tertiaryLabel.trim().isNotEmpty)
              TextButton(onPressed: onTertiary, child: Text(tertiaryLabel)),
            if (secondaryLabel != null && secondaryLabel.trim().isNotEmpty)
              TextButton(
                onPressed: onSecondary ?? () => Navigator.pop(context),
                child: Text(secondaryLabel),
              ),
            TextButton(
              onPressed: onPrimary ?? () => Navigator.pop(context),
              child: Text(resolvedPrimaryLabel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyResumeCodeToClipboard() async {
    await SaveResumeDialog.show(
      context,
      title: 'Save & resume later',
      body:
          'Use this code to return from the home page and upload documents from any device.',
      copyLabel: 'Copy code',
      doneLabel: 'Done',
    );
  }

  // Dialog methods
  void _showAddConditionDialog() {
    showDialog(context: context, builder: (context) => _buildConditionDialog());
  }

  void _showEditConditionDialog(MedicalCondition condition) {
    setState(() {
      final isOther = condition.name.trim().toLowerCase() == 'other';
      _conditionNameController.text = isOther ? '' : condition.name;
      _conditionDiagnosisDate = condition.diagnosisDate;
      _conditionStatus = condition.status;
      _conditionIsCongenital = condition.isCongenital;
      _conditionTreatmentController.text = condition.treatment ?? '';
      _conditionNotesController.text = condition.notes ?? '';
    });

    showDialog(
      context: context,
      builder: (context) => _buildConditionDialog(editing: condition),
    );
  }

  void _showAddMedicationDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildMedicationDialog(),
    );
  }

  void _showEditMedicationDialog(Medication medication) {
    setState(() {
      _medicationNameController.text = medication.name;
      _medicationDosageController.text = medication.dosage;
      _medicationFrequencyController.text = medication.frequency;
      _medicationPurposeController.text = medication.purpose ?? '';
      _medicationStartDate = medication.startDate;
      _medicationIsOngoing = medication.isOngoing;
    });

    showDialog(
      context: context,
      builder: (context) => _buildMedicationDialog(editing: medication),
    );
  }

  void _showAddAllergyDialog() {
    showDialog(context: context, builder: (context) => _buildAllergyDialog());
  }

  void _showAddVetVisitDialog() {
    showDialog(context: context, builder: (context) => _buildVetVisitDialog());
  }

  void _showEditVetVisitDialog(VetVisit visit) {
    setState(() {
      _visitDate = visit.visitDate;
      _visitType = visit.visitType;
      _vetNameController.text = visit.veterinarian;
      _clinicNameController.text = visit.clinic;
      _visitDiagnosisController.text = visit.diagnosis ?? '';
      _visitTreatmentController.text = visit.treatment ?? '';
    });

    showDialog(
      context: context,
      builder: (context) => _buildVetVisitDialog(editing: visit),
    );
  }

  Widget _buildConditionDialog({MedicalCondition? editing}) {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(
            editing == null
                ? 'Add Medical Condition'
                : 'Edit Medical Condition',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _conditionNameController,
                  decoration: const InputDecoration(
                    labelText: 'Condition Name *',
                    hintText: 'e.g., Chronic ear infections',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Congenital / since birth'),
                  subtitle: const Text(
                    'Mark when the condition has been present since birth.',
                  ),
                  value: _conditionIsCongenital,
                  onChanged: (value) {
                    setState(() => _conditionIsCongenital = value);
                    setDialogState(() {});
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: const Text('Diagnosis Date'),
                  subtitle: Text(
                    _conditionDiagnosisDate != null
                        ? _formatDate(_conditionDiagnosisDate!)
                        : 'Select date',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _conditionDiagnosisDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _conditionDiagnosisDate = date);
                      setDialogState(() {});
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
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _conditionStatus = value);
                      setDialogState(() {});
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
                  if (editing == null) {
                    _addCondition();
                  } else {
                    _updateCondition(editing);
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(editing == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMedicationDialog({Medication? editing}) {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(editing == null ? 'Add Medication' : 'Edit Medication'),
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
                    setDialogState(() {});
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
                  if (editing == null) {
                    _addMedication();
                  } else {
                    _updateMedication(editing);
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(editing == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
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

  Widget _buildVetVisitDialog({VetVisit? editing}) {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: Text(editing == null ? 'Add Vet Visit' : 'Edit Vet Visit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Visit Date'),
                  subtitle: Text(
                    _visitDate != null
                        ? _formatDate(_visitDate!)
                        : 'Select date',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _visitDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _visitDate = date);
                      setDialogState(() {});
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
                  items:
                      [
                            'checkup',
                            'emergency',
                            'surgery',
                            'follow-up',
                            'vaccination',
                          ]
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.toUpperCase()),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _visitType = value);
                      setDialogState(() {});
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
                  if (editing == null) {
                    _addVetVisit();
                  } else {
                    _updateVetVisit(editing);
                  }
                  Navigator.pop(context);
                }
              },
              child: Text(editing == null ? 'Add' : 'Save'),
            ),
          ],
        );
      },
    );
  }

  // Add/Remove methods
  void _addCondition() {
    setState(() {
      _conditions.add(
        MedicalCondition(
          id: 'cond_${DateTime.now().millisecondsSinceEpoch}',
          name: _conditionNameController.text,
          diagnosisDate: _conditionDiagnosisDate!,
          status: _conditionStatus,
          isCongenital: _conditionIsCongenital,
          treatment: _conditionTreatmentController.text.isEmpty
              ? null
              : _conditionTreatmentController.text,
          notes: _conditionNotesController.text.isEmpty
              ? null
              : _conditionNotesController.text,
        ),
      );
    });
    _clearConditionForm();
  }

  void _updateCondition(MedicalCondition existing) {
    final updated = MedicalCondition(
      id: existing.id,
      name: _conditionNameController.text,
      diagnosisDate: _conditionDiagnosisDate!,
      status: _conditionStatus,
      isCongenital: _conditionIsCongenital,
      treatment: _conditionTreatmentController.text.isEmpty
          ? null
          : _conditionTreatmentController.text,
      notes: _conditionNotesController.text.isEmpty
          ? null
          : _conditionNotesController.text,
      veterinarian: existing.veterinarian,
      lastCheckup: existing.lastCheckup,
    );

    setState(() {
      final idx = _conditions.indexWhere((c) => c.id == existing.id);
      if (idx >= 0) {
        _conditions[idx] = updated;
      }
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
    _conditionIsCongenital = false;
  }

  void _addMedication() {
    setState(() {
      _medications.add(
        Medication(
          id: 'med_${DateTime.now().millisecondsSinceEpoch}',
          name: _medicationNameController.text,
          dosage: _medicationDosageController.text,
          frequency: _medicationFrequencyController.text,
          startDate: _medicationStartDate ?? DateTime.now(),
          purpose: _medicationPurposeController.text.isEmpty
              ? null
              : _medicationPurposeController.text,
          isOngoing: _medicationIsOngoing,
        ),
      );
    });
    _clearMedicationForm();
  }

  void _updateMedication(Medication existing) {
    final updated = Medication(
      id: existing.id,
      name: _medicationNameController.text,
      dosage: _medicationDosageController.text,
      frequency: _medicationFrequencyController.text,
      startDate: existing.startDate,
      endDate: existing.endDate,
      prescribedBy: existing.prescribedBy,
      purpose: _medicationPurposeController.text.isEmpty
          ? null
          : _medicationPurposeController.text,
      isOngoing: _medicationIsOngoing,
    );

    setState(() {
      final idx = _medications.indexWhere((m) => m.id == existing.id);
      if (idx >= 0) _medications[idx] = updated;
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
      _vetVisits.add(
        VetVisit(
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
        ),
      );
    });
    _clearVetVisitForm();
  }

  void _updateVetVisit(VetVisit existing) {
    final updated = VetVisit(
      id: existing.id,
      visitDate: _visitDate ?? existing.visitDate,
      veterinarian: _vetNameController.text,
      clinic: _clinicNameController.text,
      visitType: _visitType,
      diagnosis: _visitDiagnosisController.text.isEmpty
          ? null
          : _visitDiagnosisController.text,
      treatment: _visitTreatmentController.text.isEmpty
          ? null
          : _visitTreatmentController.text,
      notes: existing.notes,
      procedures: existing.procedures,
      cost: existing.cost,
    );

    setState(() {
      final idx = _vetVisits.indexWhere((v) => v.id == existing.id);
      if (idx >= 0) _vetVisits[idx] = updated;
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
