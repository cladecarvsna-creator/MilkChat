import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Цветовые пресеты из листа «Оформление». Первый — фирменный графит MilkChat,
/// второй — тёмно-зелёный из логотипа.
const accentPresets = <Color>[
  Color(0xFF2C2C2E), // графит (по умолчанию)
  Color(0xFF35534D), // зелень логотипа
  Color(0xFF7C8CFF), // лавандовый
  Color(0xFFEF6B57), // коралловый
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

  /// Имена чатов и заголовки карточек.
  final Color title;
  final Color text;
  final Color muted;
  final Color bubbleIn;
  final Color onBubbleIn;
  final Color bubbleOut;
  final Color onBubbleOut;
  final Color pattern;
  final Color nav;

  /// Фон и поверхности всегда бело-серые, от акцентного цвета зависят
  /// только кнопки, свои пузыри и выделения.
  factory MilkPalette.from(Color seed, Brightness brightness) {
    final hsl = HSLColor.fromColor(seed);
    final gray = hsl.saturation < 0.12;
    Color c(double light) => hsl.withLightness(light).toColor();

    if (brightness == Brightness.dark) {
      final accent = gray ? const Color(0xFFE5E5EA) : c(hsl.lightness.clamp(0.55, 0.7));
      return MilkPalette(
        background: const Color(0xFF121214),
        surface: const Color(0xFF1E1E21),
        surfaceHigh: const Color(0xFF2A2A2E),
        accent: accent,
        onAccent: const Color(0xFF121214),
        title: const Color(0xFFF2F2F7),
        text: const Color(0xFFF2F2F7),
        muted: const Color(0xFF8E8E93),
        bubbleIn: const Color(0xFF2A2A2E),
        onBubbleIn: const Color(0xFFF2F2F7),
        bubbleOut: accent,
        onBubbleOut: const Color(0xFF121214),
        pattern: const Color(0xFF1C1C1F),
        nav: const Color(0xFF1E1E21),
      );
    }
    final accent = gray ? seed : c(hsl.lightness.clamp(0.3, 0.5));
    return MilkPalette(
      background: Colors.white,
      surface: const Color(0xFFF2F2F4),
      surfaceHigh: const Color(0xFFE7E7EA),
      accent: accent,
      onAccent: Colors.white,
      title: const Color(0xFF1C1C1E),
      text: const Color(0xFF1C1C1E),
      muted: const Color(0xFF8E8E93),
      bubbleIn: const Color(0xFFF0F0F2),
      onBubbleIn: const Color(0xFF1C1C1E),
      bubbleOut: accent,
      onBubbleOut: Colors.white,
      pattern: const Color(0xFFEDEDF0),
      nav: Colors.white,
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
    fontFamily: 'Unbounded',
    extensions: [p],
  );
  const stadium = StadiumBorder();
  RoundedRectangleBorder rounded(double r) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
  const label = TextStyle(fontFamily: 'Unbounded', fontWeight: FontWeight.w600, fontSize: 14);
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    iconTheme: IconThemeData(color: p.accent),
    dividerColor: Colors.transparent,
    splashFactory: InkSparkle.splashFactory,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
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
        shape: stadium,
        textStyle: label.copyWith(fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        side: BorderSide(color: p.surfaceHigh, width: 1.5),
        shape: stadium,
        textStyle: label,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.accent, shape: stadium, textStyle: label),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: stadium, textStyle: label),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(shape: const CircleBorder())),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      shape: rounded(24),
    ),
    cardTheme: CardThemeData(color: p.surface, elevation: 0, shape: rounded(28)),
    chipTheme: ChipThemeData(shape: stadium, side: BorderSide.none, backgroundColor: p.surface),
    listTileTheme: ListTileThemeData(shape: rounded(20)),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.background,
      showDragHandle: true,
      dragHandleColor: p.surfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.background, shape: rounded(32)),
    popupMenuTheme: PopupMenuThemeData(color: p.background, shape: rounded(22), elevation: 6),
    menuTheme: MenuThemeData(
      style: MenuStyle(shape: WidgetStatePropertyAll(rounded(22))),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: p.text, borderRadius: BorderRadius.circular(14)),
      textStyle: TextStyle(color: p.background, fontSize: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.text,
      contentTextStyle: TextStyle(color: p.background, fontFamily: 'Unbounded'),
      behavior: SnackBarBehavior.floating,
      shape: rounded(22),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.surfaceHigh,
      borderRadius: BorderRadius.circular(8),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.onAccent : p.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceHigh),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}

/// Настройки оформления, сохраняются на устройстве.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs)
      : _mode = ThemeMode.values[_prefs.getInt(_modeKey) ?? ThemeMode.light.index],
        _accent = Color(_prefs.getInt(_accentKey) ?? accentPresets.first.toARGB32()),
        _floatingShapes = _prefs.getBool('floating_shapes') ?? true,
        _patternIcons = _prefs.getBool('pattern_icons') ?? true;

  // Ключи с суффиксом v2: после редизайна все начинают со светлой бело-серой темы.
  static const _modeKey = 'theme_mode_v2';
  static const _accentKey = 'accent_v2';

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
    _prefs.setInt(_modeKey, v.index);
    notifyListeners();
  }

  set accent(Color v) {
    _accent = v;
    _prefs.setInt(_accentKey, v.toARGB32());
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
