import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'chat_screen.dart';
import 'chats_screen.dart';
import 'contacts_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

/// Ширина, с которой приложение показывает список и чат рядом (десктоп, веб).
const kWideLayout = 900.0;

/// Главный экран: вкладки Чаты / Контакты / Профиль / Настройки с плавающей
/// панелью снизу. На широком экране справа открывается выбранный чат.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Открывает чат: справа на широком экране или новым экраном на телефоне.
  /// Работает и с экранов, открытых поверх главного (например, профиль группы).
  static void openChat(BuildContext context, String chatId) {
    final shell = _current;
    if (shell == null || !shell.mounted) return;
    final wide = MediaQuery.sizeOf(shell.context).width >= kWideLayout;
    final nav = Navigator.of(shell.context);
    nav.popUntil((r) => r.isFirst);
    if (wide) {
      shell._select(chatId);
    } else {
      nav.push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: chatId)));
    }
  }

  static void showTab(BuildContext context, int index) => _current?._setTab(index);

  static _HomeShellState? _current;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  String? _openChat;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    HomeShell._current = this;
  }

  @override
  void dispose() {
    if (HomeShell._current == this) HomeShell._current = null;
    super.dispose();
  }

  void _select(String id) => setState(() {
        _openChat = id;
        _tab = 0;
      });

  void _setTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final wide = MediaQuery.sizeOf(context).width >= kWideLayout;

    final tabs = Stack(
      children: [
        IndexedStack(
          index: _tab,
          children: [
            ChatsScreen(
              selectedChatId: wide ? _openChat : null,
              onSelectionModeChanged: (v) => setState(() => _selecting = v),
            ),
            const ContactsScreen(),
            const ProfileScreen(),
            const SettingsScreen(),
          ],
        ),
        if (!(_selecting && _tab == 0))
          Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: _NavPill(index: _tab, onChanged: _setTab),
          ),
        ),
      ],
    );

    if (!wide) return Scaffold(body: tabs);

    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 400, child: tabs),
          Expanded(
            child: _openChat == null
                ? ChatBackground(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: p.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Выберите чат, чтобы начать общение',
                            style: TextStyle(color: p.text)),
                      ),
                    ),
                  )
                : ChatScreen(
                    key: ValueKey(_openChat),
                    chatId: _openChat!,
                    embedded: true,
                    onClose: () => setState(() => _openChat = null),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.chat_bubble_rounded, 'Чаты'),
    (Icons.people_alt_rounded, 'Контакты'),
    (Icons.person_rounded, 'Профиль'),
    (Icons.settings_rounded, 'Настройки'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 72,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: p.nav,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 18),
        ],
      ),
      child: Row(
        // Индикатор выбора — на всю высоту панели.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: Tooltip(
                message: _items[i].$2,
                child: GestureDetector(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: i == index ? p.surfaceHigh : Colors.transparent,
                      borderRadius: BorderRadius.circular(34),
                    ),
                    child: Icon(
                      _items[i].$1,
                      size: 28,
                      color: i == index ? p.text : p.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
