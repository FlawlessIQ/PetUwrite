import 'package:flutter/widgets.dart';

import 'breakpoints.dart';

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.gap = 16,
  });

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = Breakpoints.select<int>(
          constraints: constraints,
          mobile: 1,
          tablet: 2,
          desktop: 3,
        );

        if (columns == 1) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i != 0) SizedBox(height: gap),
                children[i],
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (int i = 0; i < children.length; i += columns) {
          final rowChildren = <Widget>[];
          for (int c = 0; c < columns; c++) {
            final index = i + c;
            rowChildren.add(
              Expanded(
                child: index < children.length
                    ? children[index]
                    : const SizedBox.shrink(),
              ),
            );
            if (c != columns - 1) rowChildren.add(SizedBox(width: gap));
          }
          rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: rowChildren));
          if (i + columns < children.length) rows.add(SizedBox(height: gap));
        }

        return Column(children: rows);
      },
    );
  }
}
