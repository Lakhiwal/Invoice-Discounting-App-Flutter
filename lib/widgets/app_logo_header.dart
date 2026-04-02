import 'package:flutter/material.dart';
import 'app_bar_action.dart';

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

    return SliverAppBar(
      scrolledUnderElevation: 0,
      toolbarHeight: toolbarHeight,
      pinned: pinned,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 20,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Image.asset('assets/icon/app_icon.png'),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: actions ?? const [],
    );
  }
}
