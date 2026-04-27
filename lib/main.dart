import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:invoice_discounting_app/screens/login_screen.dart';
import 'package:invoice_discounting_app/screens/main_screen.dart';
import 'package:invoice_discounting_app/screens/unlock_screen.dart';
import 'package:invoice_discounting_app/services/auth_api_service.dart';
import 'package:invoice_discounting_app/services/cache_service.dart';
import 'package:invoice_discounting_app/services/notification_service.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/no_glow_scroll.dart';
import 'package:invoice_discounting_app/utils/refresh_rate_controller.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Globals ───────────────────────────────────────────────────────────────────

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

const _pageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  },
);

const String _prefKeyRefreshRate = 'preferred_refresh_rate';

Future<void> applyRefreshRate(int hz) async {
  await RefreshRateController.setMax();
}

Future<int> getSavedRefreshRate() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_prefKeyRefreshRate) ?? -1;
}

Future<void> saveRefreshRate(int hz) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_prefKeyRefreshRate, hz);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GestureBinding.instance.resamplingEnabled = true;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 220 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 300;

  // Parallelize heavy initializations for faster startup
  await Future.wait([
    Hive.initFlutter(),
    CacheService.initialize(),
    Firebase.initializeApp(),
    NotificationService.initialize(),
    AppHaptics.loadPreference(),
  ]);

  final savedHz = await getSavedRefreshRate();
  unawaited(applyRefreshRate(savedHz));

  runApp(
    const ProviderScope(
      child: InvoFinApp(),
    ),
  );
}

class InvoFinApp extends ConsumerWidget {
  const InvoFinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          final themeProviderInst = ref.watch(themeProvider);
          final mode = themeProviderInst.flutterThemeMode;
          final textTheme = GoogleFonts.dmSansTextTheme();
          final isDark = mode == ThemeMode.dark ||
              (mode == ThemeMode.system &&
                  MediaQuery.platformBrightnessOf(context) == Brightness.dark);

