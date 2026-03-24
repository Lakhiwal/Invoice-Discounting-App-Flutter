import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:invoice_discounting_app/utils/no_glow_scroll.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/unlock_screen.dart';
import 'services/api_service.dart';
import 'services/notification_provider.dart';
import 'services/notification_service.dart';
import 'theme/theme_provider.dart';
import 'utils/refresh_rate_controller.dart';

// ── Globals ───────────────────────────────────────────────────────────────────

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final RouteObserver<ModalRoute<void>> routeObserver =
RouteObserver<ModalRoute<void>>();

// ── Refresh Rate ──────────────────────────────────────────────────────────────

const String _prefKeyRefreshRate = 'preferred_refresh_rate';

Future<void> applyRefreshRate(int hz) async {
  if (hz == 60) {
    await RefreshRateController.set60Hz();
  } else {
    await RefreshRateController.setMax();
  }
}

Future<int> getSavedRefreshRate() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(_prefKeyRefreshRate) ?? -1;
}

Future<void> saveRefreshRate(int hz) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_prefKeyRefreshRate, hz);
}

// ── Entry point ───────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GestureBinding.instance.resamplingEnabled = true;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 220 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 300;

  await Firebase.initializeApp();
  await NotificationService.initialize();
  final savedHz = await getSavedRefreshRate();
  await applyRefreshRate(savedHz);

  bool rooted = await JailbreakRootDetection.instance.isJailBroken;

  if (rooted) {
    SystemNavigator.pop();
    return;
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const InvoFinApp(),
    ),
  );
}

// ── App widget ────────────────────────────────────────────────────────────────

class InvoFinApp extends StatelessWidget {
  const InvoFinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            final textTheme = GoogleFonts.dmSansTextTheme();
            final isDark = themeProvider.flutterThemeMode == ThemeMode.dark || 
                (themeProvider.flutterThemeMode == ThemeMode.system && 
                 MediaQuery.platformBrightnessOf(context) == Brightness.dark);

            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'Finworks360',
              debugShowCheckedModeBanner: false,
              navigatorObservers: [routeObserver],
              themeAnimationDuration: const Duration(milliseconds: 200),
              scrollBehavior: const NoGlowScrollBehavior(),
              builder: (context, child) {
                // FIX: Apply system overlay style here so it updates with theme
                SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                ));

                final mediaData = MediaQuery.of(context);
                final clampedScale = mediaData.textScaler.scale(1.0).clamp(0.85, 1.3);
                return MediaQuery(
                  data: mediaData.copyWith(
                    textScaler: TextScaler.linear(clampedScale),
                  ),
                  child: child!,
                );
              },
              theme: buildLightTheme(lightDynamic).copyWith(
                textTheme: textTheme.apply(
                  bodyColor: const Color(0xFF0B1220),
                  displayColor: const Color(0xFF0B1220),
                ),
              ),
              darkTheme: buildDarkTheme(darkDynamic).copyWith(
                textTheme: textTheme.apply(
                  bodyColor: const Color(0xFFEFF4FF),
                  displayColor: const Color(0xFFEFF4FF),
                ),
              ),
              themeMode: themeProvider.flutterThemeMode,
              home: const AppRoot(),
            );
          },
        );
      },
    );
  }
}

// ── App root ──────────────────────────────────────────────────────────────────

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}

// ── Splash / auth gate ────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  DateTime? _pausedAt;
  bool _authInProgress = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleUp;
  late Animation<double> _loaderFade;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _scaleUp = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)),
    );
    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );

    _animCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuth();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    }
    if (state == AppLifecycleState.resumed) {
      if (_pausedAt == null) return;
      final diff = DateTime.now().difference(_pausedAt!);
      if (diff.inSeconds > 30 && !_authInProgress) {
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
        biometricOnly: false,
      ).timeout(const Duration(seconds: 10), onTimeout: () => false);
      if (!mounted) return;
      if (!success) {
        Navigator.of(context).pushReplacement(
          SmoothPageRoute(builder: (_) => const UnlockScreen()),
        );
      }
    } catch (e) {
      debugPrint('Re-auth error: $e');
    }
    _authInProgress = false;
  }

  Future<void> _checkAuth() async {
    if (_authInProgress) return;
    _authInProgress = true;

    try {
      if (!mounted) return;

      await precacheImage(
        const AssetImage('assets/images/logo-colored.png'),
        context,
      );

      final isLoggedIn = await ApiService.isLoggedIn();

      if (!mounted) return;

      if (!isLoggedIn) {
        Navigator.of(context).pushAndRemoveUntil(
          SmoothPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
        return;
      }

      final auth = LocalAuthentication();
      final canAuth =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();

      if (!canAuth) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          SmoothPageRoute(builder: (_) => const MainScreen()),
              (route) => false,
        );
        return;
      }

      final success = await auth
          .authenticate(
        localizedReason: 'Authenticate to open Finworks360',
        biometricOnly: false,
      )
          .timeout(const Duration(seconds: 10), onTimeout: () => false);

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        SmoothPageRoute(
          builder: (_) => success
              ? const MainScreen()
              : const LoginScreen(),
        ),
            (route) => false,
      );

    } catch (e) {
      debugPrint('Biometric auth error: $e');

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          SmoothPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
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
                ? [
              cs.surface,
              cs.surfaceContainerLow,
              cs.surface,
            ]
                : [
              cs.surface,
              cs.primaryContainer.withValues(alpha: 0.15),
              cs.surface,
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animCtrl,
            builder: (context, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with fade + scale
                Opacity(
                  opacity: _fadeIn.value,
                  child: Transform.scale(
                    scale: _scaleUp.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 18),
                      decoration: BoxDecoration(
                        color: isDark
                            ? cs.surfaceContainerHigh
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.08),
                            blurRadius: 30,
                            spreadRadius: 2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/logo-colored.png',
                        height: 44,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                // Loading indicator — fades in after logo settles
                Opacity(
                  opacity: _loaderFade.value,
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: cs.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Tagline — fades in with loader
                Opacity(
                  opacity: _loaderFade.value,
                  child: Text(
                    'Smart Invoice Investing',
                    style: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Refresh Rate Picker (used in ProfileScreen) ───────────────────────────────

class RefreshRatePicker extends StatefulWidget {
  const RefreshRatePicker({super.key});

  @override
  State<RefreshRatePicker> createState() => _RefreshRatePickerState();
}

class _RefreshRatePickerState extends State<RefreshRatePicker> {
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
    _load();
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
  Widget build(BuildContext context) {
    return Row(
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
            value:
            _options.any((o) => o.hz == _selected) ? _selected : -1,
            dropdownColor: AppColors.navyCard(context),
            style: TextStyle(
                color: AppColors.textPrimary(context), fontSize: 14),
            borderRadius: BorderRadius.circular(12),
            items: _options
                .map((o) => DropdownMenuItem(
                value: o.hz, child: Text(o.label)))
                .toList(),
            onChanged: (hz) {
              if (hz != null) _apply(hz);
            },
          ),
        ),
      ],
    );
  }
}