import 'chat_repository.dart';

/// Веб-сборка: десктопный поток не нужен, там всплывающее окно Firebase.
bool get googleDesktopConfigured => false;

Future<({String idToken, String accessToken})> googleDesktopSignIn() =>
    Future.error(const AuthFailure('Вход через Google здесь недоступен'));
