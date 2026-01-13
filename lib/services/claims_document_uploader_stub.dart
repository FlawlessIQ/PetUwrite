import 'package:firebase_storage/firebase_storage.dart';

Future<TaskSnapshot> uploadFileToStorageRef(
  Reference ref,
  String filePath, {
  SettableMetadata? metadata,
}) {
  throw UnsupportedError('uploadFileToStorageRef is not supported on this platform');
}
