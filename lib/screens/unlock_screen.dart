import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/screens/login_screen.dart';
import 'package:invoice_discounting_app/screens/main_screen.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();

  String? _name;
  bool _isAuthenticating = false;
  bool _failed = false;
  // FIX #28: specific message for lockout vs generic failure
  String _failMessage = 'Authentication failed. Try again.';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('user_data');
    if (data != null) {
      final user = jsonDecode(data) as Map<String, dynamic>;
      setState(() => _name = user['name'] as String?);
    }

    // FIX #10: only auto-prompt if a session actually exists.
    // Previously _authenticate() was called unconditionally, so the biometric
    // prompt appeared even on a fresh install or after logout — confusing
    // users who aren't even logged in yet.
    if (data == null) return;

    await Future<void>.delayed(const Duration(milliseconds: 400));
    _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    unawaited(AppHaptics.buttonPress());
    setState(() {
      _isAuthenticating = true;
      _failed = false;
    });

    try {
      final success = await _auth.authenticate(
        localizedReason: 'Authenticate to access Finworks360',
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushAndRemoveUntil(
          context,
          SmoothPageRoute<void>(builder: (_) => const MainScreen()),
          (route) => false,
        );
      } else {
        unawaited(AppHaptics.error());
        setState(() {
          _isAuthenticating = false;
          _failed = true;
        });
      }
    } on PlatformException catch (e) {
      // FIX #28: surface specific lockout messages instead of generic "failed"
      if (!mounted) return;
      unawaited(AppHaptics.error());
      var message = 'Authentication failed. Try again.';
      if (e.code == 'LockedOut') {
        message = 'Too many attempts. Wait a moment and try again.';
      } else if (e.code == 'PermanentlyLockedOut') {
        message = 'Biometrics locked. Use your device PIN or sign in below.';
      }
      setState(() {
        _isAuthenticating = false;
        _failed = true;
        _failMessage = message;
      });
    } catch (_) {
      if (!mounted) return;
      unawaited(AppHaptics.error());
      setState(() {
        _isAuthenticating = false;
        _failed = true;
        _failMessage = 'Authentication failed. Try again.';
      });
    }
  }

  Future<void> _goToLogin() async {
    unawaited(AppHaptics.selection());
    Navigator.pushAndRemoveUntil(
      context,
      SmoothPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF050508) : const Color(0xFFF8FAFF),
      body: Stack(
        children: [
          // ── Gradient background ──────────────────────────────────────────
          Positioned.fill(
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors:
                        UI.authGradient(isDark), // Item #35: shared gradient
                  ),
                ),
              ),
            ),
          ),

          // ── Blue glow ────────────────────────────────────────────────────
          Positioned(
            top: -80,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 480,
                height: 480,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.blue(context)
                          .withValues(alpha: isDark ? 0.15 : 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lock icon
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary(context).withValues(alpha: 0.12),
                      border: Border.all(
                        color:
                            AppColors.primary(context).withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      AppIcons.lock,
                      size: 40,
                      color: AppColors.primary(context),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Text(
                    _name == null
                        ? 'Unlock Finworks360'
                        : 'Welcome back,\n$_name',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),

                  const SizedBox(height: 10),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _failed ? _failMessage : 'Authenticate to continue',
                      key: ValueKey(_failed),
                      style: TextStyle(
                        fontSize: 14,
                        color: _failed
                            ? AppColors.rose(context)
                            : AppColors.textSecondary(context),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Fingerprint button ──────────────────────────────────
                  GestureDetector(
                    onTap: _authenticate,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _failed
                              ? AppColors.rose(context).withValues(alpha: 0.5)
                              : AppColors.primary(context)
                                  .withValues(alpha: 0.4),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: _failed
                            ? AppColors.rose(context).withValues(alpha: 0.06)
                            : AppColors.primary(context)
                                .withValues(alpha: 0.06),
                      ),
                      child: Icon(
                        AppIcons.fingerPrint,
                        size: 48,
                        color: _failed
                            ? AppColors.rose(context)
                            : AppColors.primary(context),
                      ),
                    ),
                  ),

                  const SizedBox(height: UI.md),

                  Text(
                    _isAuthenticating
                        ? 'Authenticating…'
                        : 'Tap to authenticate',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary(context),
                    ),
                  ),

                  // ── Sign in with password fallback ──────────────────────
                  if (_failed) ...[
                    const SizedBox(height: UI.xl),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        onPressed: _goToLogin,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.divider(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Sign in with password instead',
                          style: TextStyle(
                            color: AppColors.textSecondary(context),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
