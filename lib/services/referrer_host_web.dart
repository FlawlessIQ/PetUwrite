// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

String? getReferrerHost() {
  try {
    final ref = (html.document.referrer).trim();
    if (ref.isEmpty) return null;
    final uri = Uri.tryParse(ref);
    final host = uri?.host.trim();
    return host != null && host.isNotEmpty ? host : null;
  } catch (_) {
    return null;
  }
}
