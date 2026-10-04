import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../models/models.dart';
import 'chat_repository.dart';

/// Локальный режим без сервера: данные живут в памяти. Нужен, чтобы приложение
/// можно было запустить и посмотреть сразу, до настройки Supabase.
class DemoRepository extends ChatRepository {
  DemoRepository() {
    _seed();
  }

  final _rand = Random();
  final _changes = StreamController<void>.broadcast();
  final Map<String, Profile> _users = {};
  final Map<String, ChatSummary> _chats = {};
  final Map<String, List<Message>> _messages = {};
  final Map<String, Set<String>> _members = {};
  final Map<String, String> _about = {};
  Profile? _me;
  int _seq = 0;

  @override
  Profile? get me => _me;

  @override
  bool get isDemo => true;

  String _id() => 'd${_seq++}';

  void _emit() => _changes.add(null);

  void _seed() {
    final now = DateTime.now();
    Profile u(String id, String username, String name,
            {bool verified = false, String bio = ''}) =>
        _users[id] = Profile(
            id: id,
            username: username,
            displayName: name,
            verified: verified,
            bio: bio);

    final me = u('me', 'milkman', 'Джек', bio: 'Пью молоко и пишу код');
    final bot = u('bot', 'milkchat', 'MilkChat', verified: true);
    final vova = u('vova', 'vova', 'Вова');
    final nerix = u('nerix', 'nerixton', 'nerixton');
    final masha = u('masha', 'masha', 'Маша Коровина', verified: true);
    final sher = u('sher', 'sherlock', 'Sherlock');
    // Вход выполняется на экране авторизации кнопкой «Войти в демо».

    void chat(String id, ChatKind kind, String title, List<Profile> members,
        List<(Profile, String, Duration)> msgs,
        {String? handle,
        String? emoji,
        int unread = 0,
        bool verified = false,
        String about = ''}) {
      _members[id] = {for (final m in members) m.id};
      _about[id] = about;
      _messages[id] = [
        for (final (p, text, ago) in msgs)
          Message(
            id: _id(),
            chatId: id,
            senderId: p.id,
            senderName: p.displayName,
            text: text,
            createdAt: now.subtract(ago),
            read: true,
          )
      ];
      final peer = kind == ChatKind.direct
          ? members.firstWhere((m) => m.id != 'me')
          : null;
      _chats[id] = ChatSummary(
        id: id,
        kind: kind,
        title: title,
        handle: handle ?? (peer != null ? '@${peer.username}' : null),
        avatarEmoji: emoji,
        verified: verified,
        unread: unread,
        memberCount: members.length,
        peerId: peer?.id,
      );
      _refreshLast(id);
    }

    const m = Duration(minutes: 1);
    const h = Duration(hours: 1);
    const d = Duration(days: 1);

    chat('c_bot', ChatKind.direct, 'MilkChat', [me, bot], [
      (bot, 'Добро пожаловать в MilkChat! 🥛', d * 2),
      (bot, 'Вы вошли в аккаунт. Это демо-режим: данные хранятся только на этом устройстве.', m * 20),
    ], unread: 2, verified: true, emoji: '🥛');
    chat('c_cows', ChatKind.group, 'Группа Коров', [me, nerix, vova, masha], [
      (vova, 'Кто идёт на пастбище?', d * 3),
      (masha, 'Я! Только после обеда', d * 3 - h * 2),
      (me, 'И я', d * 2),
      (nerix, 'у меня спор болит', m * 45),
    ], emoji: '🐮', about: 'Самая дружная группа на ферме');
    chat('c_sher', ChatKind.direct, 'Sherlock', [me, sher], [
      (sher, 'Элементарно', h * 5),
      (me, 'Шкалаш', h * 3),
    ]);
    chat('c_masha', ChatKind.direct, 'Маша Коровина', [me, masha], [
      (masha, 'Привет! Как тебе новый цвет?', h * 6),
      (me, 'Отличный, оставляем', h * 6 - m),
      (masha, 'Тогда так и живём', h * 6 - m * 2),
    ], verified: true);
    chat('c_saved', ChatKind.saved, 'Избранное', [me], [
      (me, 'Купить молоко 🥛', d),
    ]);
    chat('c_news', ChatKind.channel, 'MilkChat 2.0', [me, bot, vova, nerix], [
      (bot, 'Вышло обновление: темы и плавающие фигуры на фоне', d * 2),
      (vova, '/app', d * 2 - h),
      (vova, 'Работает?', h * 26),
      (vova, 'точно', h * 4),
    ], handle: '@milkchat', emoji: '📣', about: 'Новости MilkChat');
  }

