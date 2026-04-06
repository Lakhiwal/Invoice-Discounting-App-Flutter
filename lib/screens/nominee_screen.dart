import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart';
import '../widgets/liquidity_refresh_indicator.dart';

class Nominee {
  final int id;
  final String name;
  final int age;
  final String gender;
  final String relationship;
  final String guardianName;
  final String address;

  const Nominee({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.relationship,
    required this.guardianName,
    required this.address,
  });

  factory Nominee.fromMap(Map<String, dynamic> m) => Nominee(
    id: m['id'] as int,
    name: (m['name'] ?? '') as String,
    age: (m['age'] ?? 0) as int,
    gender: (m['gender'] ?? '') as String,
    relationship: (m['relationship'] ?? '') as String,
    guardianName: (m['guardian_name'] ?? '') as String,
    address: (m['address'] ?? '') as String,
  );

  bool get isMinor => age < 18;
}

// ─────────────────────────────────────────────────────────────────────────────
// NomineeScreen
// ─────────────────────────────────────────────────────────────────────────────

class NomineeScreen extends StatefulWidget {
  const NomineeScreen({super.key});

  @override
  State<NomineeScreen> createState() => _NomineeScreenState();
}

class _NomineeScreenState extends State<NomineeScreen> {
  Nominee? _nominee;
  bool _isLoading = true;
  String? _error;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final raw = await ApiService.getNominee();
      if (!mounted) return;
      setState(() {
        _nominee = raw != null ? Nominee.fromMap(raw) : null;
        _isLoading = false;
        _isEditing = _nominee == null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load nominee details';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.scaffold(context),
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary(context)),
            onPressed: () {
              if (_isEditing && _nominee != null) {
                setState(() => _isEditing = false);
              } else {
                Navigator.pop(context);
              }
            }),
        title: Text(
            _isEditing
                ? (_nominee == null ? 'Add Nominee' : 'Edit Nominee')
                : 'Nominee Details',
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        actions: [
          if (!_isLoading && !_isEditing && _nominee != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () async {
                  await AppHaptics.selection();
                  setState(() => _isEditing = true);
                },
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: AppColors.primary(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.edit_outlined,
                      color: AppColors.primary(context), size: 18),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _isEditing
          ? _NomineeForm(nominee: _nominee, onSaved: _load)
          : _NomineeView(nominee: _nominee!, onRefresh: _load),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View
// ─────────────────────────────────────────────────────────────────────────────

class _NomineeView extends StatelessWidget {
  final Nominee nominee;
  final Future<void> Function() onRefresh;
  const _NomineeView({required this.nominee, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LiquidityRefreshIndicator(
      onRefresh: () async {
        await AppHaptics.selection();
        await onRefresh();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.primary(context).withValues(alpha: 0.12),
                AppColors.primary(context).withValues(alpha: 0.04)
              ]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primary(context).withValues(alpha: 0.25))),
          child: Column(children: [
            Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    color: AppColors.primary(context).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.primary(context)
                            .withValues(alpha: 0.3),
                        width: 2)),
                alignment: Alignment.center,
                child: Text(
                    nominee.name.isNotEmpty
                        ? nominee.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: AppColors.primary(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w700))),
            const SizedBox(height: 12),
            Text(nominee.name,
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            Text(nominee.relationship,
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 14)),
            if (nominee.isMinor) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.amber(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.amber(context)
                            .withValues(alpha: 0.4))),
                child: Text('Minor — Guardian Required',
                    style: TextStyle(
                        color: AppColors.amber(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.1))),
          child: Column(children: [
            _DetailRow(label: 'Full Name', value: nominee.name),
            _DetailRow(label: 'Relationship', value: nominee.relationship),
            _DetailRow(label: 'Age', value: '${nominee.age} years'),
            _DetailRow(label: 'Gender', value: nominee.gender),
            if (nominee.isMinor && nominee.guardianName.isNotEmpty)
              _DetailRow(label: 'Guardian', value: nominee.guardianName),
            _DetailRow(label: 'Address', value: nominee.address, isLast: true),
          ]),
        ),
      ]),
    ),
  );
}
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final bool isLast;

  const _DetailRow(
      {required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 13)),
                Flexible(
                  child: Text(value,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
        ),
        if (!isLast)
          Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form
// ─────────────────────────────────────────────────────────────────────────────

class _NomineeForm extends StatefulWidget {
  final Nominee? nominee;
  final VoidCallback onSaved;

  const _NomineeForm({required this.nominee, required this.onSaved});

  @override
  State<_NomineeForm> createState() => _NomineeFormState();
}

class _NomineeFormState extends State<_NomineeForm> {
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
      final age = int.tryParse(_ageCtrl.text);
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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final age = int.tryParse(_ageCtrl.text) ?? 0;

    if (age < 18 && _guardianCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Guardian name is required for minor nominees')),
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

      if (!result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to save nominee')),
        );
        return;
      }

      await AppHaptics.success();
      widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _input('Full Name', _nameCtrl, icon: Icons.person_outline_rounded),
            const SizedBox(height: 14),

            _input(
              'Age',
              _ageCtrl,
              icon: Icons.cake_outlined,
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
            const SizedBox(height: 14),

            // Guardian field appears reactively when age < 18
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _isMinor
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.amber(context)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.amber(context)
                              .withValues(alpha: 0.35)),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline,
                                color: AppColors.amber(context), size: 14),
                            const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Nominee is a minor. A guardian name '
                              'is mandatory as per SEBI guidelines.',
                          style: TextStyle(
                              color: AppColors.amber(context),
                              fontSize: 12),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _input('Guardian Full Name', _guardianCtrl,
                            icon: Icons.shield_outlined, required: true),
                        const SizedBox(height: 14),
                      ],
              )
                  : const SizedBox.shrink(),
            ),

            _dropdown(
              label: 'Gender',
              value: _gender,
              icon: Icons.wc_outlined,
              items: const ['Male', 'Female', 'Other'],
              onChanged: (v) => setState(() => _gender = v!),
            ),
            const SizedBox(height: 14),

            _dropdown(
              label: 'Relationship',
              value: _relationship,
              icon: Icons.people_outline_rounded,
              items: const [
                'Father',
                'Mother',
                'Spouse',
                'Brother',
                'Sister',
                'Child',
                'Other'
              ],
              onChanged: (v) => setState(() => _relationship = v!),
            ),
            const SizedBox(height: 14),

            _input('Address', _addressCtrl,
                icon: Icons.location_on_outlined, maxLines: 3),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary(context),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary(context).withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Save Nominee',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Text field matching the app's theme (same pattern as login/register).
  /// No explicit border — inherits from InputDecorationTheme.
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
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      style: TextStyle(color: AppColors.textPrimary(context)),
      validator: validator ??
              (v) {
            if (required && (v == null || v.trim().isEmpty)) {
              return 'Required';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary(context)),
        prefixIcon: icon != null
            ? Icon(icon, color: AppColors.textSecondary(context), size: 20)
            : null,
      ),
    );
  }

  /// Dropdown matching the app's theme — no explicit border.
  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    IconData? icon,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      style: TextStyle(
        color: AppColors.textPrimary(context),
        fontSize: 14,
      ),
      dropdownColor: Theme.of(context).colorScheme.surface,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textSecondary(context)),
        prefixIcon: icon != null
            ? Icon(icon, color: AppColors.textSecondary(context), size: 20)
            : null,
      ),
    );
  }
}