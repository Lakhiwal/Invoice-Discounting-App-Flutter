import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Fintech theme extension ───────────────────────────────────────────────────

final themeProvider = ChangeNotifierProvider<ThemeProvider>((ref) => ThemeProvider());

@immutable
class FintechTheme extends ThemeExtension<FintechTheme> {
  const FintechTheme({
    required this.success,
    required this.danger,
    required this.warning,
    required this.info,
    required this.cardRadius,
    required this.glassOpacity,
  });

  final Color success;
  final Color danger;
  final Color warning;
  final Color info;
  final double cardRadius;
  final double glassOpacity;

  @override
  FintechTheme copyWith({
    Color? success,
    Color? danger,
    Color? warning,
    Color? info,
    double? cardRadius,
    double? glassOpacity,
  }) =>
      FintechTheme(
        success: success ?? this.success,
        danger: danger ?? this.danger,
        warning: warning ?? this.warning,
        info: info ?? this.info,
        cardRadius: cardRadius ?? this.cardRadius,
        glassOpacity: glassOpacity ?? this.glassOpacity,
      );

  @override
  FintechTheme lerp(ThemeExtension<FintechTheme>? other, double t) {
    if (other is! FintechTheme) return this;
    return FintechTheme(
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      glassOpacity: glassOpacity + (other.glassOpacity - glassOpacity) * t,
    );
  }
}

// ── AppColors ─────────────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  static FintechTheme _f(BuildContext c) =>
      Theme.of(c).extension<FintechTheme>()!;
  static ColorScheme _s(BuildContext c) => Theme.of(c).colorScheme;

  static Color success(BuildContext c) => _f(c).success;
  static Color danger(BuildContext c) => _f(c).danger;
  static Color warning(BuildContext c) => _f(c).warning;
  static Color info(BuildContext c) => _f(c).info;

  static Color scaffold(BuildContext c) => _s(c).surface;
  static Color navyCard(BuildContext c) => _s(c).surfaceContainer;
  static Color navyLight(BuildContext c) => _s(c).surfaceContainerHigh;
  static Color navy(BuildContext c) => _s(c).surfaceContainerHighest;
  static Color divider(BuildContext c) => _s(c).outlineVariant;

  static Color textPrimary(BuildContext c) => _s(c).onSurface;
  static Color textSecondary(BuildContext c) => _s(c).onSurfaceVariant;

  static Color primary(BuildContext c) => _s(c).primary;
  static Color emerald(BuildContext c) => success(c);
  static Color rose(BuildContext c) => danger(c);
  static Color amber(BuildContext c) => warning(c);
  static Color blue(BuildContext c) => info(c);

  static const Color blueFallback = Color(0xFF1B4EDE);
  static const Color emeraldFallback = Color(0xFF10B981);
  static const Color roseFallback = Color(0xFFEF4444);
  static const Color amberFallback = Color(0xFFF59E0B);

  static List<BoxShadow> cardShadow(BuildContext c) =>
      Theme.of(c).brightness == Brightness.light
          ? [
        BoxShadow(
          color: _s(c).primary.withValues(alpha: 0.04),
          blurRadius: 20,
          offset: const Offset(0, 4),
        )
      ]
          : [];
}

// ── ThemeProvider ─────────────────────────────────────────────────────────────

enum AppThemeMode { system, light, dark, black }

class ThemeProvider extends ChangeNotifier {
  static const _kThemeKey = 'theme_mode';
  static const _kBalanceKey = 'hide_balance';

  AppThemeMode _mode = AppThemeMode.system;
  bool _hideBalance = false;

  AppThemeMode get mode => _mode;
  bool get hideBalance => _hideBalance;

  /// Returns the Flutter ThemeMode for MaterialApp.
  /// Both dark and black use ThemeMode.dark — the difference is in the
  /// ThemeData returned by darkThemeFor().
  ThemeMode get flutterThemeMode {
    switch (_mode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.black:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// True when the user explicitly chose black mode.
  bool get isBlackMode => _mode == AppThemeMode.black;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeKey);
    _mode = AppThemeMode.values.firstWhere(
          (e) => e.name == saved,
      orElse: () => AppThemeMode.system,
    );
    _hideBalance = prefs.getBool(_kBalanceKey) ?? false;
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString(_kThemeKey, mode.name);
  }

  Future<void> setHideBalance(bool hide) async {
    _hideBalance = hide;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool(_kBalanceKey, hide);
  }

  // ── Theme getters ─────────────────────────────────────────────────────────

  static ThemeData get lightTheme => buildLightTheme(null);
  static ThemeData get darkTheme => buildDarkTheme(null);
  static ThemeData get blackTheme => buildBlackTheme(null);

  /// Returns the correct dark ThemeData based on current mode.
  ThemeData darkThemeFor(ColorScheme? dynamicScheme) =>
      isBlackMode ? buildBlackTheme(dynamicScheme) : buildDarkTheme(dynamicScheme);
}

// ── Theme builders ────────────────────────────────────────────────────────────

ThemeData buildLightTheme(ColorScheme? dynamicScheme) =>
    _build(Brightness.light, _DarkVariant.none, dynamicScheme);

ThemeData buildDarkTheme(ColorScheme? dynamicScheme) =>
    _build(Brightness.dark, _DarkVariant.dark, dynamicScheme);

ThemeData buildBlackTheme(ColorScheme? dynamicScheme) =>
    _build(Brightness.dark, _DarkVariant.black, dynamicScheme);

enum _DarkVariant { none, dark, black }

ThemeData _build(Brightness brightness, _DarkVariant variant,
    [ColorScheme? dynamicScheme]) {
  final isDark = brightness == Brightness.dark;
  final isBlack = variant == _DarkVariant.black;
  const brandSeed = Color(0xFF1B4EDE);

  final ColorScheme colorScheme;
  if (dynamicScheme != null && !isBlack) {
    colorScheme = dynamicScheme.copyWith(
      error: const Color(0xFFEF4444),
      surfaceTint: Colors.transparent,
    );
  } else {
    // Surface colors per variant
    final Color surface;
    final Color surfaceContainer;
    final Color surfaceContainerHigh;

    if (isBlack) {
      // True AMOLED black
      surface = const Color(0xFF000000);
      surfaceContainer = const Color(0xFF000000);
      surfaceContainerHigh = const Color(0xFF0D0D0D);
    } else if (isDark) {
      // Dark mode — very dark but not pure black
      surface = const Color(0xFF050508);
      surfaceContainer = const Color(0xFF0A0A0F);
      surfaceContainerHigh = const Color(0xFF111118);
    } else {
      // Light mode
      surface = const Color(0xFFF4F7FF);
      surfaceContainer = const Color(0xFFFFFFFF);
      surfaceContainerHigh = const Color(0xFFEEF2FF);
    }

    colorScheme = ColorScheme.fromSeed(
      seedColor: brandSeed,
      brightness: brightness,
      surface: surface,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
    ).copyWith(
      primary: brandSeed,
      onPrimary: Colors.white,
      error: const Color(0xFFEF4444),
      surfaceTint: Colors.transparent,
    );
  }

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    fontFamily: 'Inter',
    extensions: [
      FintechTheme(
        success: const Color(0xFF10B981),
        danger: const Color(0xFFEF4444),
        warning: const Color(0xFFF59E0B),
        info: colorScheme.primary,
        cardRadius: 20,
        glassOpacity: isDark ? 0.08 : 0.7,
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      systemOverlayStyle:
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainer,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.15)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHigh,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  );
}