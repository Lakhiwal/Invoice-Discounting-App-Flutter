import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';
import 'package:invoice_discounting_app/widgets/vibe_state_wrapper.dart';

class ShieldScreen extends ConsumerStatefulWidget {
  const ShieldScreen({
    required this.isEnabled,
    required this.onChanged,
    super.key,
  });

  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  @override
  ConsumerState<ShieldScreen> createState() => _ShieldScreenState();
}

class _ShieldScreenState extends ConsumerState<ShieldScreen> {
  bool _loading = true;
  String? _error;
  String? _qrCodeBase64;
  String? _secret;
  final TextEditingController _otpController = TextEditingController();
  bool _submitting = false;
  static const _security = MethodChannel('app/security');

  @override
  void initState() {
    super.initState();
    unawaited(_security.invokeMethod('setSecure', {'isSecure': true}));
    if (!widget.isEnabled) {
      _loadSetupData();
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    unawaited(_security.invokeMethod('setSecure', {'isSecure': false}));
    super.dispose();
  }

  Future<void> _loadSetupData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      debugPrint('Shield: Loading setup data...');
      final res = await ApiService.setup2FA();
      debugPrint('Shield: Setup response: $res');
      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _qrCodeBase64 = res['qr_code'] as String?;
            _secret = res['secret'] as String?;
            _loading = false;
          });
        } else {
          final error = (res['error'] as String?) ?? 'Failed to load setup data';
          debugPrint('Shield: Setup failed: $error');
          setState(() {
            _error = error;
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Shield: Setup connection error: $e');
      if (mounted) {
        setState(() {
          _error = 'Connection error. Please try again.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleAction() async {
    final token = _otpController.text.trim();
    if (token.length != 6) {
      setState(() => _error = 'Enter a valid 6-digit code');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      debugPrint('Shield: Handling action (isEnabled: ${widget.isEnabled}, token: $token)');
      final res = widget.isEnabled
          ? await ApiService.disable2FA(token)
          : await ApiService.activate2FA(token);
      
      debugPrint('Shield: Action result: $res');

      if (mounted) {
        if (res['success'] == true) {
          unawaited(AppHaptics.success());
          debugPrint('Shield: Action success, updating state and popping');
          widget.onChanged(!widget.isEnabled);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  (res['message'] as String?) ?? 'Shield status updated',
                ),
                backgroundColor: AppColors.success(context),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          final error = (res['error'] as String?) ?? 'Action failed';
          debugPrint('Shield: Action failed: $error');
          unawaited(AppHaptics.error());
          setState(() {
            _error = error;
            _submitting = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Shield: Action exception: $e');
      if (mounted) {
        setState(() {
          _error = 'An error occurred: $e';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text(
          'Institutional Shield',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: cs.surface,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.back, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: VibeStateWrapper(
        state: _loading
            ? VibeState.loading
            : (_error != null && _qrCodeBase64 == null && !widget.isEnabled
                ? VibeState.error
                : VibeState.success),
        onRetry: _loadSetupData,
        loadingSkeleton: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildHeader(cs),
              const SizedBox(height: 32),
              const SkeletonShieldContent(),
            ],
          ),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildHeader(cs),
              const SizedBox(height: 32),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: !widget.isEnabled
                    ? _buildActivationFlow(cs, key: const ValueKey('activate'))
                    : _buildDeactivationFlow(
                        cs,
                        key: const ValueKey('deactivate'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) => Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color:
                  (widget.isEnabled ? AppColors.success(context) : cs.primary)
                      .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(UI.radiusMd),
            ),
            child: Icon(
              widget.isEnabled ? AppIcons.shieldBold : AppIcons.shield,
              size: 40,
              color: widget.isEnabled ? AppColors.success(context) : cs.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.isEnabled ? 'Shield is Active' : 'Level Up Your Security',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.isEnabled
                ? 'Your account is protected with Two-Factor Authentication (2FA).'
                : 'Add an extra layer of protection using an authenticator app like Google Authenticator or Authy.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      );

  Widget _buildActivationFlow(ColorScheme cs, {Key? key}) => Column(
        key: key,
        children: [
          if (_qrCodeBase64 != null) ...[
            Text(
              '1. Scan QR Code',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(UI.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Image.memory(
                base64Decode(_qrCodeBase64!),
                width: 200,
                height: 200,
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (_secret != null) ...[
            Text(
              "Can't scan? Enter key manually:",
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _SecretBox(secret: _secret!),
            const SizedBox(height: 32),
          ],
          _OtpInput(controller: _otpController, error: _error),
          const SizedBox(height: 32),
          _ActionButton(
            label: 'Verify & Activate',
            submitting: _submitting,
            onPressed: _handleAction,
            color: cs.primary,
          ),
        ],
      );

  Widget _buildDeactivationFlow(ColorScheme cs, {Key? key}) => Column(
        key: key,
        children: [
          _OtpInput(controller: _otpController, error: _error),
          const SizedBox(height: 32),
          _ActionButton(
            label: 'Deactivate Shield',
            submitting: _submitting,
            onPressed: _handleAction,
            color: AppColors.danger(context),
          ),
        ],
      );
}

class _SecretBox extends ConsumerWidget {
  const _SecretBox({required this.secret});

  final String secret;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: secret));
        unawaited(AppHaptics.selection());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Security key copied'),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(UI.radiusMd),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              secret,
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 12),
            Icon(AppIcons.copy, size: 16, color: cs.primary),
          ],
        ),
      ),
    );
  }
}

class _OtpInput extends ConsumerWidget {
  const _OtpInput({required this.controller, this.error});

  final TextEditingController controller;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          'Verification Code',
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code from your app',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(color: cs.outlineVariant),
            errorText: error,
            filled: true,
            fillColor: cs.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(UI.radiusMd),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends ConsumerWidget {
  const _ActionButton({
    required this.label,
    required this.submitting,
    required this.onPressed,
    required this.color,
  });

  final String label;
  final bool submitting;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: submitting ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UI.radiusMd),),
          ),
          child: submitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      );
}
