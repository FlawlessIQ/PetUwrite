import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';

import '../models/owner.dart';
import '../models/pet.dart';
import '../models/underwriting_medical_history.dart';
import '../ai/ai_service.dart';
import '../services/vet_history_parser.dart';
import '../services/underwriting_case_service.dart';
import '../services/draft_service.dart';
import '../theme/clovara_theme.dart';
import '../ui/components/clovara_logo.dart';
import '../ui/components/save_resume_dialog.dart';
import 'medical_underwriting_screen.dart';

class UnderwritingIntakeScreen extends StatefulWidget {
  final String caseId;
  final Pet pet;
  final Owner owner;
  final dynamic riskScore;

  const UnderwritingIntakeScreen({
    super.key,
    required this.caseId,
    required this.pet,
    required this.owner,
    required this.riskScore,
  });

  @override
  State<UnderwritingIntakeScreen> createState() =>
      _UnderwritingIntakeScreenState();
}

class _UnderwritingIntakeScreenState extends State<UnderwritingIntakeScreen> {
  bool _loading = true;
  String? _error;
  UnderwritingMedicalHistory? _history;

  bool _isUploadingVetRecord = false;
  String? _vetUploadStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = UnderwritingCaseService();
      final history = await service.getMedicalHistory(widget.caseId);
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _continueToMedicalHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicalUnderwritingScreen(
          pet: widget.pet,
          riskScore: widget.riskScore,
          quoteData: {
            'underwritingCaseId': widget.caseId,
            'owner': widget.owner,
          },
        ),
      ),
    );
  }

  Future<void> _uploadVetRecordPdf() async {
    setState(() {
      _isUploadingVetRecord = true;
      _vetUploadStatus = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isUploadingVetRecord = false;
        });
        return;
      }

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Unable to read PDF bytes');
      }

      setState(() {
        _vetUploadStatus = 'Uploading and parsing vet record…';
      });

      final parser = VetHistoryParser(
        aiService: GPTService(),
      );
      final parsed = await parser.parseUploadedPdfBytesForCase(
        pdfBytes: Uint8List.fromList(bytes),
        caseId: widget.caseId,
        petId: widget.pet.id,
        filename: file.name,
      );

      final parseLooksEmpty =
          parsed.diagnoses.isEmpty &&
          parsed.treatments.isEmpty &&
          parsed.medications.isEmpty &&
          parsed.vaccinations.isEmpty &&
          parsed.surgeries.isEmpty &&
          parsed.allergies.isEmpty &&
          parsed.previousClaims.isEmpty &&
          parsed.lastCheckup == null;

      if (!mounted) return;
      setState(() {
        _vetUploadStatus = parseLooksEmpty
            ? 'Vet record uploaded. We’ll review it shortly.'
            : 'Vet record uploaded and parsed.';
        _isUploadingVetRecord = false;
      });
    } on VetHistoryParseException catch (e) {
      if (!mounted) return;
      setState(() {
        _vetUploadStatus =
            'Vet record uploaded, but auto-fill failed. We’ll review it shortly. (${e.toString()})';
        _isUploadingVetRecord = false;
      });
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final lower = raw.toLowerCase();
      final isUnauthorized =
          lower.contains('firebase_storage/unauthorized') ||
          lower.contains('not authorized') ||
          lower.contains('permission');
      final friendly = isUnauthorized
          ? 'Upload blocked. Please sign in and try again, or contact support if this persists.'
          : raw.replaceAll('Exception: ', '');
      setState(() {
        _vetUploadStatus = 'Vet record upload failed: $friendly';
        _isUploadingVetRecord = false;
      });
    }
  }

  Future<void> _showSaveResumeCode() async {
    await SaveResumeDialog.show(
      context,
      ensureSaved: () async {
        // Save draft state
        await DraftService().upsertUnderwritingDraft(
          underwritingCaseId: widget.caseId,
          petName: widget.pet.name,
          riskScore: widget.riskScore,
          reason: 'Initial Intake', 
        );
      },
      title: 'Save & resume later',
      body: 'We’ll save your progress. Use this code to resume from the home page on any device.',
      copyLabel: 'Copy code',
      doneLabel: 'Done',
    );
  }

  void _handleExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Back to home?'),
        content: const Text('Any unsaved progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (shouldExit == true && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100),
            ),
          ),
          padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 8),
          child: SafeArea(
            child: Row(
              children: [
                const ClovaraLogo(
                  size: ClovaraLogoSize.large,
                  showText: true,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showSaveResumeCode,
                  icon: const Icon(Icons.bookmark_border_rounded, size: 20),
                  label: const Text('Save'),
                  style: TextButton.styleFrom(
                    foregroundColor: ClovaraColors.forest,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _handleExit,
                  icon: const Icon(Icons.close),
                  color: Colors.grey.shade600,
                  tooltip: 'Exit',
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medical History Required',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: ClovaraColors.forest,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'To finalize coverage for ${widget.pet.name}, we need to review their past medical records. This ensures we provide accurate coverage and pricing.',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Case Info Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: ClovaraColors.mist,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blueGrey.shade50),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 20, color: ClovaraColors.forest),
                                const SizedBox(width: 8),
                                Text(
                                  'Underwriting Case #${widget.caseId.substring(0, 8)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: ClovaraColors.forest,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            if (_history != null && _history!.conditions.isNotEmpty) ...[
                              const SizedBox(height: 12),
                               Text(
                                '${_history!.conditions.length} condition(s) already on file.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      
                      Text(
                        'Upload Veterinary Records',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                       const SizedBox(height: 8),
                      Text(
                        'Please upload a PDF of the full medical history from your vet.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      InkWell(
                        onTap: _isUploadingVetRecord ? null : _uploadVetRecordPdf,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isUploadingVetRecord ? Colors.grey.shade300 : ClovaraColors.clover,
                              width: 2,
                              style: BorderStyle.none, // dashed border effect requires custom painter usually, keeping simple for now
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          ),
                          // Custom Dashed Border Look or nice upload area
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isUploadingVetRecord)
                                const SizedBox(
                                  height: 32, 
                                  width: 32, 
                                  child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(ClovaraColors.clover))
                                )
                              else
                                Icon(Icons.cloud_upload_outlined, size: 48, color: ClovaraColors.clover),
                              const SizedBox(height: 16),
                              Text(
                                _isUploadingVetRecord ? 'Processing...' : 'Tap to select PDF',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _isUploadingVetRecord ? Colors.grey : ClovaraColors.forest,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_vetUploadStatus != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _vetUploadStatus!.contains('failed') ? Colors.red.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _vetUploadStatus!.contains('failed') ? Colors.red.shade200 : Colors.green.shade200,
                            ),
                          ),
                          child: Text(
                            _vetUploadStatus!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _vetUploadStatus!.contains('failed') ? Colors.red.shade800 : Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                      
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                         Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],

                      const SizedBox(height: 48),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _continueToMedicalHistory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClovaraColors.clover,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Continue to Medical History',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
