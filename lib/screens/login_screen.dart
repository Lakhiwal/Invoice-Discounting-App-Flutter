import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../services/secure_storage_service.dart';
import '../theme/theme_provider.dart';
import '../theme/ui_constants.dart';
import '../utils/app_haptics.dart';
import 'main_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _localAuth = LocalAuthentication();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isBiometricLoading = false;
  bool _biometricAvailable = false;
  String? _errorMessage;

  // FIX #11: TapGestureRecognizer must be stored as a field and disposed.
  // Creating it inline in build() leaks a new recognizer on every rebuild.
  late final TapGestureRecognizer _signUpRecognizer;

  late AnimationController _animController;
  late CurvedAnimation _fadeCurve;
  late CurvedAnimation _slideCurve;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeCurve =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _fadeAnim = _fadeCurve;
    _slideCurve =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(_slideCurve);
    _animController.forward();
    // FIX #11: initialize recognizer here, not inline in build()
    _signUpRecognizer = TapGestureRecognizer()
      ..onTap = () async {
        await AppHaptics.selection();
        if (!mounted) return;
        Navigator.of(context).push(
          SmoothPageRoute(builder: (_) => RegisterScreen()),
        );
      };
    _checkBiometricsAndAutoPrompt();
  }

  @override
  void dispose() {
    _localAuth.stopAuthentication();
    _fadeCurve.dispose();
    _slideCurve.dispose();
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _signUpRecognizer.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricsAndAutoPrompt() async {
    try {
      final results = await Future.wait([
        _localAuth.canCheckBiometrics,
        _localAuth.isDeviceSupported(),
        SecureStorageService.getCredentials(),
      ]);
      final canCheck = results[0] as bool;
      final isSupported = results[1] as bool;
      final creds = results[2] as Map<String, String?>;
      // FIX #5: check for refreshToken, not password
      final hasSaved = creds['email'] != null && creds['refreshToken'] != null;
      final available = (canCheck || isSupported) && hasSaved;

      if (mounted) setState(() => _biometricAvailable = available);

      if (available) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) _handleBiometricLogin();
      }
    } on Exception catch (e) {
      debugPrint('Biometric check error: $e');
      if (mounted) setState(() => _biometricAvailable = false);
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (_isBiometricLoading) return;

    try {
      await _localAuth.stopAuthentication();
    } catch (_) {}

    setState(() {
      _isBiometricLoading = true;
      _errorMessage = null;
    });

    bool authenticated = false;

    try {
      authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Finworks360',
        biometricOnly: false,
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric PlatformException: ${e.code} — ${e.message}');
      authenticated = false;
    } on Exception catch (e) {
      debugPrint('Biometric auth error: $e');
      authenticated = false;
    }

    if (!authenticated) {
      if (mounted) {
        setState(() {
          _isBiometricLoading = false;
          _errorMessage = null;
        });
      }
      return;
    }

    try {
      final creds = await SecureStorageService.getCredentials();
      final email = creds['email'];
      final refreshToken = creds['refreshToken'];

      // FIX #5: use the stored refresh token to re-authenticate, never replay password
      if (email == null || refreshToken == null) {
        if (mounted) {
          setState(() => _errorMessage =
              'No saved credentials. Please login with your password first.');
        }
        return;
      }

      // Save the refresh token back to SharedPreferences so ApiService can use it
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('refresh_token', refreshToken);

      // Use the refresh flow to get a fresh access token
      final refreshed = await ApiService.refreshWithStoredToken();
      if (!mounted) return;

      if (refreshed) {
        await AppHaptics.success();
        if (!mounted) return;
        // Item #2: pushAndRemoveUntil to clear login from stack
        navigatorKey.currentState!.pushAndRemoveUntil(
          SmoothPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
        _registerFcmInBackground();
      } else {
        await AppHaptics.error();
        setState(() => _errorMessage =
            'Session expired. Please login with your password.');
      }
    } on Exception catch (e) {
      debugPrint('Post-biometric login error: $e');
      if (mounted) {
        setState(() => _errorMessage =
            'Cannot connect to server. Please check your network.');
      }
    } finally {
      if (mounted) setState(() => _isBiometricLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
      return;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.login(email, password);
      if (!mounted) return;

      if (result['success'] == true) {
        _passwordController.clear();
        await AppHaptics.success();
        if (!mounted) return;
        // Item #2: pushAndRemoveUntil to clear login from stack
        navigatorKey.currentState!.pushAndRemoveUntil(
          SmoothPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
        // FIX #5: save email + refresh token (never save the raw password)
        _saveCredentialsInBackground(email, result['refresh'] as String? ?? '');
        _registerFcmInBackground();
      } else {
        await AppHaptics.error();
        setState(() => _errorMessage = result['error'] as String?);
      }
    } on Exception catch (e) {
      debugPrint('Login error: $e');
      await AppHaptics.error();
      if (mounted) {
        setState(() => _errorMessage =
            'Cannot connect to server. Please check your network.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCredentialsInBackground(
      String email, String refreshToken) async {
    try {
      // FIX #5: store refresh token, not the raw password
      await SecureStorageService.saveCredentials(
        email: email,
        refreshToken: refreshToken,
      );
    } on Exception catch (e) {
      debugPrint('Credential save error: $e');
    }
  }

  Future<void> _registerFcmInBackground() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) {
        await ApiService.registerFcmToken(token);
      }

      FirebaseMessaging.instance.onTokenRefresh.listen(
        ApiService.registerFcmToken,
      );
    } catch (e) {
      assert(() {
        debugPrint('FCM registration error: $e');
        return true;
      }());
    }
  }

  void _dismissError() => setState(() => _errorMessage = null);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.surface,
                      scheme.surfaceContainerLowest,
                    ]),
              ),
            ),
          ),

          // ── Decorative glow ──────────────────────────────────────────────
          Positioned(
            top: -80,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 520,
                height: 520,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    radius: 0.85,
                    colors: [
                      AppColors.blue(context)
                          .withValues(alpha: isDark ? 0.18 : 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 56),

                              // Logo
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 16),
                                  decoration: BoxDecoration(
                                    // Item #10: adapt to dark mode like SplashScreen
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.navyCard(context)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.blue(context)
                                            .withValues(alpha: 0.12),
                                        blurRadius: 24,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Image.asset(
                                    'assets/images/logo-colored.png',
                                    height: 48,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 44),

                              // Heading
                              Text(
                                'Welcome back.',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary(context),
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign in to your Finworks360 investor account',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 36),

                              // ── Email field ──────────────────────────────
                              TextField(
                                controller: _emailController,
                                focusNode: _emailFocusNode,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                style: TextStyle(
                                    color: AppColors.textPrimary(context)),
                                onChanged: (_) {
                                  if (_errorMessage != null) _dismissError();
                                },
                                onSubmitted: (_) {
                                  FocusScope.of(context)
                                      .requestFocus(_passwordFocusNode);
                                },
                                decoration: InputDecoration(
                                  labelText: 'Email address',
                                  labelStyle: TextStyle(
                                      color: AppColors.textSecondary(context)),
                                  prefixIcon: Icon(
                                    Icons.mail_outline_rounded,
                                    color: AppColors.textSecondary(context),
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // ── Password field ───────────────────────────
                              TextField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                keyboardType: TextInputType.visiblePassword,
                                obscureText: _obscurePassword,
                                enableSuggestions: false,
                                autocorrect: false,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                style: TextStyle(
                                    color: AppColors.textPrimary(context)),
                                onChanged: (_) {
                                  if (_errorMessage != null) _dismissError();
                                },
                                onSubmitted: (_) => _handleLogin(),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: TextStyle(
                                      color: AppColors.textSecondary(context)),
                                  prefixIcon: Icon(
                                    Icons.lock_outline_rounded,
                                    color: AppColors.textSecondary(context),
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.textSecondary(context),
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      await AppHaptics.selection();
                                      setState(() =>
                                          _obscurePassword = !_obscurePassword);
                                    },
                                  ),
                                ),
                              ),

                              // ── Forgot password ──────────────────────────
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () async {
                                    await AppHaptics.selection();
                                    // FIX #27: was a dead TODO. Now navigates to
                                    // the forgot-password flow. Replace the
                                    // showDialog below with your ForgotPasswordScreen
                                    // route when that screen is built.
                                    if (!context.mounted) return;
                                    // Item #4: user-friendly message instead of dev instructions
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Reset Password'),
                                        content: const Text(
                                            'Password reset is coming soon.\n\n'
                                            'For now, please contact support at\n'
                                            'support@finworks360.com to reset your password.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.primary(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),

                              // ── Error banner ─────────────────────────────
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                child: _errorMessage != null
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: AppColors.rose(context)
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: AppColors.rose(context)
                                                    .withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 1),
                                                child: Icon(
                                                  Icons.error_outline_rounded,
                                                  color:
                                                      AppColors.rose(context),
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _errorMessage!,
                                                  style: TextStyle(
                                                      color: AppColors.rose(
                                                          context),
                                                      fontSize: 13),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () async {
                                                  await AppHaptics.selection();
                                                  _dismissError();
                                                },
                                                child: Icon(
                                                  Icons.close_rounded,
                                                  color:
                                                      AppColors.rose(context),
                                                  size: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              const SizedBox(height: 16),

                              // ── Sign In button ───────────────────────────
                              // FIX #18: removed Pressable wrapper. Pressable.onTap
                              // and ElevatedButton.onPressed both called _handleLogin,
                              // firing it twice on every tap (safe due to _isLoading
                              // guard but unnecessary). ElevatedButton handles its
                              // own ink/press visuals.
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary(context),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        AppColors.primary(context)
                                            .withValues(alpha: 0.6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),

                              // ── Biometric section ────────────────────────
                              if (_biometricAvailable) ...[
                                const SizedBox(height: 28),
                                Row(
                                  children: [
                                    Expanded(
                                        child: Divider(
                                            color: AppColors.divider(context))),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                      child: Text(
                                        'or continue with',
                                        style: TextStyle(
                                          color:
                                              AppColors.textSecondary(context),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                        child: Divider(
                                            color: AppColors.divider(context))),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: Column(
                                    children: [
                                      GestureDetector(
                                        onTap: _isBiometricLoading
                                            ? null
                                            : () async {
                                                await AppHaptics.buttonPress();
                                                _handleBiometricLogin();
                                              },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: AppColors.primary(context)
                                                  .withValues(alpha: 0.4),
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            color: AppColors.primary(context)
                                                .withValues(alpha: 0.05),
                                          ),
                                          child: _isBiometricLoading
                                              ? SizedBox(
                                                  width: 28,
                                                  height: 28,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppColors.primary(
                                                        context),
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.fingerprint_rounded,
                                                  color: AppColors.primary(
                                                      context),
                                                  size: 36,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Fingerprint / Face ID',
                                        style: TextStyle(
                                          color:
                                              AppColors.textSecondary(context),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const Spacer(),

                              const SizedBox(height: 28),

                              // ── Sign up link ─────────────────────────────
                              Center(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary(context),
                                    ),
                                    children: [
                                      const TextSpan(
                                          text: "Don't have an account? "),
                                      TextSpan(
                                        text: 'Create one',
                                        style: TextStyle(
                                          color: AppColors.primary(context),
                                          fontWeight: FontWeight.w700,
                                        ),
                                        // FIX #11: use field recognizer, not inline
                                        recognizer: _signUpRecognizer,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ),
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
