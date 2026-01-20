import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../components/admin_section_card.dart';
import '../../theme/clovara_theme.dart';

enum _MarketingTab {
  overview,
  channels,
  discountCodes,
  spend,
}

class AdminMarketingPage extends StatefulWidget {
  const AdminMarketingPage({super.key});

  @override
  State<AdminMarketingPage> createState() => _AdminMarketingPageState();
}

class _AdminMarketingPageState extends State<AdminMarketingPage> {
  _MarketingTab _tab = _MarketingTab.overview;

  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Marketing',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024, 1, 1),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  initialDateRange: _range,
                );
                if (picked == null) return;
                setState(() => _range = picked);
              },
              icon: const Icon(Icons.date_range_outlined, size: 18),
              label: Text('${_fmt(_range.start)} → ${_fmt(_range.end)}'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TabBar(
          value: _tab,
          onChanged: (v) => setState(() => _tab = v),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildTab()),
      ],
    );
  }

  Widget _buildTab() {
    switch (_tab) {
      case _MarketingTab.overview:
        return _MarketingOverview(range: _range);
      case _MarketingTab.channels:
        return _IntakeChannelsTab(range: _range);
      case _MarketingTab.discountCodes:
        return _DiscountCodesTab(range: _range);
      case _MarketingTab.spend:
        return _SpendTab(range: _range);
    }
  }

  static String _fmt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _TabBar extends StatelessWidget {
  final _MarketingTab value;
  final ValueChanged<_MarketingTab> onChanged;

  const _TabBar({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(_MarketingTab tab, String label, IconData icon) {
      final selected = value == tab;
      final bg = selected ? ClovaraColors.forest : Colors.white;
      final fg = selected ? Colors.white : ClovaraColors.forest;

      return ChoiceChip(
        selected: selected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
          ],
        ),
        onSelected: (_) => onChanged(tab),
        backgroundColor: Colors.white,
        selectedColor: bg,
        showCheckmark: false,
        side: BorderSide(
          color: selected ? Colors.transparent : ClovaraColors.forest.withOpacity(0.20),
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        chip(_MarketingTab.overview, 'Overview', Icons.dashboard_outlined),
        chip(_MarketingTab.channels, 'Intake Channels', Icons.hub_outlined),
        chip(_MarketingTab.discountCodes, 'Discount Codes', Icons.local_offer_outlined),
        chip(_MarketingTab.spend, 'Ad Spend', Icons.payments_outlined),
      ],
    );
  }
}

class _MarketingOverview extends StatelessWidget {
  final DateTimeRange range;

  const _MarketingOverview({required this.range});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        AdminSectionCard(
          title: 'KPI Overview',
          icon: Icons.insights_outlined,
          child: _MarketingKpiGrid(range: range),
        ),
        const SizedBox(height: 12),
        AdminSectionCard(
          title: 'Top Channels (placeholder)',
          icon: Icons.campaign_outlined,
          child: const Text(
            'Next: channel rollups + charts. This page is scaffolded and will populate once events + rollups are deployed.',
          ),
        ),
        const SizedBox(height: 12),
        AdminSectionCard(
          title: 'Top Discount Codes (placeholder)',
          icon: Icons.local_offer_outlined,
          child: const Text(
            'Next: code redemption + attribution metrics. This page is scaffolded and will populate once redemptions are recorded.',
          ),
        ),
      ],
    );
  }
}

class _MarketingKpiGrid extends StatelessWidget {
  final DateTimeRange range;

  const _MarketingKpiGrid({required this.range});

  @override
  Widget build(BuildContext context) {
    final start = Timestamp.fromDate(DateTime(range.start.year, range.start.month, range.start.day));
    final end = Timestamp.fromDate(DateTime(range.end.year, range.end.month, range.end.day).add(const Duration(days: 1)));

    final query = FirebaseFirestore.instance
        .collection('marketing_events')
        .where('ts', isGreaterThanOrEqualTo: start)
        .where('ts', isLessThan: end);

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: query.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Text('Error loading KPI data: ${snapshot.error}');
        }

        final docs = snapshot.data?.docs ?? const [];
        int sessions = 0;
        int quoteStarted = 0;
        int underwritingSubmitted = 0;
        int checkoutStarted = 0;
        int purchases = 0;
        double premium = 0;
        double spend = 0;
        double discounts = 0;

        for (final d in docs) {
          final data = d.data();
          final type = (data['type'] ?? '').toString();
          switch (type) {
            case 'session_created':
              sessions++;
              break;
            case 'quote_started':
              quoteStarted++;
              break;
            case 'underwriting_submitted':
              underwritingSubmitted++;
              break;
            case 'checkout_started':
              checkoutStarted++;
              break;
            case 'purchase_completed':
              purchases++;
              premium += (data['premium'] is num) ? (data['premium'] as num).toDouble() : 0.0;
              discounts += (data['discountAmount'] is num)
                  ? (data['discountAmount'] as num).toDouble()
                  : 0.0;
              break;
            case 'spend_recorded':
              spend += (data['spend'] is num) ? (data['spend'] as num).toDouble() : 0.0;
              break;
          }
        }

