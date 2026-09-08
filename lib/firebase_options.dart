// File generated manually from android/app/google-services.json.
// Regenerate with FlutterFire CLI when adding more platforms:
//   dart pub global activate flutterfire_cli
//   flutterfire configure

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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBIVxbPf3vM9QyogubpcW9sfuM-MkZudWU',
    appId: '1:704539240164:android:5530f03bc4a00df2d8aef1',
    messagingSenderId: '704539240164',
    projectId: 'food-expiry-pantry-management',
    storageBucket: 'food-expiry-pantry-management.firebasestorage.app',
  );
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyARWFoLCcazT9-CSmVfjd8OPMXCDftuImE',
    appId: '1:704539240164:web:3650b3d3ebf71266d8aef1',
    messagingSenderId: '704539240164',
    projectId: 'food-expiry-pantry-management',
    authDomain: 'food-expiry-pantry-management.firebaseapp.com',
    storageBucket: 'food-expiry-pantry-management.firebasestorage.app',
    measurementId: 'G-FE6T6NSQ7E',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyACSeUD6k-xapFdQIQJa0f294UJwpQRIKQ',
    appId: '1:704539240164:ios:85916a5d460f2983d8aef1',
    messagingSenderId: '704539240164',
    projectId: 'food-expiry-pantry-management',
    storageBucket: 'food-expiry-pantry-management.firebasestorage.app',
    iosBundleId: 'com.example.foodExpiryAndPantryManagement',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyACSeUD6k-xapFdQIQJa0f294UJwpQRIKQ',
    appId: '1:704539240164:ios:85916a5d460f2983d8aef1',
    messagingSenderId: '704539240164',
    projectId: 'food-expiry-pantry-management',
    storageBucket: 'food-expiry-pantry-management.firebasestorage.app',
    iosBundleId: 'com.example.foodExpiryAndPantryManagement',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyARWFoLCcazT9-CSmVfjd8OPMXCDftuImE',
    appId: '1:704539240164:web:92ea8c9805534c3ad8aef1',
    messagingSenderId: '704539240164',
    projectId: 'food-expiry-pantry-management',
    authDomain: 'food-expiry-pantry-management.firebaseapp.com',
    storageBucket: 'food-expiry-pantry-management.firebasestorage.app',
    measurementId: 'G-CWWE50K08D',
  );
}
