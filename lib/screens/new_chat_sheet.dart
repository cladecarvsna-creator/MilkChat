import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/chat_repository.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

/// Лист создания группы или канала: название + участники из контактов.
Future<void> showNewChatSheet(BuildContext context, {bool channel = false}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => _NewChatSheet(channel: channel),
    );

class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet({required this.channel});
  final bool channel;

  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  late bool _channel = widget.channel;
  final _title = TextEditingController();
  final Set<String> _picked = {};
  late final Future<List<Profile>> _contacts = context.read<ChatRepository>().contacts();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _busy = true);
    try {
      final id = await context.read<ChatRepository>().createGroup(
            title: title,
            memberIds: _picked.toList(),
            channel: _channel,
          );
      if (!mounted) return;
      HomeShell.openChat(context, id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(_channel ? 'Новый канал' : 'Новая группа',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: p.text)),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Группа'), icon: Icon(Icons.group)),
                ButtonSegment(value: true, label: Text('Канал'), icon: Icon(Icons.campaign)),
              ],
              selected: {_channel},
              onSelectionChanged: (s) => setState(() => _channel = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _channel ? 'Название канала' : 'Название группы',
              ),
            ),
            const SizedBox(height: 20),
            Text(_channel ? 'Подписчики' : 'Участники',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: p.title)),
            const SizedBox(height: 10),
            FutureBuilder<List<Profile>>(
              future: _contacts,
              builder: (context, snap) {
                final people = snap.data ?? const <Profile>[];
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (people.isEmpty) {
                  return Text('Контактов пока нет — участников можно будет добавить позже.',
                      style: TextStyle(color: p.muted));
                }
                return Column(
                  children: [
                    for (var i = 0; i < people.length; i++)
                      TileCard(
                        first: i == 0,
                        last: i == people.length - 1,
                        selected: _picked.contains(people[i].id),
                        onTap: () => setState(() => _picked.contains(people[i].id)
                            ? _picked.remove(people[i].id)
                            : _picked.add(people[i].id)),
                        child: Row(
                          children: [
                            Avatar.profile(people[i], size: 44),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(people[i].displayName,
                                  style: TextStyle(color: p.title, fontWeight: FontWeight.w700)),
                            ),
                            Icon(
                              _picked.contains(people[i].id)
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked,
                              color: p.accent,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy || _title.text.trim().isEmpty ? null : _create,
              child: Text(_channel ? 'Создать канал' : 'Создать группу'),
            ),
          ],
        ),
      ),
    );
  }
}
