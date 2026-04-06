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
import '../utils/app_haptics.dart';
import 'forgot_password_screen.dart';
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
  bool _is2FARequired = false;
  String? _userEmailFor2FA;
  final _otpController = TextEditingController();
  String? _errorMessage;

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
    _otpController.dispose();
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

      if (email == null || refreshToken == null) {
        if (mounted) {
          setState(() => _errorMessage =
              'No saved credentials. Please login with your password first.');
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('refresh_token', refreshToken);

      final refreshed = await ApiService.refreshWithStoredToken();
      if (!mounted) return;

      if (refreshed) {
        await AppHaptics.success();
        if (!mounted) return;
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
        navigatorKey.currentState!.pushAndRemoveUntil(
          SmoothPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
        _saveCredentialsInBackground(email, result['refresh'] as String? ?? '');
        _registerFcmInBackground();
      } else if (result['2fa_required'] == true) {
        await AppHaptics.buttonPress();
        setState(() {
          _is2FARequired = true;
          _userEmailFor2FA = result['email'];
        });
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

  Future<void> _handle2FAVerify() async {
    final token = _otpController.text.trim();
    if (token.length != 6) {
      setState(() => _errorMessage = 'Enter a valid 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.verify2FALogin(_userEmailFor2FA!, token);
      if (!mounted) return;

      if (result['success'] == true) {
        await AppHaptics.success();
        navigatorKey.currentState!.pushAndRemoveUntil(
          SmoothPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
        _saveCredentialsInBackground(_userEmailFor2FA!, result['refresh'] as String? ?? '');
        _registerFcmInBackground();
      } else {
        await AppHaptics.error();
        setState(() => _errorMessage = result['error'] as String?);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCredentialsInBackground(
      String email, String refreshToken) async {
    try {
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
      // ── FIX: resizeToAvoidBottomInset ensures the scaffold
      // resizes when the keyboard opens, working together with
      // SingleChildScrollView to prevent overflow. ──
      resizeToAvoidBottomInset: true,
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
                // ── FIX: Removed IntrinsicHeight + ConstrainedBox wrapper.
                // IntrinsicHeight forces the Column to its natural (unconstrained)
                // height, which overflows when the keyboard opens because the
                // Spacer tries to take infinite space inside IntrinsicHeight.
                //
                // Instead: just use SingleChildScrollView + Column.
                // The "sign up" link stays at the bottom via SizedBox spacing
                // instead of Spacer. ──
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
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

                        if (!_is2FARequired) ...[
                          // ── Email field ──────────────────────────────
                          TextField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            style:
                                TextStyle(color: AppColors.textPrimary(context)),
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
                            style:
                                TextStyle(color: AppColors.textPrimary(context)),
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
                                  setState(
                                      () => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                          ),
                        ] else ...[
                          // ── 2FA field ───────────────────────────────
                          Text(
                            'Institutional Shield is active. Enter the 6-digit code from your authenticator app.',
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 12,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '000000',
                              hintStyle: TextStyle(
                                  color: AppColors.textPrimary(context).withValues(alpha: 0.1)),
                              prefixIcon: Icon(
                                Icons.shield_outlined,
                                color: AppColors.success(context),
                              ),
                            ),
                            onSubmitted: (_) => _handle2FAVerify(),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => setState(() => _is2FARequired = false),
                            child: const Text('Back to login'),
                          ),
                        ],

                        // ── Forgot password ──────────────────────────
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () async {
                              await AppHaptics.selection();
                              if (!context.mounted) return;
                              Navigator.of(context).push(
                                SmoothPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen()),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.rose(context)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: AppColors.rose(context)
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 1),
                                          child: Icon(
                                            Icons.error_outline_rounded,
                                            color: AppColors.rose(context),
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: TextStyle(
                                                color: AppColors.rose(context),
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
                                            color: AppColors.rose(context),
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
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : (_is2FARequired ? _handle2FAVerify : _handleLogin),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _is2FARequired
                                    ? AppColors.success(context)
                                    : AppColors.primary(context),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    (_is2FARequired
                                            ? AppColors.success(context)
                                            : AppColors.primary(context))
                                        .withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
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
                                  : Text(
                                      _is2FARequired ? 'Verify Shield' : 'Sign In',
                                      style: const TextStyle(
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'or continue with',
                                  style: TextStyle(
                                    color: AppColors.textSecondary(context),
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
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.primary(context)
                                            .withValues(alpha: 0.4),
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      color: AppColors.primary(context)
                                          .withValues(alpha: 0.05),
                                    ),
                                    child: _isBiometricLoading
                                        ? SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primary(context),
                                            ),
                                          )
                                        : Icon(
                                            Icons.fingerprint_rounded,
                                            color: AppColors.primary(context),
                                            size: 36,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Fingerprint / Face ID',
                                  style: TextStyle(
                                    color: AppColors.textSecondary(context),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // ── FIX: replaced Spacer() with fixed spacing.
                        // Spacer inside IntrinsicHeight caused the overflow
                        // because IntrinsicHeight forces an infinite-height
                        // Spacer to compete with keyboard insets. ──
                        const SizedBox(height: 48),

                        // ── Sign up link ─────────────────────────────
                        Center(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary(context),
                              ),
                              children: [
                                const TextSpan(text: "Don't have an account? "),
                                TextSpan(
                                  text: 'Create one',
                                  style: TextStyle(
                                    color: AppColors.primary(context),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  recognizer: _signUpRecognizer,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Bottom padding (accounts for safe area)
                        SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 24),
                      ],
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
