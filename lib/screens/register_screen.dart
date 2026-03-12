import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';

import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../theme/ui_constants.dart';
import '../utils/app_haptics.dart'; // Item #8
import 'login_screen.dart';
import 'verify_otp_screen.dart';

// Item #22: removed _kGreen — use AppColors.success(context) or emerald(context) instead

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

  // FIX #11: store recognizer as field so it can be disposed
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
    // FIX #11: initialize here, not inline in build()
    _signInRecognizer = TapGestureRecognizer()
      ..onTap = () {
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
    _signInRecognizer.dispose(); // FIX #11
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
    // FIX #12: proper email regex — old check (!email.contains('@')) passed
    // values like '@', 'a@', '@b' as valid emails
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    // FIX #29: exact 10-digit Indian mobile starting with 6-9
    // old check (mobile.length < 10) accepted 15-digit numbers
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(mobile)) {
      return 'Enter a valid 10-digit Indian mobile number.';
    }
    // FIX #13: validate PAN format [A-Z]{5}[0-9]{4}[A-Z] — old check only
    // verified length, accepting strings like 'AAAAAAAAAA'
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
        await AppHaptics.success(); // Item #8
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
        await AppHaptics.error(); // Item #8
        setState(
                () => _errorMessage = result['error'] ?? 'Registration failed.');
      }
    } catch (_) {
      await AppHaptics.error(); // Item #8
      setState(() =>
      _errorMessage = 'Cannot connect to server. Check your network.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
        return AppColors.success(context); // Item #22: was _kGreen
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

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: UI.authGradient(isDark), // Item #35: shared gradient
                ),
              ),
            ),
          ),

          // Blue glow
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.blue(context)
                      .withValues(alpha: isDark ? 0.15 : 0.08),
                  Colors.transparent,
                ]),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),

                      // Logo
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: UI.lg, vertical: UI.md),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.blue(context)
                                    .withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 4),
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

                      const SizedBox(height: 36),

                      Text('Create account.',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                            height: 1.15,
                          )),
                      const SizedBox(height: 6),
                      Text('Join Finworks360 as an investor or partner',
                          style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary(context))),

                      const SizedBox(height: 28),

                      // Account type selector
                      Text('Account type',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary(context))),
                      const SizedBox(height: 10),
                      _buildUserTypeSelector(isDark),

                      const SizedBox(height: 20),

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

                      // Password
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
                            onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),

                      // Password strength bar
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

                      // Confirm Password
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
                            onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                      ),

                      // Error
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color:
                            AppColors.rose(context).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.rose(context)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  color: AppColors.rose(context), size: 16),
                              const SizedBox(width: UI.sm),
                              Expanded(
                                child: Text(_errorMessage!,
                                    style: TextStyle(
                                        color: AppColors.rose(context),
                                        fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      // Create Account button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary(context),
                            foregroundColor: Colors.white,
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

                      // Already have account
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
                                // FIX #11: use stored recognizer
                                recognizer: _signInRecognizer,
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
            onTap: () =>
                setState(() => _selectedUserType = type['value'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: isLast ? 0 : 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary(context)
                    : (isDark ? const Color(0xFF1A2540) : Colors.white),
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