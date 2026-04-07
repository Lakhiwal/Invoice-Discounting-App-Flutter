import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/auth/login_form.dart';
import '../widgets/auth/shield_verification_form.dart';
import '../theme/ui_constants.dart';
import 'forgot_password_screen.dart';
import 'main_screen.dart';

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
      ref.read(authViewModelProvider).checkBiometrics();
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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
        auth.resetStatus();
      });
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: UI.authGradient(isDark),
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Center(child: Image.asset('assets/images/logo-colored.png', height: 48)),
                const SizedBox(height: UI.xl * 2),

                AnimatedSwitcher(
                  duration: UI.normal,
                  child: auth.status == AuthStatus.needs2FA
                      ? const ShieldVerificationForm(key: ValueKey('shield'))
                      : LoginForm(
                        key: const ValueKey('login'),
                        onForgotPassword: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                          );
                        },
                      ),
                ),

                if (auth.errorMessage != null && auth.status == AuthStatus.error) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      auth.errorMessage!,
                      style: TextStyle(color: cs.error, fontSize: 13, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const SizedBox(height: UI.xl),

                if (auth.status != AuthStatus.needs2FA)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                      },
                      child: Text('Forgot Password?', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700)),
                    ),
                  ),

                const SizedBox(height: 48),

                Center(
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('By continuing, you agree to our', style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 11)),
                      TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        onPressed: () {},
                        child: Text('Terms of Service', style: TextStyle(color: cs.primary.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                      ),
                    ],
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
