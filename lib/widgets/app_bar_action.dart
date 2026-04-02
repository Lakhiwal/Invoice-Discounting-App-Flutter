import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/notification_center_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../services/api_service.dart';
import '../services/notification_provider.dart';
import '../utils/app_haptics.dart';
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
      final user = await ApiService.getProfile();
      if (mounted) setState(() => _user = user);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final unread = context.watch<NotificationProvider>().unreadCount;

    final userName = _user?['name'] ?? 'U';
    final initial = userName.isNotEmpty ? userName[0] : 'U';
    final profilePictureUrl = _user?['profile_picture_url']?.toString();

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Material(
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
                child: Center(
                  child: Badge(
                    label: Text('$unread'),
                    isLabelVisible: unread > 0,
                    child: Icon(
                      Icons.notifications_outlined,
                      size: 24,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Profile',
                onPressed: () {
                  AppHaptics.selection();
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
                icon: Badge(
                  alignment: Alignment.topRight,
                  isLabelVisible: false,
                  smallSize: 8,
                  backgroundColor: colorScheme.primary,
                  child: _AvatarCircle(
                    initial: initial,
                    imageUrl: profilePictureUrl,
                    colorScheme: colorScheme,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String initial;
  final String? imageUrl;
  final ColorScheme colorScheme;
  final double size;

  const _AvatarCircle({
    required this.initial,
    required this.colorScheme,
    this.imageUrl,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primaryContainer,
        border: Border.all(color: colorScheme.primary, width: 1.5),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildInitial(),
              )
            : _buildInitial(),
      ),
    );
  }

  Widget _buildInitial() {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}