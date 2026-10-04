import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Круглая аватарка: фото, эмодзи или первая буква на цветном фоне.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.name,
    this.url,
    this.emoji,
    this.bytes,
    this.size = 56,
  });

  Avatar.profile(Profile p, {super.key, this.size = 56})
      : name = p.displayName.isEmpty ? p.username : p.displayName,
        url = p.avatarUrl,
        emoji = null,
        bytes = p.avatarBytes;

  Avatar.chat(ChatSummary c, {super.key, this.size = 56})
      : name = c.title,
        url = c.avatarUrl,
        emoji = c.kind == ChatKind.saved ? null : c.avatarEmoji,
        bytes = null;

  final String name;
  final String? url;
  final String? emoji;
  final dynamic bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? image = bytes != null
        ? MemoryImage(bytes)
        : (url != null && url!.isNotEmpty ? NetworkImage(url!) : null);
    if (image != null) {
      return CircleAvatar(radius: size / 2, backgroundImage: image);
    }
    if (emoji != null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        child: Text(emoji!, style: TextStyle(fontSize: size * 0.55)),
      );
    }
    final letter = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: avatarColorFor(name), shape: BoxShape.circle),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Синяя галочка подтверждённого аккаунта.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.verified, size: size, color: const Color(0xFF3B9CFF));
}

/// Круглая кнопка-«таблетка», как стрелка «назад» и «⋮» в референсе.
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 56,
    this.tooltip,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: filled ? p.accent : p.surfaceHigh,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: filled ? p.onAccent : p.text),
          ),
        ),
      ),
    );
  }
}

/// Поле поиска в виде капсулы с обводкой.
class SearchPill extends StatelessWidget {
  const SearchPill({super.key, required this.hint, this.controller, this.onChanged});

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(color: p.text, fontSize: 17),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: p.title.withValues(alpha: 0.8), fontSize: 17),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 18, right: 8),
          child: Icon(Icons.search_rounded, color: p.title),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: BorderSide(color: p.title.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(40),
          borderSide: BorderSide(color: p.title, width: 1.5),
        ),
      ),
    );
  }
}

/// Карточка-плитка со скруглёнными углами (списки чатов и настроек).
/// В группе плиток крайние углы круглее, внутренние — меньше, как в референсе.
class TileCard extends StatelessWidget {
  const TileCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.first = true,
    this.last = true,
    this.selected = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool first;
  final bool last;
  final bool selected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const big = Radius.circular(28);
    const small = Radius.circular(10);
    final radius = BorderRadius.vertical(
      top: first ? big : small,
      bottom: last ? big : small,
    );
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 12 : 3),
      child: Material(
        color: selected ? p.surfaceHigh : p.surface,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Узор фона переписки: контурные иконки + «плавающие» пятна-кляксы.
class ChatBackground extends StatelessWidget {
  const ChatBackground({
    super.key,
    required this.child,
    this.icons = true,
    this.shapes = true,
  });

  final Widget child;
  final bool icons;
  final bool shapes;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CustomPaint(
      painter: _PatternPainter(
        color: p.pattern,
        background: p.background,
        icons: icons,
        shapes: shapes,
      ),
      child: child,
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.color,
    required this.background,
    required this.icons,
    required this.shapes,
  });

  final Color color;
  final Color background;
  final bool icons;
  final bool shapes;

  static const _glyphs = [
    Icons.chat_bubble_outline,
    Icons.visibility_outlined,
    Icons.notifications_none,
    Icons.laptop_mac,
    Icons.card_giftcard,
    Icons.bolt_outlined,
    Icons.auto_awesome_outlined,
    Icons.bar_chart_rounded,
    Icons.photo_camera_outlined,
    Icons.call_outlined,
    Icons.mail_outline,
    Icons.music_note_outlined,
    Icons.favorite_border,
    Icons.local_drink_outlined,
    Icons.mood,
    Icons.public,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final rnd = math.Random(7);

    if (shapes) {
      final paint = Paint()..color = color.withValues(alpha: 0.55);
      for (var i = 0; i < (size.width * size.height / 90000).ceil() + 2; i++) {
        final c = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
        final r = 40 + rnd.nextDouble() * 50;
        canvas.drawPath(_blob(c, r, rnd), paint);
      }
    }

    if (icons) {
      const cell = 78.0;
      for (var y = 0.0; y < size.height + cell; y += cell) {
        for (var x = 0.0; x < size.width + cell; x += cell) {
          final g = _glyphs[rnd.nextInt(_glyphs.length)];
          final dx = x + rnd.nextDouble() * 30 - 15;
          final dy = y + rnd.nextDouble() * 30 - 15;
          final tp = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(g.codePoint),
              style: TextStyle(
                fontFamily: g.fontFamily,
                package: g.fontPackage,
                fontSize: 30 + rnd.nextDouble() * 14,
                color: color,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          canvas.save();
          canvas.translate(dx, dy);
          canvas.rotate((rnd.nextDouble() - 0.5) * 0.6);
          tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
          canvas.restore();
        }
      }
    }
  }

  Path _blob(Offset c, double r, math.Random rnd) {
    final path = Path();
    const n = 10;
    final radii = [for (var i = 0; i < n; i++) r * (0.75 + rnd.nextDouble() * 0.35)];
    Offset pt(int i) {
      final a = 2 * math.pi * i / n;
      final rr = radii[i % n];
      return c + Offset(math.cos(a) * rr, math.sin(a) * rr);
    }

    final start = Offset.lerp(pt(0), pt(1), 0.5)!;
    path.moveTo(start.dx, start.dy);
    for (var i = 1; i <= n; i++) {
      final mid = Offset.lerp(pt(i), pt(i + 1), 0.5)!;
      path.quadraticBezierTo(pt(i).dx, pt(i).dy, mid.dx, mid.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.color != color ||
      old.background != background ||
      old.icons != icons ||
      old.shapes != shapes;
}

/// Логотип MilkChat — волнистый пузырь с хвостиком (как иконка приложения).
class MilkLogo extends StatelessWidget {
  const MilkLogo({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _LogoPainter()),
      );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.24));
    canvas.drawRRect(rect, Paint()..color = const Color(0xFF22DD44));
    final fg = Paint()..color = const Color(0xFF1B5230);
    const cx = 0.5, cy = 0.47, r = 0.30;
    final path = Path();
    for (var i = 0; i <= 360; i++) {
      final a = 2 * math.pi * i / 360;
      final rr = r + 0.03 * math.cos(6 * a).abs();
      final p = Offset((cx + rr * math.cos(a)) * s, (cy + rr * math.sin(a)) * s);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), fg);
    canvas.drawPath(
      Path()
        ..moveTo((cx - r * 0.62) * s, (cy + r * 0.55) * s)
        ..lineTo((cx - r * 0.86) * s, (cy + r * 1.30) * s)
        ..lineTo((cx - r * 0.15) * s, (cy + r * 0.92) * s)
        ..close(),
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
