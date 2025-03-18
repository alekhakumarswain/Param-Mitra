import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCgJhVRIHvTzhqABvGqpAn2Xk-vGigLybQ',
    appId: '1:612289896320:android:a7305bb5403f3c1b9feb65',
    messagingSenderId: '612289896320',
    projectId: 'param--mitra',
    storageBucket: 'param--mitra.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB3ScPc8wpkEqbyPZauwcSsYQKBF0SXIaU',
    appId: '1:612289896320:web:496f329baa9197959feb65',
    messagingSenderId: '612289896320',
    projectId: 'param--mitra',
    authDomain: 'param--mitra.firebaseapp.com',
    storageBucket: 'param--mitra.firebasestorage.app',
    measurementId: 'G-X42TER4VQS',
  );
}
