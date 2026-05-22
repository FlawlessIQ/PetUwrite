import 'package:flutter/material.dart';

import '../admin_theme.dart';
import 'admin_status_chip.dart';

class AdminBulkActionsBar extends StatelessWidget {
  final int resultsCount;
  final int selectedCount;

  final VoidCallback? onSelectVisible;
  final VoidCallback? onClearSelection;

  /// Extra actions to show in the bar (e.g., Copy IDs, Export CSV, Open).
  /// Keep these small (TextButton/FilledButton) for density.
  final List<Widget> actions;

  const AdminBulkActionsBar({
    super.key,
    required this.resultsCount,
    required this.selectedCount,
    this.onSelectVisible,
    this.onClearSelection,
    this.actions = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    final hasResults = resultsCount > 0;
    final hasSelection = selectedCount > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminColors.surfaceRaised,
        border: Border.all(color: AdminColors.border),
        borderRadius: BorderRadius.circular(AdminRadii.lg),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AdminStatusChip(
            label: '$resultsCount results',
            color: AdminColors.muted,
            icon: Icons.list_alt,
          ),
          AdminStatusChip(
            label: 'Selected: $selectedCount',
            color: hasSelection ? AdminColors.success : AdminColors.muted,
            icon: Icons.select_all,
          ),
          TextButton.icon(
            onPressed: hasResults ? onSelectVisible : null,
            icon: const Icon(Icons.select_all, size: 18),
            label: const Text('Select visible'),
          ),
          TextButton.icon(
            onPressed: hasSelection ? onClearSelection : null,
            icon: const Icon(Icons.clear, size: 18),
            label: const Text('Clear selection'),
          ),
          ...actions,
        ],
      ),
    );
  }
}
