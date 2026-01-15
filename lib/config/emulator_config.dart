import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

class EmulatorConfig {
  static const bool useFirebaseEmulators =
      bool.fromEnvironment('USE_FIREBASE_EMULATORS', defaultValue: false);

  static const String emulatorHostOverride =
      String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '');

  static const int authPort =
      int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);
  static const int firestorePort =
      int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8080);
  static const int functionsPort =
      int.fromEnvironment('FUNCTIONS_EMULATOR_PORT', defaultValue: 5001);
  static const int storagePort =
      int.fromEnvironment('STORAGE_EMULATOR_PORT', defaultValue: 9199);

  static const String functionsRegion =
      String.fromEnvironment('FUNCTIONS_REGION', defaultValue: 'us-central1');

  static String get emulatorHost {
    final trimmed = emulatorHostOverride.trim();
    if (trimmed.isNotEmpty) return trimmed;

    if (kIsWeb) return 'localhost';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator -> host machine.
        return '10.0.2.2';
      default:
        // iOS simulator, macOS, etc.
        return 'localhost';
    }
  }

  static Future<void> configureFirebaseEmulators() async {
    if (!useFirebaseEmulators) return;

    final host = emulatorHost;

    FirebaseAuth.instance.useAuthEmulator(host, authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
    FirebaseFunctions.instance.useFunctionsEmulator(host, functionsPort);
    FirebaseStorage.instance.useStorageEmulator(host, storagePort);
  }

  static String httpFunctionUrl(
    String functionName, {
    String? region,
    String? projectId,
  }) {
    final resolvedRegion = region ?? functionsRegion;
    final resolvedProjectId = projectId ?? Firebase.app().options.projectId;

    if (useFirebaseEmulators) {
      return 'http://$emulatorHost:$functionsPort/$resolvedProjectId/$resolvedRegion/$functionName';
    }

    return 'https://$resolvedRegion-$resolvedProjectId.cloudfunctions.net/$functionName';
  }
}
