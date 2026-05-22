import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../components/admin_kpi_card.dart';
import '../components/admin_section_card.dart';
import '../admin_theme.dart';

class AdminOverviewPage extends StatelessWidget {
  final VoidCallback onOpenUnderwriting;
  final VoidCallback onOpenClaims;
  final VoidCallback onOpenPolicies;
  final VoidCallback onOpenHealth;

  const AdminOverviewPage({
    super.key,
    required this.onOpenUnderwriting,
    required this.onOpenClaims,
    required this.onOpenPolicies,
    required this.onOpenHealth,
  });

  static const _activeUnderwritingStatuses = [
    'in_progress',
    'submitted',
    'assessed',
    'referred',
  ];

  static const _activeClaimStatuses = [
    'submitted',
    'processing',
    'awaiting_info',
    'awaitingInfo',
    'needs_info',
    'awaiting_documents',
  ];

  static const _claimInfoNeededStatuses = [
    'awaiting_info',
    'awaitingInfo',
    'needs_info',
    'awaiting_documents',
  ];

  static const _payoutExceptionStatuses = [
    'failed',
    'pending_retry',
    'escalated',
  ];

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return ListView(
      children: [
        _buildKpiRow(context, firestore),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1100;

            final left = Column(
              children: [
                _AutomationAlertsCard(
                  firestore: firestore,
                  onOpenUnderwriting: onOpenUnderwriting,
                  onOpenClaims: onOpenClaims,
                  onOpenHealth: onOpenHealth,
                ),
                const SizedBox(height: 16),
                _IntegritySignalsCard(firestore: firestore),
                const SizedBox(height: 16),
                _RecentActivityCard(firestore: firestore),
              ],
            );

            final right = Column(
              children: [
                AdminSectionCard(
                  title: 'Automation Control',
                  icon: Icons.hub_outlined,
                  child: Column(
                    children: [
                      _QueueTile(
                        title: 'Decision Ledger',
                        subtitle:
                            'Search every quote, exclusion, decline, evidence signal, and bind event.',
                        icon: Icons.account_tree_outlined,
                        color: AdminColors.success,
                        onTap: onOpenUnderwriting,
                      ),
                      const SizedBox(height: 10),
                      _QueueTile(
                        title: 'Claims Automation',
                        subtitle:
                            'Monitor rules checks, fraud signals, payout status, and SLA exceptions.',
                        icon: Icons.verified_outlined,
                        color: AdminColors.warning,
                        onTap: onOpenClaims,
                      ),
                      const SizedBox(height: 10),
                      _QueueTile(
                        title: 'Policies Pipeline',
                        subtitle:
                            'Bind → active → renewal → churn with conversion insights.',
                        icon: Icons.policy_outlined,
                        color: AdminColors.info,
                        onTap: onOpenPolicies,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AdminSectionCard(
                  title: 'Decision Transparency',
                  icon: Icons.psychology_outlined,
                  child: const Text(
                    'Every decision surface in this console is designed to show:\n'
                    '• Data extracted from records, invoices, and application answers\n'
                    '• Deterministic rules fired, AI confidence, and conflict/fraud signals\n'
                    '• Complete immutable audit trail for customer disclosures and automated outcomes',
                  ),
                ),
              ],
            );

            if (!wide) {
              return Column(
                children: [left, const SizedBox(height: 16), right],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                const SizedBox(width: 16),
                SizedBox(width: 420, child: right),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildKpiRow(BuildContext context, FirebaseFirestore firestore) {
    return StreamBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
      stream: Stream.fromFuture(
        Future.wait([
          firestore
              .collection('underwriting_cases')
              .where('status', whereIn: _activeUnderwritingStatuses)
              .get(),
          firestore
              .collection('claims')
              .where('status', whereIn: _activeClaimStatuses)
              .get(),
          firestore
              .collection('policies')
              .where('status', isEqualTo: 'active')
              .get(),
          firestore.collection('underwriting_cases').limit(100).get(),
        ]),
      ),
      builder: (context, snap) {
        final uwOpen = snap.data?[0].docs.length;
        final claimsPending = snap.data?[1].docs.length;
        final activePolicies = snap.data?[2].docs.length;
        final recentCases = snap.data?[3].docs ?? const [];
        final decidedCases = recentCases
            .where((doc) {
              final data = doc.data();
              final outcome = (data['decisionOutcome'] ?? '').toString().trim();
              final status = (data['status'] ?? '').toString().toLowerCase();
              return outcome.isNotEmpty ||
                  status == 'approved' ||
                  status == 'declined' ||
                  status == 'bound';
            })
            .toList(growable: false);
        final noTouchCases = decidedCases.where((doc) {
          final decidedBy = (doc.data()['decisionDecidedBy'] ?? '')
              .toString()
              .toLowerCase();
          return decidedBy.isEmpty ||
              (!decidedBy.contains('manual') && !decidedBy.contains('human'));
        }).length;
        final noTouchRate = decidedCases.isEmpty
            ? '—'
            : '${((noTouchCases / decidedCases.length) * 100).round()}%';

        Widget buildCard(Widget card) => card;

        final cards = <Widget>[
          buildCard(
            AdminKpiCard(
              label: 'No-touch UW',
              value: noTouchRate,
              icon: Icons.bolt_outlined,
              color: AdminColors.success,
              onTap: onOpenUnderwriting,
            ),
          ),
          buildCard(
            AdminKpiCard(
              label: 'Automation Exceptions',
              value: uwOpen?.toString() ?? '—',
              icon: Icons.report_gmailerrorred_outlined,
              color: AdminColors.warning,
              onTap: onOpenUnderwriting,
            ),
          ),
          buildCard(
            AdminKpiCard(
              label: 'Claims Checks',
              value: claimsPending?.toString() ?? '—',
              icon: Icons.fact_check_outlined,
              color: AdminColors.warning,
              onTap: onOpenClaims,
            ),
          ),
          buildCard(
            AdminKpiCard(
              label: 'Active Policies',
              value: activePolicies?.toString() ?? '—',
              icon: Icons.policy_outlined,
              color: AdminColors.info,
              onTap: onOpenPolicies,
            ),
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1200
                ? 4
                : (constraints.maxWidth >= 860 ? 2 : 1);

            // Use a fixed main-axis extent instead of an aspect ratio.
            // The old aspect ratio produced overly tall tiles on wide layouts.
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 104,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              itemBuilder: (context, index) => cards[index],
            );
          },
        );
      },
    );
  }
}

class _AutomationAlertsCard extends StatelessWidget {
  final FirebaseFirestore firestore;
  final VoidCallback onOpenUnderwriting;
  final VoidCallback onOpenClaims;
  final VoidCallback onOpenHealth;

  const _AutomationAlertsCard({
    required this.firestore,
    required this.onOpenUnderwriting,
    required this.onOpenClaims,
    required this.onOpenHealth,
  });

  @override
  Widget build(BuildContext context) {
    return AdminSectionCard(
      title: 'Automation Alerts',
      icon: Icons.notifications_none_outlined,
      actions: [
        TextButton(onPressed: onOpenHealth, child: const Text('Open Health')),
      ],
      child: FutureBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
        future: Future.wait([
          firestore
              .collection('underwriting_cases')
              .where('status', whereIn: ['in_progress', 'referred'])
              .limit(20)
              .get(),
          firestore
              .collection('claims')
              .where(
                'status',
                whereIn: AdminOverviewPage._claimInfoNeededStatuses,
              )
              .limit(20)
              .get(),
          firestore
              .collection('payouts')
              .where(
                'status',
                whereIn: AdminOverviewPage._payoutExceptionStatuses,
              )
              .limit(20)
              .get(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Text('Failed to load automation alerts: ${snapshot.error}');
          }

          final underwritingDocs = snapshot.data?[0].docs ?? const [];
          final claimsDocs = snapshot.data?[1].docs ?? const [];
          final payoutDocs = snapshot.data?[2].docs ?? const [];

          final alerts = <_AutomationAlert>[
            if (underwritingDocs.isNotEmpty)
              _AutomationAlert(
                title: 'Evidence loop active',
                count: underwritingDocs.length,
                description:
                    'Applications waiting for self-serve vet records, clarifiers, or conflicting-data resolution.',
                icon: Icons.assignment_late_outlined,
                color: AdminColors.warning,
                onOpen: onOpenUnderwriting,
              ),
            if (claimsDocs.isNotEmpty)
              _AutomationAlert(
                title: 'Claim information needed',
                count: claimsDocs.length,
                description:
                    'Claims paused for customer documents or invoice details before automated completion.',
                icon: Icons.receipt_long_outlined,
                color: AdminColors.info,
                onOpen: onOpenClaims,
              ),
            if (payoutDocs.isNotEmpty)
              _AutomationAlert(
                title: 'Payout reconciliation',
                count: payoutDocs.length,
                description:
                    'Failed reimbursement attempts that need payment-system recovery, not claim adjudication.',
                icon: Icons.payments_outlined,
                color: AdminColors.danger,
                onOpen: onOpenClaims,
              ),
          ];

          if (alerts.isEmpty) {
            return _AlertClearState(onOpenHealth: onOpenHealth);
          }

          return Column(
            children: alerts
                .map(
                  (alert) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AutomationAlertRow(alert: alert),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _AutomationAlert {
  const _AutomationAlert({
    required this.title,
    required this.count,
    required this.description,
    required this.icon,
    required this.color,
    required this.onOpen,
  });

  final String title;
  final int count;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onOpen;
}

class _AutomationAlertRow extends StatelessWidget {
  const _AutomationAlertRow({required this.alert});

  final _AutomationAlert alert;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: alert.onOpen,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: AdminColors.surfaceRaised,
          border: Border.all(color: AdminColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: alert.color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: alert.color.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: alert.color.withOpacity(0.16)),
                ),
                child: Icon(alert.icon, color: alert.color, size: 21),
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
                            alert.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AdminColors.text,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: alert.color.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            alert.count.toString(),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: alert.color,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      alert.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AdminColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right, color: AdminColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertClearState extends StatelessWidget {
  final VoidCallback onOpenHealth;

  const _AlertClearState({required this.onOpenHealth});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surfaceRaised,
        border: Border.all(color: AdminColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AdminColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AdminColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No active automation alerts. Continue watching health, webhooks, and reconciliation jobs.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AdminColors.muted,
                height: 1.35,
              ),
            ),
          ),
          TextButton(onPressed: onOpenHealth, child: const Text('Health')),
        ],
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QueueTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AdminColors.border),
          color: AdminColors.surfaceRaised,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.16)),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AdminColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AdminColors.muted),
          ],
        ),
      ),
    );
  }
}

class _IntegritySignalsCard extends StatelessWidget {
  final FirebaseFirestore firestore;

