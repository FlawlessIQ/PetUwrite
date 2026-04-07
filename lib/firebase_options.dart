// Firebase configuration file - generated manually
// This file contains Firebase configuration for different platforms

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static const String _androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
    defaultValue: '',
  );
  static const String _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '',
  );
  static const String _androidProjectId = String.fromEnvironment(
    'FIREBASE_ANDROID_PROJECT_ID',
    defaultValue: 'pet-underwriter-ai',
  );
  static const String _androidMessagingSenderId = String.fromEnvironment(
    'FIREBASE_ANDROID_MESSAGING_SENDER_ID',
    defaultValue: '984654950987',
  );
  static const String _androidStorageBucket = String.fromEnvironment(
    'FIREBASE_ANDROID_STORAGE_BUCKET',
    defaultValue: 'pet-underwriter-ai.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAasP7WKdW7RaJ55uaOvcf5iu5mDDSn_FU',
    appId: '1:984654950987:web:f9c4d1e5fe50cf2ba193ce',
    messagingSenderId: '984654950987',
    projectId: 'pet-underwriter-ai',
    authDomain: 'pet-underwriter-ai.firebaseapp.com',
    storageBucket: 'pet-underwriter-ai.firebasestorage.app',
  );

  static FirebaseOptions get android {
    if (_androidApiKey.isEmpty || _androidAppId.isEmpty) {
      throw UnsupportedError(
        'Android Firebase is not configured. Provide '
        'FIREBASE_ANDROID_API_KEY and FIREBASE_ANDROID_APP_ID via '
        '--dart-define, or run FlutterFire again to regenerate '
        'lib/firebase_options.dart with Android values.',
      );
    }

    return const FirebaseOptions(
      apiKey: _androidApiKey,
      appId: _androidAppId,
      messagingSenderId: _androidMessagingSenderId,
      projectId: _androidProjectId,
      storageBucket: _androidStorageBucket,
    );
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDdkRf16WBtP3wTpHJgO6RvhgAeOLtW6_I',
    appId: '1:984654950987:ios:eaf95d2270b12f7ba193ce',
    messagingSenderId: '984654950987',
    projectId: 'pet-underwriter-ai',
    storageBucket: 'pet-underwriter-ai.firebasestorage.app',
    iosBundleId: 'com.clovara.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDdkRf16WBtP3wTpHJgO6RvhgAeOLtW6_I',
    appId: '1:984654950987:ios:eaf95d2270b12f7ba193ce',
    messagingSenderId: '984654950987',
    projectId: 'pet-underwriter-ai',
    storageBucket: 'pet-underwriter-ai.firebasestorage.app',
    iosBundleId: 'com.clovara.app',
  );
}
