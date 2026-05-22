import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/underwriting_case.dart';
import '../services/draft_service.dart';
import '../services/underwriting_case_service.dart';
import '../services/user_session_service.dart';
import '../theme/clovara_theme.dart';
import '../ui/components/save_resume_dialog.dart';
import 'underwriting_intake_screen.dart';

class UnderwritingFollowUpDocumentsScreen extends StatefulWidget {
  final String? underwritingCaseId;

  const UnderwritingFollowUpDocumentsScreen({
    super.key,
    this.underwritingCaseId,
  });

  @override
  State<UnderwritingFollowUpDocumentsScreen> createState() =>
      _UnderwritingFollowUpDocumentsScreenState();
}

class _UnderwritingFollowUpDocumentsScreenState
    extends State<UnderwritingFollowUpDocumentsScreen> {
  bool _loading = true;
  String? _error;

  Map<String, dynamic>? _pending;
  UnderwritingCase? _case;

  String? get _caseId {
    final explicit = widget.underwritingCaseId?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final fromPending = _pending?['underwritingCaseId']?.toString().trim();
    if (fromPending != null && fromPending.isNotEmpty) return fromPending;
    return null;
  }

  List<Map<String, dynamic>> get _requiredEvidence {
    final raw = _pending?['requiredEvidence'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(growable: false);
    }
    return const [];
  }

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
      _pending = await UserSessionService().getPendingUnderwriting();

      // Ensure we can read/write underwriting case data.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      final caseId = _caseId;
      if (caseId == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
        return;
      }

      final service = UnderwritingCaseService();
      final fetched = await service.getCase(caseId);

      // If the user is signed in (non-anonymous) and the case belongs to a
      // different uid, do not allow resuming uploads from this session.
      final active = FirebaseAuth.instance.currentUser;
      if (active != null && !active.isAnonymous && fetched != null) {
        final caseOwner = fetched.userId.trim();
        if (caseOwner.isNotEmpty && caseOwner != active.uid) {
          if (!mounted) return;
          setState(() {
            _case = null;
            _error =
                'This saved underwriting case belongs to a different account. Sign in to the original account or clear the saved case.';
            _loading = false;
          });
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _case = fetched;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _continueToUploads() {
    final c = _case;
    final caseId = _caseId;
    if (c == null || caseId == null) return;

    final pet = c.petSnapshot;
    final owner = c.ownerSnapshot;
    if (pet == null || owner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to resume this case (missing pet/owner details).',
          ),
        ),
      );
      return;
    }

    final riskScore = _pending?['riskScore'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnderwritingIntakeScreen(
          caseId: caseId,
          pet: pet,
          owner: owner,
          riskScore: riskScore,
        ),
      ),
    );
  }

  Future<void> _clearSaved() async {
    await UserSessionService().clearPendingUnderwriting();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved follow-up cleared.')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final caseId = _caseId;
    final petName =
        _case?.petSnapshot?.name ??
        _pending?['petName']?.toString() ??
        'your pet';

    return Scaffold(
      backgroundColor: const Color(0xFFF2EFE8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAF7),
        elevation: 0,
        foregroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'More information needed',
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Save resume code',
            onPressed: () {
              SaveResumeDialog.show(
                context,
                title: 'Save & resume later',
                body:
                    'If you leave this page, use this code to return and finish the requested uploads from any device.',
                copyLabel: 'Copy code',
                doneLabel: 'Done',
              );
            },
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
          TextButton(onPressed: _clearSaved, child: const Text('Clear')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAF7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE8E3DA)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AUTOMATED CHECKPOINT',
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFF2D6A4F),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'One more detail is needed for $petName.',
                          style: GoogleFonts.playfairDisplay(
                            color: const Color(0xFF1A1A1A),
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Clovara paused this application automatically because a required detail could not be verified. Upload the requested documents and the decisioning engine will continue.',
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFF666666),
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                        if (caseId != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Case ID: $caseId',
                            style: GoogleFonts.dmSans(
                              color: const Color(0xFF888888),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        FutureBuilder<String?>(
                          future: DraftService().getLocalResumeKey(),
                          builder: (context, snap) {
                            final key = snap.data;
                            if (key == null) return const SizedBox.shrink();
                            final pretty = DraftService().prettyCode(key);
                            return Text(
                              'Resume code: $pretty',
                              style: GoogleFonts.dmSans(
                                color: const Color(0xFF888888),
                                fontSize: 12,
                              ),
                            );
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: ClovaraColors.kWarmCoral,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_requiredEvidence.isNotEmpty)
                    Expanded(
                      child: ListView.separated(
                        itemCount: _requiredEvidence.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final e = _requiredEvidence[index];
                          final title = (e['title'] ?? '').toString().trim();
                          final details = (e['details'] ?? '')
                              .toString()
                              .trim();
                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE8E3DA),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title.isEmpty ? 'Requested document' : title,
                                  style: GoogleFonts.dmSans(
                                    color: const Color(0xFF1A1A1A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (details.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    details,
                                    style: GoogleFonts.dmSans(
                                      color: const Color(0xFF666666),
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE8E3DA)),
                        ),
                        child: Text(
                          'Open your case to upload the requested record and continue the automated decision.',
                          style: GoogleFonts.dmSans(
                            color: const Color(0xFF666666),
                            fontSize: 15,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _case == null ? null : _continueToUploads,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6A4F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Upload documents & continue',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
