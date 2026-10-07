import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/chat_repository.dart';
import 'data/firebase_repository.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

class MilkChatApp extends StatelessWidget {
  const MilkChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return MaterialApp(
      title: 'MilkChat',
      debugShowCheckedModeBanner: false,
      themeMode: theme.mode,
      theme: buildTheme(theme.accent, Brightness.light),
      darkTheme: buildTheme(theme.accent, Brightness.dark),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Unbounded заметно шире прежнего шрифта: чуть ужимаем весь текст,
      // чтобы заголовки помещались в строку. Системный масштаб сохраняется.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: _CompactText(mq.textScaler)),
          child: child!,
        );
      },
      home: const _AuthGate(),
    );
  }
}

class _CompactText extends TextScaler {
  const _CompactText(this.base);
  final TextScaler base;
  static const _factor = 0.88;

  @override
  double scale(double fontSize) => base.scale(fontSize) * _factor;

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * _factor;

  @override
  bool operator ==(Object other) => other is _CompactText && other.base == base;

  @override
  int get hashCode => base.hashCode;
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ChatRepository>();
    if (repo.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (repo is FirebaseRepository && repo.needsEmailVerification) {
      return const VerifyEmailScreen();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: repo.me == null
          ? const AuthScreen(key: ValueKey('auth'))
          : HomeShell(key: ValueKey(repo.me!.id)),
    );
  }
}
