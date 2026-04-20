import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/screens/status_view_screen.dart';
import 'package:invoice_discounting_app/services/status_service.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/utils/smooth_page_route.dart';

class AppLogoHeader extends ConsumerWidget {
  const AppLogoHeader({
    required this.title,
    super.key,
    this.actions,
    this.toolbarHeight = 72,
    this.pinned = true,
    this.bottom,
  });
  final String title;
  final List<Widget>? actions;
  final double toolbarHeight;
  final bool pinned;
  final PreferredSizeWidget? bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = ref.watch(statusProvider);
    final hasStatus = status != null;
    final isSeen = status?.isSeen ?? false;

    final ringColor =
        isSeen ? Colors.grey.withValues(alpha: 0.3) : colorScheme.primary;

    return SliverAppBar(
      scrolledUnderElevation: 0.5,
      toolbarHeight: toolbarHeight,
      pinned: pinned,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (status != null) {
                AppHaptics.selection();
                Navigator.of(context, rootNavigator: true).push(
                  SmoothPageRoute<void>(
                    builder: (_) => StatusViewScreen(status: status),
                  ),
                );
              }
            },
            child: Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: hasStatus
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ringColor,
                        width: 2,
                      ),
                    )
                  : null,
              child: Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.95)
                      : Colors.white,
                  shape: BoxShape.circle,
                  border: hasStatus
                      ? Border.all(color: colorScheme.surface, width: 2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Hero(
                  tag: 'app_logo_hero',
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
        ],
      ),
      actions: [
        if (actions != null) ...actions!,
        const SizedBox(width: 8),
      ],
      bottom: bottom,
    );
  }
}
