import 'csv_download_stub.dart' if (dart.library.html) 'csv_download_web.dart';

/// Downloads a CSV file on web.
///
/// On non-web platforms, this throws [UnsupportedError].
void downloadCsv(String filename, String csvContent) {
  downloadCsvImpl(filename, csvContent);
}
