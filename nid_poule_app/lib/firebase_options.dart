import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError('DefaultFirebaseOptions not implemented for this platform.');
  }
  
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyBMheVQeYoVfV_QfyF85FTOOwNijtiHmnM",
    appId: "1:516369218141:web:xxxxxxxxxxxxxx",  // À compléter Web app
    messagingSenderId: "516369218141",
    projectId: "nid-de-poulet",
    authDomain: "nid-de-poulet.firebaseapp.com",
    storageBucket: "nid-de-poulet.firebasestorage.app",
  );
}
