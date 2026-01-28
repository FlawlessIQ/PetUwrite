import 'package:flutter/widgets.dart';

import '../helpers/breakpoints.dart';

class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.child,
    this.backgroundColor,
    this.verticalPadding,
  });

  final Widget child;
  final Color? backgroundColor;
  final double? verticalPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical =
            verticalPadding ??
            Breakpoints.select<double>(
              constraints: constraints,
              mobile: 22,
              tablet: 32,
              desktop: 44,
            );

        final content = Padding(
          padding: EdgeInsets.symmetric(vertical: vertical),
          child: child,
        );

        if (backgroundColor == null) return content;
        return ColoredBox(color: backgroundColor!, child: content);
      },
    );
  }
}
