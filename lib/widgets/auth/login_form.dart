import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/view_models/auth_view_model.dart';

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({required this.onForgotPassword, super.key});
  final VoidCallback onForgotPassword;

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final auth = ref.read(authViewModelProvider);
    auth.login(_emailController.text, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email address
        Text(
          'Email address',
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Enter your email',
            prefixIcon: Icon(AppIcons.mail, color: cs.primary, size: 20),
          ),
          onSubmitted: (_) =>
              FocusScope.of(context).requestFocus(_passwordFocusNode),
        ),

        const SizedBox(height: 20),

        // Password
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: widget.onForgotPassword,
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  color: cs.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          focusNode: _passwordFocusNode,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            prefixIcon: Icon(AppIcons.lock, color: cs.primary, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? AppIcons.eyeSlash : AppIcons.eye,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          onSubmitted: (_) => _handleLogin(),
        ),

        const SizedBox(height: 32),

        // Login Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: auth.status == AuthStatus.loading ? null : _handleLogin,
            child: auth.status == AuthStatus.loading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: LoadingAnimationWidget.hexagonDots(
                      color: cs.onPrimary,
                      size: 20,
                    ),
                  )
                : const Text(
                    'Sign In',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),

        if (auth.isBiometricAvailable) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: auth.status == AuthStatus.loading
                  ? null
                  : auth.biometricLogin,
              icon: Icon(AppIcons.fingerPrint, color: cs.primary),
              label: Text(
                'Use Biometric Login',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
