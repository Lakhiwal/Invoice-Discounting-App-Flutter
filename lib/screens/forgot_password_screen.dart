import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart';
import '../utils/smooth_page_route.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // ── Step: 0 = email, 1 = OTP, 2 = new password ─────────────────────────
  int _step = 0;

  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _otpFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _loading = false;
  String? _error;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // Resend OTP cooldown
  int _resendCooldown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _emailFocus.dispose();
    _otpFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _dismissError() => setState(() => _error = null);

  // ── Step 1: Request OTP ─────────────────────────────────────────────────

  Future<void> _requestOtp() async {
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.forgotPassword(email: email);
      if (!mounted) return;

      if (result['success'] == true) {
        await AppHaptics.success();
        setState(() {
          _step = 1;
          _loading = false;
        });
        _startResendCooldown();
        // Auto-focus OTP field
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _otpFocus.requestFocus();
        });
      } else {
        await AppHaptics.error();
        setState(() {
          _loading = false;
          _error = result['error'] as String? ?? 'Failed to send OTP.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      await AppHaptics.error();
      setState(() {
        _loading = false;
        _error = 'Connection error. Please check your network.';
      });
    }
  }

  // ── Step 2: Verify OTP + Reset Password ─────────────────────────────────

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    final otp = _otpCtrl.text.trim();
    final password = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (otp.isEmpty || otp.length < 6) {
      setState(() => _error = 'Please enter the 6-digit OTP.');
      return;
    }

    if (password.isEmpty) {
      setState(() => _error = 'Please enter a new password.');
      return;
    }

    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    // Strong password check
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[^A-Za-z0-9]').hasMatch(password);

    if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
      setState(() => _error =
      'Password needs uppercase, lowercase, number, and special character.');
      return;
    }

    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.resetPassword(
        email: _emailCtrl.text.trim(),
        otp: otp,
        newPassword: password,
      );
      if (!mounted) return;

      if (result['success'] == true) {
        await AppHaptics.success();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successful. Please sign in.'),
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.of(context).pushAndRemoveUntil(
          SmoothPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      } else {
        await AppHaptics.error();
        setState(() {
          _loading = false;
          _error = result['error'] as String? ?? 'Reset failed.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      await AppHaptics.error();
      setState(() {
        _loading = false;
        _error = 'Connection error. Please check your network.';
      });
    }
  }

  // ── Resend OTP ──────────────────────────────────────────────────────────

  void _startResendCooldown() {
    _resendCooldown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _resendOtp() async {
    if (_resendCooldown > 0) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result =
      await ApiService.resendOtp(email: _emailCtrl.text.trim());
      if (!mounted) return;

      if (result['success'] == true) {
        await AppHaptics.selection();
        _startResendCooldown();
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New OTP sent to your email.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _loading = false;
          _error = result['error'] as String?;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to resend OTP.';
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_loading,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: _loading
              ? null
              : IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: colorScheme.onSurface, size: 18),
            onPressed: () {
              if (_step > 0 && !_loading) {
                setState(() {
                  _step--;
                  _error = null;
                });
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            'Reset Password',
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        body: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // ── Step indicator ──────────────────────────────────────
              _StepIndicator(currentStep: _step),
              const SizedBox(height: 32),

              // ── Step content ────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: switch (_step) {
                  0 => _buildEmailStep(colorScheme),
                  1 => _buildOtpAndPasswordStep(colorScheme),
                  _ => const SizedBox.shrink(),
                },
              ),

              // ── Error banner ────────────────────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _error != null
                    ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                          colorScheme.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(Icons.error_outline_rounded,
                              color: colorScheme.error, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: TextStyle(
                                  color: colorScheme.error,
                                  fontSize: 13)),
                        ),
                        GestureDetector(
                          onTap: _dismissError,
                          child: Icon(Icons.close_rounded,
                              color: colorScheme.error, size: 16),
                        ),
                      ],
                    ),
                  ),
                )
                    : const SizedBox.shrink(),
              ),

              SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 0: Email ──────────────────────────────────────────────────────

  Widget _buildEmailStep(ColorScheme cs) {
    return Column(
      key: const ValueKey('email_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Forgot your password?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your registered email and we\'ll send you a verification code.',
          style: TextStyle(
            fontSize: 14,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _emailCtrl,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          enabled: !_loading,
          onChanged: (_) {
            if (_error != null) _dismissError();
          },
          onSubmitted: (_) => _requestOtp(),
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            labelText: 'Email address',
            labelStyle: TextStyle(color: cs.onSurfaceVariant),
            prefixIcon: Icon(Icons.mail_outline_rounded,
                color: cs.onSurfaceVariant, size: 20),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _requestOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              disabledBackgroundColor: cs.primary.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white),
            )
                : const Text('Send OTP',
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  // ── Step 1: OTP + New Password (combined) ──────────────────────────────

  Widget _buildOtpAndPasswordStep(ColorScheme cs) {
    return Column(
      key: const ValueKey('otp_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter verification code',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            children: [
              const TextSpan(text: 'We sent a 6-digit code to '),
              TextSpan(
                text: _emailCtrl.text.trim(),
                style: TextStyle(
                    color: cs.onSurface, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // OTP field
        TextField(
          controller: _otpCtrl,
          focusNode: _otpFocus,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          enabled: !_loading,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) {
            if (_error != null) _dismissError();
          },
          onSubmitted: (_) => _passFocus.requestFocus(),
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 12,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 12,
            ),
          ),
        ),

        // Resend OTP
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed:
            _resendCooldown > 0 || _loading ? null : _resendOtp,
            style: TextButton.styleFrom(
              padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _resendCooldown > 0
                  ? 'Resend in ${_resendCooldown}s'
                  : 'Resend OTP',
              style: TextStyle(
                fontSize: 13,
                color: _resendCooldown > 0
                    ? cs.onSurfaceVariant
                    : cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // New password
        TextField(
          controller: _passCtrl,
          focusNode: _passFocus,
          obscureText: _obscurePass,
          textInputAction: TextInputAction.next,
          enabled: !_loading,
          onChanged: (_) {
            if (_error != null) _dismissError();
          },
          onSubmitted: (_) => _confirmFocus.requestFocus(),
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            labelText: 'New Password',
            labelStyle: TextStyle(color: cs.onSurfaceVariant),
            prefixIcon: Icon(Icons.lock_outline_rounded,
                color: cs.onSurfaceVariant, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
              onPressed: _loading
                  ? null
                  : () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Confirm password
        TextField(
          controller: _confirmCtrl,
          focusNode: _confirmFocus,
          obscureText: _obscureConfirm,
          textInputAction: TextInputAction.done,
          enabled: !_loading,
          onChanged: (_) {
            if (_error != null) _dismissError();
          },
          onSubmitted: (_) => _resetPassword(),
          style: TextStyle(color: cs.onSurface),
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            labelStyle: TextStyle(color: cs.onSurfaceVariant),
            prefixIcon: Icon(Icons.check_circle_outline_rounded,
                color: cs.onSurfaceVariant, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
              onPressed: _loading
                  ? null
                  : () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Password requirements hint
        _PasswordHint(password: _passCtrl.text),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              disabledBackgroundColor: cs.primary.withValues(alpha: 0.6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white),
            )
                : const Text('Reset Password',
                style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        _StepDot(
            label: 'Email', active: currentStep >= 0, completed: currentStep > 0),
        Expanded(
          child: Container(
            height: 2,
            color: currentStep > 0
                ? cs.primary
                : cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        _StepDot(
            label: 'Reset', active: currentStep >= 1, completed: false),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool active;
  final bool completed;

  const _StepDot({
    required this.label,
    required this.active,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? cs.primary : cs.surfaceContainerHighest,
            border: Border.all(
              color: active ? cs.primary : cs.outlineVariant.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: completed
                ? Icon(Icons.check_rounded, color: cs.onPrimary, size: 14)
                : Text(
              active ? '●' : '○',
              style: TextStyle(
                color: active ? cs.onPrimary : cs.onSurfaceVariant,
                fontSize: 8,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active ? cs.onSurface : cs.onSurfaceVariant,
            fontSize: 10,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _PasswordHint extends StatelessWidget {
  final String password;
  const _PasswordHint({required this.password});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (password.isEmpty) return const SizedBox.shrink();

    final checks = [
      (RegExp(r'.{8,}').hasMatch(password), '8+ characters'),
      (RegExp(r'[A-Z]').hasMatch(password), 'Uppercase'),
      (RegExp(r'[a-z]').hasMatch(password), 'Lowercase'),
      (RegExp(r'[0-9]').hasMatch(password), 'Number'),
      (RegExp(r'[^A-Za-z0-9]').hasMatch(password), 'Special char'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: checks.map((c) {
        final (passed, label) = c;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              passed
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              size: 14,
              color: passed
                  ? AppColors.success(context)
                  : cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: passed
                    ? AppColors.success(context)
                    : cs.onSurfaceVariant.withValues(alpha: 0.6),
                fontWeight: passed ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}