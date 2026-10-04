import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/chat_repository.dart';
import '../data/firebase_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'admin_screen.dart';
import 'home_shell.dart';
import 'theme_sheet.dart';

class _Item {
  const _Item(this.icon, this.color, this.title, this.subtitle, this.onTap);
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final void Function(BuildContext) onTap;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _query = '';

  static void _soon(BuildContext context, String title) => showModalBottomSheet(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800, color: ctx.palette.text)),
              const SizedBox(height: 12),
              Text('Этот раздел появится в одной из следующих версий MilkChat.',
                  textAlign: TextAlign.center, style: TextStyle(color: ctx.palette.muted)),
            ],
          ),
        ),
      );

  static final _groups = <List<_Item>>[
    [
      _Item(Icons.palette_outlined, const Color(0xFF3B82F6), 'Темы',
          'Оформление и цвет переписки', (c) => showThemeSheet(c)),
      _Item(Icons.dashboard_customize_outlined, const Color(0xFF8B5CF6), 'Изменить',
          'Вид карточек, аватарок и панели', (c) => _soon(c, 'Изменить')),
      _Item(Icons.shield_outlined, const Color(0xFF10B981), 'Конфиденциальность',
          'Чёрный список и кто вас видит', (c) => _soon(c, 'Конфиденциальность')),
    ],
    [
      _Item(Icons.devices_outlined, const Color(0xFF06B6D4), 'Устройства',
          'Где выполнен вход в аккаунт', (c) => _devices(c)),
      _Item(Icons.notifications_none_rounded, const Color(0xFFEC4899), 'Уведомления',
          'Сигнал на отправку и на входящее', (c) => _notifications(c)),
    ],
    [
      _Item(Icons.storage_rounded, const Color(0xFFF97316), 'Данные и память',
          'Картинки, сохранённые на устройстве', (c) => _soon(c, 'Данные и память')),
    ],
    [
      _Item(Icons.shopping_bag_outlined, const Color(0xFFF59E0B), 'Магазин',
          'Подарки для переписки', (c) => _soon(c, 'Магазин')),
      _Item(Icons.person_outline_rounded, const Color(0xFF7C3AED), 'Профиль',
          'Аватар, имя, юзернейм, о себе', (c) => HomeShell.showTab(c, 2)),
      _Item(Icons.info_outline_rounded, const Color(0xFF22C55E), 'О MilkChat',
          'Версия и сведения о приложении', (c) => _about(c)),
    ],
  ];

  static void _about(BuildContext context) => showAboutDialog(
        context: context,
        applicationName: 'MilkChat',
        applicationVersion: '1.0.0',
        applicationIcon: const MilkLogo(size: 56),
        applicationLegalese: 'Мессенджер для своих 🥛',
      );

  static void _devices(BuildContext context) {
    final p = context.palette;
    final platform = kIsWeb
        ? 'Веб-браузер'
        : switch (defaultTargetPlatform) {
            TargetPlatform.android => 'Android',
            TargetPlatform.windows => 'Windows',
            TargetPlatform.macOS => 'macOS',
            TargetPlatform.linux => 'Linux',
            TargetPlatform.iOS => 'iOS',
            _ => 'Устройство',
          };
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text('Устройства',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: p.text)),
            ),
            TileCard(
              child: Row(children: [
                Icon(Icons.devices_rounded, color: p.accent),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('MilkChat · $platform',
                      style: TextStyle(color: p.title, fontWeight: FontWeight.w700)),
                  Text('Это устройство, в сети', style: TextStyle(color: p.muted)),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _notifications(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        final p = ctx.palette;
        Widget sw(String key, String title, String sub) => TileCard(
              first: key == 'notify_incoming',
              last: key == 'notify_sent',
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: TextStyle(color: p.title, fontWeight: FontWeight.w700)),
                    Text(sub, style: TextStyle(color: p.muted, fontSize: 13)),
                  ]),
                ),
                Switch(
                  value: prefs.getBool(key) ?? true,
                  onChanged: (v) => setState(() => prefs.setBool(key, v)),
                ),
              ]),
            );
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 12),
                child: Text('Уведомления',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: p.text)),
              ),
              sw('notify_incoming', 'Входящие сообщения', 'Звук при новом сообщении'),
              sw('notify_sent', 'Отправка', 'Звук при отправке сообщения'),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final repo = context.watch<ChatRepository>();
    final me = repo.me!;
    final q = _query.toLowerCase();
    final groups = [
      if (repo is FirebaseRepository && repo.isStaff)
        [
          _Item(Icons.admin_panel_settings_outlined, const Color(0xFFF59E0B), 'Админка',
              'Пользователи, каналы, жалобы', (c) {
            Navigator.of(c).push(MaterialPageRoute(builder: (_) => const AdminScreen()));
          }),
        ],
      for (final g in _groups)
        [
          for (final i in g)
            if (q.isEmpty ||
                i.title.toLowerCase().contains(q) ||
                i.subtitle.toLowerCase().contains(q))
              i
        ]
    ].where((g) => g.isNotEmpty).toList();

    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            children: [
              SearchPill(
                hint: 'Найти настройки',
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
              const SizedBox(height: 16),
              if (q.isEmpty)
                TileCard(
                  onTap: () => HomeShell.showTab(context, 2),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  child: Row(children: [
                    Avatar.profile(me, size: 56),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(me.displayName.isEmpty ? me.username : me.displayName,
                            style: TextStyle(
                                color: p.text, fontSize: 19, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('@${me.username}', style: TextStyle(color: p.muted)),
                      ]),
                    ),
                  ]),
                ),
              for (final g in groups)
                for (var i = 0; i < g.length; i++)
                  TileCard(
                    first: i == 0,
                    last: i == g.length - 1,
                    onTap: () => g[i].onTap(context),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                    child: Row(children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: g[i].color, shape: BoxShape.circle),
                        child: Icon(g[i].icon, color: Colors.black.withValues(alpha: 0.55)),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(g[i].title,
                              style: TextStyle(
                                  color: p.title, fontSize: 19, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(g[i].subtitle,
                              style: TextStyle(color: p.title.withValues(alpha: 0.75))),
                        ]),
                      ),
                    ]),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
