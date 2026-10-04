import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import 'chat_repository.dart';

/// Работа с сервером Supabase: вход, чаты, сообщения в реальном времени.
/// Схема базы — в supabase/schema.sql.
class SupabaseRepository extends ChatRepository {
  SupabaseRepository(this._db) {
    _authSub = _db.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.signedOut) {
        _me = null;
        notifyListeners();
      } else if (state.session != null && _me?.id != state.session!.user.id) {
        _loadMe();
      }
    });
    if (_db.auth.currentUser != null) _loadMe();
  }

  final SupabaseClient _db;
  late final StreamSubscription<AuthState> _authSub;
  Profile? _me;
  bool _loading = false;
  int _channelSeq = 0;

  @override
  Profile? get me => _me;

  @override
  bool get isDemo => false;

  /// Сессия есть, но профиль ещё загружается.
  bool get loading => _loading || (_db.auth.currentUser != null && _me == null);

  String get _uid => _db.auth.currentUser!.id;

  Future<void> _loadMe() async {
    _loading = true;
    try {
      final row = await _db.from('profiles').select().eq('id', _uid).single();
      _me = Profile.fromMap(row);
      unawaited(_db
          .from('profiles')
          .update({'last_seen': DateTime.now().toUtc().toIso8601String()})
          .eq('id', _uid));
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _db.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final res = await _db.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'display_name': displayName},
    );
    if (res.session == null) {
      throw const AuthException(
          'Мы отправили письмо для подтверждения почты. Откройте его и войдите.');
    }
  }

  @override
  Future<void> signOut() => _db.auth.signOut();

  @override
  Future<void> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    Uint8List? avatarBytes,
    String? avatarExt,
  }) async {
    final patch = <String, dynamic>{
      'display_name': ?displayName,
      'username': ?username,
      'bio': ?bio,
    };
    if (avatarBytes != null) {
      final path = '$_uid/avatar_${DateTime.now().millisecondsSinceEpoch}.${avatarExt ?? 'png'}';
      await _db.storage.from('avatars').uploadBinary(path, avatarBytes);
      patch['avatar_url'] = _db.storage.from('avatars').getPublicUrl(path);
    }
    if (patch.isEmpty) return;
    await _db.from('profiles').update(patch).eq('id', _uid);
    await _loadMe();
  }

  /// Перезапрашивает список чатов при любом новом сообщении или изменении участия.
  @override
  Stream<List<ChatSummary>> watchChats() {
    late final StreamController<List<ChatSummary>> out;
    RealtimeChannel? channel;
    Timer? debounce;

    Future<void> load() async {
      try {
        final rows = await _db.rpc('my_chats') as List<dynamic>;
        if (!out.isClosed) {
          out.add([for (final r in rows) ChatSummary.fromMap(r as Map<String, dynamic>)]);
        }
      } catch (e, s) {
        if (!out.isClosed) out.addError(e, s);
      }
    }

    void schedule([_]) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 250), load);
    }

    out = StreamController<List<ChatSummary>>(
      onListen: () {
        load();
        channel = _db
            .channel('my-chats-$_uid-${_channelSeq++}')
            .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'messages',
                callback: schedule)
            .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'chat_members',
                callback: schedule)
            .subscribe();
      },
      onCancel: () async {
        debounce?.cancel();
        if (channel != null) await _db.removeChannel(channel!);
      },
    );
    return out.stream;
  }

  @override
  Stream<List<Message>> watchMessages(String chatId) {
    final names = <String, String>{};
    late final StreamController<List<Message>> out;
    StreamSubscription<dynamic>? msgSub;
    StreamSubscription<dynamic>? readSub;
    var messages = <Message>[];
    DateTime? othersRead;

    Future<void> ensureNames(Iterable<String> ids) async {
      final missing = ids.where((id) => !names.containsKey(id)).toSet();
      if (missing.isEmpty) return;
      final rows = await _db
          .from('profiles')
          .select('id, username, display_name')
          .inFilter('id', missing.toList());
      for (final r in rows) {
        final name = (r['display_name'] as String?) ?? '';
        names[r['id'] as String] = name.isEmpty ? r['username'] as String : name;
      }
    }

    void emit() {
      if (out.isClosed) return;
      out.add([
        for (final m in messages)
          Message(
            id: m.id,
            chatId: m.chatId,
            senderId: m.senderId,
            senderName: names[m.senderId],
            text: m.text,
            createdAt: m.createdAt,
            read: othersRead != null && !m.createdAt.isAfter(othersRead!),
          )
      ]);
    }

    out = StreamController<List<Message>>(
      onListen: () {
        msgSub = _db
            .from('messages')
            .stream(primaryKey: ['id'])
            .eq('chat_id', chatId)
            .order('created_at')
            .limit(500)
            .listen((rows) async {
          // Поток отдаёт последние 500 сообщений от новых к старым.
          messages = [for (final r in rows) Message.fromMap(r)]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          await ensureNames(messages.map((m) => m.senderId));
          emit();
        }, onError: out.addError);
        readSub = _db
            .from('chat_members')
            .stream(primaryKey: ['chat_id', 'user_id'])
            .eq('chat_id', chatId)
            .listen((rows) {
          DateTime? latest;
          for (final r in rows) {
            if (r['user_id'] == _uid) continue;
            final t = DateTime.parse(r['last_read_at'] as String).toLocal();
            if (latest == null || t.isAfter(latest)) latest = t;
          }
          othersRead = latest;
          emit();
        }, onError: out.addError);
      },
      onCancel: () async {
        await msgSub?.cancel();
        await readSub?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<void> sendMessage(String chatId, String text) async {
    await _db.from('messages').insert({'chat_id': chatId, 'body': text});
  }

  @override
  Future<ChatDetails> chatDetails(String chatId) async {
    final rows = await _db.rpc('my_chats') as List<dynamic>;
    final chat = ChatSummary.fromMap(rows
        .cast<Map<String, dynamic>>()
        .firstWhere((r) => r['id'] == chatId));
    final info = await _db.from('chats').select('about').eq('id', chatId).single();
    final members = await _db
        .from('chat_members')
        .select('profiles(*)')
        .eq('chat_id', chatId);
    return ChatDetails(
      chat: chat,
      about: (info['about'] as String?) ?? '',
      members: [
        for (final m in members) Profile.fromMap(m['profiles'] as Map<String, dynamic>)
      ],
    );
  }

  @override
  Future<List<Profile>> searchUsers(String query) async {
    final q = query.replaceFirst('@', '').replaceAll(RegExp(r'[%,()]'), '').trim();
    if (q.isEmpty) return [];
    final rows = await _db
        .from('profiles')
        .select()
        .or('username.ilike.%$q%,display_name.ilike.%$q%')
        .neq('id', _uid)
        .limit(30);
    return [for (final r in rows) Profile.fromMap(r)];
  }

  /// Контакты — все, с кем есть общие чаты.
  @override
  Future<List<Profile>> contacts() async {
    final mine = await _db.from('chat_members').select('chat_id').eq('user_id', _uid);
    final ids = [for (final r in mine) r['chat_id'] as String];
    if (ids.isEmpty) return [];
    final rows = await _db
        .from('chat_members')
        .select('profiles(*)')
        .inFilter('chat_id', ids)
        .neq('user_id', _uid);
    final seen = <String, Profile>{};
    for (final r in rows) {
      final p = Profile.fromMap(r['profiles'] as Map<String, dynamic>);
      seen[p.id] = p;
    }
    return seen.values.toList()..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  @override
  Future<String> openDirectChat(String userId) async =>
      await _db.rpc('open_direct_chat', params: {'p_peer': userId}) as String;

  @override
  Future<String> createGroup({
    required String title,
    required List<String> memberIds,
    bool channel = false,
  }) async =>
      await _db.rpc('create_group', params: {
        'p_title': title,
        'p_members': memberIds,
        'p_channel': channel,
      }) as String;

  Future<void> _patchMembership(Iterable<String> ids, Map<String, dynamic> patch) =>
      _db
          .from('chat_members')
          .update(patch)
          .eq('user_id', _uid)
          .inFilter('chat_id', ids.toList());

  @override
  Future<void> setPinned(Iterable<String> chatIds, bool value) =>
      _patchMembership(chatIds, {'pinned': value});

  @override
  Future<void> setMuted(Iterable<String> chatIds, bool value) =>
      _patchMembership(chatIds, {'muted': value});

  @override
  Future<void> setArchived(Iterable<String> chatIds, bool value) =>
      _patchMembership(chatIds, {'archived': value});

  @override
  Future<void> markRead(Iterable<String> chatIds) => _patchMembership(
      chatIds, {'last_read_at': DateTime.now().toUtc().toIso8601String()});

  @override
  Future<void> leaveChats(Iterable<String> chatIds) => _db
      .from('chat_members')
      .delete()
      .eq('user_id', _uid)
      .inFilter('chat_id', chatIds.toList());

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
