import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Понятная пользователю ошибка входа или запроса.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Источник данных MilkChat. В приложении — [FirebaseRepository];
/// в тестах — локальная подделка из test/fake_repository.dart.
abstract class ChatRepository extends ChangeNotifier {
  /// Текущий пользователь или null, если не выполнен вход.
  Profile? get me;


  /// Сессия есть, но профиль ещё загружается — показываем индикатор.
  bool get loading => false;

  /// Можно ли войти через Google на этой платформе.
  bool get supportsGoogle => false;

  Future<void> signInWithGoogle() =>
      Future.error(UnsupportedError('Вход через Google здесь недоступен'));

  Future<void> resetPassword(String email) =>
      Future.error(UnsupportedError('Сброс пароля здесь недоступен'));

  Future<void> signIn({required String email, required String password});
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  });
  Future<void> signOut();
  Future<void> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    Uint8List? avatarBytes,
    String? avatarExt,
  });

  Stream<List<ChatSummary>> watchChats();
  Stream<List<Message>> watchMessages(String chatId);
  Future<void> sendMessage(String chatId, String text);

  Future<ChatDetails> chatDetails(String chatId);
  Future<List<Profile>> searchUsers(String query);
  Future<List<Profile>> contacts();

  /// Возвращает id существующего или нового личного чата.
  Future<String> openDirectChat(String userId);
  Future<String> createGroup({
    required String title,
    required List<String> memberIds,
    bool channel = false,
  });

  Future<void> setPinned(Iterable<String> chatIds, bool value);
  Future<void> setMuted(Iterable<String> chatIds, bool value);
  Future<void> setArchived(Iterable<String> chatIds, bool value);
  Future<void> markRead(Iterable<String> chatIds);
  Future<void> leaveChats(Iterable<String> chatIds);
}
