import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../components/admin_kpi_card.dart';
import '../components/admin_section_card.dart';
import '../../theme/clovara_theme.dart';

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
                AdminSectionCard(
                  title: 'Operational Alerts',
                  icon: Icons.notifications_none_outlined,
                  actions: [
                    TextButton(onPressed: onOpenHealth, child: const Text('Open Health')),
                  ],
                  child: const Text(
                    'Wire this to SLA breaches, payout failures, fraud flags, rule deploy errors.\n'
                    'The panel is intentionally designed for action, not passive monitoring.',
                  ),
                ),
                const SizedBox(height: 16),
                _RecentActivityCard(firestore: firestore),
              ],
            );

            final right = Column(
              children: [
                AdminSectionCard(
                  title: 'Work Queues',
                  icon: Icons.inbox_outlined,
                  child: Column(
                    children: [
                      _QueueTile(
                        title: 'Underwriting Inbox',
                        subtitle: 'Review, annotate, decide, override with audit trail.',
                        icon: Icons.rule_folder_outlined,
                        color: ClovaraColors.clover,
                        onTap: onOpenUnderwriting,
                      ),
                      const SizedBox(height: 10),
                      _QueueTile(
                        title: 'Claims Inbox',
                        subtitle: 'Fraud flags, severity indicators, SLA timers, bulk triage.',
                        icon: Icons.fact_check_outlined,
                        color: ClovaraColors.sunset,
                        onTap: onOpenClaims,
                      ),
                      const SizedBox(height: 10),
                      _QueueTile(
                        title: 'Policies Pipeline',
                        subtitle: 'Bind → active → renewal → churn with conversion insights.',
                        icon: Icons.policy_outlined,
                        color: Colors.indigo,
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
                    '• AI model outputs (confidence + reasoning)\n'
                    '• Human decision + override rationale\n'
                    '• Complete audit trail (who/what/when)',
                  ),
                ),
              ],
            );

            if (!wide) {
              return Column(
                children: [
                  left,
                  const SizedBox(height: 16),
                  right,
                ],
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
          firestore.collection('underwriting_cases').where('status', whereIn: ['submitted', 'assessed', 'referred']).get(),
          firestore.collection('claims').where('status', isEqualTo: 'processing').get(),
          firestore.collection('policies').where('status', isEqualTo: 'active').get(),
        ]),
      ),
      builder: (context, snap) {
        final uwOpen = snap.data?[0].docs.length;
        final claimsPending = snap.data?[1].docs.length;
        final activePolicies = snap.data?[2].docs.length;

        Widget buildCard(Widget card) => card;

        final cards = <Widget>[
          buildCard(
            AdminKpiCard(
              label: 'Underwriting Open',
              value: uwOpen?.toString() ?? '—',
              icon: Icons.rule_folder_outlined,
              color: ClovaraColors.clover,
              onTap: onOpenUnderwriting,
            ),
          ),
          buildCard(
            AdminKpiCard(
              label: 'Claims Pending',
              value: claimsPending?.toString() ?? '—',
              icon: Icons.fact_check_outlined,
              color: ClovaraColors.sunset,
              onTap: onOpenClaims,
            ),
          ),
          buildCard(
            AdminKpiCard(
              label: 'Active Policies',
              value: activePolicies?.toString() ?? '—',
              icon: Icons.policy_outlined,
              color: Colors.indigo,
              onTap: onOpenPolicies,
            ),
          ),
          buildCard(
            AdminKpiCard(
              label: 'System Health',
              value: 'Operational',
              icon: Icons.monitor_heart_outlined,
              color: ClovaraColors.forest,
              onTap: onOpenHealth,
            ),
          ),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1200 ? 4 : (constraints.maxWidth >= 860 ? 2 : 1);

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
          border: Border.all(color: color.withOpacity(0.25)),
          color: color.withOpacity(0.06),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.68),
                        ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
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
        stream: firestore.collection('audit_logs').orderBy('timestamp', descending: true).limit(12).snapshots(),
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
                          color: ClovaraColors.clover,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          (doc.data()['action'] ?? doc.data()['eventType'] ?? 'event').toString(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        (doc.data()['actorEmail'] ?? '').toString(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
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
