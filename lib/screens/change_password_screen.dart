import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/screens/login_screen.dart';
import 'package:invoice_discounting_app/screens/profile/widgets/app_bar_widgets.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart'; // Item #8
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  String? _error;

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newController.text != _confirmController.text) {
      unawaited(AppHaptics.error()); // Item #8
      setState(() => _error = 'Passwords do not match');
      return;
    }

    if (_newController.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.changePassword(
      _currentController.text,
      _newController.text,
    );

    // FIX: check mounted BEFORE setting loading = false.
    // If the user somehow navigated away (edge case), we must not
    // call setState on a dead widget.
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      unawaited(AppHaptics.success()); // Item #8
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_password');
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );

      Navigator.of(context).pushAndRemoveUntil(
        SmoothPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } else {
      unawaited(AppHaptics.error()); // Item #8
      setState(() => _error = result['error'] as String?);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_loading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _loading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please wait, updating your password…'),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              pinned: true,
              toolbarHeight: 72,
              leadingWidth: 64,
              scrolledUnderElevation: 0,
              backgroundColor: cs.surface,
              surfaceTintColor: Colors.transparent,
              leading: !_loading ? const ProfileBackButton() : null,
              automaticallyImplyLeading: !_loading,
              centerTitle: true,
              title: Text(
                'Change Password',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Text(
                    'SECURITY UPDATE',
                    style: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        _passwordInput(
                          label: 'Current Password',
                          controller: _currentController,
                          icon: AppIcons.lock,
                          show: _showCurrent,
                          toggle: () =>
                              setState(() => _showCurrent = !_showCurrent),
                        ),
                        const SizedBox(height: 16),
                        _passwordInput(
                          label: 'New Password',
                          controller: _newController,
                          icon: AppIcons.password,
                          show: _showNew,
                          toggle: () => setState(() => _showNew = !_showNew),
                        ),
                        const SizedBox(height: 16),
                        _passwordInput(
                          label: 'Confirm New Password',
                          controller: _confirmController,
                          icon: AppIcons.check,
                          show: _showConfirm,
                          toggle: () =>
                              setState(() => _showConfirm = !_showConfirm),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            AppColors.danger(context).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              AppColors.danger(context).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.error,
                            color: AppColors.danger(context),
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: AppColors.danger(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: LoadingAnimationWidget.staggeredDotsWave(
                                  color: Colors.white, size: 24,),
                            )
                          : const Text(
                              'Update Password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'After changing your password you will be logged out and need to log in again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child:
                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 40),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool show,
    required VoidCallback toggle,
    bool isLast = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: !show,
      enabled: !_loading,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            show ? AppIcons.eye : AppIcons.eyeSlash,
            size: 20,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          onPressed: _loading ? null : toggle,
        ),
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}
