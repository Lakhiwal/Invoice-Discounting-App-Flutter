import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/screens/login_screen.dart';
import 'package:invoice_discounting_app/screens/verify_otp_screen.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _panController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  String _selectedUserType = 'investor';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  late final TapGestureRecognizer _signInRecognizer;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Password strength (0–4) ───────────────────────────────────────────────
  int _passwordStrength = 0;

  final List<Map<String, Object>> _userTypes = [
    {
      'value': 'investor',
      'label': 'Investor',
      'icon': AppIcons.trendingUp,
      'desc': 'Invest in invoices',
    },
    {
      'value': 'business_partner',
      'label': 'Partner',
      'icon': AppIcons.partner,
      'desc': 'Business collaboration',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
    _passwordController.addListener(_evaluatePassword);
    _signInRecognizer = TapGestureRecognizer()
      ..onTap = () async {
        unawaited(AppHaptics.selection());
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          SmoothPageRoute<void>(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      };
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _panController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _signInRecognizer.dispose();
    super.dispose();
  }

  // ── Password strength ─────────────────────────────────────────────────────
  void _evaluatePassword() {
    final p = _passwordController.text;
    var score = 0;
    if (p.length >= 8) score++;
    if (p.contains(RegExp('[A-Z]'))) score++;
    if (p.contains(RegExp('[0-9]'))) score++;
    if (p.contains(RegExp('[^A-Za-z0-9]'))) score++;
    setState(() => _passwordStrength = score);
  }

  Color _strengthColor() {
    switch (_passwordStrength) {
      case 1:
        return AppColors.rose(context);
      case 2:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 4:
        return AppColors.success(context);
      default:
        return Colors.transparent;
    }
  }

  String _strengthLabel() {
    switch (_passwordStrength) {
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return '';
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────
  String? _validate() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final mobile = _mobileController.text.trim();
    final pan = _panController.text.trim().toUpperCase();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.isEmpty) return 'Full name is required.';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
      return 'Enter a valid 10-digit Indian mobile number.';
    }
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
      return 'Enter a valid PAN number (e.g. ABCDE1234F).';
    }
    if (password.length < 8) return 'Password must be at least 8 characters.';
    if (!password.contains(RegExp('[A-Z]'))) {
      return 'Password needs an uppercase letter.';
    }
    if (!password.contains(RegExp('[0-9]'))) return 'Password needs a number.';
    if (!password.contains(RegExp('[^A-Za-z0-9]'))) {
      return 'Password needs a special character.';
    }
    if (password != confirm) return 'Passwords do not match.';
    return null;
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();

    final error = _validate();
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobile: _mobileController.text.trim(),
        panNumber: _panController.text.trim().toUpperCase(),
        password: _passwordController.text,
        userType: _selectedUserType,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        unawaited(AppHaptics.success());
        Navigator.of(context).push(
          SmoothPageRoute<void>(
            builder: (_) => VerifyOtpScreen(
              email: _emailController.text.trim(),
              name: _nameController.text.trim(),
              password: _passwordController.text,
            ),
          ),
        );
      } else {
        unawaited(AppHaptics.error());
        setState(
          () => _errorMessage =
              (result['error'] as String?) ?? 'Registration failed.',
        );
      }
    } catch (_) {
      unawaited(AppHaptics.error());
      setState(
        () => _errorMessage = 'Cannot connect to server. Check your network.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _dismissError() => setState(() => _errorMessage = null);

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // ── Decorative glow (matches login) ─────────────────────────────
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

          // ── Content ─────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: IntrinsicHeight(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 40),

                              // ── Logo (matches login: dark-mode aware) ───────────
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.navyCard(context)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(UI.radiusLg),
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

                              const SizedBox(height: 36),

                              // ── Heading ─────────────────────────────────────────
                              Text(
                                'Create account.',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary(context),
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Join Finworks360 as an investor or partner',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),

                              const SizedBox(height: 28),

                              // ── Account type ────────────────────────────────────
                              Text(
                                'Account type',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildUserTypeSelector(isDark),

                              const SizedBox(height: 20),

                              // ── Form fields ─────────────────────────────────────
                              _buildField(
                                controller: _nameController,
                                label: 'Full name',
                                icon: AppIcons.user,
                                inputType: TextInputType.name,
                                capitalization: TextCapitalization.words,
                              ),
                              const SizedBox(height: 14),

                              _buildField(
                                controller: _emailController,
                                label: 'Email address',
                                icon: AppIcons.mail,
                                inputType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 14),

                              _buildField(
                                controller: _mobileController,
                                label: 'Mobile number',
                                icon: AppIcons.phone,
                                inputType: TextInputType.phone,
                              ),
                              const SizedBox(height: 14),

                              _buildField(
                                controller: _panController,
                                label: 'PAN number',
                                icon: AppIcons.card,
                                capitalization: TextCapitalization.characters,
                                maxLength: 10,
                              ),
                              const SizedBox(height: 14),

                              // ── Password ────────────────────────────────────────
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  labelStyle: TextStyle(
                                    color: AppColors.textSecondary(context),
                                  ),
                                  prefixIcon: Icon(
                                    AppIcons.lock,
                                    color: AppColors.textSecondary(context),
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? AppIcons.eyeSlash
                                          : AppIcons.eye,
                                      color: AppColors.textSecondary(context),
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      unawaited(AppHaptics.selection());
                                      setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      );
                                    },
                                  ),
                                ),
                              ),

                              // ── Password strength bar ──────────────────────────
                              if (_passwordController.text.isNotEmpty) ...[
                                const SizedBox(height: UI.sm),
                                Row(
                                  children: [
                                    ...List.generate(
                                      4,
                                      (i) => Expanded(
                                        child: Container(
                                          height: 3,
                                          margin: EdgeInsets.only(
                                            right: i < 3 ? 4 : 0,
                                          ),
                                          decoration: BoxDecoration(
                                            color: i < _passwordStrength
                                                ? _strengthColor()
                                                : AppColors.divider(context),
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: UI.sm),
                                    Text(
                                      _strengthLabel(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _strengthColor(),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 14),

                              // ── Confirm Password ───────────────────────────────
                              TextField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirm,
                                style: TextStyle(
                                  color: AppColors.textPrimary(context),
                                ),
                                onSubmitted: (_) => _handleRegister(),
                                decoration: InputDecoration(
                                  labelText: 'Confirm password',
                                  labelStyle: TextStyle(
                                    color: AppColors.textSecondary(context),
                                  ),
                                  prefixIcon: Icon(
                                    AppIcons.lock,
                                    color: AppColors.textSecondary(context),
                                    size: 20,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? AppIcons.eyeSlash
                                          : AppIcons.eye,
                                      color: AppColors.textSecondary(context),
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      unawaited(AppHaptics.selection());
                                      setState(
                                        () =>
                                            _obscureConfirm = !_obscureConfirm,
                                      );
                                    },
                                  ),
                                ),
                              ),

                              // ── Error banner ──────────────────────────────────
                              AnimatedSize(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                child: _errorMessage != null
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Container(
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
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 1,
                                                ),
                                                child: Icon(
                                                  AppIcons.error,
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
                                                      context,
                                                    ),
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () async {
                                                  unawaited(
                                                      AppHaptics.selection(),);
                                                  _dismissError();
                                                },
                                                child: Icon(
                                                  AppIcons.close,
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

                              const Spacer(),
                              const SizedBox(height: 32),

                              // ── Create Account button ──────────────────────────
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary(context),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        AppColors.primary(context)
                                            .withValues(alpha: 0.6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(UI.radiusMd),
                                    ),
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
                                          'Create Account',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 28),

                              // ── Sign in link ───────────────────────────────────
                              Center(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary(context),
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: 'Already have an account? ',
                                      ),
                                      TextSpan(
                                        text: 'Sign in',
                                        style: TextStyle(
                                          color: AppColors.primary(context),
                                          fontWeight: FontWeight.w700,
                                        ),
                                        recognizer: _signInRecognizer,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ── Bottom padding ─────────────────────────────────
                              SizedBox(
                                height:
                                    MediaQuery.of(context).padding.bottom + 24,
                              ),
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
    ),
    );
  }

  // ── Account type pill selector ────────────────────────────────────────────
  Widget _buildUserTypeSelector(bool isDark) => Row(
        children: _userTypes.asMap().entries.map((entry) {
          final type = entry.value;
          final isLast = entry.key == _userTypes.length - 1;
          final isSelected = _selectedUserType == type['value'];

          return Expanded(
            child: GestureDetector(
              onTap: () async {
                unawaited(AppHaptics.selection());
                setState(() => _selectedUserType = type['value']! as String);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: isLast ? 0 : 12),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary(context)
                      : (isDark ? AppColors.navyCard(context) : Colors.white),
                  borderRadius: BorderRadius.circular(UI.radiusMd),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary(context)
                        : AppColors.divider(context),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary(context)
                                .withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  children: [
                    Icon(
                      type['icon']! as IconData,
                      size: 26,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      type['label']! as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type['desc']! as String,
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );

  // ── Reusable text field ───────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    int? maxLength,
  }) =>
      TextField(
        controller: controller,
        keyboardType: inputType,
        textCapitalization: capitalization,
        maxLength: maxLength,
        style: TextStyle(color: AppColors.textPrimary(context)),
        onChanged: (_) {
          if (_errorMessage != null) _dismissError();
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppColors.textSecondary(context)),
          prefixIcon:
              Icon(icon, color: AppColors.textSecondary(context), size: 20),
          counterText: '',
        ),
      );
}
