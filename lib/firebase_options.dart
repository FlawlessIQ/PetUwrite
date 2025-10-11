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

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: '1:984654950987:android:YOUR_APP_ID',
    messagingSenderId: '984654950987',
    projectId: 'pet-underwriter-ai',
    storageBucket: 'pet-underwriter-ai.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: '1:984654950987:ios:YOUR_APP_ID',
    messagingSenderId: '984654950987',
    projectId: 'pet-underwriter-ai',
    storageBucket: 'pet-underwriter-ai.firebasestorage.app',
    iosBundleId: 'com.petunderwriter.petUnderwriterAi',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: '1:984654950987:ios:YOUR_APP_ID',
    messagingSenderId: '984654950987',
    projectId: 'pet-underwriter-ai',
    storageBucket: 'pet-underwriter-ai.firebasestorage.app',
    iosBundleId: 'com.petunderwriter.petUnderwriterAi',
  );
}
