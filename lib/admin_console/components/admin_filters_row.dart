import 'package:flutter/material.dart';

/// A dense, reusable filter row for console inboxes.
///
/// Intended usage:
/// - optional search input
/// - optional leading controls (dropdowns, chips)
/// - optional trailing actions
class AdminFiltersRow extends StatelessWidget {
  final List<Widget> leading;
  final Widget? search;
  final List<Widget> trailing;

  const AdminFiltersRow({
    super.key,
    this.leading = const <Widget>[],
    this.search,
    this.trailing = const <Widget>[],
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...leading,
        if (search != null)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 320, maxWidth: 560),
            child: search!,
          ),
        ...trailing,
      ],
    );
  }
}
