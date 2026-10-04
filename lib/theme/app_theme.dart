import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Цветовые пресеты из листа «Оформление». Первый — фирменный мятный MilkChat.
const accentPresets = <Color>[
  Color(0xFF5EE0C0), // мята (по умолчанию)
  Color(0xFF7C8CFF), // лавандовый
  Color(0xFFEF6B57), // коралловый
  Color(0xFF9AA0A6), // графит
  Color(0xFF4DA8FF), // голубой
  Color(0xFF5CD67A), // зелёный
  Color(0xFFFF8A3D), // оранжевый
  Color(0xFFE76BC8), // розовый
];

/// Палитра приложения, вычисляется из акцентного цвета и режима.
@immutable
class MilkPalette extends ThemeExtension<MilkPalette> {
  const MilkPalette({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.accent,
    required this.onAccent,
    required this.title,
    required this.text,
    required this.muted,
    required this.bubbleIn,
    required this.onBubbleIn,
    required this.bubbleOut,
    required this.onBubbleOut,
    required this.pattern,
    required this.nav,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color accent;
  final Color onAccent;

  /// Имена чатов и заголовки карточек (в тёмной теме — мятные).
  final Color title;
  final Color text;
  final Color muted;
  final Color bubbleIn;
  final Color onBubbleIn;
  final Color bubbleOut;
  final Color onBubbleOut;
  final Color pattern;
  final Color nav;

  factory MilkPalette.from(Color seed, Brightness brightness) {
    final hsl = HSLColor.fromColor(seed);
    final h = hsl.hue;
    final s = hsl.saturation;
    Color c(double sat, double light) =>
        HSLColor.fromAHSL(1, h, (s * sat).clamp(0, 1), light).toColor();

    if (brightness == Brightness.dark) {
      return MilkPalette(
        background: c(0.55, 0.09),
        surface: c(0.45, 0.18),
        surfaceHigh: c(0.45, 0.24),
        accent: c(1.0, 0.63),
        onAccent: c(0.6, 0.12),
        title: c(1.0, 0.68),
        text: const Color(0xFFF1F5F4),
        muted: c(0.35, 0.62),
        bubbleIn: c(0.45, 0.20),
        onBubbleIn: const Color(0xFFF1F5F4),
        bubbleOut: c(0.95, 0.75),
        onBubbleOut: c(0.6, 0.13),
        pattern: c(0.3, 0.21),
        nav: c(0.55, 0.07),
      );
    }
    return MilkPalette(
      background: c(0.45, 0.95),
      surface: c(0.35, 0.89),
      surfaceHigh: c(0.40, 0.83),
      accent: c(0.9, 0.38),
      onAccent: Colors.white,
      title: c(0.9, 0.28),
      text: c(0.4, 0.12),
      muted: c(0.25, 0.40),
      bubbleIn: Colors.white,
      onBubbleIn: c(0.4, 0.12),
      bubbleOut: c(0.75, 0.42),
      onBubbleOut: Colors.white,
      pattern: c(0.3, 0.80),
      nav: c(0.4, 0.98),
    );
  }

  @override
  MilkPalette copyWith() => this;

  @override
  MilkPalette lerp(MilkPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MilkPalette(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      title: l(title, other.title),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      bubbleIn: l(bubbleIn, other.bubbleIn),
      onBubbleIn: l(onBubbleIn, other.onBubbleIn),
      bubbleOut: l(bubbleOut, other.bubbleOut),
      onBubbleOut: l(onBubbleOut, other.onBubbleOut),
      pattern: l(pattern, other.pattern),
      nav: l(nav, other.nav),
    );
  }
}

extension MilkPaletteX on BuildContext {
  MilkPalette get palette => Theme.of(this).extension<MilkPalette>()!;
}

ThemeData buildTheme(Color seed, Brightness brightness) {
  final p = MilkPalette.from(seed, brightness);
  final scheme = ColorScheme.fromSeed(
    seedColor: p.accent,
    brightness: brightness,
  ).copyWith(
    primary: p.accent,
    onPrimary: p.onAccent,
    surface: p.background,
    onSurface: p.text,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceHigh,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    fontFamily: 'Nunito',
    extensions: [p],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    iconTheme: IconThemeData(color: p.accent),
    dividerColor: Colors.transparent,
    splashFactory: InkSparkle.splashFactory,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceHigh,
      hintStyle: TextStyle(color: p.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.accent,
        foregroundColor: p.onAccent,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.background,
      showDragHandle: true,
      dragHandleColor: p.muted,
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.surface),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surfaceHigh,
      contentTextStyle: TextStyle(color: p.text),
      behavior: SnackBarBehavior.floating,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onAccent : p.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceHigh),
    ),
  );
}

/// Настройки оформления, сохраняются на устройстве.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs)
      : _mode = ThemeMode.values[_prefs.getInt('theme_mode') ?? ThemeMode.dark.index],
        _accent = Color(_prefs.getInt('accent') ?? accentPresets.first.toARGB32()),
        _floatingShapes = _prefs.getBool('floating_shapes') ?? true,
        _patternIcons = _prefs.getBool('pattern_icons') ?? true;

  final SharedPreferences _prefs;
  ThemeMode _mode;
  Color _accent;
  bool _floatingShapes;
  bool _patternIcons;

  ThemeMode get mode => _mode;
  Color get accent => _accent;
  bool get floatingShapes => _floatingShapes;
  bool get patternIcons => _patternIcons;

  set mode(ThemeMode v) {
    _mode = v;
    _prefs.setInt('theme_mode', v.index);
    notifyListeners();
  }

  set accent(Color v) {
    _accent = v;
    _prefs.setInt('accent', v.toARGB32());
    notifyListeners();
  }

  set floatingShapes(bool v) {
    _floatingShapes = v;
    _prefs.setBool('floating_shapes', v);
    notifyListeners();
  }

  set patternIcons(bool v) {
    _patternIcons = v;
    _prefs.setBool('pattern_icons', v);
    notifyListeners();
  }
}
