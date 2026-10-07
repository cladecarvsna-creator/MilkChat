import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/chat_repository.dart';
import 'data/firebase_repository.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fonts = kIsWeb ? _loadWebFonts() : Future<void>.value();
  final prefs = await SharedPreferences.getInstance();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Например, Linux (Firebase его не поддерживает) или Android без своего appId.
    runApp(_FirebaseMissing(error: '$e'));
    return;
  }
  await fonts;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController(prefs)),
        ChangeNotifierProvider<ChatRepository>(create: (_) => FirebaseRepository()),
      ],
      child: const MilkChatApp(),
    ),
  );
}

/// На вебе хостинг может отдавать старый assets/FontManifest.json из своего
/// кэша, и тогда движок не знает про Unbounded и рисует стандартным шрифтом.
/// Поэтому регистрируем шрифт сами, прямо из файлов, без этого списка.
Future<void> _loadWebFonts() async {
  try {
    final loader = FontLoader('Unbounded');
    for (final w in const [400, 500, 600, 700, 800]) {
      loader.addFont(rootBundle.load('assets/fonts/Unbounded-$w.ttf'));
    }
    await loader.load();
  } catch (e) {
    debugPrint('Шрифт Unbounded не загрузился: $e');
  }
}

class _FirebaseMissing extends StatelessWidget {
  const _FirebaseMissing({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Не удалось подключиться к Firebase на этой платформе.\n\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8E8E93)),
              ),
            ),
          ),
        ),
      );
}
