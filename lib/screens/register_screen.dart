import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';

import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../theme/ui_constants.dart';
import '../utils/app_haptics.dart';
import 'login_screen.dart';
import 'verify_otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
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
  late CurvedAnimation _fadeCurve;
  late CurvedAnimation _slideCurve;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Password strength (0–4) ───────────────────────────────────────────────
  int _passwordStrength = 0;

  final _userTypes = [
    {
      'value': 'investor',
      'label': 'Investor',
      'icon': Icons.trending_up_rounded
    },
    {'value': 'seller', 'label': 'Seller', 'icon': Icons.store_rounded},
    {'value': 'debtor', 'label': 'Debtor', 'icon': Icons.receipt_long_rounded},
    {
      'value': 'business_partner',
      'label': 'Partner',
      'icon': Icons.handshake_rounded
    },
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeCurve =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _fadeAnim = _fadeCurve;
    _slideCurve =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(_slideCurve);
    _animController.forward();
    _passwordController.addListener(_evaluatePassword);
    _signInRecognizer = TapGestureRecognizer()
      ..onTap = () async {
        await AppHaptics.selection();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          SmoothPageRoute(builder: (_) => const LoginScreen()),
        );
      };
  }

  @override
  void dispose() {
    _fadeCurve.dispose();
    _slideCurve.dispose();
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
    int score = 0;
    if (p.length >= 8) score++;
    if (p.contains(RegExp(r'[A-Z]'))) score++;
    if (p.contains(RegExp(r'[0-9]'))) score++;
    if (p.contains(RegExp(r'[^A-Za-z0-9]'))) score++;
    setState(() => _passwordStrength = score);
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
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password needs an uppercase letter.';
    }
    if (!password.contains(RegExp(r'[0-9]'))) return 'Password needs a number.';
    if (!password.contains(RegExp(r'[^A-Za-z0-9]'))) {
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
        await AppHaptics.success();
        Navigator.of(context).push(
          SmoothPageRoute(
            builder: (_) => VerifyOtpScreen(
              email: _emailController.text.trim(),
              name: _nameController.text.trim(),
              password: _passwordController.text,
            ),
          ),
        );
      } else {
        await AppHaptics.error();
        setState(
                () => _errorMessage = result['error'] ?? 'Registration failed.');
      }
    } catch (_) {
      await AppHaptics.error();
      setState(() =>
      _errorMessage = 'Cannot connect to server. Check your network.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _dismissError() => setState(() => _errorMessage = null);

  // ── Strength helpers ──────────────────────────────────────────────────────
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Background gradient (matches login) ─────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surface,
                    scheme.surfaceContainerLowest,
                  ],
                ),
              ),
            ),
          ),

          // ── Decorative glow (matches login: 520px + IgnorePointer) ──────
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

          // ── Content ─────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      // ── Logo (matches login: dark-mode aware) ───────────
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: isDark
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

                      const SizedBox(height: 36),

                      // ── Heading ─────────────────────────────────────────
                      Text('Create account.',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                            height: 1.15,
                          )),
                      const SizedBox(height: 8),
                      Text('Join Finworks360 as an investor or partner',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary(context))),

                      const SizedBox(height: 28),

                      // ── Account type ────────────────────────────────────
                      Text('Account type',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary(context))),
                      const SizedBox(height: 10),
                      _buildUserTypeSelector(isDark),

                      const SizedBox(height: 20),

                      // ── Form fields ─────────────────────────────────────
                      _buildField(
                        controller: _nameController,
                        label: 'Full name',
                        icon: Icons.person_outline_rounded,
                        inputType: TextInputType.name,
                        capitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),

                      _buildField(
                        controller: _emailController,
                        label: 'Email address',
                        icon: Icons.mail_outline_rounded,
                        inputType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),

                      _buildField(
                        controller: _mobileController,
                        label: 'Mobile number',
                        icon: Icons.phone_outlined,
                        inputType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),

                      _buildField(
                        controller: _panController,
                        label: 'PAN number',
                        icon: Icons.credit_card_outlined,
                        capitalization: TextCapitalization.characters,
                        maxLength: 10,
                      ),
                      const SizedBox(height: 14),

                      // ── Password ────────────────────────────────────────
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: AppColors.textPrimary(context)),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(
                              color: AppColors.textSecondary(context)),
                          prefixIcon: Icon(Icons.lock_outline_rounded,
                              color: AppColors.textSecondary(context),
                              size: 20),
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

                      // ── Password strength bar ──────────────────────────
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: UI.sm),
                        Row(
                          children: [
                            ...List.generate(4, (i) {
                              return Expanded(
                                child: Container(
                                  height: 3,
                                  margin:
                                  EdgeInsets.only(right: i < 3 ? 4 : 0),
                                  decoration: BoxDecoration(
                                    color: i < _passwordStrength
                                        ? _strengthColor()
                                        : AppColors.divider(context),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(width: UI.sm),
                            Text(_strengthLabel(),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _strengthColor(),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),

                      // ── Confirm Password ───────────────────────────────
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirm,
                        style: TextStyle(color: AppColors.textPrimary(context)),
                        onSubmitted: (_) => _handleRegister(),
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          labelStyle: TextStyle(
                              color: AppColors.textSecondary(context)),
                          prefixIcon: Icon(Icons.lock_outline_rounded,
                              color: AppColors.textSecondary(context),
                              size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textSecondary(context),
                              size: 20,
                            ),
                            onPressed: () async {
                              await AppHaptics.selection();
                              setState(
                                  () => _obscureConfirm = !_obscureConfirm);
                            },
                          ),
                        ),
                      ),

                      // ── Error banner (matches login: AnimatedSize + dismiss) ──
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: _errorMessage != null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
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
                                        padding: const EdgeInsets.only(top: 1),
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

                      const SizedBox(height: 28),

                      // ── Create Account button ──────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(context),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.primary(context)
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
                                  strokeWidth: 2.5, color: Colors.white))
                              : const Text('Create Account',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Sign in link ───────────────────────────────────
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary(context)),
                            children: [
                              const TextSpan(text: 'Already have an account? '),
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
                          height: MediaQuery.of(context).padding.bottom + 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Account type pill selector ────────────────────────────────────────────
  Widget _buildUserTypeSelector(bool isDark) {
    return Row(
      children: _userTypes.asMap().entries.map((entry) {
        final type = entry.value;
        final isLast = entry.key == _userTypes.length - 1;
        final isSelected = _selectedUserType == type['value'];

        return Expanded(
          child: GestureDetector(
            onTap: () async {
              await AppHaptics.selection();
              setState(() => _selectedUserType = type['value'] as String);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: isLast ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary(context)
                    : (isDark ? AppColors.navyCard(context) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary(context)
                      : AppColors.divider(context),
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: AppColors.primary(context)
                        .withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
                    : [],
              ),
              child: Column(
                children: [
                  Icon(
                    type['icon'] as IconData,
                    size: 20,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondary(context),
                  ),
                  const SizedBox(height: UI.xs),
                  Text(
                    type['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
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
  }

  // ── Reusable text field ───────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    int? maxLength,
  }) {
    return TextField(
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
}