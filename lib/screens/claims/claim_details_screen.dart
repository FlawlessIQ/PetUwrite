import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/claim.dart';
import '../../services/claim_tracker_service.dart';
import '../../services/claims_service.dart';
import 'claim_intake_screen.dart';
import '../../theme/clovara_theme.dart';
import '../../widgets/claim_timeline_widget.dart';
import '../../widgets/clover_avatar.dart';

class ClaimDetailsScreen extends StatefulWidget {
  final String claimId;

  const ClaimDetailsScreen({super.key, required this.claimId});

  @override
  State<ClaimDetailsScreen> createState() => _ClaimDetailsScreenState();
}

class _ClaimDetailsScreenState extends State<ClaimDetailsScreen> {
  final ClaimsService _claimsService = ClaimsService();
  bool _busy = false;

  Future<void> _setupReimbursementMethod(
    BuildContext context,
    Claim claim,
  ) async {
    try {
      setState(() => _busy = true);

      String? maybeHttpUrl;
      final base = Uri.base;
      if (base.scheme == 'http' || base.scheme == 'https') {
        maybeHttpUrl = base.origin;
      }

      final result = await FirebaseFunctions.instance
          .httpsCallable('createReimbursementOnboardingLink')
          .call({
            if (maybeHttpUrl != null) 'returnUrl': maybeHttpUrl,
            if (maybeHttpUrl != null) 'refreshUrl': maybeHttpUrl,
          });

      final data = (result.data as Map?)?.cast<String, dynamic>() ?? {};
      final url = data['url'] as String?;
      if (url == null || url.isEmpty) {
        throw Exception('Missing onboarding URL');
      }

      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Open this link to finish setup: $url')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reimbursement setup failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshReimbursementSetupStatus(BuildContext context) async {
    try {
      setState(() => _busy = true);

      final result = await FirebaseFunctions.instance
          .httpsCallable('refreshReimbursementSetupStatus')
          .call();

      final data = (result.data as Map?)?.cast<String, dynamic>() ?? {};
      final onboarded = data['onboarded'] == true;

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            onboarded
                ? 'Reimbursement method is ready.'
                : 'Still not complete. Finish setup in Stripe, then refresh again.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Refresh failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadDocuments(BuildContext context, Claim claim) async {
    try {
      setState(() => _busy = true);

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      );

      if (result == null || result.files.isEmpty) return;

      final claimRef = getClaimDocument(claim.claimId);
      int uploaded = 0;

      for (final f in result.files) {
        final name = f.name;
        final upload = kIsWeb
            ? (f.bytes == null
                  ? null
                  : await _claimsService
                        .uploadClaimDocumentFromBytesWithMetadata(
                          f.bytes!,
                          name,
                          claim.claimId,
                        ))
            : (f.path == null
                  ? null
                  : await _claimsService.uploadClaimDocumentWithMetadata(
                      f.path!,
                      claim.claimId,
                    ));

        if (upload == null) {
          continue;
        }

        final url = upload['downloadUrl'] as String;
        final storagePath = upload['storagePath'] as String;
        final fileName = (upload['fileName'] as String?) ?? name;
        final contentType = upload['contentType'] as String?;

        // Track the attachment for robust backend automation (extraction + retries).
        // Best-effort: if Firestore rules block this subcollection write, server-side
        // automation can still hydrate attachment records from claim.attachments URLs.
        try {
          await claimRef.collection('attachments').add({
            'downloadUrl': url,
            'storagePath': storagePath,
            'fileName': fileName,
            'contentType': contentType,
            'uploadedAt': FieldValue.serverTimestamp(),
            'uploadedBy': FirebaseAuth.instance.currentUser?.uid,
            'extractionStatus': 'queued',
          });
        } catch (e) {
          print(
            '⚠️ ClaimDetails attachment metadata write blocked; continuing. error=$e',
          );
        }

        await claimRef.update({
          'attachments': FieldValue.arrayUnion([url]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        uploaded++;
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uploaded == 0
                ? 'No documents uploaded'
                : 'Uploaded $uploaded document${uploaded == 1 ? '' : 's'}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitClaim(BuildContext context, Claim claim) async {
    if (claim.status != ClaimStatus.draft) return;

    if (claim.description.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a description before submitting.')),
      );
      return;
    }

    final submitWithoutDocs = claim.attachments.isEmpty
        ? await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Submit without documents?'),
              content: const Text(
                'You haven\'t uploaded any receipts or vet records yet. You can submit now and add documents later, but it may delay review.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Submit'),
                ),
              ],
            ),
          )
        : true;

    if (submitWithoutDocs != true) return;

    try {
      setState(() => _busy = true);

      await getClaimDocument(claim.claimId).update({
        'status': ClaimStatus.submitted.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Kick off processing (best-effort).
      try {
        await FirebaseFunctions.instance
            .httpsCallable('processClaimDecision')
            .call({'claimId': claim.claimId});
      } catch (_) {
        // Ignore; claim can be processed later by backend.
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Claim submitted.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _continueWithClover(BuildContext context, Claim claim) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClaimIntakeScreen(
          policyId: claim.policyId,
          petId: claim.petId,
          draftClaimId: claim.claimId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Claim Status')),
      body: StreamBuilder<DocumentSnapshot<Claim>>(
        stream: getClaimDocument(widget.claimId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(
              message: 'Failed to load claim: ${snapshot.error}',
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final claimDoc = snapshot.data!;
          final claim = claimDoc.data();

          if (claim == null) {
            return const _ErrorState(message: 'Claim not found');
          }

          final cloverMessage = ClaimTrackerService.getCurrentMessage(claim);
          final progress = ClaimTrackerService.getProgressPercentage(claim);
          final eta = ClaimTrackerService.getEstimatedTimeRemaining(claim);
          final updates = ClaimTrackerService.getDetailedUpdates(claim);

          final canUpload =
              claim.status == ClaimStatus.draft ||
              claim.status == ClaimStatus.submitted ||
              claim.status == ClaimStatus.processing ||
              claim.status == ClaimStatus.awaitingInfo;
          final canSubmit = claim.status == ClaimStatus.draft;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _HeaderCard(claim: claim, progress: progress, eta: eta),
              const SizedBox(height: 16),
              Center(
                child: CloverAvatar(
                  expression: cloverMessage.expression,
                  state: CloverState.idle,
                  size: 120,
                  message: cloverMessage.message,
                  animated: true,
                  showGlow: claim.status == ClaimStatus.processing,
                ),
              ),
              const SizedBox(height: 14),
              _ActionCard(
                busy: _busy,
                claim: claim,
                canUpload: canUpload,
                canSubmit: canSubmit,
                onContinue: () => _continueWithClover(context, claim),
                onUpload: () => _uploadDocuments(context, claim),
                onSubmit: () => _submitClaim(context, claim),
              ),
              const SizedBox(height: 16),
              ClaimTimelineWidget(claim: claim, showTimestamps: true),
              const SizedBox(height: 16),
              _UpdatesCard(updates: updates),
              const SizedBox(height: 16),
              _DecisionCard(claim: claim),
              const SizedBox(height: 16),
              _ReimbursementMethodCard(
                ownerId: claim.ownerId,
                busy: _busy,
                onSetup: () => _setupReimbursementMethod(context, claim),
                onRefresh: () => _refreshReimbursementSetupStatus(context),
              ),
              const SizedBox(height: 16),
              _PayoutStatusCard(claimId: widget.claimId),
              const SizedBox(height: 16),
              _AttachmentsCard(
                attachments: claim.attachments,
                busy: _busy,
                canUpload: canUpload,
                onUpload: () => _uploadDocuments(context, claim),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.claim,
    required this.busy,
    required this.canUpload,
    required this.canSubmit,
    required this.onContinue,
    required this.onUpload,
    required this.onSubmit,
  });

  final Claim claim;
  final bool busy;
  final bool canUpload;
  final bool canSubmit;
  final VoidCallback onContinue;
  final VoidCallback onUpload;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isDraft = claim.status == ClaimStatus.draft;

    final primary = isDraft
        ? FilledButton.icon(
            onPressed: busy ? null : onContinue,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Continue with Clover'),
          )
        : FilledButton.icon(
            onPressed: busy || !canUpload ? null : onUpload,
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Upload documents'),
          );

    final upload = OutlinedButton.icon(
      onPressed: busy || !canUpload ? null : onUpload,
      icon: const Icon(Icons.upload_file_outlined),
      label: const Text('Upload'),
    );

    final submit = OutlinedButton.icon(
      onPressed: busy || !canSubmit ? null : onSubmit,
      icon: const Icon(Icons.check_circle_outline),
      label: const Text('Submit'),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClovaraColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                primary,
                if (isDraft) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: upload),
                      const SizedBox(width: 10),
                      Expanded(child: submit),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  Text(
                    'Upload receipts or vet records to keep things moving.',
                    style: ClovaraTypography.bodySmall.copyWith(
                      color: ClovaraColors.slate,
                    ),
                  ),
                ],
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: primary),
              if (isDraft) ...[
                const SizedBox(width: 12),
                upload,
                const SizedBox(width: 10),
                submit,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PayoutStatusCard extends StatelessWidget {
  final String claimId;

  const _PayoutStatusCard({required this.claimId});

  @override
  Widget build(BuildContext context) {
    final payoutsQuery = FirebaseFirestore.instance
        .collection('payouts')
        .where('claimId', isEqualTo: claimId)
        .limit(1);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: payoutsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Don’t block the screen for payout read issues.
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final data = docs.first.data();
        final status = (data['status'] as String? ?? 'unknown').toLowerCase();
        final amount = (data['amount'] as num?)?.toDouble();
        final currency = (data['currency'] as String? ?? 'USD').toUpperCase();
        final retryCount = (data['retryCount'] as num?)?.toInt();
        final lastError = data['lastError'] as String?;

        final (label, color) = switch (status) {
          'completed' => ('COMPLETED', ClovaraColors.forest),
          'pending' => ('IN PROGRESS', ClovaraColors.info),
          'pending_retry' => ('RETRYING', ClovaraColors.sunset),
          'failed' => ('NEEDS REVIEW', ClovaraColors.error),
          _ => ('UNKNOWN', ClovaraColors.slate),
        };

        final amountText = amount == null
            ? '—'
            : (currency == 'USD'
                  ? '\$${amount.toStringAsFixed(2)}'
                  : '${amount.toStringAsFixed(2)} $currency');

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClovaraColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Payment',
                      style: ClovaraTypography.h3.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: color.withOpacity(0.25)),
                    ),
                    child: Text(
                      label,
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Amount',
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: ClovaraColors.slate,
                      ),
                    ),
                  ),
                  Text(
                    amountText,
                    style: ClovaraTypography.body.copyWith(
                      color: ClovaraColors.forest,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (status == 'pending_retry' && retryCount != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Retry attempts: $retryCount',
                  style: ClovaraTypography.bodySmall.copyWith(
                    color: ClovaraColors.slate,
                  ),
                ),
              ],
              if (status == 'failed') ...[
                const SizedBox(height: 8),
                Text(
                  'We hit an issue sending your reimbursement. Our team will review and reprocess it shortly.',
                  style: ClovaraTypography.bodySmall.copyWith(
                    color: ClovaraColors.slate,
                  ),
                ),
                if (lastError != null && lastError.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Reference: ${lastError.length > 80 ? '${lastError.substring(0, 80)}…' : lastError}',
                    style: ClovaraTypography.bodySmall.copyWith(
                      color: ClovaraColors.slate,
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ReimbursementMethodCard extends StatelessWidget {
  final String ownerId;
  final bool busy;
  final VoidCallback onSetup;
  final VoidCallback onRefresh;

  const _ReimbursementMethodCard({
    required this.ownerId,
    required this.busy,
    required this.onSetup,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (ownerId.trim().isEmpty) return const SizedBox.shrink();

    final userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(ownerId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final connectAccountId = data['stripeConnectAccountId'] as String?;
        final onboarded = data['stripeConnectOnboarded'] == true;

        final ready =
            connectAccountId != null &&
            connectAccountId.isNotEmpty &&
            onboarded;

        final (label, color) = ready
            ? ('READY', ClovaraColors.forest)
            : ('NOT SET UP', ClovaraColors.sunset);

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClovaraColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reimbursement method',
                      style: ClovaraTypography.h3.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: color.withOpacity(0.25)),
                    ),
                    child: Text(
                      label,
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                ready
                    ? 'Bank transfer is ready. If your claim is approved, this helps us send your reimbursement faster.'
                    : 'Set up bank transfer now to avoid delays if your claim is approved.',
                style: ClovaraTypography.bodySmall.copyWith(
                  color: ClovaraColors.slate,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Powered by Stripe (we never store your bank details)',
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: ClovaraColors.slate,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: busy ? null : onRefresh,
                    child: const Text('Refresh'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: busy ? null : onSetup,
                    icon: const Icon(Icons.account_balance_outlined, size: 18),
                    label: Text(ready ? 'Manage' : 'Set up'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Claim claim;
  final int progress;
  final String eta;

  const _HeaderCard({
    required this.claim,
    required this.progress,
    required this.eta,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(claim.status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ClovaraColors.mist,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      claim.claimType.displayName,
                      style: ClovaraTypography.h3.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Incident: ${DateFormat.yMMMd().format(claim.incidentDate)}',
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: ClovaraColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: claim.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Claim amount',
                  style: ClovaraTypography.bodySmall.copyWith(
                    color: ClovaraColors.slate,
                  ),
                ),
              ),
              Text(
                '\$${claim.claimAmount.toStringAsFixed(2)}',
                style: ClovaraTypography.body.copyWith(
                  color: ClovaraColors.forest,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress / 100.0,
              minHeight: 10,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$progress% complete',
                style: ClovaraTypography.bodySmall.copyWith(
                  color: ClovaraColors.slate,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                eta,
                style: ClovaraTypography.bodySmall.copyWith(
                  color: ClovaraColors.slate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ClaimStatus status;
  final Color color;

  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ClaimStatus.draft => 'DRAFT',
      ClaimStatus.submitted => 'SUBMITTED',
      ClaimStatus.processing => 'PROCESSING',
      ClaimStatus.awaitingInfo => 'INFO NEEDED',
      ClaimStatus.settling => 'PAYMENT',
      ClaimStatus.settled => 'SETTLED',
      ClaimStatus.denied => 'DENIED',
      ClaimStatus.cancelled => 'CANCELLED',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: ClovaraTypography.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _UpdatesCard extends StatelessWidget {
  final List<String> updates;

  const _UpdatesCard({required this.updates});

  @override
  Widget build(BuildContext context) {
    if (updates.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClovaraColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest updates',
            style: ClovaraTypography.h3.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...updates.map(
            (u) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                u,
                style: ClovaraTypography.bodySmall.copyWith(
                  color: ClovaraColors.slate,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  final Claim claim;

  const _DecisionCard({required this.claim});

  @override
  Widget build(BuildContext context) {
    if (claim.aiDecision == null && claim.aiReasoningExplanation == null) {
      return const SizedBox.shrink();
    }

    final reasoning = claim.aiReasoningExplanation ?? {};
    final denialReason = reasoning['denialReason'] as String?;
    final explanation = reasoning['explanation'] as String?;
    final flags = (reasoning['flagsForReview'] as List?)?.cast<dynamic>();

    final isDenied = claim.status == ClaimStatus.denied;
    final awaitingInfo = claim.status == ClaimStatus.awaitingInfo;
    final inProgress = !isDenied && claim.status == ClaimStatus.processing;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClovaraColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDenied
                ? 'Decision'
                : awaitingInfo
                ? 'Information needed'
                : 'Review update',
            style: ClovaraTypography.h3.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (awaitingInfo)
            Text(
              "We need a bit more information to complete review. Upload the requested documents (or reply in Clover to clarify details) and we'll continue automatically.",
              style: ClovaraTypography.bodySmall.copyWith(
                color: ClovaraColors.slate,
              ),
            ),
          if (inProgress)
            Text(
              "Review in progress — we're verifying your documents and policy details now.",
              style: ClovaraTypography.bodySmall.copyWith(
                color: ClovaraColors.slate,
              ),
            ),
          if (isDenied &&
              denialReason != null &&
              denialReason.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: $denialReason',
              style: ClovaraTypography.bodySmall.copyWith(
                color: ClovaraColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (explanation != null && explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              explanation,
              style: ClovaraTypography.bodySmall.copyWith(
                color: ClovaraColors.slate,
              ),
            ),
          ],
          if (flags != null && flags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'To keep things moving',
              style: ClovaraTypography.bodySmall.copyWith(
                color: ClovaraColors.slate,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...flags
                .take(6)
                .map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• ${f.toString()}',
                      style: ClovaraTypography.bodySmall.copyWith(
                        color: ClovaraColors.slate,
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentsCard extends StatelessWidget {
  final List<String> attachments;

  final bool busy;
  final bool canUpload;
  final VoidCallback onUpload;

  const _AttachmentsCard({
    required this.attachments,
    required this.busy,
    required this.canUpload,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClovaraColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Documents',
                  style: ClovaraTypography.h3.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (canUpload)
                OutlinedButton.icon(
                  onPressed: busy ? null : onUpload,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Upload'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (attachments.isEmpty)
            Text(
              'No documents uploaded yet.',
              style: ClovaraTypography.bodySmall.copyWith(
                color: ClovaraColors.slate,
              ),
            )
          else
            ...attachments.map((url) => _AttachmentRow(url: url)),
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  final String url;

  const _AttachmentRow({required this.url});

  String _friendlyName(String value) {
    try {
      final uri = Uri.parse(value);
      final segments = uri.pathSegments;

      // Firebase Storage download URLs look like:
      // /v0/b/<bucket>/o/<urlEncodedObjectPath>?alt=media&token=...
      final oIndex = segments.indexOf('o');
      if (oIndex != -1 && oIndex + 1 < segments.length) {
        final objectPath = Uri.decodeComponent(segments[oIndex + 1]);
        final parts = objectPath.split('/').where((p) => p.trim().isNotEmpty);
        final last = parts.isEmpty ? null : parts.last;
        if (last != null && last.trim().isNotEmpty) return last;
      }

      // Generic URLs: use last path segment.
      if (segments.isNotEmpty) {
        final last = segments.last;
        if (last.trim().isNotEmpty) return Uri.decodeComponent(last);
      }
    } catch (_) {
      // Ignore and fall back.
    }
    return 'Document';
  }

  IconData _iconFor(String nameOrUrl) {
    final lower = nameOrUrl.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp')) {
      return Icons.image_outlined;
    }
    return Icons.description_outlined;
  }

  Future<void> _open(BuildContext context) async {
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        throw Exception('Invalid document URL');
      }

      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Open this link: $url')));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open document: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _friendlyName(url);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: ClovaraColors.mist,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClovaraColors.border),
            ),
            child: Row(
              children: [
                Icon(_iconFor(name), size: 18, color: ClovaraColors.slate),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ClovaraTypography.bodySmall.copyWith(
                          color: ClovaraColors.forest,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to open',
                        style: ClovaraTypography.bodySmall.copyWith(
                          color: ClovaraColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Open',
                  onPressed: () => _open(context),
                  icon: const Icon(Icons.open_in_new, size: 18),
                ),
                IconButton(
                  tooltip: 'Copy link',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied document link')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: ClovaraTypography.body.copyWith(color: ClovaraColors.error),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

Color _statusColor(ClaimStatus status) {
  switch (status) {
    case ClaimStatus.settled:
      return ClovaraColors.success;
    case ClaimStatus.settling:
      return ClovaraColors.success;
    case ClaimStatus.denied:
      return ClovaraColors.error;
    case ClaimStatus.processing:
      return ClovaraColors.sunset;
    case ClaimStatus.awaitingInfo:
      return ClovaraColors.sunset;
    case ClaimStatus.submitted:
      return ClovaraColors.info;
    case ClaimStatus.cancelled:
      return ClovaraColors.slate;
    case ClaimStatus.draft:
      return ClovaraColors.slate;
  }
}
