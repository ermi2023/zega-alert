// Firebase configuration for ZEGA-ALERT.
// Android app registered in project `zega-alert` (com.example.zega_alert_mobile).
// To add other platforms run: flutterfire configure
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions are configured for Android only. '
      'Run "flutterfire configure" to add other platforms.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCyVYwv401B8zA6ET6GJEt3dFSBi1vc0LU',
    appId: '1:1030998060411:android:6c4cd5215c8e7cfe22a1de',
    messagingSenderId: '1030998060411',
    projectId: 'zega-alert',
    storageBucket: 'zega-alert.firebasestorage.app',
  );
}
