import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/chat_repository.dart';
import '../data/firebase_repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';

/// Админка MilkChat. Видна только модераторам (claim `staff`); каждое действие
/// дополнительно проверяют правила Firestore.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Админка'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Обзор'),
              Tab(text: 'Пользователи'),
              Tab(text: 'Группы и каналы'),
              Tab(text: 'Жалобы'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          _Overview(),
          _Users(),
          _Chats(),
          _Reports(),
        ]),
      ),
    );
  }
}

FirebaseRepository _repo(BuildContext context) =>
    context.read<ChatRepository>() as FirebaseRepository;

Future<void> _run(BuildContext context, Future<void> Function() f, [String? done]) async {
  final m = ScaffoldMessenger.of(context);
  try {
    await f();
    if (done != null) m.showSnackBar(SnackBar(content: Text(done)));
  } on AuthFailure catch (e) {
    m.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

Future<bool> _confirm(BuildContext context, String title, String action) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action, style: const TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    ) ??
    false;

/// Загружает данные и даёт обновить их потягиванием вниз.
class _Loader<T> extends StatefulWidget {
  const _Loader({required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) builder;

  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  late Future<T> _f = widget.load();

  void _reload() => setState(() => _f = widget.load());

  @override
  void didUpdateWidget(covariant _Loader<T> old) {
    super.didUpdateWidget(old);
    if (old.load != widget.load) _reload();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _f,
        builder: (context, s) {
          if (s.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$s.error', textAlign: TextAlign.center),
                  TextButton(onPressed: _reload, child: const Text('Повторить')),
                ]),
              ),
            );
          }
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: widget.builder(context, s.data as T, _reload),
          );
        },
      );
}

// ─── Обзор ───────────────────────────────────────────────────────────────────

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _Loader<AdminStats>(
      load: _repo(context).adminStats,
      builder: (context, s, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            _stat(p, 'Пользователи', s.users, Icons.people_outline),
            _stat(p, 'Заблокированы', s.banned, Icons.block),
            _stat(p, 'Группы', s.groups, Icons.groups_outlined),
            _stat(p, 'Каналы', s.channels, Icons.campaign_outlined),
            _stat(p, 'Личные чаты', s.directs, Icons.chat_bubble_outline),
            _stat(p, 'Жалобы', s.reports, Icons.flag_outlined),
          ]),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('Написать в канал MilkChat'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ChatScreen(chatId: officialChannelId))),
          ),
        ],
      ),
    );
  }

  Widget _stat(MilkPalette p, String label, int value, IconData icon) => Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: p.accent),
          const SizedBox(height: 8),
          Text('$value',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: p.text)),
          Text(label, style: TextStyle(color: p.muted)),
        ]),
      );
}

// ─── Пользователи ────────────────────────────────────────────────────────────

