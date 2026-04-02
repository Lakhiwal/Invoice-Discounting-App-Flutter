import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../theme/theme_provider.dart';
import '../utils/app_haptics.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PersonalDetailsScreen — Personal details page with crop & preview
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
    return name
        .split(' ')
        .map((e) => e.isNotEmpty ? e[0] : '')
        .take(1)
        .join('');
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

  void _viewFullImage() {
    if (!_hasPicture) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: _pictureUrl!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
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
                  _pickCropAndPreview(ImageSource.camera);
                }),
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
            _SheetOption(
                icon: Icons.photo_library_rounded,
                iconColor: AppColors.success(context),
                label: 'Select from gallery',
                onTap: () {
                  Navigator.pop(context);
                  _pickCropAndPreview(ImageSource.gallery);
                }),
            if (_hasPicture) ...[
              Divider(
                  height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
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

  /// Pick → Crop (circle) → Preview → Upload
  Future<void> _pickCropAndPreview(ImageSource source) async {
    try {
      // 1) Pick image
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;

      // 2) Crop to circle
      final cropped = await _cropImage(File(picked.path));
      if (cropped == null || !mounted) return;

      // 3) Preview & confirm
      final confirmed = await _showPreviewDialog(cropped);
      if (confirmed != true || !mounted) return;

      // 4) Upload
      await _uploadImage(cropped);
    } catch (_) {
      if (mounted) {
        _snack('Could not pick image', isError: true);
      }
    }
  }

  /// Launches image_cropper with a circular crop area
  Future<File?> _cropImage(File imageFile) async {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      compressQuality: 85,
      maxWidth: 800,
      maxHeight: 800,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: isDark ? Colors.black : cs.surface,
          toolbarWidgetColor: cs.onSurface,
          statusBarLight: !isDark,
          backgroundColor: isDark ? Colors.black : cs.surface,
          activeControlsWidgetColor: cs.primary,
          cropGridColor: Colors.white24,
          cropFrameColor: cs.primary,
          dimmedLayerColor: Colors.black54,
          cropStyle: CropStyle.circle,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          doneButtonTitle: 'Done',
          cancelButtonTitle: 'Cancel',
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );

    if (croppedFile == null) return null;
    return File(croppedFile.path);
  }

  /// Shows a bottom sheet preview of the cropped image with before/after
  Future<bool?> _showPreviewDialog(File croppedFile) {
    final cs = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final previewSize = screenWidth * 0.4;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Preview',
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This is how your profile picture will look',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 28),

            // ── Preview: circular avatar mock ──
            Container(
              width: previewSize,
              height: previewSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // The cropped image in a circle
                  Container(
                    width: previewSize,
                    height: previewSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.primary, width: 3),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipOval(
                      child: Image.file(
                        croppedFile,
                        fit: BoxFit.cover,
                        width: previewSize,
                        height: previewSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Context: show how it looks in a mini mockup ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  // Mini avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.primary, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipOval(
                      child: Image.file(
                        croppedFile,
                        fit: BoxFit.cover,
                        width: 44,
                        height: 44,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _profile?['name']?.toString() ?? 'Your Name',
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'How others will see you',
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Action buttons ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.onSurface,
                      side: BorderSide(
                          color: cs.outlineVariant.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Use This Photo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Uploads the cropped file to the server
  Future<void> _uploadImage(File imageFile) async {
    setState(() => _uploading = true);
    try {
      final result = await ApiService.uploadProfilePicture(imageFile);
      if (!mounted) return;

      if (result['success'] == true) {
        await AppHaptics.success();
        setState(() {
          _profile?['profile_picture_url'] = result['url'];
          _uploading = false;
        });
        widget.onProfileUpdated();
        _snack('Profile picture updated', isError: false);
      } else {
        await AppHaptics.error();
        setState(() => _uploading = false);
        _snack(result['error'] ?? 'Upload failed', isError: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _uploading = false);
        _snack('Upload failed', isError: true);
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
    final dob =
        _profile?['date_of_birth']?.toString() ?? _profile?['dob']?.toString();
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
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Avatar with edit badge ─────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── CENTERED AVATAR ──
                    Center(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(100),
                        onTap: _hasPicture ? _viewFullImage : _showPictureSheet,
                        child: Stack(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    cs.primary.withValues(alpha: 0.9),
                                    cs.primaryContainer,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _uploading
                                  ? Center(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: cs.onPrimary,
                                  ),
                                ),
                              )
                                  : _hasPicture
                                  ? CachedNetworkImage(
                                imageUrl: _pictureUrl!,
                                fit: BoxFit.cover,
                                width: 110,
                                height: 110,
                              )
                                  : _initialsWidget(cs),
                            ),
                            if (!_uploading)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _showPictureSheet,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: cs.surface,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: const Icon(Icons.edit,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Info fields ────────────────────────────────────────
              _InfoField(
                icon: Icons.person_outline_rounded,
                label: 'Full name (as on PAN card)',
                value: name,
              ),

              if (dob != null && dob.isNotEmpty)
                _InfoField(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date of Birth',
                  value: _maskDob(dob),
                ),

              if (mobile.isNotEmpty)
                _InfoField(
                  icon: Icons.phone_iphone_rounded,
                  label: 'Mobile Number',
                  value: _maskMobile(mobile),
                ),

              if (email.isNotEmpty)
                _InfoField(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  value: _maskEmail(email),
                ),

              if (pan.isNotEmpty)
                _InfoField(
                  icon: Icons.credit_card_outlined,
                  label: 'PAN number',
                  value: _maskPan(pan),
                ),

              if (gender != null && gender.isNotEmpty)
                _InfoField(
                  icon: Icons.person_pin_outlined,
                  label: 'Gender',
                  value: gender[0].toUpperCase() + gender.substring(1),
                ),
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
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          )));
}

class _InfoField extends StatelessWidget {
  final String label, value;
  final IconData icon;

  const _InfoField({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 84), // Align with text
          child: Divider(
            height: 1,
            color: cs.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
      ],
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