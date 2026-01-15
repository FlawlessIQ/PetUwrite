import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

import '../models/owner.dart';
import '../models/pet.dart';
import '../models/underwriting_medical_history.dart';
import '../ai/ai_service.dart';
import '../services/vet_history_parser.dart';
import '../services/underwriting_case_service.dart';
import '../theme/clovara_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClovaraColors.mist,
      appBar: AppBar(
        backgroundColor: ClovaraColors.white,
        elevation: 0,
        title: const Text('Underwriting Intake'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next step: medical history',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We need a bit more detail about ${widget.pet.name}\'s medical history to confirm coverage and any exclusions that may apply.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Case ID: ${widget.caseId}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                        ),
                        if (_history != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Conditions captured: ${_history!.conditions.length}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: ClovaraColors.kWarmCoral),
                          ),
                        ],

                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isUploadingVetRecord
                                ? null
                                : _uploadVetRecordPdf,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ClovaraColors.forest,
                              side: BorderSide(color: Colors.grey.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isUploadingVetRecord
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Upload vet record (PDF)'),
                          ),
                        ),
                        if (_vetUploadStatus != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _vetUploadStatus!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _continueToMedicalHistory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ClovaraColors.clover,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
