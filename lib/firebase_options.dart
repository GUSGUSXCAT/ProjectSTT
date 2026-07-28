import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for android - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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
    apiKey: 'AIzaSyAenRnNyzRPsPYKFJWYhgPqH0s0fqknNOQ',
    appId: '1:624391339517:web:ba45d7abad4d1c59d86d94',
    messagingSenderId: '624391339517',
    projectId: 'cloud-project-60e4a',
    authDomain: 'cloud-project-60e4a.firebaseapp.com',
    storageBucket: 'cloud-project-60e4a.firebasestorage.app',
    measurementId: 'G-W5DCX1HMTF',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAenRnNyzRPsPYKFJWYhgPqH0s0fqknNOQ',
    appId: '1:624391339517:web:111064feb4c1752bd86d94',
    messagingSenderId: '624391339517',
    projectId: 'cloud-project-60e4a',
    authDomain: 'cloud-project-60e4a.firebaseapp.com',
    storageBucket: 'cloud-project-60e4a.firebasestorage.app',
    measurementId: 'G-NLMGF2XF9T',
  );

}