// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

void downloadCsvImpl(String filename, String csvContent) {
  final normalizedFilename = filename.toLowerCase().endsWith('.csv')
      ? filename
      : '$filename.csv';

  // Add UTF-8 BOM so Excel opens UTF-8 CSVs correctly.
  final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(csvContent)];
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', normalizedFilename)
    ..style.display = 'none';

  try {
    html.document.body?.children.add(anchor);
    anchor.click();
  } finally {
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