          return MaterialApp(
            navigatorKey: navigatorKey,
            title: 'Finworks360',
            debugShowCheckedModeBanner: false,
            navigatorObservers: [routeObserver],
            themeAnimationDuration: Duration.zero,
            scrollBehavior: const NoGlowScrollBehavior(),
            builder: (context, child) {
              final mediaData = MediaQuery.of(context);
              final clampedScale =
                  mediaData.textScaler.scale(1).clamp(0.85, 1.3);
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarIconBrightness:
                      isDark ? Brightness.light : Brightness.dark,
                ),
                child: MediaQuery(
                  data: mediaData.copyWith(
                    textScaler: TextScaler.linear(clampedScale),
                  ),
                  child: child!,
                ),
              );
            },
            theme: buildLightTheme(lightDynamic).copyWith(
              pageTransitionsTheme: _pageTransitionsTheme,
              textTheme: textTheme.apply(
                bodyColor: const Color(0xFF0B1220),
                displayColor: const Color(0xFF0B1220),
              ),
            ),
            darkTheme: themeProviderInst.darkThemeFor(darkDynamic).copyWith(
                  pageTransitionsTheme: _pageTransitionsTheme,
                  textTheme: textTheme.apply(
                    bodyColor: const Color(0xFFEFF4FF),
                    displayColor: const Color(0xFFEFF4FF),
                  ),
                ),
            themeMode: mode,
            home: const AppRoot(),
          );
        },
      );
}

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const SplashScreen();
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  DateTime? _pausedAt;
  bool _authInProgress = false;
  bool _isFirstLaunch = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleUp;
  late Animation<double> _loaderFade;
  double _loadingProgress = 0.0;
  String _loadingStatus = 'Initializing Secure Gateway...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );
    _scaleUp = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _loaderFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: const Interval(0.5, 1, curve: Curves.easeIn),
      ),
    );

    unawaited(_animCtrl.forward());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initFirstLaunch();
      if (mounted) _checkAuth();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) _pausedAt = DateTime.now();
    if (state == AppLifecycleState.resumed) {
      if (_pausedAt == null) return;
      final diff = DateTime.now().difference(_pausedAt!);
      final useBiometrics = ref.read(themeProvider).useBiometrics;

      if (diff.inSeconds > 30 && !_authInProgress && useBiometrics) {
        await _reauthenticate();
      }
    }
  }

  Future<void> _reauthenticate() async {
    if (_authInProgress) return;
    _authInProgress = true;
    try {
      final auth = LocalAuthentication();
      final success = await auth
          .authenticate(
            localizedReason: 'Authenticate to open Finworks360',
            biometricOnly: true,
          )
          .timeout(const Duration(seconds: 10), onTimeout: () => false);

      if (!mounted) return;
      if (!success) {
        unawaited(
          Navigator.of(context).pushReplacement(
            SmoothPageRoute<void>(builder: (_) => const UnlockScreen()),
          ),
        );
      }
    } catch (_) {}
    _authInProgress = false;
  }

  Future<void> _initFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isFirstLaunch = prefs.getBool('first_launch_done') != true;
      });
    }
  }

  Future<void> _markFirstLaunchDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch_done', true);
  }

  Future<void> _setProgress(double val, String status) async {
    if (!mounted) return;

    if (_isFirstLaunch) {
      final start = _loadingProgress;
      final diff = val - start;
      final steps = (diff.abs() * 100).clamp(5, 30).toInt();
      final stepDuration = Duration(milliseconds: 1800 ~/ steps);

      for (int i = 1; i <= steps; i++) {
        await Future<void>.delayed(stepDuration);
        if (!mounted) return;
        setState(() {
          _loadingProgress = start + (diff * (i / steps));
          _loadingStatus = status;
        });
      }
    } else {
      setState(() {
        _loadingProgress = val;
        _loadingStatus = status;
      });
    }

    // Milestone haptic tick
    if (val < 1.0) {
      unawaited(AppHaptics.selection());
    } else {
      // Completion haptic — satisfying success chord
      unawaited(AppHaptics.success());
    }
  }

  Future<void> _checkAuth() async {
    if (_authInProgress) return;
    _authInProgress = true;

    try {
      await _setProgress(0.15, 'Initializing Secure Gateway...');

      if (mounted) {
        await precacheImage(
          const AssetImage('assets/images/logo-colored.png'),
          context,
        );
      }

      if (!mounted) return;
      await _setProgress(0.35, 'Syncing Market Intelligence...');

      // PROACTIVE SYNC: Don't just check for token existence, verify it with the server.
      final isSessionValid = await AuthApiService.refreshWithStoredToken();

      if (!mounted) return;
      await _setProgress(0.60, 'Validating Encrypted Ledger...');

      if (!isSessionValid) {
        await AuthApiService.logout();
        await _setProgress(1.0, 'Ready');
        if (_isFirstLaunch) await _markFirstLaunchDone();
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          unawaited(
            Navigator.of(context).pushAndRemoveUntil(
              SmoothPageRoute<void>(builder: (_) => const LoginScreen()),
              (route) => false,
            ),
          );
        }
        return;
      }

      final auth = LocalAuthentication();
      final canAuth =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();

      final useBiometrics = ref.read(themeProvider).useBiometrics;

      if (!canAuth || !useBiometrics) {
        if (!mounted) return;
        await _setProgress(1.0, 'Ready');
        if (_isFirstLaunch) await _markFirstLaunchDone();
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          unawaited(
            Navigator.of(context).pushAndRemoveUntil(
              SmoothPageRoute<void>(builder: (_) => const MainScreen()),
              (route) => false,
            ),
          );
        }
        return;
      }

      await _setProgress(0.85, 'Finalizing Portfolio Integrity...');

      final success = await auth
          .authenticate(
            localizedReason: 'Authenticate to open Finworks360',
            biometricOnly: true,
          )
          .timeout(const Duration(seconds: 10), onTimeout: () => false);

      if (!mounted) return;
      await _setProgress(1.0, 'Ready');
      if (_isFirstLaunch) await _markFirstLaunchDone();
      await Future<void>.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        unawaited(
          Navigator.of(context).pushAndRemoveUntil(
            SmoothPageRoute<void>(
              builder: (_) =>
                  success ? const MainScreen() : const LoginScreen(),
            ),
            (route) => false,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        await _setProgress(1.0, 'Error');
        if (mounted) {
          unawaited(
            Navigator.of(context).pushAndRemoveUntil(
              SmoothPageRoute<void>(builder: (_) => const LoginScreen()),
              (route) => false,
            ),
          );
        }
      }
    } finally {
      _authInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [cs.surface, cs.surfaceContainerLow, cs.surface]
                : [
                    cs.surface,
                    cs.primaryContainer.withValues(alpha: 0.15),
                    cs.surface,
                  ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _fadeIn,
                child: ScaleTransition(
                  scale: _scaleUp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(UI.radiusLg),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.08),
                          blurRadius: 30,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Hero(
                      tag: 'app_logo_hero',
                      child: Image.asset(
                        'assets/images/logo-colored.png',
                        height: 48,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // FIX #Skeleton: removed SkeletonHomeContent from splash screen
              // to prevent it from showing behind the biometric prompt.
              // Instead, we show a subtle, centered loader if needed.
              FadeTransition(
                opacity: _loaderFade,
                child: Column(
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * 0.72,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: _loadingProgress),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutExpo,
                          builder: (context, value, child) =>
                              LinearProgressIndicator(
                            value: value,
                            backgroundColor: cs.primary.withValues(alpha: 0.08),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(cs.primary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _loadingStatus,
                        key: ValueKey(_loadingStatus),
                        style: TextStyle(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          fontFamily: GoogleFonts.dmSans().fontFamily,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RefreshRatePicker extends ConsumerStatefulWidget {
  const RefreshRatePicker({super.key});

  @override
  ConsumerState<RefreshRatePicker> createState() => _RefreshRatePickerState();
}

class _RefreshRatePickerState extends ConsumerState<RefreshRatePicker> {
  static const List<({int hz, String label})> _options = [
    (hz: -1, label: 'Maximum (recommended)'),
    (hz: 60, label: '60 Hz'),
    (hz: 90, label: '90 Hz'),
    (hz: 120, label: '120 Hz'),
    (hz: 144, label: '144 Hz'),
  ];

  int _selected = -1;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final hz = await getSavedRefreshRate();
    if (mounted) setState(() => _selected = hz);
  }

  Future<void> _apply(int hz) async {
    setState(() => _selected = hz);
    await saveRefreshRate(hz);
    await applyRefreshRate(hz);
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Refresh Rate',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _options.any((o) => o.hz == _selected) ? _selected : -1,
              dropdownColor: AppColors.navyCard(context),
              style: TextStyle(
                color: AppColors.textPrimary(context),
                fontSize: 14,
              ),
              borderRadius: BorderRadius.circular(UI.radiusLg),
              items: _options
                  .map(
                    (o) => DropdownMenuItem(value: o.hz, child: Text(o.label)),
                  )
                  .toList(),
              onChanged: (hz) => hz != null ? _apply(hz) : null,
            ),
          ),
        ],
      );
}
