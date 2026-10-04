import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Пользователь MilkChat.
class Profile {
  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    this.bio = '',
    this.avatarUrl,
    this.verified = false,
    this.banned = false,
    this.lastSeen,
    this.avatarBytes,
  });

  final String id;
  final String username;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final bool verified;

  /// Заблокирован модератором: не может писать и создавать чаты.
  final bool banned;
  final DateTime? lastSeen;

  /// Аватарка, выбранная в демо-режиме (без загрузки на сервер).
  final Uint8List? avatarBytes;

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        username: (m['username'] as String?) ?? '',
        displayName: (m['display_name'] as String?) ?? '',
        bio: (m['bio'] as String?) ?? '',
        avatarUrl: m['avatar_url'] as String?,
        verified: (m['verified'] as bool?) ?? false,
        lastSeen: m['last_seen'] == null
            ? null
            : DateTime.parse(m['last_seen'] as String).toLocal(),
      );

  Profile copyWith({
    String? username,
    String? displayName,
    String? bio,
    Uint8List? avatarBytes,
    bool? verified,
  }) =>
      Profile(
        id: id,
        username: username ?? this.username,
        displayName: displayName ?? this.displayName,
        bio: bio ?? this.bio,
        avatarUrl: avatarUrl,
        verified: verified ?? this.verified,
        banned: banned,
        lastSeen: lastSeen,
        avatarBytes: avatarBytes ?? this.avatarBytes,
      );
}

enum ChatKind { direct, group, channel, saved }

extension ChatKindLabel on ChatKind {
  String get label => switch (this) {
        ChatKind.direct => 'Личный чат',
        ChatKind.group => 'Группа',
        ChatKind.channel => 'Канал',
        ChatKind.saved => 'Избранное',
      };

  static ChatKind parse(String? v) => switch (v) {
        'group' => ChatKind.group,
        'channel' => ChatKind.channel,
        'saved' => ChatKind.saved,
        _ => ChatKind.direct,
      };
}

/// Чат в списке: сам чат + личные настройки пользователя + последнее сообщение.
class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.kind,
    required this.title,
    this.handle,
    this.avatarUrl,
    this.avatarEmoji,
    this.verified = false,
    this.lastMessage,
    this.lastSenderName,
    this.lastFromMe = false,
    this.lastRead = false,
    this.lastAt,
    this.unread = 0,
    this.pinned = false,
    this.muted = false,
    this.archived = false,
    this.memberCount = 0,
    this.peerId,
    this.canPost = true,
  });

  final String id;
  final ChatKind kind;
  final String title;
  final String? handle;
  final String? avatarUrl;
  final String? avatarEmoji;
  final bool verified;
  final String? lastMessage;
  final String? lastSenderName;
  final bool lastFromMe;
  final bool lastRead;
  final DateTime? lastAt;
  final int unread;
  final bool pinned;
  final bool muted;
  final bool archived;
  final int memberCount;
  final String? peerId;

  /// Можно ли мне писать сюда (в каналах — только администраторам).
  final bool canPost;

  factory ChatSummary.fromMap(Map<String, dynamic> m) => ChatSummary(
        id: m['id'] as String,
        kind: ChatKindLabel.parse(m['kind'] as String?),
        title: (m['title'] as String?) ?? 'Без названия',
        handle: m['handle'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        avatarEmoji: m['avatar_emoji'] as String?,
        verified: (m['verified'] as bool?) ?? false,
        lastMessage: m['last_message'] as String?,
        lastSenderName: m['last_sender_name'] as String?,
        lastFromMe: (m['last_from_me'] as bool?) ?? false,
        lastRead: (m['last_read'] as bool?) ?? false,
        lastAt: m['last_at'] == null
            ? null
            : DateTime.parse(m['last_at'] as String).toLocal(),
        unread: (m['unread'] as num?)?.toInt() ?? 0,
        pinned: (m['pinned'] as bool?) ?? false,
        muted: (m['muted'] as bool?) ?? false,
        archived: (m['archived'] as bool?) ?? false,
        memberCount: (m['member_count'] as num?)?.toInt() ?? 0,
        peerId: m['peer_id'] as String?,
        canPost: (m['can_post'] as bool?) ?? true,
      );

  ChatSummary copyWith({
    String? lastMessage,
    String? lastSenderName,
    bool? lastFromMe,
    bool? lastRead,
    DateTime? lastAt,
    int? unread,
    bool? pinned,
    bool? muted,
    bool? archived,
    int? memberCount,
  }) =>
      ChatSummary(
        id: id,
        kind: kind,
        title: title,
        handle: handle,
        avatarUrl: avatarUrl,
        avatarEmoji: avatarEmoji,
        verified: verified,
        lastMessage: lastMessage ?? this.lastMessage,
        lastSenderName: lastSenderName ?? this.lastSenderName,
        lastFromMe: lastFromMe ?? this.lastFromMe,
        lastRead: lastRead ?? this.lastRead,
        lastAt: lastAt ?? this.lastAt,
        unread: unread ?? this.unread,
        pinned: pinned ?? this.pinned,
        muted: muted ?? this.muted,
        archived: archived ?? this.archived,
        memberCount: memberCount ?? this.memberCount,
        peerId: peerId,
        canPost: canPost,
      );
}

class Message {
  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.senderName,
    this.read = false,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final String? senderName;
  final bool read;

  factory Message.fromMap(Map<String, dynamic> m) => Message(
        id: m['id'].toString(),
        chatId: m['chat_id'] as String,
        senderId: m['sender_id'] as String,
        text: (m['body'] as String?) ?? '',
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        senderName: m['sender_name'] as String?,
      );
}

/// Детали чата для страницы профиля группы/канала/собеседника.
class ChatDetails {
  const ChatDetails({required this.chat, required this.members, this.about = ''});
  final ChatSummary chat;
  final List<Profile> members;
  final String about;
}

/// Цвет аватарки по строке — как в референсе (оранжевые, фиолетовые, синие кружки).
Color avatarColorFor(String seed) {
  const palette = [
    Color(0xFFFF9F1C),
    Color(0xFF8B5CF6),
    Color(0xFF3B9CFF),
    Color(0xFFFF6B6B),
    Color(0xFF22C55E),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
  ];
  var h = 0;
  for (final c in seed.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return palette[h % palette.length];
}

/// Счётчики для админки.
class AdminStats {
  const AdminStats({
    required this.users,
    required this.banned,
    required this.groups,
    required this.channels,
    required this.directs,
    required this.reports,
  });
  final int users, banned, groups, channels, directs, reports;
}

/// Группа или канал в админке.
class AdminChat {
  const AdminChat({
    required this.id,
    required this.title,
    required this.channel,
    required this.members,
    required this.verified,
    required this.createdBy,
  });
  final String id, title, createdBy;
  final bool channel, verified;
  final int members;
}

/// Жалоба пользователя на сообщение.
class Report {
  const Report({
    required this.id,
    required this.reporterId,
    required this.chatId,
    this.messageId,
    this.targetId,
    required this.text,
    this.createdAt,
  });
  final String id, reporterId, chatId, text;
  final String? messageId, targetId;
  final DateTime? createdAt;
}
