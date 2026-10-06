import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Настройки проекта Firebase «milkchat-915d4».
///
/// Веб и Windows используют веб-приложение из консоли Firebase. Для Android
/// и macOS нужно добавить в консоли свои приложения (пакет com.milkchat.milkchat)
/// и передать их appId при сборке, например
/// `--dart-define=FIREBASE_ANDROID_APP_ID=1:548648083112:android:...`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS || TargetPlatform.macOS => apple,
      _ => web,
    };
  }

  static const _apiKey = 'AIzaSyD3HrW5NUXXOUBoA7UrhvFsVMBNwGzrs50';
  static const _projectId = 'milkchat-915d4';
  static const _bucket = 'milkchat-915d4.firebasestorage.app';
  static const _sender = '548648083112';
  static const _webAppId = '1:548648083112:web:5b919821f711fd558fec9d';
  // Пустая строка, если при сборке не передали (в CI — переменные репозитория).
  static const _androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const _appleAppId = String.fromEnvironment('FIREBASE_APPLE_APP_ID');

  static const web = FirebaseOptions(
    apiKey: _apiKey,
    authDomain: 'milkchat-915d4.firebaseapp.com',
    projectId: _projectId,
    storageBucket: _bucket,
    messagingSenderId: _sender,
    appId: _webAppId,
    measurementId: 'G-M71M9T2MW7',
  );

  static const android = FirebaseOptions(
    apiKey: _apiKey,
    projectId: _projectId,
    storageBucket: _bucket,
    messagingSenderId: _sender,
    appId: _androidAppId == '' ? _webAppId : _androidAppId,
  );

  static const apple = FirebaseOptions(
    apiKey: _apiKey,
    projectId: _projectId,
    storageBucket: _bucket,
    messagingSenderId: _sender,
    appId: _appleAppId == '' ? _webAppId : _appleAppId,
    iosBundleId: 'com.milkchat.milkchat',
  );
}
