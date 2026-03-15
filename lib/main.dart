import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'services/firebase_auth_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Ensure the app has a Firebase Auth identity (anonymous if not already
  // signed in) so that Firestore security rules with `request.auth != null`
  // are satisfied from the very first read.
  await FirebaseAuthBootstrap.ensureSignedIn();
  runApp(const KingTruxApp());
}
