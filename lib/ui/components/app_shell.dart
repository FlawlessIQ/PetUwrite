import 'package:flutter/material.dart';

import '../tokens.dart';
import 'app_footer.dart';
import 'app_top_nav.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
    this.background,
  });

  final Widget child;
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final themed = AppTheme.build(Theme.of(context), context);
    return Theme(
      data: themed,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Optional background layer
            if (background != null)
              Positioned.fill(
                child: background!,
              ),
            // Main content with semi-transparent background
            Column(
              children: [
                const AppTopNav(),
                Expanded(
                  child: SelectionArea(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          child,
                          const AppFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
