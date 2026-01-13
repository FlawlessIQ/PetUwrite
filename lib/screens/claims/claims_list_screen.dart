import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/clovara_theme.dart';
import 'claim_details_screen.dart';

class ClaimsListScreen extends StatelessWidget {
  const ClaimsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Claims'),
      ),
      body: user == null
          ? const _EmptyState(message: 'Please sign in to view your claims.')
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('claims')
                  .where('ownerId', isEqualTo: user.uid)
                  .orderBy('updatedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _EmptyState(message: 'Error loading claims: ${snapshot.error}');
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const _EmptyState(
                    message: 'No claims yet. When you file a claim, it will appear here.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final claimType = (data['claimType'] as String?) ?? 'Claim';
                    final status = (data['status'] as String?) ?? 'processing';
                    final amount = (data['claimAmount'] as num?)?.toDouble() ?? 0.0;
                    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

                    final statusColor = _statusColor(status);

                    return Container(
                      decoration: BoxDecoration(
                        color: ClovaraColors.mist,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ClaimDetailsScreen(claimId: doc.id),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _statusIcon(status),
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
                                        claimType.toUpperCase(),
                                        style: ClovaraTypography.body.copyWith(
                                          color: ClovaraColors.forest,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            status.toUpperCase(),
                                            style: ClovaraTypography.bodySmall.copyWith(
                                              color: statusColor,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (updatedAt != null) ...[
                                            const SizedBox(width: 10),
                                            Text(
                                              '• ${DateFormat.yMMMd().add_jm().format(updatedAt)}',
                                              style: ClovaraTypography.bodySmall.copyWith(
                                                color: ClovaraColors.slate,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (amount > 0)
                                  Text(
                                    '\$${amount.toStringAsFixed(0)}',
                                    style: ClovaraTypography.body.copyWith(
                                      color: ClovaraColors.forest,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.chevron_right,
                                  color: ClovaraColors.slate.withOpacity(0.8),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: ClovaraTypography.body.copyWith(color: ClovaraColors.slate),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'settled':
      return ClovaraColors.success;
    case 'settling':
    case 'approved':
      return ClovaraColors.success;
    case 'denied':
    case 'rejected':
      return ClovaraColors.error;
    case 'submitted':
      return ClovaraColors.info;
    default:
      return ClovaraColors.sunset;
  }
}

IconData _statusIcon(String status) {
  switch (status.toLowerCase()) {
    case 'settled':
      return Icons.check_circle;
    case 'settling':
    case 'approved':
      return Icons.payments;
    case 'denied':
    case 'rejected':
      return Icons.cancel;
    case 'submitted':
      return Icons.file_upload;
    default:
      return Icons.pending;
  }
}
