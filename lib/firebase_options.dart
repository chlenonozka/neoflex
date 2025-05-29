// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Веб пока не поддерживается');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Платформа не поддерживается');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCqleuGyJqlo_NMgKT5Wfuzmtd_WA-mAgg',
    appId: '1:350558049429:android:e72b8f4777503cdfd6779c',
    messagingSenderId: '350558049429',
    projectId: 'neoflex-599cc',
    storageBucket: 'neoflex-599cc.firebasestorage.app',
  );
}