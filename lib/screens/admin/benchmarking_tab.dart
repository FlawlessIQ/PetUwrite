import 'package:flutter/material.dart';
import 'package:csv/csv.dart';

import '../../services/benchmarking_service.dart';
import '../../utils/csv_download.dart';

class BenchmarkingTab extends StatefulWidget {
  const BenchmarkingTab({super.key});

  @override
  State<BenchmarkingTab> createState() => _BenchmarkingTabState();
}

class _BenchmarkingTabState extends State<BenchmarkingTab> {
  final BenchmarkingService _service = BenchmarkingService();

  bool _refreshing = false;
  bool _computing = false;

  DateTime _start = DateTime(DateTime.now().year, DateTime.now().month - 2, 1);
  DateTime _end = DateTime.now();

  String _cohort = '';

  String? _error;
  PortfolioMetricsSnapshot? _selectedSnapshot;

  Future<void> _exportSnapshotCsv(PortfolioMetricsSnapshot snapshot) async {
    try {
      final rows = <List<String>>[
        const ['field', 'value'],
        ['snapshotId', snapshot.id],
        [
          'computedAt',
          snapshot.computedAt != null
              ? snapshot.computedAt!.toIso8601String()
              : '',
        ],
        ['benchmarkVersionId', snapshot.benchmarkVersionId ?? ''],
        ...snapshot.filters.entries.map(
          (e) => ['filter.${e.key}', '${e.value}'],
        ),
        ...snapshot.metrics.entries.map(
          (e) => ['metric.${e.key}', '${e.value}'],
        ),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final filename = 'benchmark_snapshot_${snapshot.id}.csv';
      downloadCsv(filename, csv);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ CSV downloaded'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } on UnsupportedError catch (e) {
      if (!mounted) return;
      _showError('CSV export not supported here: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to export CSV: $e');
    }
  }

  void _showError(String message) {
    setState(() => _error = message);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;

    setState(() {
      _error = null;
      if (isStart) {
        _start = picked;
        if (_start.isAfter(_end)) {
          _end = _start;
        }
      } else {
        _end = picked;
        if (_end.isBefore(_start)) {
          _start = _end;
        }
      }
    });
  }

  Future<void> _refreshReference() async {
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      await _service.refreshBenchmarkReference(
        source: 'Curated internal reference (seed)',
        notes: 'Refreshed from bundled seed; no external scraping.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Reference data refreshed'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to refresh reference: $e');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _computeSnapshot() async {
    setState(() {
      _computing = true;
      _error = null;
    });
    try {
      final result = await _service.computePortfolioMetricsSnapshot(
        start: _start,
        end: _end,
        cohort: _cohort,
      );

      if (!mounted) return;
      final snapshotId = result['snapshotId']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Snapshot computed${snapshotId != null ? ': $snapshotId' : ''}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to compute snapshot: $e');
    } finally {
      if (mounted) setState(() => _computing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          title: 'Reference Data',
          subtitle:
              'Versioned benchmark bands with provenance. Admin-readable; server-written.',
          trailing: FilledButton.icon(
            onPressed: _refreshing ? null : _refreshReference,
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_outlined, size: 18),
            label: Text(_refreshing ? 'Refreshing…' : 'Refresh'),
          ),
          child: StreamBuilder<BenchmarkReferenceCurrent?>(
            stream: _service.watchCurrentReference(),
            builder: (context, snap) {
              final current = snap.data;
              if (snap.connectionState == ConnectionState.waiting) {
                return const _Skeleton(height: 110);
              }
              if (current == null || current.activeVersionId.isEmpty) {
                return _EmptyState(
                  title: 'No reference version published yet',
                  actionText: 'Refresh to seed reference bands',
                );
              }

              return StreamBuilder<BenchmarkReferenceVersion?>(
                stream: _service.watchReferenceVersion(current.activeVersionId),
                builder: (context, versionSnap) {
                  final version = versionSnap.data;
                  if (versionSnap.connectionState == ConnectionState.waiting) {
                    return const _Skeleton(height: 140);
                  }
                  if (version == null) {
                    return Text(
                      'Active version not found: ${current.activeVersionId}',
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          _Chip(label: 'Version', value: version.versionId),
                          _Chip(label: 'Source', value: version.source),
                          if (version.checksum != null &&
                              version.checksum!.isNotEmpty)
                            _Chip(label: 'Checksum', value: version.checksum!),
                          if (version.createdAt != null)
                            _Chip(
                              label: 'Created',
                              value: _fmtDateTime(version.createdAt!),
                            ),
                        ],
                      ),
                      if (version.notes != null &&
                          version.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          version.notes!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _BandsTable(bands: version.bands),
                    ],
                  );
                },
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        _Section(
          title: 'Portfolio Snapshot',
          subtitle:
              'Compute Clovara metrics for a period/cohort and compare to the reference bands.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(isStart: true),
                    icon: const Icon(Icons.date_range_outlined, size: 18),
                    label: Text('Start: ${_fmtDate(_start)}'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickDate(isStart: false),
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text('End: ${_fmtDate(_end)}'),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Cohort (optional)',
                        hintText: 'e.g., dog, cat, CA, premium-tier',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => _cohort = v,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _computing ? null : _computeSnapshot,
                    icon: _computing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.calculate_outlined, size: 18),
                    label: Text(_computing ? 'Computing…' : 'Compute Snapshot'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _selectedSnapshot == null
                        ? null
                        : () => _exportSnapshotCsv(_selectedSnapshot!),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Export CSV'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              const SizedBox(height: 12),
              StreamBuilder<List<PortfolioMetricsSnapshot>>(
                stream: _service.watchSnapshots(limit: 20),
                builder: (context, snap) {
                  final items = snap.data ?? const [];
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _Skeleton(height: 160);
                  }
                  if (items.isEmpty) {
                    return _EmptyState(
                      title: 'No snapshots yet',
                      actionText: 'Compute your first snapshot above',
                    );
                  }

                  final selected = (() {
                    final existingId = _selectedSnapshot?.id;
                    if (existingId == null) return items.first;
                    for (final s in items) {
                      if (s.id == existingId) return s;
                    }
                    return items.first;
                  })();

                  if (_selectedSnapshot?.id != selected.id) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      setState(() => _selectedSnapshot = selected);
                    });
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StreamBuilder<BenchmarkReferenceCurrent?>(
                        stream: _service.watchCurrentReference(),
                        builder: (context, currentSnap) {
                          final current = currentSnap.data;
                          if (current == null ||
                              current.activeVersionId.isEmpty) {
                            return _SnapshotSummary(snapshot: selected);
                          }

                          return StreamBuilder<BenchmarkReferenceVersion?>(
                            stream: _service.watchReferenceVersion(
                              current.activeVersionId,
                            ),
                            builder: (context, versionSnap) {
                              return _SnapshotSummary(
                                snapshot: selected,
                                reference: versionSnap.data,
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Recent snapshots',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 260,
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final s = items[i];
                            final isSelected = s.id == selected.id;
                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              title: Text(
                                s.id,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${s.computedAt != null ? _fmtDateTime(s.computedAt!) : '—'} • cohort=${s.filters['cohort'] ?? 'all'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () =>
                                  setState(() => _selectedSnapshot = s),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BandsTable extends StatelessWidget {
  final List<BenchmarkReferenceBand> bands;

  const _BandsTable({required this.bands});

  @override
  Widget build(BuildContext context) {
    if (bands.isEmpty) {
      return const _EmptyState(
        title: 'No bands configured',
        actionText: 'Refresh to seed defaults',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Metric')),
          DataColumn(label: Text('Low')),
          DataColumn(label: Text('Median')),
          DataColumn(label: Text('High')),
          DataColumn(label: Text('Unit')),
        ],
        rows: [
          for (final b in bands)
            DataRow(
              cells: [
                DataCell(Text(b.metric)),
                DataCell(Text(_fmtNum(b.low))),
                DataCell(Text(_fmtNum(b.median))),
                DataCell(Text(_fmtNum(b.high))),
                DataCell(Text(b.unit ?? '')),
              ],
            ),
        ],
      ),
    );
  }
}

class _SnapshotSummary extends StatelessWidget {
  final PortfolioMetricsSnapshot snapshot;
  final BenchmarkReferenceVersion? reference;

  const _SnapshotSummary({required this.snapshot, this.reference});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final metrics = snapshot.metrics;

    final Map<String, BenchmarkReferenceBand> bandsByMetric = {
      for (final b in (reference?.bands ?? const <BenchmarkReferenceBand>[]))
        b.metric: b,
    };

    String fmtMoney(dynamic v) {
      final n = (v as num?)?.toDouble();
      if (n == null) return '—';
      return '\$${n.toStringAsFixed(2)}';
    }

    String fmtPct(dynamic v) {
      final n = (v as num?)?.toDouble();
      if (n == null) return '—';
      return '${(n * 100).toStringAsFixed(1)}%';
    }

    String fmtNum2(dynamic v) {
      final n = (v as num?)?.toDouble();
      if (n == null) return '—';
      return n.toStringAsFixed(2);
    }

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 12,
              children: [
                _MetricTile(
                  label: 'Active policies',
                  value: '${metrics['activePolicyCount'] ?? '—'}',
                ),
                _MetricTile(
                  label: 'New policies',
                  value: '${metrics['newPolicies'] ?? '—'}',
                ),
                _MetricTile(
                  label: 'Claims filed',
                  value: '${metrics['claimsCount'] ?? '—'}',
                ),
                _MetricTile(
                  label: 'Settled claims',
                  value: '${metrics['claimsSettledCount'] ?? '—'}',
                ),
                _MetricTile(
                  label: 'Paid (approx)',
                  value: fmtMoney(metrics['claimsPaidTotal']),
                ),
                _MetricTile(
                  label: 'Loss ratio (approx)',
                  value: fmtPct(metrics['lossRatioApprox']),
                ),
                _MetricTile(
                  label: 'Frequency',
                  value: fmtNum2(metrics['claimFrequency']),
                ),
                _MetricTile(
                  label: 'Severity',
                  value: fmtMoney(metrics['claimSeverity']),
                ),
              ],
            ),
            if (bandsByMetric.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'Comparison vs benchmark bands',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              _ComparisonTable(snapshot: snapshot, reference: reference!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final PortfolioMetricsSnapshot snapshot;
  final BenchmarkReferenceVersion reference;

  const _ComparisonTable({required this.snapshot, required this.reference});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String fmtValue(String metric, double value, BenchmarkReferenceBand band) {
      final unit = (band.unit ?? '').toLowerCase();
      if (unit == 'usd') return '\$${value.toStringAsFixed(2)}';
      if (unit == 'ratio') return '${(value * 100).toStringAsFixed(1)}%';
      if (metric.toLowerCase().contains('ratio')) {
        return '${(value * 100).toStringAsFixed(1)}%';
      }
      if (unit.contains('hour')) return value.toStringAsFixed(1);
      if (unit.contains('claims')) return value.toStringAsFixed(3);
      return value.toStringAsFixed(3);
    }

    String statusFor(double value, BenchmarkReferenceBand band) {
      if (value < band.low) return 'Below';
      if (value > band.high) return 'Above';
      return 'In band';
    }

    Color colorFor(String status) {
      switch (status) {
        case 'Below':
          return scheme.primary;
        case 'Above':
          return scheme.error;
        default:
          return scheme.tertiary;
      }
    }

    final rows = <DataRow>[];
    for (final band in reference.bands) {
      final raw = snapshot.metrics[band.metric];
      if (raw is! num) continue;
      final value = raw.toDouble();
      final status = statusFor(value, band);

      rows.add(
        DataRow(
          cells: [
            DataCell(Text(band.metric)),
            DataCell(Text(fmtValue(band.metric, value, band))),
            DataCell(Text(fmtValue(band.metric, band.low, band))),
            DataCell(Text(fmtValue(band.metric, band.median, band))),
            DataCell(Text(fmtValue(band.metric, band.high, band))),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorFor(status).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: colorFor(status)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (rows.isEmpty) {
      return const _EmptyState(
        title: 'No comparable metrics found',
        actionText: 'Compute a snapshot that includes band metrics',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Metric')),
          DataColumn(label: Text('Clovara')),
          DataColumn(label: Text('Low')),
          DataColumn(label: Text('Median')),
          DataColumn(label: Text('High')),
          DataColumn(label: Text('Status')),
        ],
        rows: rows,
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;

  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;

  const _Chip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String actionText;

  const _EmptyState({required this.title, required this.actionText});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(actionText, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;

  const _Skeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

String _fmtDate(DateTime dt) {
  return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

String _fmtDateTime(DateTime dt) {
  final d = _fmtDate(dt);
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$d $hh:$mm';
}

String _fmtNum(double v) {
  if (v.abs() >= 1000) return v.toStringAsFixed(0);
  if (v.abs() >= 10) return v.toStringAsFixed(2);
  return v.toStringAsFixed(3);
}
