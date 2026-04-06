import 'package:flutter/material.dart';

class AppLogoHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final double toolbarHeight;
  final bool pinned;

  const AppLogoHeader({
    super.key,
    required this.title,
    this.actions,
    this.toolbarHeight = 72,
    this.pinned = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.95) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Image.asset(
              'assets/icon/app_icon.png',
              filterQuality: FilterQuality.high,
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
    );
  }
}
