import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/chat_repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'new_chat_sheet.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key, this.selectedChatId, this.onSelectionModeChanged});

  final String? selectedChatId;
  final ValueChanged<bool>? onSelectionModeChanged;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late final Stream<List<ChatSummary>> _chats;
  final _search = TextEditingController();
  final Set<String> _selected = {};
  bool _showArchive = false;
  List<Profile> _people = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _chats = context.read<ChatRepository>().watchChats();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    setState(() {});
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _people = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final res = await context.read<ChatRepository>().searchUsers(q.trim());
      if (mounted && _search.text.trim() == q.trim()) setState(() => _people = res);
    });
  }

  void _toggle(String id) {
    final before = _selected.isNotEmpty;
    setState(() => _selected.contains(id) ? _selected.remove(id) : _selected.add(id));
    if (before != _selected.isNotEmpty) {
      widget.onSelectionModeChanged?.call(_selected.isNotEmpty);
    }
  }

  void _clearSelection() {
    setState(_selected.clear);
    widget.onSelectionModeChanged?.call(false);
  }

  List<ChatSummary> _visible(List<ChatSummary> all) {
    final q = _search.text.trim().toLowerCase();
    final list = all.where((c) {
      if (q.isNotEmpty) {
        return c.title.toLowerCase().contains(q) ||
            (c.lastMessage ?? '').toLowerCase().contains(q);
      }
      return c.archived == _showArchive;
    }).toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return (b.lastAt ?? DateTime(0)).compareTo(a.lastAt ?? DateTime(0));
      });
    return list;
  }

  Future<void> _bulk(Future<void> Function(ChatRepository, Set<String>) action,
      [String? done]) async {
    final ids = Set<String>.of(_selected);
    _clearSelection();
    await action(context.read<ChatRepository>(), ids);
    if (done != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final repo = context.watch<ChatRepository>();
    final selecting = _selected.isNotEmpty;

    return StreamBuilder<List<ChatSummary>>(
      stream: _chats,
      builder: (context, snap) {
        final all = snap.data ?? const <ChatSummary>[];
        final chats = _visible(all);
        final archivedCount = all.where((c) => c.archived).length;
        final byId = {for (final c in all) c.id: c};
        final selectedChats = _selected.map((id) => byId[id]).whereType<ChatSummary>();
        final allPinned = selectedChats.isNotEmpty && selectedChats.every((c) => c.pinned);
        final allMuted = selectedChats.isNotEmpty && selectedChats.every((c) => c.muted);

        return PopScope(
          canPop: !selecting && !_showArchive,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (selecting) {
              _clearSelection();
            } else {
              setState(() => _showArchive = false);
            }
          },
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverSafeArea(
                    bottom: false,
                    sliver: SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      sliver: SliverToBoxAdapter(
                        child: SizedBox(
                          height: 60,
                          child: selecting
                              ? _selectionHeader(chats)
                              : _header(repo),
                        ),
                      ),
                    ),
                  ),
                  if (snap.hasError)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Ошибка загрузки: ${snap.error}',
                            style: TextStyle(color: p.muted)),
                      ),
                    ),
                  if (!snap.hasData && !snap.hasError)
                    const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator())),
                  if (_showArchive || (archivedCount > 0 && _search.text.isEmpty))
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: TileCard(
                          onTap: () => setState(() => _showArchive = !_showArchive),
                          child: Row(
                            children: [
                              Icon(_showArchive ? Icons.arrow_back : Icons.archive_outlined,
                                  color: p.title),
                              const SizedBox(width: 16),
                              Text(
                                _showArchive ? 'Назад к чатам' : 'Архив',
                                style: TextStyle(
                                    color: p.title, fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const Spacer(),
                              if (!_showArchive)
                                Text('$archivedCount', style: TextStyle(color: p.muted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                    sliver: SliverList.builder(
                      itemCount: chats.length + (_people.isEmpty ? 0 : _people.length + 1),
                      itemBuilder: (context, i) {
                        if (i < chats.length) {
                          final c = chats[i];
                          return _ChatTile(
                            chat: c,
                            first: i == 0,
                            last: i == chats.length - 1,
                            selected: _selected.contains(c.id),
                            highlighted: widget.selectedChatId == c.id,
                            onTap: () => selecting
                                ? _toggle(c.id)
                                : HomeShell.openChat(context, c.id),
                            onLongPress: () => _toggle(c.id),
                          );
                        }
                        if (i == chats.length) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                            child: Text('Люди',
                                style: TextStyle(
                                    color: p.title, fontWeight: FontWeight.w800, fontSize: 18)),
                          );
                        }
                        final u = _people[i - chats.length - 1];
                        return TileCard(
                          onTap: () async {
                            final id = await repo.openDirectChat(u.id);
                            if (!context.mounted) return;
                            _search.clear();
                            _onSearch('');
                            HomeShell.openChat(context, id);
                          },
                          child: Row(
                            children: [
                              Avatar.profile(u, size: 48),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u.displayName,
                                        style: TextStyle(
                                            color: p.title, fontWeight: FontWeight.w700)),
                                    Text('@${u.username}', style: TextStyle(color: p.muted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (snap.hasData && chats.isEmpty && _people.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _search.text.isEmpty
                              ? 'Пока нет чатов. Нажмите «+», чтобы начать переписку.'
                              : 'Ничего не найдено',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.muted),
                        ),
                      ),
                    ),
                ],
              ),
              if (selecting)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: SafeArea(
                    top: false,
                    child: _SelectionBar(
                      pinned: allPinned,
                      muted: allMuted,
                      archived: _showArchive,
                      onPin: () => _bulk((r, ids) => r.setPinned(ids, !allPinned)),
                      onRead: () => _bulk((r, ids) => r.markRead(ids)),
                      onMute: () => _bulk((r, ids) => r.setMuted(ids, !allMuted)),
                      onArchive: () => _bulk((r, ids) => r.setArchived(ids, !_showArchive),
                          _showArchive ? 'Возвращено из архива' : 'Перенесено в архив'),
                      onDelete: () => _confirmDelete(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete() async {
    final p = context.palette;
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить ${plural(n, 'чат', 'чата', 'чатов')}?'),
        content: const Text('Вы выйдете из выбранных чатов, и они пропадут из списка.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Отмена', style: TextStyle(color: p.title))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить', style: TextStyle(color: Color(0xFFFF6B6B)))),
        ],
      ),
    );
    if (ok == true) await _bulk((r, ids) => r.leaveChats(ids), 'Удалено');
  }

  Widget _header(ChatRepository repo) {
    final me = repo.me!;
    return Row(
      children: [
        RoundButton(
          icon: Icons.add_rounded,
          tooltip: 'Новый чат',
          onPressed: () => showNewChatSheet(context),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SearchPill(
            hint: 'Найти в MilkChat',
            controller: _search,
            onChanged: _onSearch,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => HomeShell.showTab(context, 2),
          child: Avatar.profile(me, size: 54),
        ),
      ],
    );
  }

  Widget _selectionHeader(List<ChatSummary> visible) {
    final p = context.palette;
    return Row(
      children: [
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${_selected.length} выбрано',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.text),
          ),
        ),
        RoundButton(
          icon: Icons.done_all_rounded,
          tooltip: 'Выбрать все',
          onPressed: () => setState(() => _selected.addAll(visible.map((c) => c.id))),
        ),
        const SizedBox(width: 10),
        RoundButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Отмена',
          onPressed: _clearSelection,
        ),
      ],
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.chat,
    required this.first,
    required this.last,
    required this.selected,
    required this.highlighted,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatSummary chat;
  final bool first;
  final bool last;
  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = chat;
    final preview = c.lastMessage == null
        ? ''
        : c.lastFromMe
            ? 'Вы: ${c.lastMessage}'
            : (c.kind == ChatKind.group && c.lastSenderName != null)
                ? '${c.lastSenderName}: ${c.lastMessage}'
                : c.lastMessage!;

    return TileCard(
      first: first,
      last: last,
      selected: selected || highlighted,
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              c.kind == ChatKind.saved
                  ? Container(
                      width: 62,
                      height: 62,
                      decoration:
                          const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle),
                      child: const Icon(Icons.bookmark_rounded, color: Colors.white, size: 30),
                    )
                  : Avatar.chat(c, size: 62),
              if (selected)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.surfaceHigh, width: 2.5),
                    ),
                    child: Icon(Icons.check_rounded, size: 16, color: p.onAccent),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (c.kind == ChatKind.channel)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.campaign_rounded, size: 18, color: p.title),
                      ),
                    Flexible(
                      child: Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: p.title, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ),
                    if (c.verified) ...[
                      const SizedBox(width: 6),
                      const VerifiedBadge(),
                    ],
                    if (c.muted) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.volume_off_rounded, size: 16, color: p.muted),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.title.withValues(alpha: 0.85), fontSize: 15),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Chip(child: Text(chatTime(c.lastAt), style: TextStyle(color: p.muted, fontSize: 13))),
              const SizedBox(height: 8),
              if (c.unread > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 26),
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.muted ? p.muted : p.accent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text('${c.unread}',
                      style: TextStyle(
                          color: p.onAccent, fontWeight: FontWeight.w800, fontSize: 13)),
                )
              else if (c.pinned)
                _Chip(child: Icon(Icons.push_pin_rounded, size: 16, color: p.muted))
              else if (c.lastFromMe)
                _Chip(
                  child: Icon(
                    c.lastRead ? Icons.done_all_rounded : Icons.check_rounded,
                    size: 17,
                    color: p.accent,
                  ),
                )
              else
                const SizedBox(height: 26),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.palette.background.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(13),
        ),
        child: child,
      );
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.pinned,
    required this.muted,
    required this.archived,
    required this.onPin,
    required this.onRead,
    required this.onMute,
    required this.onArchive,
    required this.onDelete,
  });

  final bool pinned;
  final bool muted;
  final bool archived;
  final VoidCallback onPin;
  final VoidCallback onRead;
  final VoidCallback onMute;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget item(IconData icon, String label, VoidCallback onTap, [Color? color]) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color ?? p.text),
                  const SizedBox(height: 6),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color ?? p.text, fontSize: 12.5)),
                ],
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 18)],
      ),
      child: Row(
        children: [
          item(pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
              pinned ? 'Открепить' : 'Закрепить', onPin),
          item(Icons.done_all_rounded, 'Прочитать', onRead),
          item(muted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
              muted ? 'Со звуком' : 'Без звука', onMute),
          item(archived ? Icons.unarchive_outlined : Icons.archive_outlined,
              archived ? 'Вернуть' : 'В архив', onArchive),
          item(Icons.delete_outline_rounded, 'Удалить', onDelete, const Color(0xFFFF6B6B)),
        ],
      ),
    );
  }
}