  void _refreshLast(String chatId) {
    final msgs = _messages[chatId]!;
    final c = _chats[chatId]!;
    if (msgs.isEmpty) return;
    final last = msgs.last;
    _chats[chatId] = c.copyWith(
      lastMessage: last.text,
      lastSenderName: last.senderName,
      lastFromMe: last.senderId == 'me',
      lastRead: last.read,
      lastAt: last.createdAt,
    );
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    _me ??= _users['me'];
    notifyListeners();
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    _me = _users['me'] = _users['me']!.copyWith(
      username: username,
      displayName: displayName,
    );
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _me = null;
    notifyListeners();
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    Uint8List? avatarBytes,
    String? avatarExt,
  }) async {
    _me = _users['me'] = _me!.copyWith(
        displayName: displayName,
        username: username,
        bio: bio,
        avatarBytes: avatarBytes);
    notifyListeners();
  }

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Stream<List<ChatSummary>> watchChats() => _watch(() => _chats.values.toList());

  @override
  Stream<List<Message>> watchMessages(String chatId) =>
      _watch(() => List.unmodifiable(_messages[chatId] ?? const <Message>[]));

  @override
  Future<void> sendMessage(String chatId, String text) async {
    final me = _me!;
    _messages[chatId]!.add(Message(
      id: _id(),
      chatId: chatId,
      senderId: me.id,
      senderName: me.displayName,
      text: text,
      createdAt: DateTime.now(),
    ));
    _refreshLast(chatId);
    _emit();

    // Собеседник «прочитал» и иногда отвечает — чтобы демо выглядело живым.
    Timer(const Duration(milliseconds: 900), () {
      final list = _messages[chatId]!;
      for (var i = 0; i < list.length; i++) {
        final msg = list[i];
        if (msg.senderId == me.id && !msg.read) {
          list[i] = Message(
              id: msg.id,
              chatId: msg.chatId,
              senderId: msg.senderId,
              senderName: msg.senderName,
              text: msg.text,
              createdAt: msg.createdAt,
              read: true);
        }
      }
      _refreshLast(chatId);
      _emit();
    });
    final chat = _chats[chatId]!;
    final others = _members[chatId]!.where((id) => id != me.id).toList();
    if (chat.kind == ChatKind.saved || others.isEmpty) return;
    Timer(Duration(milliseconds: 1500 + _rand.nextInt(1500)), () {
      final who = _users[others[_rand.nextInt(others.length)]]!;
      const replies = ['Ага 👍', 'Мууу 🐮', 'Согласен', 'Ха-ха', 'Позже отвечу', 'Точно!'];
      _messages[chatId]!.add(Message(
        id: _id(),
        chatId: chatId,
        senderId: who.id,
        senderName: who.displayName,
        text: replies[_rand.nextInt(replies.length)],
        createdAt: DateTime.now(),
      ));
      _refreshLast(chatId);
      _emit();
    });
  }

  @override
  Future<ChatDetails> chatDetails(String chatId) async => ChatDetails(
        chat: _chats[chatId]!,
        members: [for (final id in _members[chatId]!) _users[id]!],
        about: _about[chatId] ?? '',
      );

  @override
  Future<List<Profile>> searchUsers(String query) async {
    final q = query.toLowerCase().replaceFirst('@', '');
    return _users.values
        .where((u) =>
            u.id != _me?.id &&
            (u.username.toLowerCase().contains(q) ||
                u.displayName.toLowerCase().contains(q)))
        .toList();
  }

  @override
  Future<List<Profile>> contacts() async =>
      _users.values.where((u) => u.id != _me?.id).toList();

  @override
  Future<String> openDirectChat(String userId) async {
    for (final c in _chats.values) {
      if (c.kind == ChatKind.direct && c.peerId == userId) return c.id;
    }
    final peer = _users[userId]!;
    final id = _id();
    _members[id] = {_me!.id, userId};
    _messages[id] = [];
    _chats[id] = ChatSummary(
      id: id,
      kind: ChatKind.direct,
      title: peer.displayName,
      handle: '@${peer.username}',
      verified: peer.verified,
      memberCount: 2,
      peerId: userId,
      lastAt: DateTime.now(),
    );
    _emit();
    return id;
  }

  @override
  Future<String> createGroup({
    required String title,
    required List<String> memberIds,
    bool channel = false,
  }) async {
    final id = _id();
    _members[id] = {_me!.id, ...memberIds};
    _messages[id] = [];
    _chats[id] = ChatSummary(
      id: id,
      kind: channel ? ChatKind.channel : ChatKind.group,
      title: title,
      memberCount: _members[id]!.length,
      lastAt: DateTime.now(),
      lastMessage: channel ? 'Канал создан' : 'Группа создана',
    );
    _emit();
    return id;
  }

  void _update(Iterable<String> ids, ChatSummary Function(ChatSummary) f) {
    for (final id in ids) {
      final c = _chats[id];
      if (c != null) _chats[id] = f(c);
    }
    _emit();
  }

  @override
  Future<void> setPinned(Iterable<String> chatIds, bool value) async =>
      _update(chatIds, (c) => c.copyWith(pinned: value));

  @override
  Future<void> setMuted(Iterable<String> chatIds, bool value) async =>
      _update(chatIds, (c) => c.copyWith(muted: value));

  @override
  Future<void> setArchived(Iterable<String> chatIds, bool value) async =>
      _update(chatIds, (c) => c.copyWith(archived: value));

  @override
  Future<void> markRead(Iterable<String> chatIds) async =>
      _update(chatIds, (c) => c.copyWith(unread: 0));

  @override
  Future<void> leaveChats(Iterable<String> chatIds) async {
    for (final id in chatIds) {
      _chats.remove(id);
      _messages.remove(id);
      _members.remove(id);
    }
    _emit();
  }

  @override
  void dispose() {
    _changes.close();
    super.dispose();
  }
}
