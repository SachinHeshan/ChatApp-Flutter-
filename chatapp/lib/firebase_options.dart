import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAhLnJElgzQ97zkZCqCAu7f0dPQEhmxEH0',
    appId: '1:771151947898:web:your_web_app_id',
    messagingSenderId: '771151947898',
    projectId: 'chatapp-d8b7b',
    authDomain: 'chatapp-d8b7b.firebaseapp.com',
    storageBucket: 'chatapp-d8b7b.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAhLnJElgzQ97zkZCqCAu7f0dPQEhmxEH0',
    appId: '1:771151947898:android:b25bb7648c4d28b38f73c3',
    messagingSenderId: '771151947898',
    projectId: 'chatapp-d8b7b',
    storageBucket: 'chatapp-d8b7b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAhLnJElgzQ97zkZCqCAu7f0dPQEhmxEH0',
    appId: '1:771151947898:ios:your_ios_app_id',
    messagingSenderId: '771151947898',
    projectId: 'chatapp-d8b7b',
    storageBucket: 'chatapp-d8b7b.firebasestorage.app',
    iosBundleId: 'com.example.chatapp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAhLnJElgzQ97zkZCqCAu7f0dPQEhmxEH0',
    appId: '1:771151947898:ios:your_ios_app_id',
    messagingSenderId: '771151947898',
    projectId: 'chatapp-d8b7b',
    storageBucket: 'chatapp-d8b7b.firebasestorage.app',
    iosBundleId: 'com.example.chatapp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAhLnJElgzQ97zkZCqCAu7f0dPQEhmxEH0',
    appId: '1:771151947898:web:your_web_app_id',
    messagingSenderId: '771151947898',
    projectId: 'chatapp-d8b7b',
    authDomain: 'chatapp-d8b7b.firebaseapp.com',
    storageBucket: 'chatapp-d8b7b.firebasestorage.app',
  );
}
