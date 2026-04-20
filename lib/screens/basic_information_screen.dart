import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:invoice_discounting_app/screens/main_screen.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';

class BasicInformationScreen extends StatefulWidget {
  const BasicInformationScreen({super.key});

  @override
  State<BasicInformationScreen> createState() => _BasicInformationScreenState();
}

class _BasicInformationScreenState extends State<BasicInformationScreen>
    with SingleTickerProviderStateMixin {
  DateTime? _selectedDate;
  String? _selectedGender;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    unawaited(_animController.forward());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppColors.primary(context),
                    onPrimary: Colors.white,
                    secondary: AppColors.primary(context),
                    surface: const Color(0xFF1A2540),
                    onSecondary: Colors.white,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary(context),
                    secondary: AppColors.primary(context),
                    onSurface: Colors.black87,
                    onSecondary: Colors.white,
                  ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary(context),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            dialogTheme: DialogThemeData(
                backgroundColor:
                    isDark ? const Color(0xFF151D33) : Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      AppHaptics.selection();
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedDate == null || _selectedGender == null) {
      setState(() {
        _errorMessage = 'Both Date of Birth and Gender are required';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dobFormatted = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      final result = await ApiService.updateBasicInfo(
        dob: dobFormatted,
        gender: _selectedGender!,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        unawaited(AppHaptics.success());
        // Go to main screen and remove all previous routes
        unawaited(
          Navigator.of(context).pushAndRemoveUntil(
            SmoothPageRoute<void>(builder: (_) => const MainScreen()),
            (route) => false,
          ),
        );
      } else {
        unawaited(AppHaptics.error());
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to save information';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error. Try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildGenderCard(String title, String value, IconData icon) {
    final isSelected = _selectedGender == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          setState(() {
            _selectedGender = value;
          });
        },
        child: AnimatedContainer(
          duration: UI.normal,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary(context).withValues(alpha: 0.1)
                : (isDark ? const Color(0xFF1A2540) : Colors.white),
            borderRadius: BorderRadius.circular(UI.radiusMd),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary(context)
                  : AppColors.divider(context),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.primary(context)
                    : AppColors.textSecondary(context),
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary(context)
                      : AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        title: const Text('Basic Information'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: UI.authGradient(isDark),
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Complete your Profile',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'We need a few more details before you can start exploring options.',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary(context),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Date of Birth Section
                          Text(
                            'Date of Birth',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _selectDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1A2540)
                                    : Colors.white,
                                borderRadius:
                                    BorderRadius.circular(UI.radiusMd),
                                border: Border.all(
                                  color: AppColors.divider(context),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    AppIcons.calendar,
                                    color: AppColors.primary(context),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _selectedDate == null
                                          ? 'Select your date of birth'
                                          : DateFormat.yMMMd()
                                              .format(_selectedDate!),
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: _selectedDate == null
                                            ? AppColors.textSecondary(context)
                                            : AppColors.textPrimary(context),
                                        fontWeight: _selectedDate == null
                                            ? FontWeight.w500
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Gender Section
                          Text(
                            'Gender',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildGenderCard('Male', 'M', AppIcons.male),
                              const SizedBox(width: 12),
                              _buildGenderCard('Female', 'F', AppIcons.female),
                              const SizedBox(width: 12),
                              _buildGenderCard(
                                  'Other', 'O', AppIcons.nonBinary),
                            ],
                          ),
                          const SizedBox(height: 24),

                          if (_errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(12),
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
                                children: [
                                  Icon(
                                    AppIcons.error,
                                    color: AppColors.rose(context),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: AppColors.rose(context),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          const SizedBox(height: 48),

                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary(context),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(UI.radiusMd),
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
                                      'Save and Continue',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
