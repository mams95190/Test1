// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    // Android
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyBMheVQeYoVfV_QfyF85FTOOwNijtiHmnM",
    appId: "1:516369218141:android:0e3b3feadf7e4e597c6bb4",
    messagingSenderId: "516369218141",
    projectId: "nid-de-poulet",
    storageBucket: "nid-de-poulet.firebasestorage.app",
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyBMheVQeYoVfV_QfyF85FTOOwNijtiHmnM",
    appId: "1:516369218141:web:xxxxxxxxxxxxxx",  // Web app
    messagingSenderId: "516369218141",
    projectId: "nid-de-poulet",
    authDomain: "nid-de-poulet.firebaseapp.com",
    storageBucket: "nid-de-poulet.firebasestorage.app",
  );
}
