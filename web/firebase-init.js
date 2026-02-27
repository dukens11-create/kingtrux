// Firebase Web SDK initialization for KINGTRUX.
//
// Exports the initialized Firebase app and service handles for use in
// web-only JavaScript code (e.g., scripts that run outside the Flutter layer).
//
// NOTE: The Flutter/Dart layer initialises Firebase through FlutterFire
// (lib/firebase_options.dart). This module exposes the same configuration
// for standalone JavaScript usage when the modular Firebase JS SDK is needed
// directly.
//
// The `apiKey` placeholder is replaced at CI build time from the
// WEB_FIREBASE_API_KEY secret (see .github/workflows/ci.yml).
// Obtain your measurementId from the Firebase Console → Project settings →
// Your apps → Web app and replace YOUR_WEB_FIREBASE_MEASUREMENT_ID, or add
// a WEB_FIREBASE_MEASUREMENT_ID CI secret following the same sed pattern.
//
// See README.md → "Firebase Web Modules" for usage instructions.

import { initializeApp } from 'https://www.gstatic.com/firebasejs/11.3.1/firebase-app.js';
import { isSupported, getAnalytics } from 'https://www.gstatic.com/firebasejs/11.3.1/firebase-analytics.js';
import { getAuth } from 'https://www.gstatic.com/firebasejs/11.3.1/firebase-auth.js';
import { getFirestore } from 'https://www.gstatic.com/firebasejs/11.3.1/firebase-firestore.js';
import { getStorage } from 'https://www.gstatic.com/firebasejs/11.3.1/firebase-storage.js';

const firebaseConfig = {
  apiKey: 'YOUR_WEB_FIREBASE_API_KEY',
  authDomain: 'kingtrux-387ae.firebaseapp.com',
  projectId: 'kingtrux-387ae',
  storageBucket: 'kingtrux-387ae.firebasestorage.app',
  messagingSenderId: '802226888759',
  appId: '1:802226888759:web:4a64ff7011e28876c8dfb2',
  measurementId: 'YOUR_WEB_FIREBASE_MEASUREMENT_ID',
};

/** Initialized Firebase app instance. */
export const app = initializeApp(firebaseConfig);

/**
 * Firebase Analytics instance, or `null` when Analytics is not supported
 * (e.g. SSR, Node.js, or a browser where cookies/storage are blocked).
 * Guarded by `isSupported()` to prevent crashes in restricted environments.
 */
export const analytics = (await isSupported()) ? getAnalytics(app) : null;

/** Firebase Authentication service handle. */
export const auth = getAuth(app);

/** Cloud Firestore database service handle. */
export const db = getFirestore(app);

/** Firebase Storage service handle. */
export const storage = getStorage(app);
