import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../premium_card.dart';

enum CoverageMark { yes, sometimes, no }

class CoverageMatrixRow {
  const CoverageMatrixRow({
    required this.title,
    required this.detail,
    required this.accidentIllness,
    required this.accidentOnly,
    this.footnote,
  });

  final String title;
  final String detail;
  final CoverageMark accidentIllness;
  final CoverageMark accidentOnly;
  final String? footnote;
}

class CoverageMatrix extends StatelessWidget {
  const CoverageMatrix({
    super.key,
    required this.rows,
    this.title = 'Coverage at a glance',
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<CoverageMatrixRow> rows;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      showShadow: false,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 760;

          final header = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                const SizedBox(height: 14),
                for (final r in rows) ...[
                  _StackedRow(row: r),
                  const SizedBox(height: 12),
                ],
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              const SizedBox(height: 14),
              _DesktopHeader(),
              const Divider(height: 1, thickness: 1, color: AppColors.border),
              for (final r in rows) ...[
                _DesktopRow(row: r),
                const Divider(height: 1, thickness: 1, color: AppColors.border),
              ],
              const SizedBox(height: 10),
              Text(
                'Notes: “Sometimes” usually depends on waiting periods, medical necessity, and policy terms.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(color: AppColors.textSubtle),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textSubtle,
          ),
      child: const Row(
        children: [
          Expanded(flex: 8, child: Text('Category')),
          Expanded(flex: 2, child: Text('A&I', textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text('Accident', textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class _DesktopRow extends StatelessWidget {
  const _DesktopRow({required this.row});

  final CoverageMatrixRow row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepGreen,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.detail,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(color: AppColors.textMuted),
                ),
                if (row.footnote != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    row.footnote!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(color: AppColors.textSubtle),
                  ),
                ],
              ],
            ),
          ),
          Expanded(flex: 2, child: _Mark(mark: row.accidentIllness)),
          Expanded(flex: 2, child: _Mark(mark: row.accidentOnly)),
        ],
      ),
    );
  }
}

class _StackedRow extends StatelessWidget {
  const _StackedRow({required this.row});

  final CoverageMatrixRow row;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadii.br16,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.title,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepGreen,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            row.detail,
            style: Theme.of(context)
                .textTheme
                .bodySmall!
                .copyWith(color: AppColors.textMuted),
          ),
          if (row.footnote != null) ...[
            const SizedBox(height: 4),
            Text(
              row.footnote!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: AppColors.textSubtle),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniLabel(
                  label: 'Accident & Illness',
                  mark: row.accidentIllness,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniLabel(
                  label: 'Accident-only',
                  mark: row.accidentOnly,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel({required this.label, required this.mark});

  final String label;
  final CoverageMark mark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.70),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(fontWeight: FontWeight.w700, color: AppColors.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _Mark(mark: mark),
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.mark});

  final CoverageMark mark;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (mark) {
      CoverageMark.yes => (Icons.check_circle, AppColors.success),
      CoverageMark.sometimes => (Icons.remove_circle, AppColors.warning),
      CoverageMark.no => (Icons.cancel, AppColors.textSubtle),
    };

    return Center(child: Icon(icon, size: 18, color: color));
  }
}
