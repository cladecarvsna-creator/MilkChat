import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Лист «Оформление»: светлая/тёмная тема, акцентный цвет, фон переписки.
Future<void> showThemeSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => const _ThemeSheet(),
    );

class _ThemeSheet extends StatelessWidget {
  const _ThemeSheet();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeController>();
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Оформление',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800, color: p.text)),
                    Text(dark ? 'Сейчас тёмная тема' : 'Сейчас светлая тема',
                        style: TextStyle(color: p.muted)),
                  ],
                ),
              ),
              _ModeToggle(
                dark: dark,
                onChanged: (d) => t.mode = d ? ThemeMode.dark : ThemeMode.light,
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: 250,
              child: ChatBackground(
                icons: t.patternIcons,
                shapes: t.floatingShapes,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PreviewBubble('Привет! Как тебе новый цвет?', '18:51', mine: false),
                      _PreviewBubble('Отличный, оставляем', '18:52', mine: true),
                      _PreviewBubble('Тогда так и живём', '18:53', mine: false),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Цвет',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: p.title)),
          const SizedBox(height: 12),
          Container(
            height: 112,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(20),
              itemCount: accentPresets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 18),
              itemBuilder: (_, i) => _Swatch(
                seed: accentPresets[i],
                dark: dark,
                selected: t.accent.toARGB32() == accentPresets[i].toARGB32(),
                onTap: () => t.accent = accentPresets[i],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Фон переписки',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: p.title)),
          const SizedBox(height: 12),
          _SwitchTile(
            icon: Icons.bubble_chart_outlined,
            title: 'Плавающие фигуры',
            subtitle: 'Мягкие пятна на фоне чата',
            value: t.floatingShapes,
            onChanged: (v) => t.floatingShapes = v,
            first: true,
          ),
          _SwitchTile(
            icon: Icons.interests_outlined,
            title: 'Узор из иконок',
            subtitle: 'Контурные рисунки, как на обоях',
            value: t.patternIcons,
            onChanged: (v) => t.patternIcons = v,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.dark, required this.onChanged});
  final bool dark;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget seg(bool isDark, IconData icon) {
      final on = dark == isDark;
      return GestureDetector(
        onTap: () => onChanged(isDark),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 78,
          height: 52,
          decoration: BoxDecoration(
            color: on ? p.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Icon(icon, color: on ? p.onAccent : p.text),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.nav, borderRadius: BorderRadius.circular(30)),
      child: Row(children: [
        seg(false, Icons.light_mode_outlined),
        seg(true, Icons.dark_mode_rounded),
      ]),
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble(this.text, this.time, {required this.mine});
  final String text;
  final String time;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = mine ? p.onBubbleOut : p.onBubbleIn;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        decoration: BoxDecoration(
          color: mine ? p.bubbleOut : p.bubbleIn,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: Text(text, style: TextStyle(color: fg, fontSize: 17))),
            const SizedBox(width: 8),
            Text(time, style: TextStyle(color: fg.withValues(alpha: 0.65), fontSize: 12)),
            if (mine) ...[
              const SizedBox(width: 4),
              Icon(Icons.done_all_rounded, size: 15, color: fg.withValues(alpha: 0.75)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.seed,
    required this.dark,
    required this.selected,
    required this.onTap,
  });

  final Color seed;
  final bool dark;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sp = MilkPalette.from(seed, dark ? Brightness.dark : Brightness.light);
    final p = context.palette;
    Widget block(Color c) => Container(
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
        );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: sp.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? p.text : p.surfaceHigh, width: selected ? 3 : 1.5),
        ),
        child: Column(
          children: [
            Expanded(child: SizedBox(width: double.infinity, child: block(sp.accent))),
            const SizedBox(height: 4),
            Expanded(
              child: Row(children: [
                Expanded(child: block(sp.surfaceHigh)),
                const SizedBox(width: 4),
                Expanded(child: block(sp.surface)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.first = false,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TileCard(
      first: first,
      last: last,
      onTap: () => onChanged(!value),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(children: [
        Icon(icon, color: p.accent),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w600)),
            Text(subtitle, style: TextStyle(color: p.muted, fontSize: 13)),
          ]),
        ),
        Switch(value: value, onChanged: onChanged),
      ]),
    );
  }
}
