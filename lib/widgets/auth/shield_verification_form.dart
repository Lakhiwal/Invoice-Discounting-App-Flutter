import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/view_models/auth_view_model.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class ShieldVerificationForm extends ConsumerStatefulWidget {
  const ShieldVerificationForm({super.key});

  @override
  ConsumerState<ShieldVerificationForm> createState() =>
      _ShieldVerificationFormState();
}

class _ShieldVerificationFormState
    extends ConsumerState<ShieldVerificationForm> {
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _handleVerify() {
    final auth = ref.read(authViewModelProvider);
    auth.verify2FA(_otpController.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authViewModelProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Icon(
                AppIcons.shieldBold,
                color: AppColors.success(context),
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Institutional Shield',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code from your authenticator app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          autofocus: true,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 10,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle:
                TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.1)),
            prefixIcon: Icon(AppIcons.password, color: cs.primary),
          ),
          onChanged: (val) {
            if (val.length == 6) _handleVerify();
          },
          onSubmitted: (_) => _handleVerify(),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: auth.status == AuthStatus.loading ? null : _handleVerify,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success(context),
            ),
            child: auth.status == AuthStatus.loading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: LoadingAnimationWidget.staggeredDotsWave(color: Colors.white, size: 24),
                  )
                : const Text(
                    'Verify Shield',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: auth.resetStatus,
            child: Text(
              'Back to login',
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
