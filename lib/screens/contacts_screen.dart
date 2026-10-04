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

/// Контакты: люди из общих чатов + глобальный поиск по юзернейму.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _search = TextEditingController();
  late Future<List<Profile>> _future;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _future = context.read<ChatRepository>().contacts();
  }

  @override
  void dispose() {
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final repo = context.read<ChatRepository>();
      setState(() {
        _future = q.trim().isEmpty ? repo.contacts() : repo.searchUsers(q.trim());
      });
    });
  }

  Future<void> _open(Profile u) async {
    final id = await context.read<ChatRepository>().openDirectChat(u.id);
    if (mounted) HomeShell.openChat(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: SearchPill(
              hint: 'Найти людей по имени или @нику',
              controller: _search,
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Profile>>(
              future: _future,
              builder: (context, snap) {
                final people = snap.data ?? const <Profile>[];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                  children: [
                    TileCard(
                      first: true,
                      last: false,
                      onTap: () => showNewChatSheet(context),
                      child: _row(p, Icons.group_add_rounded, 'Создать группу', null),
                    ),
                    TileCard(
                      first: false,
                      last: true,
                      onTap: () => showNewChatSheet(context, channel: true),
                      child: _row(p, Icons.campaign_rounded, 'Создать канал', null),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                      child: Text(
                        _search.text.trim().isEmpty ? 'Контакты' : 'Результаты поиска',
                        style: TextStyle(
                            color: p.text, fontWeight: FontWeight.w800, fontSize: 22),
                      ),
                    ),
                    if (snap.connectionState == ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator())
                    else if (people.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _search.text.trim().isEmpty
                              ? 'Здесь появятся люди из ваших чатов. Найдите друзей через поиск.'
                              : 'Никого не нашли',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.muted),
                        ),
                      ),
                    for (var i = 0; i < people.length; i++)
                      TileCard(
                        first: i == 0,
                        last: i == people.length - 1,
                        onTap: () => _open(people[i]),
                        child: Row(
                          children: [
                            Avatar.profile(people[i], size: 52),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Flexible(
                                      child: Text(people[i].displayName,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: p.title,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 17)),
                                    ),
                                    if (people[i].verified) ...[
                                      const SizedBox(width: 6),
                                      const VerifiedBadge(size: 16),
                                    ],
                                  ]),
                                  Text(
                                    '@${people[i].username} · ${lastSeen(people[i].lastSeen)}',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: p.muted, fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(MilkPalette p, IconData icon, String title, String? sub) => Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: p.surfaceHigh, shape: BoxShape.circle),
            child: Icon(icon, color: p.accent),
          ),
          const SizedBox(width: 14),
          Text(title,
              style: TextStyle(color: p.title, fontWeight: FontWeight.w800, fontSize: 17)),
        ],
      );
}
