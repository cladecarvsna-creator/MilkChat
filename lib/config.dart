/// Ключи Supabase передаются при сборке:
///   flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///               --dart-define=SUPABASE_KEY=sb_publishable_...
/// Без них приложение запускается в демо-режиме с локальными данными.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  /// Publishable (или старый anon) ключ из Project Settings → API Keys.
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
