import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../theme/theme_provider.dart';
import '../../../theme/ui_constants.dart';
import '../../../utils/smooth_page_route.dart';
import '../../personal_details_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Hero Section — ring avatar · name · email · tags · investor journey bar
//
// Drop-in replacement for: lib/screens/profile/widgets/hero_section.dart
// ═══════════════════════════════════════════════════════════════════════════════

class ProfileHeroSection extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final bool isKycVerified;
  final List<(String label, bool done)> journeySteps;
  final double journeyProgress;
  final VoidCallback? onProfileUpdated;

  const ProfileHeroSection({
    super.key,
    required this.profile,
    required this.isKycVerified,
    required this.journeySteps,
    required this.journeyProgress,
    this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final name = profile?['name'] ?? '';
    final email = profile?['email'] ?? '';
    final initials = name.isNotEmpty
        ? name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(1).join('')
        : '?';

    final memberSince = _computeMemberSince(profile);
    final pictureUrl = profile?['profile_picture_url']?.toString();

    final allDone = journeySteps.every((s) => s.$2);
    final doneCount = journeySteps.where((s) => s.$2).length;

    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          // ── Avatar with ring — tap opens Personal Details ───────
          GestureDetector(
            onTap: () {
              Navigator.of(context, rootNavigator: false).push(
                SmoothPageRoute(
                  builder: (_) => PersonalDetailsScreen(
                    profile: profile,
                    onProfileUpdated: onProfileUpdated ?? () {},
                  ),
                ),
              );
            },
            child: Hero(
              tag: 'profile-avatar',
              child: _MemberRingAvatar(
                initials: initials,
                memberSince: memberSince,
                imageUrl: pictureUrl,
                size: 72,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),

          Text(email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: colorScheme.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isKycVerified)
                ProfileTag(
                    label: '✓ KYC Verified',
                    color: AppColors.success(context)),
              if (isKycVerified) const SizedBox(width: 6),
              ProfileTag(label: '● Active', color: colorScheme.primary),
            ],
          ),
          const SizedBox(height: 16),

          // ── Investor journey strip ──────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(UI.radiusMd),
              border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('INVESTOR JOURNEY',
                        style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: allDone
                            ? AppColors.success(context)
                            .withValues(alpha: 0.12)
                            : colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                          allDone
                              ? 'All steps done'
                              : '$doneCount/${journeySteps.length} done',
                          style: TextStyle(
                              color: allDone
                                  ? AppColors.success(context)
                                  : colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: journeyProgress),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 4,
                    backgroundColor:
                    colorScheme.outlineVariant.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.success(context)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: journeySteps
                      .map((step) => Text(step.$1,
                      style: TextStyle(
                          color: step.$2
                              ? AppColors.success(context)
                              : colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: step.$2
                              ? FontWeight.w600
                              : FontWeight.w400)))
                      .toList()),
            ]),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _computeMemberSince(Map<String, dynamic>? profile) {
    final raw = profile?['created_at']?.toString();
    if (raw != null) {
      final dt = DateTime.tryParse(raw);
      if (dt != null) {
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        return "${months[dt.month - 1]}'${dt.year.toString().substring(2)}";
      }
    }
    return "Mar'26";
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MEMBER RING AVATAR
// ═══════════════════════════════════════════════════════════════════════════════

class _MemberRingAvatar extends StatelessWidget {
  final String initials;
  final String memberSince;
  final String? imageUrl;
  final double size;

  const _MemberRingAvatar({
    required this.initials,
    required this.memberSince,
    this.imageUrl,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final outerSize = size + 40;
    final hasPicture = imageUrl != null && imageUrl!.isNotEmpty;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(
          size: Size(outerSize, outerSize),
          painter: _CurvedTextPainter(
            text: 'MEMBER SINCE $memberSince',
            color: cs.primary.withValues(alpha: 0.4),
            radius: outerSize / 2 - 2,
          ),
        ),
        CustomPaint(
          size: Size(size + 12, size + 12),
          painter: _DottedRingPainter(
            color: cs.primary.withValues(alpha: 0.15),
            radius: (size + 8) / 2,
          ),
        ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primaryContainer,
            border:
            Border.all(color: cs.primary.withValues(alpha: 0.3), width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasPicture
              ? CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            width: size,
            height: size,
            placeholder: (_, __) => _Initials(initials, size, cs),
            errorWidget: (_, __, ___) => _Initials(initials, size, cs),
          )
              : _Initials(initials, size, cs),
        ),
      ]),
    );
  }
}

Widget _Initials(String initials, double size, ColorScheme cs) => Center(
  child: Text(initials,
      style: TextStyle(
          color: cs.onPrimaryContainer,
          fontSize: size * 0.3,
          fontWeight: FontWeight.w700)),
);

// ═══════════════════════════════════════════════════════════════════════════════
// PAINTERS
// ═══════════════════════════════════════════════════════════════════════════════

class _CurvedTextPainter extends CustomPainter {
  final String text;
  final Color color;
  final double radius;
  _CurvedTextPainter(
      {required this.text, required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final fullText = '$text  •  $text  •  ';
    final charAngle = (2 * math.pi) / fullText.length;
    const startAngle = -math.pi / 2;

    for (int i = 0; i < fullText.length; i++) {
      final angle = startAngle + charAngle * i;
      final tp = TextPainter(
        text: TextSpan(
            text: fullText[i],
            style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle));
      canvas.rotate(angle + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CurvedTextPainter old) =>
      old.text != text || old.color != color;
}

class _DottedRingPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DottedRingPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 64; i++) {
      final angle = (i / 64) * 2 * math.pi;
      canvas.drawCircle(
          Offset(center.dx + radius * math.cos(angle),
              center.dy + radius * math.sin(angle)),
          0.8,
          paint);
    }
  }

  @override
  bool shouldRepaint(_DottedRingPainter old) => old.color != color;
}

class ProfileTag extends StatelessWidget {
  final String label;
  final Color color;
  const ProfileTag({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25))),
    child: Text(label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.w600)),
  );
}