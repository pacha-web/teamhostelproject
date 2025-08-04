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
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyA5IOUxsbYX7TIQ8Idi8ULBjN_zzsoz49E",
    authDomain: "hostelegatepass.firebaseapp.com",
    projectId: "hostelegatepass",
    storageBucket: "hostelegatepass.firebasestorage.app",
    messagingSenderId: "323050962282",
    appId: "1:323050962282:web:d24917d29fed4a95aab913",
    measurementId: "G-XXXXXXX", // optional, can be removed if you don’t have this
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyA5IOUxsbYX7TIQ8Idi8ULBjN_zzsoz49E",
    appId: "1:323050962282:web:d24917d29fed4a95aab913",
    messagingSenderId: "323050962282",
    projectId: "hostelegatepass",
    storageBucket: "hostelegatepass.firebasestorage.app",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyA5IOUxsbYX7TIQ8Idi8ULBjN_zzsoz49E",
    appId: "1:323050962282:web:d24917d29fed4a95aab913",
    messagingSenderId: "323050962282",
    projectId: "hostelegatepass",
    storageBucket: "hostelegatepass.firebasestorage.app",
    iosBundleId: "com.example.app", // update this with your real iOS bundle ID
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: "AIzaSyA5IOUxsbYX7TIQ8Idi8ULBjN_zzsoz49E",
    appId: "1:323050962282:web:d24917d29fed4a95aab913",
    messagingSenderId: "323050962282",
    projectId: "hostelegatepass",
    storageBucket: "hostelegatepass.firebasestorage.app",
    iosBundleId: "com.example.app", // update this too
  );
}
