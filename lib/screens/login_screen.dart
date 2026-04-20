import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/screens/forgot_password_screen.dart';
import 'package:invoice_discounting_app/screens/main_screen.dart';
import 'package:invoice_discounting_app/screens/register_screen.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:invoice_discounting_app/view_models/auth_view_model.dart';
import 'package:invoice_discounting_app/widgets/auth/login_form.dart';
import 'package:invoice_discounting_app/widgets/auth/shield_verification_form.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-check for saved credentials for biometric display
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(authViewModelProvider).checkBiometrics());
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    // Handle navigation on successful authentication
    if (auth.status == AuthStatus.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          Navigator.of(context).pushReplacement(
            SmoothPageRoute<void>(builder: (_) => const MainScreen()),
          ),
        );
        auth.resetStatus();
      });
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: UI.authGradient(isDark),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
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
                        if (isDark)
                          cs.primary.withValues(alpha: 0.15)
                        else
                          cs.primary.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────────
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 40),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? cs.surfaceContainerHigh
                                      : Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(UI.radiusLg),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cs.primary.withValues(alpha: 0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Hero(
                                  tag: 'app_logo_hero',
                                  child: Image.asset(
                                    'assets/images/logo-colored.png',
                                    height: 48,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: UI.xl * 1.5),

                            AnimatedSwitcher(
                              duration: UI.normal,
                              child: auth.status == AuthStatus.needs2FA
                                  ? const ShieldVerificationForm(
                                      key: ValueKey('shield'),
                                    )
                                  : LoginForm(
                                      key: const ValueKey('login'),
                                      onForgotPassword: () {
                                        AppHaptics.selection();
                                        unawaited(
                                          Navigator.push<void>(
                                            context,
                                            SmoothPageRoute<void>(
                                              builder: (_) =>
                                                  const ForgotPasswordScreen(),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),

                            if (auth.errorMessage != null &&
                                auth.status == AuthStatus.error) ...[
                              const SizedBox(height: 16),
                              Center(
                                child: Text(
                                  auth.errorMessage!,
                                  style: TextStyle(
                                    color: cs.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],

                            const Spacer(),
                            const SizedBox(height: 32),

                            // ── Register link ─────────────────────────────────────────
                            if (auth.status != AuthStatus.needs2FA)
                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    AppHaptics.selection();
                                    unawaited(
                                      Navigator.push<void>(
                                        context,
                                        SmoothPageRoute<void>(
                                          builder: (_) =>
                                              const RegisterScreen(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: RichText(
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: cs.onSurfaceVariant
                                            .withValues(alpha: 0.8),
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: "Don't have an account? ",
                                        ),
                                        TextSpan(
                                          text: 'Sign Up',
                                          style: TextStyle(
                                            color: cs.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 48),

                            Center(
                              child: Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'By continuing, you agree to our',
                                    style: TextStyle(
                                      color: cs.onSurfaceVariant
                                          .withValues(alpha: 0.6),
                                      fontSize: 11,
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: AppHaptics.selection,
                                    child: Text(
                                      'Terms of Service',
                                      style: TextStyle(
                                        color:
                                            cs.primary.withValues(alpha: 0.8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ── Bottom padding for safe area ──────────────────
                            SizedBox(
                              height: MediaQuery.of(context).padding.bottom + 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
