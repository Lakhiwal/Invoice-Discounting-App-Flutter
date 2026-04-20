import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/screens/basic_information_screen.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';

const Color _kGreen = Color(0xFF10B981);

class VerifyOtpScreen extends ConsumerStatefulWidget {
  // still needed for initial login after OTP

  const VerifyOtpScreen({
    required this.email,
    required this.name,
    required this.password,
    super.key,
  });
  final String email;
  final String name;
  final String password;

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen>
    with SingleTickerProviderStateMixin {
  // ── OTP fields ─────────────────────────────────────────────────────────────
  static const int _otpLength = 6;
  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  // ── State ──────────────────────────────────────────────────────────────────
  bool _isVerifying = false;
  bool _isResending = false;
  bool _verified = false;
  String? _errorMessage;

  // ── Countdown timer ────────────────────────────────────────────────────────
  int _secondsLeft = 60;
  Timer? _timer;

  bool get _canResend => _secondsLeft == 0;

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    unawaited(_animController.forward());
    _startTimer();
  }

  @override
  void dispose() {
    _animController.dispose();
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  // ── Verify ─────────────────────────────────────────────────────────────────
  Future<void> _handleVerify() async {
    if (_otp.length != _otpLength) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit OTP.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final result =
          await ApiService.verifyEmailOtp(email: widget.email, otp: _otp);

      if (!mounted) return;

      if (result['success'] == true) {
        unawaited(AppHaptics.success());
        setState(() => _verified = true);
        _timer?.cancel();

        // One-time login ensures the user gets a local session token
        final loginResult = await ApiService.login(
          widget.email,
          widget.password,
        );

        if (!mounted) return;

        if (loginResult['success'] != true) {
          // Login failed — show error but keep verified state
          setState(() {
            _verified = false;
            _errorMessage = loginResult['error'] as String? ??
                'Login failed after verification. Please try logging in manually.';
          });
          return;
        }

        await Future<void>.delayed(const Duration(milliseconds: 1200));
        if (!mounted) return;

        unawaited(
          Navigator.of(context).pushReplacement(
            SmoothPageRoute<void>(
              builder: (_) => const BasicInformationScreen(),
            ),
          ),
        );
      } else {
        unawaited(AppHaptics.error());
        setState(
          () => _errorMessage =
              (result['error'] as String?) ?? 'Invalid OTP. Please try again.',
        );
        _clearOtp();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Cannot connect to server. Check your network.',
        );
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ── Resend ─────────────────────────────────────────────────────────────────
  Future<void> _handleResend() async {
    if (!_canResend) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.resendOtp(email: widget.email);
      if (!mounted) return;

      if (result['success'] == true) {
        _startTimer();
        _clearOtp();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('OTP sent successfully!'),
            backgroundColor: _kGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UI.radiusSm),),
          ),
        );
      } else {
        setState(
          () => _errorMessage =
              (result['error'] as String?) ?? 'Failed to resend OTP.',
        );
      }
    } catch (_) {
      setState(() => _errorMessage = 'Network error. Try again.');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _clearOtp() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_isVerifying,
      onPopInvokedWithResult: (didPop, result) {
        // can handle extra cleanup here if needed
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffold(context),
        body: Stack(
          children: [
            // Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: UI.authGradient(isDark),
                  ),
                ),
              ),
            ),

            // Glow
            Positioned(
              top: -60,
              left: -60,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.blue(context)
                          .withValues(alpha: isDark ? 0.12 : 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const SizedBox(height: UI.lg),

                        // Back button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () {
                              AppHaptics.selection();
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1A2540)
                                    : Colors.white,
                                borderRadius:
                                    BorderRadius.circular(UI.radiusMd),
                                border: Border.all(
                                  color: AppColors.divider(context),
                                ),
                              ),
                              child: Icon(
                                AppIcons.back,
                                size: 18,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        if (_verified)
                          _buildSuccessState(context)
                        else ...[
                          _buildEmailIcon(context),
                          const SizedBox(height: 28),
                          Text(
                            'Verify your email',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(context),
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary(context),
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(
                                  text: "We've sent a 6-digit code to\n",
                                ),
                                TextSpan(
                                  text: widget.email,
                                  style: TextStyle(
                                    color: AppColors.primary(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          _buildOtpBoxes(isDark),
                          const SizedBox(height: 12),
                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.rose(context)
                                    .withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(UI.radiusSm),
                                border: Border.all(
                                  color: AppColors.rose(context)
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    AppIcons.error,
                                    color: AppColors.rose(context),
                                    size: 16,
                                  ),
                                  const SizedBox(width: UI.sm),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: AppColors.rose(context),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isVerifying ? null : _handleVerify,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary(context),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(UI.radiusMd),
                                ),
                                elevation: 0,
                              ),
                              child: _isVerifying
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Verify Email',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: UI.lg),
                          _buildResendSection(context),
                          const SizedBox(height: UI.xl),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1A2540)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(UI.radiusMd),
                              border:
                                  Border.all(color: AppColors.divider(context)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  AppIcons.shield,
                                  color: AppColors.primary(context),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'This OTP expires in 5 minutes. Never share it with anyone.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ],
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

  Widget _buildOtpBoxes(bool isDark) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _otpLength,
          (i) => Container(
            width: 48,
            height: 56,
            margin: EdgeInsets.only(right: i < _otpLength - 1 ? 8 : 0),
            child: TextField(
              controller: _controllers[i],
              focusNode: _focusNodes[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(1),
              ],
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
              decoration: InputDecoration(
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: isDark ? const Color(0xFF1A2540) : Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UI.radiusMd),
                  borderSide:
                      BorderSide(color: AppColors.divider(context), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UI.radiusMd),
                  borderSide:
                      BorderSide(color: AppColors.primary(context), width: 2),
                ),
              ),
              onChanged: (val) {
                if (val.length > 1) {
                  final digits = val.replaceAll(RegExp(r'\D'), '');
                  for (var j = 0; j < _otpLength && j < digits.length; j++) {
                    _controllers[j].text = digits[j];
                  }
                  final nextEmpty = digits.length < _otpLength
                      ? digits.length
                      : _otpLength - 1;
                  _focusNodes[nextEmpty].requestFocus();
                  if (digits.length == _otpLength) _handleVerify();
                  return;
                }
                if (val.isNotEmpty && i < _otpLength - 1) {
                  _focusNodes[i + 1].requestFocus();
                }
                if (_otp.length == _otpLength) _handleVerify();
              },
              onTap: () {
                _controllers[i].selection = TextSelection.fromPosition(
                  TextPosition(offset: _controllers[i].text.length),
                );
              },
            ),
          ),
        ),
      );

  Widget _buildResendSection(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Didn't receive the code? ",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(context),
            ),
          ),
          if (_isResending)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary(context),
              ),
            )
          else if (_canResend)
            GestureDetector(
              onTap: _handleResend,
              child: Text(
                'Resend OTP',
                style: TextStyle(
                  color: AppColors.primary(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Text(
              'Resend in 0:${_secondsLeft.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      );

  Widget _buildEmailIcon(BuildContext context) => Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary(context).withValues(alpha: 0.15),
              AppColors.blue(context).withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(
            color: AppColors.primary(context).withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Icon(
          AppIcons.mail,
          size: 38,
          color: AppColors.primary(context),
        ),
      );

  Widget _buildSuccessState(BuildContext context) => Column(
        children: [
          const SizedBox(height: 40),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, val, child) =>
                Transform.scale(scale: val, child: child),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kGreen.withValues(alpha: 0.12),
                border:
                    Border.all(color: _kGreen.withValues(alpha: 0.4), width: 2),
              ),
              child: Icon(AppIcons.check, size: 48, color: _kGreen),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Email Verified!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Opening your profile…\nFill in your details to complete setup.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(context),
              height: 1.6,
            ),
          ),
          const SizedBox(height: UI.xl),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary(context),
            ),
          ),
        ],
      );
}
