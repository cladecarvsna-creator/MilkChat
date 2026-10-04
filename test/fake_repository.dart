import 'dart:async';
import 'dart:typed_data';

import 'package:milkchat/models/models.dart';
import 'package:milkchat/data/chat_repository.dart';

/// Хранилище в памяти для виджет-тестов. В приложении не используется.
class FakeRepository extends ChatRepository {
  FakeRepository() {
    _seed();
  }

  final _changes = StreamController<void>.broadcast();
  final Map<String, Profile> _users = {};
  final Map<String, ChatSummary> _chats = {};
  final Map<String, List<Message>> _messages = {};
  final Map<String, Set<String>> _members = {};
  final Map<String, String> _about = {};

  /// Кто может писать в канал. В группах и личных чатах пишут все.
  final Map<String, Set<String>> _admins = {};
  Profile? _me;
  int _seq = 0;

  @override
  Profile? get me => _me;

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

    u('me', 'milkman', 'Джек', bio: 'Пью молоко и пишу код');
    final official = u('milkchat', 'milkchat', 'MilkChat', verified: true);
    // Вход выполняется на экране авторизации кнопкой «Войти в демо».

    _members['c_milkchat'] = {'me', official.id};
    _admins['c_milkchat'] = {official.id};
    _about['c_milkchat'] = 'Официальный канал MilkChat: новости и обновления';
    _messages['c_milkchat'] = [
      for (final (text, ago) in [
        ('Добро пожаловать в MilkChat! 🥛', const Duration(minutes: 20)),
        ('Это демо-режим: данные хранятся только в этом окне. '
            'Создавайте свои группы и каналы кнопкой «+».', const Duration(minutes: 19)),
      ])
        Message(
          id: _id(),
          chatId: 'c_milkchat',
          senderId: official.id,
          senderName: official.displayName,
          text: text,
          createdAt: now.subtract(ago),
          read: true,
        )
    ];
    _chats['c_milkchat'] = const ChatSummary(
      id: 'c_milkchat',
      kind: ChatKind.channel,
      title: 'MilkChat',
      handle: '@milkchat',
      verified: true,
      unread: 2,
      memberCount: 2,
      canPost: false,
    );
    _refreshLast('c_milkchat');
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
    final admins = _admins[chatId];
    if (admins != null && !admins.contains(me.id)) {
      throw StateError('В канал пишут только администраторы');
    }
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
    if (channel) _admins[id] = {_me!.id};
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
      _admins.remove(id);
    }
    _emit();
  }

  @override
  void dispose() {
    _changes.close();
    super.dispose();
  }
}
