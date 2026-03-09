import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Web requires explicit FirebaseOptions because there is no native config file.
  // Android and iOS read from google-services.json / GoogleService-Info.plist,
  // so passing options there would override the native file (and would fail when
  // the Dart placeholders like YOUR_ANDROID_FIREBASE_API_KEY are not replaced).
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } else {
    await Firebase.initializeApp();
  }

  runApp(const KingTruxApp());
}
