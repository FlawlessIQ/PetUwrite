// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

bool isRunningUnderAppMount() {
  final pathname = html.window.location.pathname ?? '';
  return pathname == '/app' || pathname.startsWith('/app/');
}

bool redirectToMarketingSite({String path = '/', bool replace = true}) {
  final normalized = path.startsWith('/') ? path : '/$path';
  if (replace) {
    html.window.location.replace(normalized);
  } else {
    html.window.location.assign(normalized);
  }
  return true;
}
