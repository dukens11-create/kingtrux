// PLACEHOLDER — Replace with real Firebase configuration.
//
// Run `flutterfire configure` after setting up your Firebase project, or
// manually copy the values from the Firebase Console into the constants below.
//
// See README.md → "Firebase Authentication Setup" for step-by-step
// instructions.

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Web Firebase options.
  ///
  /// Replace these placeholder values with real credentials from your
  /// Firebase Console (Project settings → Your apps → Web app → SDK setup).
  /// See README.md → "Firebase Authentication Setup – Web".
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_FIREBASE_API_KEY',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-firebase-project-id',
    storageBucket: 'your-firebase-project-id.appspot.com',
    authDomain: 'your-firebase-project-id.firebaseapp.com',
  );

  /// Android Firebase options.
  ///
  /// Replace these placeholder values with real credentials from your
  /// Firebase Console or from the generated google-services.json.
  /// See README.md → "Firebase Authentication Setup – Android".
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_FIREBASE_API_KEY',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-firebase-project-id',
    storageBucket: 'your-firebase-project-id.appspot.com',
  );

  /// iOS Firebase options.
  ///
  /// Replace these placeholder values with real credentials from your
  /// Firebase Console or from GoogleService-Info.plist.
  /// See README.md → "Firebase Authentication Setup – iOS".
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_FIREBASE_API_KEY',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-firebase-project-id',
    storageBucket: 'your-firebase-project-id.appspot.com',
    iosClientId: 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com',
    iosBundleId: 'com.example.kingtrux',
  );
}
