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
class ChatInfoScreen extends StatefulWidget {
  const ChatInfoScreen({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  late Future<ChatDetails> _details = context.read<ChatRepository>().chatDetails(widget.chatId);

  void _reload() => setState(() {
        _details = context.read<ChatRepository>().chatDetails(widget.chatId);
      });

  /// Выполняет действие, показывает ошибку и перечитывает чат.
  Future<void> _run(Future<void> Function() action, [String? done]) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (done != null) messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) _reload();
  }

  Future<void> _editHandle(ChatDetails d) async {
    final repo = context.read<ChatRepository>();
    final c = TextEditingController(text: d.chat.handle?.replaceFirst('@', '') ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Юз канала'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: c,
              autofocus: true,
              decoration: const InputDecoration(prefixText: '@', hintText: 'milk_news'),
            ),
            const SizedBox(height: 10),
            const Text(
              'По юзу канал можно найти в поиске и подписаться. '
              'Пустое поле — канал станет закрытым.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (value == null) return;
    await _run(() => repo.setChatHandle(d.chat.id, value.isEmpty ? null : value),
        value.isEmpty ? 'Канал теперь закрытый' : 'Юз сохранён: @$value');
  }

  /// Действия админа с участником: написать, админ, удалить.
  Future<void> _memberActions(ChatDetails d, Profile m) async {
    final repo = context.read<ChatRepository>();
    final me = repo.me?.id;
    final channel = d.chat.kind == ChatKind.channel;
    final amAdmin = d.isAdmin(me);
    final isAdmin = d.admins.contains(m.id);
    // Создателя снимает только он сам.
    final protectedCreator = m.id == d.createdBy && me != d.createdBy;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline_rounded),
            title: const Text('Написать'),
            onTap: () => Navigator.pop(ctx, 'dm'),
          ),
          if (amAdmin && !protectedCreator)
            ListTile(
              leading: Icon(isAdmin ? Icons.remove_moderator_outlined : Icons.add_moderator_outlined),
              title: Text(isAdmin ? 'Снять администратора' : 'Сделать администратором'),
              onTap: () => Navigator.pop(ctx, 'admin'),
            ),
          if (amAdmin && !protectedCreator)
            ListTile(
              leading: const Icon(Icons.person_remove_outlined, color: Color(0xFFFF6B6B)),
              title: Text(channel ? 'Удалить из канала' : 'Удалить из группы',
                  style: const TextStyle(color: Color(0xFFFF6B6B))),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
        ]),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'dm':
        final id = await repo.openDirectChat(m.id);
        if (mounted) HomeShell.openChat(context, id);
      case 'admin':
        await _run(() => repo.setAdmin(d.chat.id, m.id, !isAdmin),
            isAdmin ? '${m.displayName} больше не администратор' : '${m.displayName} теперь администратор');
      case 'remove':
        await _run(() => repo.removeMember(d.chat.id, m.id), '${m.displayName} удалён');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final repo = context.read<ChatRepository>();
    return Scaffold(
      body: FutureBuilder<ChatDetails>(
        future: _details,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Ошибка: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;
          final c = d.chat;
          final peer = c.kind == ChatKind.direct
              ? d.members.where((m) => m.id == c.peerId).firstOrNull
              : null;
          final isGroup = c.kind == ChatKind.group || c.kind == ChatKind.channel;
          final amAdmin = d.isAdmin(repo.me?.id);
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
                        if (!d.isMember)
                          _Action(
                            icon: Icons.add_rounded,
                            label: 'Подписаться',
                            onTap: () => _run(() => repo.joinChannel(c.id), 'Вы подписались'),
                          ),
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
                      _InfoTile(
                          icon: Icons.info_outline,
                          title: 'Тип',
                          value: c.kind == ChatKind.channel
                              ? (c.handle == null ? 'Закрытый канал' : 'Публичный канал')
                              : c.kind.label),
                      if (c.kind == ChatKind.channel && (amAdmin || c.handle != null))
                        _InfoTile(
                          icon: Icons.alternate_email,
                          title: 'Юз канала',
                          value: c.handle ?? 'Не задан — нажмите, чтобы канал можно было найти',
                          trailing: amAdmin ? Icons.edit_outlined : null,
                          onTap: amAdmin ? () => _editHandle(d) : null,
                        ),
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
                              : () => _memberActions(d, d.members[i]),
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
                              if (d.admins.contains(d.members[i].id))
                                Text(
                                  d.members[i].id == d.createdBy ? 'владелец' : 'админ',
                                  style: TextStyle(color: p.accent, fontWeight: FontWeight.w700),
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
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final IconData? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TileCard(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      onTap: onTap ?? (trailing == null ? null : () {}),
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
