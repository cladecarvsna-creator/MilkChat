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
  Future<void> sendMessage(
    String chatId,
    String text, {
    MessageRef? replyTo,
    String? forwardedFrom,
  });

  /// Удаление для всех: своё сообщение — автор, любое — админ (проверяют правила).
  Future<void> deleteMessage(String chatId, String messageId) =>
      Future.error(UnsupportedError('Удаление здесь недоступно'));

  Future<ChatDetails> chatDetails(String chatId);
  Future<List<Profile>> searchUsers(String query);

  /// Публичные каналы по юзу (@имя).
  Future<List<ChatSummary>> searchChannels(String query) async => const [];

  /// Подписаться на канал.
  Future<void> joinChannel(String chatId) =>
      Future.error(UnsupportedError('Подписка здесь недоступна'));

  /// Юз канала: null — сделать канал закрытым.
  Future<void> setChatHandle(String chatId, String? handle) =>
      Future.error(UnsupportedError('Юзы здесь недоступны'));

  /// Назначить или снять администратора группы или канала.
  Future<void> setAdmin(String chatId, String userId, bool value) =>
      Future.error(UnsupportedError('Админы здесь недоступны'));

  /// Убрать участника (админ).
  Future<void> removeMember(String chatId, String userId) =>
      Future.error(UnsupportedError('Здесь недоступно'));
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
