import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import '../../../theme/theme_provider.dart';
import '../../../theme/ui_constants.dart';
import '../../../utils/app_haptics.dart';

class ShieldManagementSheet extends StatefulWidget {
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const ShieldManagementSheet({
    super.key,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  State<ShieldManagementSheet> createState() => _ShieldManagementSheetState();
}

class _ShieldManagementSheetState extends State<ShieldManagementSheet> {
  bool _loading = true;
  String? _error;
  String? _qrCodeBase64;
  String? _secret;
  final TextEditingController _otpController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isEnabled) {
      _loadSetupData();
    } else {
      setState(() => _loading = false);
    }
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
          _qrCodeBase64 = res['qr_code'];
          _secret = res['secret'];
          _loading = false;
        });
      } else {
        setState(() {
          _error = res['error'] ?? 'Failed to load setup data';
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
            content: Text(res['message'] ?? 'Shield status updated'),
            backgroundColor: AppColors.success(context),
          ),
        );
      } else {
        setState(() {
          _error = res['error'] ?? 'Action failed';
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
        top: 32,
        bottom: 24 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(cs),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
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

  Widget _buildHeader(ColorScheme cs) {
    return Column(
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
          widget.isEnabled ? Icons.shield : Icons.shield_outlined,
          size: 48,
          color: widget.isEnabled ? AppColors.success(context) : cs.primary,
        ),
        const SizedBox(height: 16),
        Text(
          widget.isEnabled ? 'Deactivate Shield' : 'Activate Institutional Shield',
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
  }

  Widget _buildActivationFlow(ColorScheme cs) {
    return Column(
      children: [
        if (_qrCodeBase64 != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.memory(
              base64Decode(_qrCodeBase64!),
              width: 180,
              height: 180,
            ),
          ),
        const SizedBox(height: 20),
        if (_secret != null)
          _SecretBox(secret: _secret!),
        const SizedBox(height: 24),
        _OtpInput(controller: _otpController, error: _error),
        const SizedBox(height: 24),
        _ActionButton(
          label: 'Activate Shield',
          submitting: _submitting,
          onPressed: _handleAction,
          color: AppColors.success(context),
        ),
      ],
    );
  }

  Widget _buildDeactivationFlow(ColorScheme cs) {
    return Column(
      children: [
        _OtpInput(controller: _otpController, error: _error),
        const SizedBox(height: 24),
        _ActionButton(
          label: 'Deactivate Shield',
          submitting: _submitting,
          onPressed: _handleAction,
          color: AppColors.danger(context),
        ),
      ],
    );
  }

  Widget _buildErrorView(ColorScheme cs) {
    return Column(
      children: [
        Text(_error!, style: TextStyle(color: AppColors.danger(context))),
        const SizedBox(height: 16),
        TextButton(onPressed: _loadSetupData, child: const Text('Retry')),
      ],
    );
  }
}

class _SecretBox extends StatelessWidget {
  final String secret;
  const _SecretBox({required this.secret});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          'Manual Entry Key',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4), fontSize: 12),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: secret));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Key copied to clipboard'), duration: Duration(seconds: 1)),
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

class _OtpInput extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  const _OtpInput({required this.controller, this.error});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter Authenticator Code',
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.1)),
            errorText: error,
            filled: true,
            fillColor: cs.onSurface.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool submitting;
  final VoidCallback onPressed;
  final Color color;

  const _ActionButton({
    required this.label,
    required this.submitting,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: submitting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: submitting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
