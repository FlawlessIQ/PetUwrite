import 'package:flutter/material.dart';

/// A lightweight, console-friendly wrapper around [DataTable] that provides:
/// - Row selection via checkbox column
/// - Header select-all that only affects the visible [items]
/// - Horizontal scrolling + min-width constraints
///
/// This is intentionally minimal so each module can keep its own columns/cells.
class AdminSelectableDataTable<T> extends StatelessWidget {
  final List<T> items;
  final String Function(T item) getId;

  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectedIdsChanged;

  final List<DataColumn> columns;
  final List<DataCell> Function(BuildContext context, T item) buildCells;

  final int? sortColumnIndex;
  final bool sortAscending;
  final bool showCheckboxColumn;

  const AdminSelectableDataTable({
    super.key,
    required this.items,
    required this.getId,
    required this.selectedIds,
    required this.onSelectedIdsChanged,
    required this.columns,
    required this.buildCells,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.showCheckboxColumn = true,
  });

  @override
  Widget build(BuildContext context) {
    final visibleIds = items.map(getId).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              showCheckboxColumn: showCheckboxColumn,
              sortColumnIndex: sortColumnIndex,
              sortAscending: sortAscending,
              onSelectAll: showCheckboxColumn
                  ? (value) {
                      final next = Set<String>.from(selectedIds);
                      final checked = value ?? false;
                      if (checked) {
                        next.addAll(visibleIds);
                      } else {
                        for (final id in visibleIds) {
                          next.remove(id);
                        }
                      }
                      onSelectedIdsChanged(next);
                    }
                  : null,
              columns: columns,
              rows: items.map((item) {
                final id = getId(item);
                final selected = selectedIds.contains(id);

                return DataRow(
                  selected: selected,
                  onSelectChanged: showCheckboxColumn
                      ? (value) {
                          final next = Set<String>.from(selectedIds);
                          final checked = value ?? false;
                          if (checked) {
                            next.add(id);
                          } else {
                            next.remove(id);
                          }
                          onSelectedIdsChanged(next);
                        }
                      : null,
                  cells: buildCells(context, item),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
