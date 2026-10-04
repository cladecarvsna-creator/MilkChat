import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/chat_repository.dart';
import 'data/supabase_repository.dart';
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
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<ChatRepository>();
    if (repo is SupabaseRepository && repo.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: repo.me == null
          ? const AuthScreen(key: ValueKey('auth'))
          : HomeShell(key: ValueKey(repo.me!.id)),
    );
  }
}
