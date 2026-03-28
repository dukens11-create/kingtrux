import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'config.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Ensure the user has an auth token before the app starts so that Firestore
  // reads (e.g. Weigh Station Status) succeed even before the user completes
  // a full sign-in. Anonymous credentials are upgraded automatically when the
  // user later signs in with email / Google / Apple.
  if (Config.enableAnonymousAuthForStatus) {
    await AuthService().ensureSignedIn();
  }

  runApp(const KingTruxApp());
}
