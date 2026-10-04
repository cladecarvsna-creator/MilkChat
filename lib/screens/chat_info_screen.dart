import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../data/chat_repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

/// Профиль чата: группа, канал или собеседник.
class ChatInfoScreen extends StatelessWidget {
  const ChatInfoScreen({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final repo = context.read<ChatRepository>();
    return Scaffold(
      body: FutureBuilder<ChatDetails>(
        future: repo.chatDetails(chatId),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Ошибка: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;
          final c = d.chat;
          final peer = c.kind == ChatKind.direct
              ? d.members.where((m) => m.id == c.peerId).firstOrNull
              : null;
          final isGroup = c.kind == ChatKind.group || c.kind == ChatKind.channel;
          final countLabel = c.kind == ChatKind.channel
              ? plural(d.members.length, 'подписчик', 'подписчика', 'подписчиков')
              : plural(d.members.length, 'участник', 'участника', 'участников');

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Row(
                      children: [
                        RoundButton(
                          icon: Icons.arrow_back_rounded,
                          size: 52,
                          tooltip: 'Назад',
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        RoundButton(
                          icon: c.muted
                              ? Icons.notifications_off_outlined
                              : Icons.notifications_none_rounded,
                          size: 52,
                          tooltip: c.muted ? 'Включить звук' : 'Без звука',
                          onPressed: () async {
                            await repo.setMuted([c.id], !c.muted);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(c.muted ? 'Звук включён' : 'Без звука')));
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: peer != null
                          ? Avatar.profile(peer, size: 140)
                          : Avatar.chat(c, size: 140),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            c.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 30, fontWeight: FontWeight.w800, color: p.text),
                          ),
                        ),
                        if (c.verified) ...[
                          const SizedBox(width: 8),
                          const VerifiedBadge(size: 24),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: p.surfaceHigh,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 8, color: p.muted),
                            const SizedBox(width: 8),
                            Text(
                              peer != null ? lastSeen(peer.lastSeen) : countLabel,
                              style: TextStyle(color: p.text.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Action(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Открыть',
                          onTap: () => HomeShell.openChat(context, c.id),
                        ),
                        _Action(
                          icon: Icons.reply_rounded,
                          flip: true,
                          label: 'Поделиться',
                          onTap: () {
                            final link = c.handle != null
                                ? 'milkchat.app/${c.handle!.replaceFirst('@', '')}'
                                : 'milkchat.app/c/${c.id}';
                            Clipboard.setData(ClipboardData(text: link));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ссылка скопирована: $link')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.only(left: 6, bottom: 12),
                      child: Text('Информация',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800, color: p.text)),
                    ),
                    if (peer != null) ...[
                      _InfoTile(icon: Icons.alternate_email, title: 'Юзернейм', value: '@${peer.username}'),
                      if (peer.bio.isNotEmpty)
                        _InfoTile(icon: Icons.info_outline, title: 'О себе', value: peer.bio),
                    ] else ...[
                      _InfoTile(icon: Icons.info_outline, title: 'Тип', value: c.kind.label),
                      if (d.about.isNotEmpty)
                        _InfoTile(icon: Icons.notes_rounded, title: 'Описание', value: d.about),
                      if (isGroup)
                        _InfoTile(
                          icon: Icons.people_alt_rounded,
                          title: c.kind == ChatKind.channel ? 'Подписчиков' : 'Участников',
                          value: '${d.members.length}',
                        ),
                    ],
                    _InfoTile(
                      icon: Icons.image_outlined,
                      title: 'Медиа, ссылки и документы',
                      value: 'Всё, чем обменивались в переписке',
                      trailing: Icons.arrow_forward_rounded,
                    ),
                    if (isGroup) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 12, 6, 12),
                        child: Text(c.kind == ChatKind.channel ? 'Подписчики' : 'Участники',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800, color: p.text)),
                      ),
                      for (var i = 0; i < d.members.length; i++)
                        TileCard(
                          first: i == 0,
                          last: i == d.members.length - 1,
                          onTap: d.members[i].id == repo.me?.id
                              ? null
                              : () async {
                                  final id = await repo.openDirectChat(d.members[i].id);
                                  if (!context.mounted) return;
                                  HomeShell.openChat(context, id);
                                },
                          child: Row(
                            children: [
                              Avatar.profile(d.members[i], size: 44),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.members[i].id == repo.me?.id
                                          ? '${d.members[i].displayName} (вы)'
                                          : d.members[i].displayName,
                                      style: TextStyle(
                                          color: p.title, fontWeight: FontWeight.w700),
                                    ),
                                    Text('@${d.members[i].username}',
                                        style: TextStyle(color: p.muted, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap, this.flip = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        Material(
          color: p.surfaceHigh,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: 80,
              child: Transform.flip(
                flipX: flip,
                child: Icon(icon, color: p.accent, size: 30),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: p.text.withValues(alpha: 0.8))),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.title, required this.value, this.trailing});

  final IconData icon;
  final String title;
  final String value;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TileCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      onTap: trailing == null ? null : () {},
      child: Row(
        children: [
          Icon(icon, color: p.text.withValues(alpha: 0.75)),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: p.text.withValues(alpha: 0.7))),
              ],
            ),
          ),
          if (trailing != null) Icon(trailing, color: p.text.withValues(alpha: 0.75)),
        ],
      ),
    );
  }
}