  const _IntegritySignalsCard({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return AdminSectionCard(
      title: 'Integrity & Fraud Signals',
      icon: Icons.security_outlined,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            'Last 100 cases',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.58),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('underwriting_cases')
            .orderBy('updatedAt', descending: true)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Text('Failed to load integrity signals: ${snapshot.error}');
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Text(
              'No recent decision cases yet. Signals will appear here once quote traffic starts.',
            );
          }

          var evidenceRequests = 0;
          var highSeveritySignals = 0;
          var automatedDeclines = 0;
          var cleanDecisions = 0;

          for (final doc in docs) {
            final data = doc.data();
            final status = (data['status'] ?? '').toString().toLowerCase();
            final outcome = (data['decisionOutcome'] ?? '')
                .toString()
                .toLowerCase();

            final requiredEvidence =
                data['requiredEvidence'] ?? data['requiredEvidenceCodes'];
            if (status == 'referred' ||
                status == 'in_progress' ||
                (requiredEvidence is List && requiredEvidence.isNotEmpty)) {
              evidenceRequests++;
            }

            final fraudSignals =
                data['fraudSignals'] ??
                data['conflictSignals'] ??
                data['integritySignals'];
            if (fraudSignals is List &&
                fraudSignals.any((signal) => _isHighSeveritySignal(signal))) {
              highSeveritySignals++;
            }

            if (status == 'declined' || outcome.contains('decline')) {
              automatedDeclines++;
            }

            final integrityPassed = data['integrityPassed'] == true;
            final pricingEnabled = data['pricingEnabled'] == true;
            if (integrityPassed && pricingEnabled) {
              cleanDecisions++;
            }
          }

          return Column(
            children: [
              _SignalRow(
                label: 'Evidence requests',
                value: evidenceRequests.toString(),
                description:
                    'Self-serve records, clinic details, or conflict clarification needed.',
                color: AdminColors.warning,
              ),
              const SizedBox(height: 10),
              _SignalRow(
                label: 'High-severity signals',
                value: highSeveritySignals.toString(),
                description:
                    'Critical fraud, identity, document, or conflicting-data signals.',
                color: AdminColors.danger,
              ),
              const SizedBox(height: 10),
              _SignalRow(
                label: 'Automated declines',
                value: automatedDeclines.toString(),
                description:
                    'Final deterministic outcomes with no payment collection.',
                color: AdminColors.warning,
              ),
              const SizedBox(height: 10),
              _SignalRow(
                label: 'Clean bind-ready decisions',
                value: cleanDecisions.toString(),
                description:
                    'Integrity passed and pricing enabled for straight-through bind.',
                color: AdminColors.success,
              ),
            ],
          );
        },
      ),
    );
  }

  static bool _isHighSeveritySignal(Object? raw) {
    if (raw is! Map) return false;
    final severity = (raw['severity'] ?? '').toString().toLowerCase();
    return severity == 'high' || severity == 'critical';
  }
}

class _SignalRow extends StatelessWidget {
  final String label;
  final String value;
  final String description;
  final Color color;

  const _SignalRow({
    required this.label,
    required this.value,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surfaceRaised,
        border: Border.all(color: AdminColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.16)),
            ),
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AdminColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  final FirebaseFirestore firestore;

  const _RecentActivityCard({required this.firestore});

  @override
  Widget build(BuildContext context) {
    return AdminSectionCard(
      title: 'Recent Activity',
      icon: Icons.history,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('audit_logs')
            .orderBy('timestamp', descending: true)
            .limit(12)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Text('Failed to load activity: ${snapshot.error}');
          }

          final items = snapshot.data?.docs ?? const [];
          if (items.isEmpty) {
            return const Text('No audit activity found yet.');
          }

          return Column(
            children: [
              for (final doc in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: AdminColors.success,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (doc.data()['action'] ??
                                  doc.data()['eventType'] ??
                                  'event')
                              .toString(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        (doc.data()['actorEmail'] ?? '').toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
