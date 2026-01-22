import 'package:flutter/widgets.dart';

class Breakpoints {
  // Tuned for 390 (mobile), 768 (tablet), 1200 (desktop)
  static const double mobileMax = 699;
  static const double tabletMax = 1099;

  static bool isMobile(BoxConstraints c) => c.maxWidth <= mobileMax;
  static bool isTablet(BoxConstraints c) =>
      c.maxWidth > mobileMax && c.maxWidth <= tabletMax;
  static bool isDesktop(BoxConstraints c) => c.maxWidth > tabletMax;

  static T select<T>({
    required BoxConstraints constraints,
    required T mobile,
    required T tablet,
    required T desktop,
  }) {
    if (isMobile(constraints)) return mobile;
    if (isTablet(constraints)) return tablet;
    return desktop;
  }
}
