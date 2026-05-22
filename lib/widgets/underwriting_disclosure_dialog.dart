import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/underwriting_decision.dart';
import '../theme/clovara_theme.dart';

/// Disclosure dialog that presents underwriting decisions (exclusions, pricing adjustments)
/// and requires user acknowledgment before proceeding to plan selection and binding.
class UnderwritingDisclosureDialog extends StatefulWidget {
  final UnderwritingDecision decision;
  final String petName;

  const UnderwritingDisclosureDialog({
    super.key,
    required this.decision,
    required this.petName,
  });

  @override
  State<UnderwritingDisclosureDialog> createState() =>
      _UnderwritingDisclosureDialogState();
}

class _UnderwritingDisclosureDialogState
    extends State<UnderwritingDisclosureDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final decision = widget.decision;

    if (decision.outcome == UnderwritingOutcome.decline) {
      return _buildDeclineDialog();
    }

    if (decision.outcome == UnderwritingOutcome.approveWithExclusions) {
      return _buildExclusionDisclosureDialog();
    }

    // Standard approval (no disclosure needed, but confirm)
    return _buildStandardApprovalDialog();
  }

  Widget _buildDeclineDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            Icons.cancel_outlined,
            color: ClovaraColors.kWarmCoral,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Coverage not available',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clovara could not offer coverage for ${widget.petName} based on the automated eligibility rules and the information provided.',
              style: GoogleFonts.dmSans(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 16),
            _buildReasonCodesSection(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF7F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8E3DA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF2D6A4F),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This decision is generated from the same eligibility rules used for every application. You can start a new quote if details change, or contact support if any information shown is incorrect.',
                      style: GoogleFonts.dmSans(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildExclusionDisclosureDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: ClovaraColors.clover,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Approved with coverage exclusions',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clovara can offer coverage for ${widget.petName} with specific exclusions based on the medical history provided.',
              style: GoogleFonts.dmSans(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),
            Text(
              'Excluded conditions',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...widget.decision.exclusions.map(
              (exclusion) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exclusion.conditionName,
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (exclusion.notes?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                exclusion.notes!,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildReasonCodesSection(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Claims related to the excluded condition${widget.decision.exclusions.length > 1 ? 's' : ''} will not be covered. All other eligible veterinary care will be covered according to your plan terms.',
                      style: GoogleFonts.dmSans(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _acknowledged,
              onChanged: (val) {
                setState(() {
                  _acknowledged = val ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'I understand these exclusions before choosing a plan',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _acknowledged ? () => Navigator.pop(context, true) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: ClovaraColors.clover,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: const Text('Accept & Continue'),
        ),
      ],
    );
  }

  Widget _buildStandardApprovalDialog() {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.check_circle, color: ClovaraColors.clover, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Approved automatically',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.petName} passed automated eligibility with no condition-specific exclusions.',
            style: GoogleFonts.dmSans(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 16),
          _buildReasonCodesSection(),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: ClovaraColors.clover,
            foregroundColor: Colors.white,
          ),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildReasonCodesSection() {
    if (widget.decision.reasonCodes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Decision signals',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: widget.decision.reasonCodes
              .map(
                (code) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    code,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