        final visitToPurchase = sessions == 0 ? 0.0 : purchases / sessions;
        final cac = purchases == 0 ? 0.0 : spend / purchases;
        final roas = spend == 0 ? 0.0 : premium / spend;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _kpi('Sessions', sessions.toString()),
            _kpi('Quote Started', quoteStarted.toString()),
            _kpi('UW Submitted', underwritingSubmitted.toString()),
            _kpi('Checkout Started', checkoutStarted.toString()),
            _kpi('Purchases', purchases.toString()),
            _kpi('Premium', premium == 0 ? '—' : '\$${premium.toStringAsFixed(2)}'),
            _kpi('Discounts', discounts == 0 ? '—' : '\$${discounts.toStringAsFixed(2)}'),
            _kpi('Spend', spend == 0 ? '—' : '\$${spend.toStringAsFixed(2)}'),
            _kpi('Visit→Purchase', '${(visitToPurchase * 100).toStringAsFixed(1)}%'),
            _kpi('CAC', cac == 0 ? '—' : '\$${cac.toStringAsFixed(2)}'),
            _kpi('ROAS', roas == 0 ? '—' : roas.toStringAsFixed(2)),
          ],
        );
      },
    );
  }

  Widget _kpi(String label, String value) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntakeChannelsTab extends StatelessWidget {
  final DateTimeRange range;

  const _IntakeChannelsTab({required this.range});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        AdminSectionCard(
          title: 'Intake Channels',
          icon: Icons.hub_outlined,
          actions: [
            FilledButton.icon(
              onPressed: () => _showCreateChannelDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Channel'),
            ),
          ],
          child: _ChannelsTable(range: range),
        ),
      ],
    );
  }

  Future<void> _showCreateChannelDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final utmSourceCtrl = TextEditingController();
    final utmMediumCtrl = TextEditingController();
    final utmCampaignCtrl = TextEditingController();
    final referrerHostCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Intake Channel'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                const SizedBox(height: 8),
                TextField(controller: utmSourceCtrl, decoration: const InputDecoration(labelText: 'UTM Source (optional)')),
                const SizedBox(height: 8),
                TextField(controller: utmMediumCtrl, decoration: const InputDecoration(labelText: 'UTM Medium (optional)')),
                const SizedBox(height: 8),
                TextField(controller: utmCampaignCtrl, decoration: const InputDecoration(labelText: 'UTM Campaign (optional)')),
                const SizedBox(height: 8),
                TextField(controller: referrerHostCtrl, decoration: const InputDecoration(labelText: 'Referrer Host (optional)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;

                final doc = FirebaseFirestore.instance.collection('intake_channels').doc();
                await doc.set({
                  'name': name,
                  'status': 'active',
                  'matchRules': {
                    'utmSource': utmSourceCtrl.text.trim(),
                    'utmMedium': utmMediumCtrl.text.trim(),
                    'utmCampaign': utmCampaignCtrl.text.trim(),
                    'referrerHost': referrerHostCtrl.text.trim(),
                  },
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    nameCtrl.dispose();
    utmSourceCtrl.dispose();
    utmMediumCtrl.dispose();
    utmCampaignCtrl.dispose();
    referrerHostCtrl.dispose();
  }
}

class _ChannelsTable extends StatelessWidget {
  final DateTimeRange range;

  const _ChannelsTable({required this.range});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('intake_channels').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Text('Error loading channels: ${snapshot.error}');
        }

        final docs = snapshot.data?.docs ?? const [];
        if (docs.isEmpty) {
          return const Text('No channels yet. Create your first intake channel.');
        }

        return DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Match Rules')),
          ],
          rows: [
            for (final doc in docs)
              DataRow(
                cells: [
                  DataCell(Text((doc.data()['name'] ?? '').toString())),
                  DataCell(Text((doc.data()['status'] ?? '').toString())),
                  DataCell(Text(_rulesSummary(doc.data()['matchRules']))),
                ],
              ),
          ],
        );
      },
    );
  }

  String _rulesSummary(dynamic rules) {
    if (rules is! Map) return '—';
    final m = rules.cast<String, dynamic>();

    final parts = <String>[];
    void add(String k, String label) {
      final v = (m[k] ?? '').toString().trim();
      if (v.isNotEmpty) parts.add('$label=$v');
    }

    add('utmSource', 'src');
    add('utmMedium', 'med');
    add('utmCampaign', 'cmp');
    add('referrerHost', 'ref');

    return parts.isEmpty ? '—' : parts.join(', ');
  }
}

class _DiscountCodesTab extends StatelessWidget {
  final DateTimeRange range;

  const _DiscountCodesTab({required this.range});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        AdminSectionCard(
          title: 'Discount Codes (Stripe Promotion Codes)',
          icon: Icons.local_offer_outlined,
          child: const Text(
            'Next: create/disable/sync promo codes via Cloud Functions and edit Firestore-based eligibility rules per code.',
          ),
        ),
      ],
    );
  }
}

class _SpendTab extends StatelessWidget {
  final DateTimeRange range;

  const _SpendTab({required this.range});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        AdminSectionCard(
          title: 'Ad Spend',
          icon: Icons.payments_outlined,
          child: const Text(
            'Next: manual spend entry + CSV import. Spend events roll into KPI overview once recorded.',
          ),
        ),
      ],
    );
  }
}
