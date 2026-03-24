import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/notification_center_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../services/api_service.dart';
import '../services/notification_provider.dart';
import '../utils/app_haptics.dart';
import '../utils/hero_page_route.dart';
import '../utils/smooth_page_route.dart';

/// Shared app-bar actions — notification bell + profile avatar.
///
/// Drop this into the `actions` list of any SliverAppBar / AppBar:
/// ```dart
/// SliverAppBar(
///   actions: const [AppBarActions()],
/// )
/// ```
class AppBarActions extends StatefulWidget {
  const AppBarActions({super.key});

  @override
  State<AppBarActions> createState() => _AppBarActionsState();
}

class _AppBarActionsState extends State<AppBarActions> {
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final user = await ApiService.getCachedUser();
      if (mounted) setState(() => _user = user);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unread = context.watch<NotificationProvider>().unreadCount;

    final userName = _user?['name'] ?? 'U';
    final initial = userName.isNotEmpty ? userName[0] : 'U';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Notification bell ──
        Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: () {
              AppHaptics.selection();
              Navigator.push(
                context,
                SmoothPageRoute(
                  builder: (_) => const NotificationCenterScreen(),
                ),
              );
            },
            containedInkWell: false,
            highlightShape: BoxShape.circle,
            radius: 20,
            splashFactory: InkRipple.splashFactory,
            splashColor: colorScheme.onSurface.withValues(alpha: 0.10),
            highlightColor: colorScheme.onSurface.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Badge(
                label: Text('$unread'),
                isLabelVisible: unread > 0,
                child: Icon(
                  Icons.notifications_outlined,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // ── Profile avatar ──
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: IconButton(
              tooltip: 'Profile',
              onPressed: () {
                AppHaptics.selection();
                Navigator.of(context, rootNavigator: true).push(
                  HeroPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              icon: Badge(
                alignment: Alignment.topRight,
                isLabelVisible: false,
                smallSize: 8,
                backgroundColor: colorScheme.primary,
                child: Hero(
                  tag: 'profile-avatar',
                  placeholderBuilder: (context, heroSize, child) {
                    return _AvatarCircle(
                      initial: initial,
                      colorScheme: colorScheme,
                    );
                  },
                  child: _AvatarCircle(
                    initial: initial,
                    colorScheme: colorScheme,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String initial;
  final ColorScheme colorScheme;

  const _AvatarCircle({
    required this.initial,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primaryContainer,
        border: Border.all(color: colorScheme.primary, width: 1.5),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
