import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/claim.dart';
import '../../services/claim_tracker_service.dart';
import '../../theme/clovara_theme.dart';
import '../../widgets/claim_timeline_widget.dart';
import '../../widgets/clover_avatar.dart';

class ClaimDetailsScreen extends StatelessWidget {
  final String claimId;

  const ClaimDetailsScreen({
    super.key,
    required this.claimId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Claim Status'),
      ),
      body: StreamBuilder<DocumentSnapshot<Claim>>(
        stream: getClaimDocument(claimId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(message: 'Failed to load claim: ${snapshot.error}');
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

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _HeaderCard(
                claim: claim,
                progress: progress,
                eta: eta,
              ),
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
              const SizedBox(height: 16),
              ClaimTimelineWidget(claim: claim, showTimestamps: true),
              const SizedBox(height: 16),
              _UpdatesCard(updates: updates),
              const SizedBox(height: 16),
              _DecisionCard(claim: claim),
              const SizedBox(height: 16),
              _PayoutStatusCard(claimId: claimId),
              const SizedBox(height: 16),
              _AttachmentsCard(attachments: claim.attachments),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  const _StatusChip({
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ClaimStatus.draft => 'DRAFT',
      ClaimStatus.submitted => 'SUBMITTED',
      ClaimStatus.processing => 'PROCESSING',
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
            'Decision details',
            style: ClovaraTypography.h3.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (claim.aiDecision != null)
            Text(
              'AI recommendation: ${claim.aiDecision!.displayName}',
              style: ClovaraTypography.bodySmall.copyWith(
                color: ClovaraColors.slate,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (denialReason != null && denialReason.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Denial reason: $denialReason',
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
              'Flags for review',
              style: ClovaraTypography.bodySmall.copyWith(
                color: ClovaraColors.slate,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ...flags.take(6).map(
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

  const _AttachmentsCard({required this.attachments});

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
          Text(
            'Documents',
            style: ClovaraTypography.h3.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
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
            ...attachments.map(
              (url) => _AttachmentRow(url: url),
            ),
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  final String url;

  const _AttachmentRow({required this.url});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 18, color: ClovaraColors.slate),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ClovaraTypography.bodySmall.copyWith(
                color: ClovaraColors.slate,
              ),
            ),
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
    case ClaimStatus.submitted:
      return ClovaraColors.info;
    case ClaimStatus.cancelled:
      return ClovaraColors.slate;
    case ClaimStatus.draft:
      return ClovaraColors.slate;
  }
}
