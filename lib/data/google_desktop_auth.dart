import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';

import 'chat_repository.dart';

/// OAuth-клиент Google типа «Desktop app» из Google Cloud проекта milkchat-915d4.
/// Передаётся при сборке: `--dart-define=GOOGLE_DESKTOP_CLIENT_ID=...`
/// и `--dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...` (секрет у десктоп-клиента
/// по правилам Google не считается тайной, но в репозиторий его не кладём).
const _clientId = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
const _clientSecret = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');

bool get googleDesktopConfigured => _clientId.isNotEmpty;

/// Вход через Google на Windows, macOS и Linux: открывает браузер, ловит ответ
/// на 127.0.0.1 (loopback + PKCE) и возвращает токены для Firebase.
Future<({String idToken, String accessToken})> googleDesktopSignIn() async {
  if (!googleDesktopConfigured) {
    throw const AuthFailure('Вход через Google на компьютере ещё не настроен');
  }
  final rnd = Random.secure();
  String token(int n) =>
      base64UrlEncode(List.generate(n, (_) => rnd.nextInt(256))).replaceAll('=', '');
  final verifier = token(48);
  final challenge =
      base64UrlEncode(sha256.convert(ascii.encode(verifier)).bytes).replaceAll('=', '');
  final state = token(16);

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final redirect = 'http://127.0.0.1:${server.port}';
  try {
    final url = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': _clientId,
      'redirect_uri': redirect,
      'response_type': 'code',
      'scope': 'openid email profile',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
      'prompt': 'select_account',
    });
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw const AuthFailure('Не удалось открыть браузер');
    }

    String? code;
    await for (final req in server.timeout(const Duration(minutes: 5),
        onTimeout: (s) => s.close())) {
      final q = req.uri.queryParameters;
      if (!q.containsKey('code') && !q.containsKey('error')) {
        // Например, запрос favicon.ico.
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        continue;
      }
      final ok = q['state'] == state && q['code'] != null;
      req.response.headers.contentType = ContentType.html;
      req.response.write(_page(ok));
      await req.response.close();
      if (ok) code = q['code'];
      break;
    }
    if (code == null) throw const AuthFailure('Вход отменён');

    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.https('oauth2.googleapis.com', '/token'));
      req.headers.contentType =
          ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
      req.write(Uri(queryParameters: {
        'code': code,
        'client_id': _clientId,
        'client_secret': _clientSecret,
        'redirect_uri': redirect,
        'grant_type': 'authorization_code',
        'code_verifier': verifier,
      }).query);
      final res = await req.close();
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final idToken = body['id_token'] as String?;
      if (res.statusCode != 200 || idToken == null) {
        throw AuthFailure('Google не выдал вход: ${body['error_description'] ?? body['error']}');
      }
      return (idToken: idToken, accessToken: body['access_token'] as String? ?? '');
    } finally {
      client.close();
    }
  } on SocketException {
    throw const AuthFailure('Нет соединения с интернетом');
  } finally {
    await server.close(force: true);
  }
}

String _page(bool ok) => '''<!doctype html><html lang="ru"><meta charset="utf-8">
<title>MilkChat</title>
<body style="background:#F2F2F4;color:#1C1C1E;font-family:sans-serif;display:flex;
align-items:center;justify-content:center;height:100vh;margin:0;text-align:center">
<div><h1>${ok ? 'Готово!' : 'Вход не выполнен'}</h1>
<p>${ok ? 'Можно закрыть эту вкладку и вернуться в MilkChat.' : 'Вернитесь в MilkChat и попробуйте ещё раз.'}</p></div>
</body></html>''';
