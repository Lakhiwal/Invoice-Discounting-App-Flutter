import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class ShieldManagementSheet extends ConsumerStatefulWidget {
  const ShieldManagementSheet({
    required this.isEnabled,
    required this.onChanged,
    super.key,
  });
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  @override
  ConsumerState<ShieldManagementSheet> createState() =>
      _ShieldManagementSheetState();
}

class _ShieldManagementSheetState extends ConsumerState<ShieldManagementSheet> {
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
    _security.invokeMethod('setSecure', {'isSecure': true});
    if (!widget.isEnabled) {
      _loadSetupData();
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    _security.invokeMethod('setSecure', {'isSecure': false});
    super.dispose();
  }

  Future<void> _loadSetupData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await ApiService.setup2FA();
    if (mounted) {
      if (res['success'] == true) {
        setState(() {
          _qrCodeBase64 = res['qr_code'] as String?;
          _secret = res['secret'] as String?;
          _loading = false;
        });
      } else {
        setState(() {
          _error = (res['error'] as String?) ?? 'Failed to load setup data';
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

    final res = widget.isEnabled
        ? await ApiService.disable2FA(token)
        : await ApiService.activate2FA(token);

    if (mounted) {
      if (res['success'] == true) {
        widget.onChanged(!widget.isEnabled);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((res['message'] as String?) ?? 'Shield status updated'),
            backgroundColor: AppColors.success(context),
          ),
        );
      } else {
        setState(() {
          _error = (res['error'] as String?) ?? 'Action failed';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 24 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(cs),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: SkeletonShieldContent(),
            )
          else if (_error != null && _qrCodeBase64 == null && !widget.isEnabled)
            _buildErrorView(cs)
          else if (!widget.isEnabled)
            _buildActivationFlow(cs)
          else
            _buildDeactivationFlow(cs),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Icon(
            widget.isEnabled ? AppIcons.shieldBold : AppIcons.shield,
            size: 48,
            color: widget.isEnabled ? AppColors.success(context) : cs.primary,
          ),
          const SizedBox(height: 16),
          Text(
            widget.isEnabled
                ? 'Deactivate Shield'
                : 'Activate Institutional Shield',
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isEnabled
                ? 'Disable 2FA security'
                : 'Add an extra layer of protection to your account',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      );

  Widget _buildActivationFlow(ColorScheme cs) => Column(
        children: [
          if (_qrCodeBase64 != null)
            _StaggeredEntrance(
              staggerIndex: 1,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.memory(
                  base64Decode(_qrCodeBase64!),
                  width: 160,
                  height: 160,
                ),
              ),
            ),
          const SizedBox(height: 20),
          if (_secret != null)
            _StaggeredEntrance(
              staggerIndex: 2,
              child: _SecretBox(secret: _secret!),
            ),
          const SizedBox(height: 24),
          _StaggeredEntrance(
            staggerIndex: 3,
            child: _OtpInput(controller: _otpController, error: _error),
          ),
          const SizedBox(height: 24),
          _StaggeredEntrance(
            staggerIndex: 4,
            child: _ActionButton(
              label: 'Activate Shield',
              submitting: _submitting,
              onPressed: _handleAction,
              color: AppColors.emerald(context),
            ),
          ),
        ],
      );

  Widget _buildDeactivationFlow(ColorScheme cs) => Column(
        children: [
          _StaggeredEntrance(
            staggerIndex: 1,
            child: _OtpInput(controller: _otpController, error: _error),
          ),
          const SizedBox(height: 24),
          _StaggeredEntrance(
            staggerIndex: 2,
            child: _ActionButton(
              label: 'Deactivate Shield',
              submitting: _submitting,
              onPressed: _handleAction,
              color: AppColors.rose(context),
            ),
          ),
        ],
      );

  Widget _buildErrorView(ColorScheme cs) => Column(
        children: [
          Text(_error!, style: TextStyle(color: AppColors.danger(context))),
          const SizedBox(height: 16),
          TextButton(onPressed: _loadSetupData, child: const Text('Retry')),
        ],
      );
}

class _SecretBox extends ConsumerWidget {
  const _SecretBox({required this.secret});
  final String secret;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          'Manual Entry Key',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.4),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            AppHaptics.selection();
            Clipboard.setData(ClipboardData(text: secret));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Key copied to clipboard'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: cs.surfaceTint,
                showCloseIcon: true,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              secret,
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Enter Authenticator Code',
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          onChanged: (v) {
            if (v.length == 6) {
              AppHaptics.success();
            } else if (v.isNotEmpty) AppHaptics.selection();
          },
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 12,
            color: cs.primary,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.1)),
            errorText: error,
            filled: true,
            fillColor: cs.onSurface.withValues(alpha: 0.04),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide:
                  BorderSide(color: cs.onSurface.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: cs.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.rose(context)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: AppColors.rose(context), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaggeredEntrance extends ConsumerWidget {
  const _StaggeredEntrance({required this.child, required this.staggerIndex});
  final Widget child;
  final int staggerIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, val, child) {
          final delay = staggerIndex * 0.1;
          final animValue = (val - delay).clamp(0.0, 1.0);
          return Opacity(
            opacity: animValue,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - animValue)),
              child: child,
            ),
          );
        },
        child: child,
      );
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: submitting
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: LoadingAnimationWidget.staggeredDotsWave(color: Colors.white, size: 24),
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
