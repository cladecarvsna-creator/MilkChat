import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'chat_repository.dart';

/// Id официального канала MilkChat. Создаётся скриптом tool/admin (Admin SDK).
const officialChannelId = 'milkchat';

/// Firebase: Authentication + Firestore + Storage.
///
/// Структура Firestore (правила — firestore.rules):
///   users/{uid}                 публичный профиль; verified пишет только Admin SDK
///   usernames/{lower}           {uid} — уникальность юзернеймов
///   user_settings/{uid}/chats/{chatId}   pinned / muted / archived (только владелец)
///   chats/{chatId}              kind: direct | group | channel | saved,
///                               members, admins, lastMessage, unread.{uid}, readAt.{uid}
///   chats/{chatId}/messages/{id}
/// Каналы — это chats с kind == 'channel': отдельные коллекции channels и
/// channel_members не нужны, участники и админы лежат в самом документе.
class FirebaseRepository extends ChatRepository {
  FirebaseRepository({FirebaseAuth? auth, FirebaseFirestore? db, FirebaseStorage? storage})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance {
    _authSub = _auth.authStateChanges().listen(_onUser);
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  late final StreamSubscription<User?> _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _meSub;
  Profile? _me;
  bool _loading = true;
  bool _staff = false;
  final Map<String, Profile> _profiles = {};

  @override
  Profile? get me => _me;
  @override
  bool get loading => _loading;

  /// Почта ещё не подтверждена (для входа по паролю).
  bool get needsEmailVerification {
    final u = _auth.currentUser;
    if (u == null) return false;
    final password = u.providerData.any((p) => p.providerId == 'password');
    return password && !u.emailVerified;
  }

  /// Модератор MilkChat. Роль выдаётся только сервером (Custom Claim `staff`),
  /// а правила Firestore проверяют её сами — флаг лишь показывает админку.
  bool get isStaff => _staff;

  /// Почему не удалось прочитать роль (показывается в «О MilkChat»).
  String? roleError;

  /// Перечитывает роль из свежего токена — после выдачи прав не нужно перезаходить.
  Future<void> refreshRole() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final token = await user.getIdTokenResult(true);
      final staff = token.claims?['staff'] == true;
      roleError = null;
      if (staff != _staff) {
        _staff = staff;
        notifyListeners();
      }
    } catch (e) {
      roleError = '$e';
      debugPrint('MilkChat: роль не прочитана: $e');
    }
  }

  String? get uid => _auth.currentUser?.uid;

  String get _uid => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _chats => _db.collection('chats');
  CollectionReference<Map<String, dynamic>> _settings(String uid) =>
      _db.collection('user_settings').doc(uid).collection('chats');

  // ─── Авторизация ──────────────────────────────────────────────────────────

  Future<void> _onUser(User? user) async {
    await _meSub?.cancel();
    _meSub = null;
    if (user == null) {
      _staff = false;
      _me = null;
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      await _ensureProfile(user);
      await refreshRole();
      _meSub = _users.doc(user.uid).snapshots().listen((s) {
        if (!s.exists) return;
        _me = _profileFrom(s);
        _loading = false;
        notifyListeners();
      });
      unawaited(_users.doc(user.uid).update({'lastSeen': FieldValue.serverTimestamp()}));
      unawaited(_joinOfficialChannel());
    } catch (e) {
      _loading = false;
      notifyListeners();
      debugPrint('MilkChat: профиль не загружен: $e');
    }
  }

  /// Создаёт профиль при первом входе (через Google или после регистрации).
  Future<void> _ensureProfile(User user, {String? username, String? displayName}) async {
    final ref = _users.doc(user.uid);
    if ((await ref.get()).exists) return;
    final base = (username ?? _usernameFrom(user)).trim();
    final rnd = Random();
    for (var attempt = 0; attempt < 5; attempt++) {
      final name = attempt == 0 ? base : '${base}_${rnd.nextInt(9000) + 1000}';
      try {
        await _db.runTransaction((tx) async {
          final un = _db.collection('usernames').doc(name.toLowerCase());
          if ((await tx.get(un)).exists) throw const AuthFailure('username-taken');
          tx.set(un, {'uid': user.uid});
          tx.set(ref, {
            'username': name,
            'usernameLower': name.toLowerCase(),
            'displayName': displayName ?? user.displayName ?? name,
            'bio': '',
            'avatarUrl': user.photoURL,
            'verified': false,
            'createdAt': FieldValue.serverTimestamp(),
            'lastSeen': FieldValue.serverTimestamp(),
          });
        });
        return;
      } on AuthFailure {
        if (username != null) rethrow;
      }
    }
    throw const AuthFailure('Не удалось подобрать свободный юзернейм');
  }

  String _usernameFrom(User u) {
    final raw = (u.email ?? 'user').split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final s = raw.length < 3 ? 'user_$raw' : raw;
    return s.length > 24 ? s.substring(0, 24) : s;
  }

  Future<void> _joinOfficialChannel() async {
    try {
      await _chats.doc(officialChannelId).update({
        'members': FieldValue.arrayUnion([_uid]),
      });
    } catch (_) {
      // Канал ещё не создан администратором — ничего страшного.
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithEmailAndPassword(email: email, password: password));

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) =>
      _guard(() async {
        final taken =
            await _db.collection('usernames').doc(username.toLowerCase()).get();
        if (taken.exists) throw const AuthFailure('Этот юзернейм уже занят');
        final cred =
            await _auth.createUserWithEmailAndPassword(email: email, password: password);
        await cred.user!.updateDisplayName(displayName);
        await _ensureProfile(cred.user!, username: username, displayName: displayName);
        await cred.user!.sendEmailVerification();
      });

  @override
  bool get supportsGoogle =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Веб — всплывающее окно Google OAuth; Android/iOS — нативный поток
  /// `signInWithProvider` из firebase_auth (пакет google_sign_in не нужен).
  @override
  Future<void> signInWithGoogle() => _guard(() async {
        final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
        if (kIsWeb) {
          await _auth.signInWithPopup(provider);
        } else {
          await _auth.signInWithProvider(provider);
        }
      });

  @override
  Future<void> resetPassword(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email));

  Future<void> resendVerification() =>
      _guard(() async => _auth.currentUser?.sendEmailVerification());

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
    notifyListeners();
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_authMessage(e.code));
    } on FirebaseException catch (e) {
      throw AuthFailure(e.code == 'permission-denied'
          ? 'Нет доступа. Проверьте правила Firestore.'
          : (e.message ?? e.code));
    }
  }

  static String _authMessage(String code) => switch (code) {
        'invalid-email' => 'Неверный адрес почты',
        'user-disabled' => 'Аккаунт заблокирован',
        'user-not-found' || 'wrong-password' || 'invalid-credential' =>
          'Неверная почта или пароль',
        'email-already-in-use' => 'Эта почта уже зарегистрирована',
        'weak-password' => 'Слишком простой пароль (минимум 6 символов)',
        'too-many-requests' => 'Слишком много попыток, попробуйте позже',
        'network-request-failed' => 'Нет соединения с интернетом',
        'popup-closed-by-user' || 'cancelled-popup-request' => 'Вход отменён',
        'popup-blocked' => 'Браузер заблокировал окно входа Google',
        'unauthorized-domain' => 'Домен не добавлен в Authorized domains Firebase',
        'operation-not-allowed' => 'Этот способ входа выключен в Firebase',
        _ => 'Ошибка входа ($code)',
      };

  // ─── Профили ──────────────────────────────────────────────────────────────

  Profile _profileFrom(DocumentSnapshot<Map<String, dynamic>> s) {
    final m = s.data()!;
    final p = Profile(
      id: s.id,
      username: m['username'] as String? ?? '',
      displayName: m['displayName'] as String? ?? '',
      bio: m['bio'] as String? ?? '',
      avatarUrl: m['avatarUrl'] as String?,
      verified: m['verified'] as bool? ?? false,
      banned: m['banned'] as bool? ?? false,
      lastSeen: (m['lastSeen'] as Timestamp?)?.toDate(),
    );
    _profiles[p.id] = p;
    return p;
  }

  Future<List<Profile>> _loadProfiles(Iterable<String> ids, {bool refresh = false}) async {
    final missing = ids.where((id) => refresh || !_profiles.containsKey(id)).toSet().toList();
    for (var i = 0; i < missing.length; i += 30) {
      final part = missing.sublist(i, min(i + 30, missing.length));
      final snap = await _users.where(FieldPath.documentId, whereIn: part).get();
      for (final d in snap.docs) {
        _profileFrom(d);
      }
    }
    return [for (final id in ids) ?_profiles[id]];
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? username,
    String? bio,
    Uint8List? avatarBytes,
    String? avatarExt,
  }) =>
      _guard(() async {
        final ref = _users.doc(_uid);
        final patch = <String, dynamic>{'displayName': ?displayName, 'bio': ?bio};
        if (avatarBytes != null) {
          patch['avatarUrl'] = await _uploadAvatar(avatarBytes, avatarExt);
        }
        if (username != null && username != _me?.username) {
          final old = _me!.username.toLowerCase();
          await _db.runTransaction((tx) async {
            final un = _db.collection('usernames').doc(username.toLowerCase());
            final cur = await tx.get(un);
            if (cur.exists && cur.data()?['uid'] != _uid) {
              throw const AuthFailure('Этот юзернейм уже занят');
            }
            tx.set(un, {'uid': _uid});
            if (old != username.toLowerCase()) {
              tx.delete(_db.collection('usernames').doc(old));
            }
            tx.update(ref, {
              ...patch,
              'username': username,
              'usernameLower': username.toLowerCase(),
            });
          });
          return;
        }
        if (patch.isNotEmpty) await ref.update(patch);
      });

  static const _maxAvatarBytes = 2 * 1024 * 1024;

  Future<String> _uploadAvatar(Uint8List bytes, String? ext) async {
    final type = switch ((ext ?? '').toLowerCase()) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => throw const AuthFailure('Поддерживаются PNG, JPG, WEBP и GIF'),
    };
    if (bytes.length > _maxAvatarBytes) {
      throw const AuthFailure('Аватарка должна быть меньше 2 МБ');
    }
    final ref = _storage.ref('avatars/$_uid/avatar_${DateTime.now().millisecondsSinceEpoch}');
    await ref.putData(bytes, SettableMetadata(contentType: type));
    return ref.getDownloadURL();
  }

  @override
  Future<List<Profile>> searchUsers(String query) async {
    final q = query.replaceFirst('@', '').trim().toLowerCase();
    if (q.length < 2) return [];
    final snap = await _users
        .where('usernameLower', isGreaterThanOrEqualTo: q)
        .where('usernameLower', isLessThan: '$q')
        .limit(20)
        .get();
    return [for (final d in snap.docs) if (d.id != _uid) _profileFrom(d)];
  }

  @override
  Future<List<Profile>> contacts() async {
    final snap = await _chats.where('members', arrayContains: _uid).get();
    final ids = <String>{};
    for (final d in snap.docs) {
      if (d.data()['kind'] == 'channel') continue;
      ids.addAll(List<String>.from(d.data()['members'] as List? ?? const []));
    }
    ids.remove(_uid);
    final list = await _loadProfiles(ids);
    return list..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  // ─── Чаты ─────────────────────────────────────────────────────────────────

  @override
  Stream<List<ChatSummary>> watchChats() {
    late final StreamController<List<ChatSummary>> out;
    StreamSubscription<dynamic>? chatsSub, settingsSub;
    var chatDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var settings = <String, Map<String, dynamic>>{};

    Future<void> emit() async {
      final peers = <String>{};
      for (final d in chatDocs) {
        if (d.data()['kind'] == 'direct') {
          peers.addAll(List<String>.from(d.data()['members'] as List).where((m) => m != _uid));
        }
      }
      await _loadProfiles(peers);
      if (out.isClosed) return;
      out.add([for (final d in chatDocs) _summary(d, settings[d.id] ?? const {})]);
    }

    out = StreamController<List<ChatSummary>>(
      onListen: () {
        chatsSub = _chats.where('members', arrayContains: _uid).snapshots().listen((s) {
          chatDocs = s.docs;
          emit();
        }, onError: out.addError);
        settingsSub = _settings(_uid).snapshots().listen((s) {
          settings = {for (final d in s.docs) d.id: d.data()};
          emit();
        }, onError: out.addError);
      },
      onCancel: () async {
        await chatsSub?.cancel();
        await settingsSub?.cancel();
      },
    );
    return out.stream;
  }

  ChatSummary _summary(DocumentSnapshot<Map<String, dynamic>> d, Map<String, dynamic> st) {
    final m = d.data()!;
    final kind = ChatKindLabel.parse(m['kind'] as String?);
    final members = List<String>.from(m['members'] as List? ?? const []);
    final admins = List<String>.from(m['admins'] as List? ?? const []);
    final peerId = kind == ChatKind.direct
        ? members.firstWhere((x) => x != _uid, orElse: () => _uid)
        : null;
    final peer = peerId == null ? null : _profiles[peerId];
    final last = m['lastMessage'] as Map<String, dynamic>?;
    final lastAt = (m['lastAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final readAt = (m['readAt'] as Map<String, dynamic>?) ?? const {};
    final othersRead = readAt.entries.any((e) =>
        e.key != _uid && !((e.value as Timestamp?)?.toDate() ?? DateTime(0)).isBefore(lastAt));
    return ChatSummary(
      id: d.id,
      kind: kind,
      title: peer != null
          ? (peer.displayName.isEmpty ? peer.username : peer.displayName)
          : (m['title'] as String? ?? ''),
      handle: peer != null ? '@${peer.username}' : m['handle'] as String?,
      avatarUrl: peer?.avatarUrl ?? m['avatarUrl'] as String?,
      verified: peer?.verified ?? (m['verified'] as bool? ?? false),
      lastMessage: last?['text'] as String?,
      lastSenderName: last?['senderName'] as String?,
      lastFromMe: last?['senderId'] == _uid,
      lastRead: othersRead,
      lastAt: lastAt,
      unread: ((m['unread'] as Map<String, dynamic>?)?[_uid] as num?)?.toInt() ?? 0,
      pinned: st['pinned'] as bool? ?? false,
      muted: st['muted'] as bool? ?? false,
      archived: st['archived'] as bool? ?? false,
      memberCount: members.length,
      peerId: peerId,
      canPost: kind != ChatKind.channel || admins.contains(_uid),
    );
  }

  @override
  Stream<List<Message>> watchMessages(String chatId) {
    late final StreamController<List<Message>> out;
    StreamSubscription<dynamic>? msgSub, chatSub;
    var docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    var othersRead = DateTime(0);

    void emit() {
      if (out.isClosed) return;
      out.add([
        for (final d in docs.reversed)
          () {
            final m = d.data();
            final at = (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            return Message(
              id: d.id,
              chatId: chatId,
              senderId: m['senderId'] as String,
              senderName: m['senderName'] as String?,
              text: m['text'] as String? ?? '',
              createdAt: at,
              read: !at.isAfter(othersRead),
            );
          }()
      ]);
    }

    out = StreamController<List<Message>>(
      onListen: () {
        final chat = _chats.doc(chatId);
        msgSub = chat
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(300)
            .snapshots()
            .listen((s) {
          docs = s.docs;
          emit();
        }, onError: out.addError);
        chatSub = chat.snapshots().listen((s) {
          final readAt = (s.data()?['readAt'] as Map<String, dynamic>?) ?? const {};
          othersRead = DateTime(0);
          for (final e in readAt.entries) {
            final t = (e.value as Timestamp?)?.toDate();
            if (e.key != _uid && t != null && t.isAfter(othersRead)) othersRead = t;
          }
          emit();
        }, onError: out.addError);
      },
      onCancel: () async {
        await msgSub?.cancel();
        await chatSub?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<void> sendMessage(String chatId, String text) => _guard(() async {
        final chatRef = _chats.doc(chatId);
        final chat = await chatRef.get();
        final members = List<String>.from(chat.data()?['members'] as List? ?? const []);
        final me = _me!;
        final name = me.displayName.isEmpty ? me.username : me.displayName;
        final batch = _db.batch();
        batch.set(chatRef.collection('messages').doc(), {
          'senderId': _uid,
          'senderName': name,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.update(chatRef, {
          'lastMessage': {'text': text, 'senderId': _uid, 'senderName': name},
          'lastAt': FieldValue.serverTimestamp(),
          'readAt.$_uid': FieldValue.serverTimestamp(),
          for (final m in members)
            if (m != _uid) 'unread.$m': FieldValue.increment(1),
        });
        await batch.commit();
      });

  /// Редактирование своего сообщения.
  Future<void> editMessage(String chatId, String messageId, String text) =>
      _guard(() => _chats.doc(chatId).collection('messages').doc(messageId).update({
            'text': text,
            'editedAt': FieldValue.serverTimestamp(),
          }));

  /// Удаление: своё сообщение — автор; любое — админ группы или канала (проверяют правила).
  Future<void> deleteMessage(String chatId, String messageId) =>
      _guard(() => _chats.doc(chatId).collection('messages').doc(messageId).delete());

  @override
  Future<ChatDetails> chatDetails(String chatId) async {
    final d = await _chats.doc(chatId).get();
    final members = List<String>.from(d.data()?['members'] as List? ?? const []);
    final profiles = await _loadProfiles(members, refresh: true);
    final st = (await _settings(_uid).doc(chatId).get()).data() ?? const {};
    return ChatDetails(
      chat: _summary(d, st),
      members: profiles,
      about: d.data()?['about'] as String? ?? '',
    );
  }

  @override
  Future<String> openDirectChat(String userId) => _guard(() async {
        final ids = [_uid, userId]..sort();
        final ref = _chats.doc('dm_${ids.join('_')}');
        final snap = await ref.get();
        if (!snap.exists) {
          await ref.set({
            'kind': 'direct',
            'members': ids,
            'admins': <String>[],
            'createdBy': _uid,
            'createdAt': FieldValue.serverTimestamp(),
            'lastAt': FieldValue.serverTimestamp(),
          });
        }
        return ref.id;
      });

  @override
  Future<String> createGroup({
    required String title,
    required List<String> memberIds,
    bool channel = false,
  }) =>
      _guard(() async {
        final ref = await _chats.add({
          'kind': channel ? 'channel' : 'group',
          'title': title,
          'about': '',
          'members': {_uid, ...memberIds}.toList(),
          'admins': [_uid],
          'createdBy': _uid,
          'createdAt': FieldValue.serverTimestamp(),
          'lastAt': FieldValue.serverTimestamp(),
          'lastMessage': {
            'text': channel ? 'Канал создан' : 'Группа создана',
            'senderId': _uid,
            'senderName': _me?.displayName ?? '',
          },
        });
        return ref.id;
      });

  /// Добавить участников (админ группы/канала).
  Future<void> addMembers(String chatId, List<String> userIds) => _guard(() =>
      _chats.doc(chatId).update({'members': FieldValue.arrayUnion(userIds)}));

  /// Убрать участника (админ) или выйти самому.
  Future<void> removeMember(String chatId, String userId) => _guard(() =>
      _chats.doc(chatId).update({'members': FieldValue.arrayRemove([userId])}));

  Future<void> _patchSettings(Iterable<String> ids, Map<String, dynamic> patch) =>
      _guard(() async {
        final batch = _db.batch();
        for (final id in ids) {
          batch.set(_settings(_uid).doc(id), patch, SetOptions(merge: true));
        }
        await batch.commit();
      });

  @override
  Future<void> setPinned(Iterable<String> chatIds, bool value) =>
      _patchSettings(chatIds, {'pinned': value});
  @override
  Future<void> setMuted(Iterable<String> chatIds, bool value) =>
      _patchSettings(chatIds, {'muted': value});
  @override
  Future<void> setArchived(Iterable<String> chatIds, bool value) =>
      _patchSettings(chatIds, {'archived': value});

  @override
  Future<void> markRead(Iterable<String> chatIds) => _guard(() async {
        final batch = _db.batch();
        for (final id in chatIds) {
          batch.update(_chats.doc(id), {
            'unread.$_uid': 0,
            'readAt.$_uid': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      });

  @override
  Future<void> leaveChats(Iterable<String> chatIds) => _guard(() async {
        for (final id in chatIds) {
          await removeMember(id, _uid);
          await _settings(_uid).doc(id).delete();
        }
      });

  // ─── Модерация (только claim staff; правила проверяют то же самое) ────────

  Future<AdminStats> adminStats() => _guard(() async {
        Future<int> n(Query<Map<String, dynamic>> q) async =>
            (await q.count().get()).count ?? 0;
        final r = await Future.wait([
          n(_users),
          n(_users.where('banned', isEqualTo: true)),
          n(_chats.where('kind', isEqualTo: 'group')),
          n(_chats.where('kind', isEqualTo: 'channel')),
          n(_chats.where('kind', isEqualTo: 'direct')),
          n(_db.collection('reports')),
        ]);
        return AdminStats(
          users: r[0], banned: r[1], groups: r[2], channels: r[3], directs: r[4], reports: r[5]);
      });

  /// Пользователи: последние зарегистрированные или поиск по юзернейму.
  Future<List<Profile>> adminUsers(String query) => _guard(() async {
        final q = query.trim().toLowerCase().replaceAll('@', '');
        final snap = q.isEmpty
            ? await _users.orderBy('createdAt', descending: true).limit(100).get()
            : await _users
                .where('usernameLower', isGreaterThanOrEqualTo: q)
                .where('usernameLower', isLessThan: '$q\uf8ff')
                .limit(50)
                .get();
        return snap.docs.map(_profileFrom).toList();
      });

  Future<void> adminSetVerified(String userId, bool value) =>
      _guard(() => _users.doc(userId).update({'verified': value}));

  Future<void> adminSetBanned(String userId, bool value) =>
      _guard(() => _users.doc(userId).update({'banned': value}));

  /// Все группы и каналы (личные переписки модератор не просматривает).
  Future<List<AdminChat>> adminChats() => _guard(() async {
        final snap = await _chats.where('kind', whereIn: ['group', 'channel']).limit(200).get();
        final list = snap.docs.map((d) {
          final m = d.data();
          return AdminChat(
            id: d.id,
            title: m['title'] as String? ?? d.id,
            channel: m['kind'] == 'channel',
            members: (m['members'] as List?)?.length ?? 0,
            verified: m['verified'] as bool? ?? false,
            createdBy: m['createdBy'] as String? ?? '',
          );
        }).toList()
          ..sort((a, b) => b.members.compareTo(a.members));
        return list;
      });

  Future<void> adminSetChatVerified(String chatId, bool value) =>
      _guard(() => _chats.doc(chatId).update({'verified': value}));

  Future<void> adminRenameChat(String chatId, String title) =>
      _guard(() => _chats.doc(chatId).update({'title': title}));

  /// Удаляет чат вместе с сообщениями.
  Future<void> adminDeleteChat(String chatId) => _guard(() async {
        final msgs = _chats.doc(chatId).collection('messages');
        while (true) {
          final page = await msgs.limit(400).get();
          if (page.docs.isEmpty) break;
          final b = _db.batch();
          for (final d in page.docs) {
            b.delete(d.reference);
          }
          await b.commit();
        }
        await _chats.doc(chatId).delete();
      });

  Future<List<Report>> adminReports() => _guard(() async {
        final snap = await _db
            .collection('reports')
            .orderBy('createdAt', descending: true)
            .limit(100)
            .get();
        return snap.docs.map((d) {
          final m = d.data();
          return Report(
            id: d.id,
            reporterId: m['reporterId'] as String? ?? '',
            chatId: m['chatId'] as String? ?? '',
            messageId: m['messageId'] as String?,
            targetId: m['targetId'] as String?,
            text: m['text'] as String? ?? '',
            createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
          );
        }).toList();
      });

  Future<void> adminCloseReport(String reportId) =>
      _guard(() => _db.collection('reports').doc(reportId).delete());

  /// Жалоба на сообщение — её увидят модераторы в админке.
  Future<void> report(Message m) => _guard(() => _db.collection('reports').add({
        'reporterId': _uid,
        'chatId': m.chatId,
        'messageId': m.id,
        'targetId': m.senderId,
        'text': m.text.length > 500 ? m.text.substring(0, 500) : m.text,
        'createdAt': FieldValue.serverTimestamp(),
      }));

  Future<Profile?> profileById(String id) async =>
      id.isEmpty ? null : (await _loadProfiles([id])).firstOrNull;

  @override
  void dispose() {
    _authSub.cancel();
    _meSub?.cancel();
    super.dispose();
  }
}
