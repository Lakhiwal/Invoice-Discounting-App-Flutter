import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/screens/personal_details_screen.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Hero Section — ring avatar · name · email · tags · investor journey bar
//
// Drop-in replacement for: lib/screens/profile/widgets/hero_section.dart
// ═══════════════════════════════════════════════════════════════════════════════

class ProfileHeroSection extends ConsumerWidget {
  const ProfileHeroSection({
    required this.profile,
    required this.isKycVerified,
    required this.journeySteps,
    required this.journeyProgress,
    super.key,
    this.onProfileUpdated,
  });
  final Map<String, dynamic>? profile;
  final bool isKycVerified;
  final List<(String label, bool done)> journeySteps;
  final double journeyProgress;
  final VoidCallback? onProfileUpdated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    final name = (profile?['name'] as String?) ?? '';
    final email = (profile?['email'] as String?) ?? '';
    final initials = name.isNotEmpty
        ? name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(1).join()
        : '?';

    final memberSince = _computeMemberSince(profile);
    final pictureUrl = profile?['profile_picture_url']?.toString();

    final allDone = journeySteps.every((s) => s.$2);
    final doneCount = journeySteps.where((s) => s.$2).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.08),
              colorScheme.primary.withValues(alpha: 0.03),
              colorScheme.surface,
            ],
          ),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Avatar with ring — tap opens Personal Details ───────
            Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    AppHaptics.selection();
                    Navigator.of(context).push(
                      SmoothPageRoute<void>(
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
                      size: 84,
                    ),
                  ),
                ),
                if (isKycVerified)
                  Positioned(
                    bottom: 0,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.success(context),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: colorScheme.surface, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success(context)
                                .withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        AppIcons.verified,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  AppIcons.mail,
                  size: 12,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isKycVerified)
                  _EliteBadge(
                    label: 'ELITE INVESTOR',
                    color: colorScheme.primary,
                  ),
                if (isKycVerified) const SizedBox(width: 8),
                ProfileTag(
                  label: isKycVerified ? 'VERIFIED' : 'PENDING',
                  color: isKycVerified
                      ? AppColors.success(context)
                      : AppColors.warning(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Investor journey strip ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'INVESTOR JOURNEY',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        allDone
                            ? 'COMPLETE'
                            : '${(journeyProgress * 100).toInt()}%',
                        style: TextStyle(
                          color: allDone
                              ? AppColors.success(context)
                              : colorScheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: journeyProgress),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutQuart,
                    builder: (context, value, _) => Stack(
                      children: [
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: value,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary,
                                  AppColors.success(context),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success(context)
                                      .withValues(alpha: 0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _computeMemberSince(Map<String, dynamic>? profile) {
    final raw = profile?['created_at']?.toString();
    if (raw != null) {
      final dt = DateTime.tryParse(raw);
      if (dt != null) {
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
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

class _MemberRingAvatar extends ConsumerWidget {
  const _MemberRingAvatar({
    required this.initials,
    required this.memberSince,
    this.imageUrl,
    this.size = 100,
  });
  final String initials;
  final String memberSince;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final outerSize = size + 28;
    final hasPicture = imageUrl != null && imageUrl!.isNotEmpty;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(outerSize, outerSize),
            painter: _CurvedTextPainter(
              text: 'MEMBER SINCE $memberSince',
              color: cs.onSurfaceVariant,
              radius: (size / 2) + 8,
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primaryContainer,
              border: Border.all(
                color: cs.primary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasPicture
                ? CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    placeholder: (_, __) => _initialsWidget(initials, size, cs),
                    errorWidget: (_, __, ___) =>
                        _initialsWidget(initials, size, cs),
                  )
                : _initialsWidget(initials, size, cs),
          ),
        ],
      ),
    );
  }
}

Widget _initialsWidget(String initials, double size, ColorScheme cs) => Center(
      child: Text(
        initials,
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontSize: size * 0.3,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

// ═══════════════════════════════════════════════════════════════════════════════
// PAINTERS
// ═══════════════════════════════════════════════════════════════════════════════

class _CurvedTextPainter extends CustomPainter {
  _CurvedTextPainter({
    required this.text,
    required this.color,
    required this.radius,
  });
  final String text;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final fullText = '$text  •  $text  •  ';
    final charAngle = (2 * math.pi) / fullText.length;
    const startAngle = -math.pi / 2;

    for (var i = 0; i < fullText.length; i++) {
      final angle = startAngle + charAngle * i;
      final tp = TextPainter(
        text: TextSpan(
          text: fullText[i],
          style: TextStyle(
            color: color,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.rotate(angle + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CurvedTextPainter old) =>
      old.text != text || old.color != color;
}

// Removed _DottedRingPainter as per layout redesign

class ProfileTag extends ConsumerWidget {
  const ProfileTag({required this.label, required this.color, super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _EliteBadge extends StatelessWidget {
  const _EliteBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4), // Sharp badge
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.star, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
}
