import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

Future<TaskSnapshot> uploadFileToStorageRef(
  Reference ref,
  String filePath, {
  SettableMetadata? metadata,
}) {
  return ref.putFile(File(filePath), metadata);
}
