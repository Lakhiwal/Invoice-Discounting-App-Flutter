import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/models/nominee.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';

class AddNomineeScreen extends ConsumerStatefulWidget {
  const AddNomineeScreen({super.key, this.nominee});
  final Nominee? nominee;

  @override
  ConsumerState<AddNomineeScreen> createState() => _AddNomineeScreenState();
}

class _AddNomineeScreenState extends ConsumerState<AddNomineeScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _guardianCtrl = TextEditingController();

  String _gender = 'Male';
  String _relationship = 'Father';
  bool _saving = false;
  bool _isMinor = false;

  @override
  void initState() {
    super.initState();

    final n = widget.nominee;
    if (n != null) {
      _nameCtrl.text = n.name;
      _ageCtrl.text = n.age.toString();
      _addressCtrl.text = n.address;
      _guardianCtrl.text = n.guardianName;
      _gender = n.gender.isNotEmpty ? n.gender : 'Male';
      _relationship = n.relationship.isNotEmpty ? n.relationship : 'Father';
      _isMinor = n.age < 18;
    }

    _ageCtrl.addListener(() {
      final ageText = _ageCtrl.text.trim();
      if (ageText.isEmpty) {
        if (_isMinor) setState(() => _isMinor = false);
        return;
      }
      final age = int.tryParse(ageText);
      final newIsMinor = age != null && age < 18;
      if (newIsMinor != _isMinor) {
        setState(() => _isMinor = newIsMinor);
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _addressCtrl.dispose();
    _guardianCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      unawaited(AppHaptics.error());
      return;
    }

    setState(() => _saving = true);

    final age = int.tryParse(_ageCtrl.text) ?? 0;

    if (age < 18 && _guardianCtrl.text.trim().isEmpty) {
      unawaited(AppHaptics.error());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardian name is required for minor nominees'),
        ),
      );
      setState(() => _saving = false);
      return;
    }

    try {
      final result = await ApiService.saveNominee(
        name: _nameCtrl.text.trim(),
        age: age,
        gender: _gender,
        relationship: _relationship,
        guardianName: _guardianCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );

      if (!mounted) return;

      if (result['success'] != true) {
        unawaited(AppHaptics.error());
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text((result['error'] as String?) ?? 'Failed to save nominee'),
          ),
        );
        return;
      }

      if (!mounted) return;
      unawaited(AppHaptics.success());
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      unawaited(AppHaptics.error());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isEdit = widget.nominee != null;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Update Nominee' : 'Add Nominee',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: cs.surface,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.back, size: 20),
          onPressed: () {
            AppHaptics.selection();
            Navigator.pop(context);
          },
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NOMINEE DETAILS',
                    style: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _input(
                    'Full Name',
                    _nameCtrl,
                    icon: AppIcons.user,
                  ),
                  const SizedBox(height: 16),

                  _input(
                    'Age',
                    _ageCtrl,
                    icon: AppIcons.cake,
                    keyboard: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final n = int.tryParse(v);
                      if (n == null || n < 1 || n > 120) {
                        return 'Enter a valid age (1–120)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Guardian section for minors
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    child: _isMinor
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.amber(context)
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.amber(context)
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        AppIcons.info,
                                        color: AppColors.amber(context),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Nominee is a minor. A guardian name is mandatory.',
                                          style: TextStyle(
                                            color: AppColors.amber(context),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _input(
                                  'Guardian Full Name',
                                  _guardianCtrl,
                                  icon: AppIcons.shield,
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  _dropdown(
                    label: 'Gender',
                    value: _gender,
                    icon: AppIcons.wc,
                    items: const ['Male', 'Female', 'Other'],
                    onChanged: (v) {
                      AppHaptics.selection();
                      setState(() => _gender = v!);
                    },
                  ),
                  const SizedBox(height: 16),

                  _dropdown(
                    label: 'Relationship',
                    value: _relationship,
                    icon: AppIcons.people,
                    items: const [
                      'Father',
                      'Mother',
                      'Spouse',
                      'Brother',
                      'Sister',
                      'Child',
                      'Other',
                    ],
                    onChanged: (v) {
                      AppHaptics.selection();
                      setState(() => _relationship = v!);
                    },
                  ),
                  const SizedBox(height: 16),

                  _input(
                    'Address',
                    _addressCtrl,
                    icon: AppIcons.location,
                    maxLines: 3,
                  ),
                  const Spacer(),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saving
                          ? null
                          : () {
                              unawaited(AppHaptics.buttonPress());
                              _save();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary(context),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isEdit ? 'Update Details' : 'Save Nominee',
                              style: const TextStyle(
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
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    IconData? icon,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    bool required = true,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      validator: validator ??
          (v) {
            if (required && (v == null || v.trim().isEmpty)) return 'Required';
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    IconData? icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      items:
          items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        filled: true,
        fillColor: cs.surfaceContainerHigh.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