class _Users extends StatefulWidget {
  const _Users();

  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> {
  String _q = '';
  late Future<List<Profile>> Function() _load = _make();

  Future<List<Profile>> Function() _make() {
    final q = _q;
    final repo = _repo(context);
    return () => repo.adminUsers(q);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final me = context.read<ChatRepository>().me?.id;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: SearchPill(
          hint: 'Юзернейм',
          onChanged: (v) => setState(() {
            _q = v;
            _load = _make();
          }),
        ),
      ),
      Expanded(
        child: _Loader<List<Profile>>(
          load: _load,
          builder: (context, users, reload) => ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, i) {
              final u = users[i];
              return ListTile(
                leading: Avatar.profile(u, size: 44),
                title: Row(children: [
                  Flexible(
                    child: Text(u.displayName.isEmpty ? u.username : u.displayName,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (u.verified) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.verified, size: 16, color: p.accent),
                  ],
                ]),
                subtitle: Text(
                  '@${u.username}${u.banned ? ' · заблокирован' : ''}',
                  style: TextStyle(color: u.banned ? const Color(0xFFFF6B6B) : p.muted),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (a) async {
                    final repo = _repo(context);
                    switch (a) {
                      case 'verify':
                        await _run(context, () => repo.adminSetVerified(u.id, !u.verified),
                            u.verified ? 'Галочка снята' : 'Галочка выдана');
                      case 'ban':
                        if (!u.banned &&
                            !await _confirm(context, 'Заблокировать @${u.username}?',
                                'Заблокировать')) {
                          return;
                        }
                        if (!context.mounted) return;
                        await _run(context, () => repo.adminSetBanned(u.id, !u.banned),
                            u.banned ? 'Разблокирован' : 'Заблокирован');
                      case 'chat':
                        final id = await repo.openDirectChat(u.id);
                        if (context.mounted) {
                          Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => ChatScreen(chatId: id)));
                        }
                        return;
                    }
                    reload();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'verify',
                        child: Text(u.verified ? 'Снять галочку' : 'Выдать галочку')),
                    if (u.id != me)
                      PopupMenuItem(
                          value: 'ban',
                          child: Text(u.banned ? 'Разблокировать' : 'Заблокировать')),
                    if (u.id != me)
                      const PopupMenuItem(value: 'chat', child: Text('Написать')),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }
}

// ─── Группы и каналы ─────────────────────────────────────────────────────────

class _Chats extends StatelessWidget {
  const _Chats();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _Loader<List<AdminChat>>(
      load: _repo(context).adminChats,
      builder: (context, chats, reload) => chats.isEmpty
          ? ListView(children: const [
              Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Групп и каналов пока нет')),
              )
            ])
          : ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, i) {
                final c = chats[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: p.surface,
                    child: Icon(c.channel ? Icons.campaign_outlined : Icons.groups_outlined,
                        color: p.accent),
                  ),
                  title: Row(children: [
                    Flexible(child: Text(c.title, overflow: TextOverflow.ellipsis)),
                    if (c.verified) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.verified, size: 16, color: p.accent),
                    ],
                  ]),
                  subtitle: Text(
                      '${c.channel ? 'Канал' : 'Группа'} · участников: ${c.members}',
                      style: TextStyle(color: p.muted)),
                  trailing: PopupMenuButton<String>(
                    onSelected: (a) async {
                      final repo = _repo(context);
                      switch (a) {
                        case 'verify':
                          await _run(context, () => repo.adminSetChatVerified(c.id, !c.verified));
                        case 'rename':
                          final ctl = TextEditingController(text: c.title);
                          final t = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Новое название'),
                              content: TextField(controller: ctl, autofocus: true),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Отмена')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
                                    child: const Text('Сохранить')),
                              ],
                            ),
                          );
                          if (t == null || t.isEmpty || !context.mounted) return;
                          await _run(context, () => repo.adminRenameChat(c.id, t));
                        case 'delete':
                          if (c.id == officialChannelId) return;
                          if (!await _confirm(
                              context, 'Удалить «${c.title}» со всеми сообщениями?', 'Удалить')) {
                            return;
                          }
                          if (!context.mounted) return;
                          await _run(context, () => repo.adminDeleteChat(c.id), 'Удалено');
                      }
                      reload();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'verify',
                          child: Text(c.verified ? 'Снять галочку' : 'Выдать галочку')),
                      const PopupMenuItem(value: 'rename', child: Text('Переименовать')),
                      if (c.id != officialChannelId)
                        const PopupMenuItem(
                            value: 'delete',
                            child: Text('Удалить', style: TextStyle(color: Color(0xFFFF6B6B)))),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ─── Жалобы ──────────────────────────────────────────────────────────────────

class _Reports extends StatelessWidget {
  const _Reports();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _Loader<List<Report>>(
      load: _repo(context).adminReports,
      builder: (context, reports, reload) => reports.isEmpty
          ? ListView(children: const [
              Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Жалоб нет')),
              )
            ])
          : ListView.builder(
              itemCount: reports.length,
              itemBuilder: (context, i) {
                final r = reports[i];
                return Card(
                  color: p.surface,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.text.isEmpty ? '(без текста)' : r.text,
                          style: TextStyle(color: p.text, fontSize: 16)),
                      const SizedBox(height: 6),
                      FutureBuilder(
                        future: _repo(context).profileById(r.targetId ?? ''),
                        builder: (context, s) => Text(
                          'Автор: ${s.data == null ? '—' : '@${s.data!.username}'}',
                          style: TextStyle(color: p.muted),
                        ),
                      ),
                      Wrap(spacing: 4, children: [
                        if (r.messageId != null)
                          TextButton(
                            onPressed: () async {
                              await _run(context,
                                  () => _repo(context).deleteMessage(r.chatId, r.messageId!));
                              if (!context.mounted) return;
                              await _run(context, () => _repo(context).adminCloseReport(r.id),
                                  'Сообщение удалено');
                              reload();
                            },
                            child: const Text('Удалить сообщение',
                                style: TextStyle(color: Color(0xFFFF6B6B))),
                          ),
                        if (r.targetId != null && r.targetId!.isNotEmpty)
                          TextButton(
                            onPressed: () async {
                              if (!await _confirm(
                                  context, 'Заблокировать автора?', 'Заблокировать')) {
                                return;
                              }
                              if (!context.mounted) return;
                              await _run(context,
                                  () => _repo(context).adminSetBanned(r.targetId!, true),
                                  'Автор заблокирован');
                            },
                            child: const Text('Заблокировать автора'),
                          ),
                        TextButton(
                          onPressed: () async {
                            await _run(context, () => _repo(context).adminCloseReport(r.id),
                                'Жалоба закрыта');
                            reload();
                          },
                          child: const Text('Закрыть'),
                        ),
                      ]),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}
