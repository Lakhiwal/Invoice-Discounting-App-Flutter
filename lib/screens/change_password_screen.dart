import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../theme/ui_constants.dart';
import '../utils/smooth_page_route.dart';
import '../utils/app_haptics.dart'; // Item #8
import 'login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
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
      await AppHaptics.error(); // Item #8
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
        _currentController.text, _newController.text);

    // FIX: check mounted BEFORE setting loading = false.
    // If the user somehow navigated away (edge case), we must not
    // call setState on a dead widget.
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success']) {
      await AppHaptics.success(); // Item #8
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_password');
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully')));

      Navigator.of(context).pushAndRemoveUntil(
          SmoothPageRoute(builder: (_) => const LoginScreen()),
              (route) => false);
    } else {
      await AppHaptics.error(); // Item #8
      setState(() => _error = result['error']);
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX: wrap with PopScope to block back navigation while a submit is
    // in progress. Without this, the user can pop mid-request, the mounted
    // check fires too late, and prefs may be cleared on a dead widget.
    return PopScope(
      // canPop: false while loading — prevent accidental dismissal during API call
      canPop: !_loading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _loading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Please wait, updating your password…')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffold(context),
        appBar: AppBar(
          title: const Text('Change Password'),
          backgroundColor: AppColors.scaffold(context),
          elevation: 0,
          // FIX: disable the appbar back button while loading too
          automaticallyImplyLeading: !_loading,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Update your account password',
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 13)),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.navyCard(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color:
                      AppColors.divider(context).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _currentController,
                      obscureText: !_showCurrent,
                      // FIX: disable fields while loading to prevent mid-request edits
                      enabled: !_loading,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _showCurrent
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: AppColors.textSecondary(context),
                              size: 20),
                          onPressed: _loading
                              ? null
                              : () => setState(
                                  () => _showCurrent = !_showCurrent),
                        ),
                      ),
                    ),
                    const SizedBox(height: UI.md),
                    TextField(
                      controller: _newController,
                      obscureText: !_showNew,
                      enabled: !_loading,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock_reset),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _showNew
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: AppColors.textSecondary(context),
                              size: 20),
                          onPressed: _loading
                              ? null
                              : () =>
                              setState(() => _showNew = !_showNew),
                        ),
                      ),
                    ),
                    const SizedBox(height: UI.md),
                    TextField(
                      controller: _confirmController,
                      obscureText: !_showConfirm,
                      enabled: !_loading,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon:
                        const Icon(Icons.check_circle_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _showConfirm
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: AppColors.textSecondary(context),
                              size: 20),
                          onPressed: _loading
                              ? null
                              : () => setState(
                                  () => _showConfirm = !_showConfirm),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Error banner
              if (_error != null) ...[
                const SizedBox(height: UI.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color:
                    AppColors.danger(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.danger(context)
                            .withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline,
                        color: AppColors.danger(context), size: 18),
                    const SizedBox(width: UI.sm),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(
                              color: AppColors.danger(context),
                              fontSize: 13)),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                      : const Text('Update Password',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                  'After changing your password you will be logged out and '
                      'need to log in again.',
                  style: TextStyle(
                      color: AppColors.textSecondary(context),
                      fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}