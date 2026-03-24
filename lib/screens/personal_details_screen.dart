import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PersonalDetailsScreen — Groww-inspired "Personal details" page
//
// Place at: lib/screens/personal_details_screen.dart
// ═══════════════════════════════════════════════════════════════════════════════

class PersonalDetailsScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback onProfileUpdated;

  const PersonalDetailsScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  late Map<String, dynamic>? _profile;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile != null
        ? Map<String, dynamic>.from(widget.profile!)
        : null;
  }

  String get _initials {
    final name = _profile?['name']?.toString() ?? '';
    if (name.isEmpty) return '?';
    return name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(1).join('');
  }

  String? get _pictureUrl => _profile?['profile_picture_url']?.toString();
  bool get _hasPicture => _pictureUrl != null && _pictureUrl!.isNotEmpty;

  // ── Masking ─────────────────────────────────────────────────────────────

  String _maskEmail(String email) {
    if (email.isEmpty) return '--';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 3) return '${'*' * local.length}@$domain';
    return '${local.substring(0, 3)}${'*' * (local.length - 4)}${local[local.length - 1]}@$domain';
  }

  String _maskMobile(String mobile) {
    if (mobile.length <= 5) return mobile;
    return '${'*' * (mobile.length - 5)}${mobile.substring(mobile.length - 5)}';
  }

  String _maskPan(String pan) {
    if (pan.length <= 4) return pan;
    return '${'*' * (pan.length - 4)}${pan.substring(pan.length - 4)}';
  }

  String _maskDob(String? dob) {
    if (dob == null || dob.isEmpty) return '--';
    final parts = dob.split('-');
    if (parts.length == 3) return '**/**/${parts[0]}';
    final slashParts = dob.split('/');
    if (slashParts.length == 3) return '**/**/${slashParts[2]}';
    return dob;
  }

  // ── Picture actions ─────────────────────────────────────────────────────

  void _showPictureSheet() {
    AppHaptics.selection();
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change profile picture',
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            _SheetOption(
                icon: Icons.camera_alt_rounded,
                iconColor: cs.primary,
                label: 'Take picture',
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUpload(ImageSource.camera);
                }),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
            _SheetOption(
                icon: Icons.photo_library_rounded,
                iconColor: AppColors.success(context),
                label: 'Select from gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUpload(ImageSource.gallery);
                }),
            if (_hasPicture) ...[
              Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.2)),
              _SheetOption(
                  icon: Icons.delete_outline_rounded,
                  iconColor: AppColors.danger(context),
                  label: 'Remove Picture',
                  onTap: () {
                    Navigator.pop(context);
                    _removePicture();
                  }),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
          source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (picked == null || !mounted) return;

      setState(() => _uploading = true);
      final result = await ApiService.uploadProfilePicture(File(picked.path));
      if (!mounted) return;

      if (result['success'] == true) {
        await AppHaptics.success();
        setState(() {
          _profile?['profile_picture_url'] = result['url'];
          _uploading = false;
        });
        widget.onProfileUpdated();
      } else {
        await AppHaptics.error();
        setState(() => _uploading = false);
        _snack(result['error'] ?? 'Upload failed', isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _uploading = false);
        _snack('Could not pick image', isError: true);
      }
    }
  }

  Future<void> _removePicture() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove picture?'),
        content: const Text('Your profile will show your initials instead.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Remove',
                  style: TextStyle(color: AppColors.danger(context)))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _uploading = true);
    final result = await ApiService.deleteProfilePicture();
    if (!mounted) return;

    if (result['success'] == true) {
      await AppHaptics.selection();
      setState(() {
        _profile?['profile_picture_url'] = null;
        _uploading = false;
      });
      widget.onProfileUpdated();
    } else {
      setState(() => _uploading = false);
      _snack(result['error'] ?? 'Failed to remove', isError: true);
    }
  }

  void _snack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
      isError ? AppColors.danger(context) : AppColors.success(context),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = _profile?['name']?.toString() ?? '--';
    final email = _profile?['email']?.toString() ?? '';
    final mobile = _profile?['mobile']?.toString() ?? '';
    final pan = _profile?['pan_number']?.toString() ?? '';
    final dob = _profile?['date_of_birth']?.toString() ?? _profile?['dob']?.toString();
    final gender = _profile?['gender']?.toString();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: cs.onSurface, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: Text('Personal details',
            style: TextStyle(
                color: cs.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          const SizedBox(height: 16),

          // ── Avatar with edit badge ─────────────────────────────
          Center(
            child: GestureDetector(
              onTap: _showPictureSheet,
              child: Stack(children: [
                if (_uploading)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: cs.primaryContainer),
                    child: Center(
                        child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: cs.primary))),
                  )
                else
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primaryContainer,
                      border: Border.all(
                          color: cs.outline.withValues(alpha: 0.15), width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _hasPicture
                        ? CachedNetworkImage(
                      imageUrl: _pictureUrl!,
                      fit: BoxFit.cover,
                      width: 120,
                      height: 120,
                      placeholder: (_, __) => _initialsWidget(cs),
                      errorWidget: (_, __, ___) => _initialsWidget(cs),
                    )
                        : _initialsWidget(cs),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.camera_alt_rounded,
                            size: 13, color: cs.onSurface),
                        const SizedBox(width: 4),
                        Text('Edit',
                            style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          const SizedBox(height: 24),
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.15)),

          // ── Info fields ────────────────────────────────────────
          _InfoField(label: 'Full name (as on PAN card)', value: name),
          _divider(cs),
          if (dob != null && dob.isNotEmpty) ...[
            _InfoField(label: 'Date of Birth', value: _maskDob(dob)),
            _divider(cs),
          ],
          if (mobile.isNotEmpty) ...[
            _InfoField(label: 'Mobile Number', value: _maskMobile(mobile)),
            _divider(cs),
          ],
          if (email.isNotEmpty) ...[
            _InfoField(label: 'Email', value: _maskEmail(email)),
            _divider(cs),
          ],
          if (pan.isNotEmpty) ...[
            _InfoField(label: 'PAN number', value: _maskPan(pan)),
            _divider(cs),
          ],
          if (gender != null && gender.isNotEmpty)
            _InfoField(
                label: 'Gender',
                value: gender[0].toUpperCase() + gender.substring(1)),
          const SizedBox(height: 60),
        ]),
      ),
    );
  }

  Widget _initialsWidget(ColorScheme cs) => Center(
      child: Text(_initials,
          style: TextStyle(
              color: cs.onPrimaryContainer,
              fontSize: 48,
              fontWeight: FontWeight.w600)));

  Widget _divider(ColorScheme cs) => Divider(
      height: 1,
      indent: 20,
      endIndent: 20,
      color: cs.outlineVariant.withValues(alpha: 0.15));
}

class _InfoField extends StatelessWidget {
  final String label, value;
  const _InfoField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: cs.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _SheetOption(
      {required this.icon,
        required this.iconColor,
        required this.label,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        await AppHaptics.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500))),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
        ]),
      ),
    );
  }
}