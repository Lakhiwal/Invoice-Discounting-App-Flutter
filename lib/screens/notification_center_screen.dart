import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/notification_provider.dart';
import '../theme/theme_provider.dart';
import '../theme/ui_constants.dart';
import '../utils/app_haptics.dart';
import '../utils/smooth_page_route.dart';
import '../widgets/pressable.dart';
import '../widgets/stagger_list.dart';
import 'invoice_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NotificationCenterScreen
//
//  Grouped by date ("Today", "Yesterday", "This Week", "Earlier").
//  Swipe-to-dismiss individual notifications.
//  Pull-to-refresh from API.
//  Unread dot synced via NotificationProvider.
// ─────────────────────────────────────────────────────────────────────────────

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  void _handleTap(
      BuildContext context, Map<String, dynamic> notification) async {
    final provider = context.read<NotificationProvider>();
    final id = notification['id']?.toString() ?? '';
    if (id.isNotEmpty) provider.markAsRead(id);

    final type = notification['type'] ?? '';
    if (type == 'new_invoice' && notification['invoice_id'] != null) {
      final invoiceId = int.tryParse(notification['invoice_id'].toString());
      if (invoiceId != null) {
        try {
          final invoice = await ApiService.getInvoiceDetail(invoiceId);
          if (invoice != null && mounted) {
            Navigator.push(
              context,
              SmoothPageRoute(
                  builder: (_) => InvoiceDetailScreen.fromMap(invoice)),
            );
          }
        } catch (_) {}
      }
    }
  }

  void _handleDismiss(
      BuildContext context, Map<String, dynamic> notification) async {
    await AppHaptics.selection();
    final provider = context.read<NotificationProvider>();
    final id = notification['id']?.toString() ?? '';
    if (id.isNotEmpty) provider.removeNotification(id);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;
    final isLoading = provider.isLoading;
    final unread = provider.unreadCount;

    // Group by date
    final groups = _groupByDate(notifications);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // ── App bar ──────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 100,
            backgroundColor: colorScheme.surface,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Notifications',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  letterSpacing: -0.5,
                ),
              ),
              centerTitle: false,
              titlePadding:
              const EdgeInsets.symmetric(horizontal: 56, vertical: 16),
            ),
            actions: [
              if (unread > 0)
                TextButton(
                  onPressed: () async {
                    await AppHaptics.selection();
                    provider.markAllAsRead();
                  },
                  child: Text(
                    'Read all',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              if (notifications.isNotEmpty)
                IconButton(
                  onPressed: () => _showClearDialog(context, provider),
                  icon: Icon(Icons.delete_sweep_outlined,
                      color: colorScheme.onSurfaceVariant, size: 22),
                ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Unread count pill ────────────────────────────────────────
          if (!isLoading && unread > 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$unread unread',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Loading state ───────────────────────────────────────────
          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )

          // ── Empty state ─────────────────────────────────────────────
          else if (notifications.isEmpty)
            SliverFillRemaining(child: _EmptyState())

          // ── Notification list (grouped) ─────────────────────────────
          else
            ...groups.entries.map((entry) {
              final label = entry.key;
              final items = entry.value;
              return SliverMainAxisGroup(
                slivers: [
                  // Group header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                  // Group items
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (ctx, i) {
                          final item = items[i];
                          return Dismissible(
                            key: ValueKey(item['id']),
                            direction: DismissDirection.endToStart,
                            onDismissed: (_) =>
                                _handleDismiss(context, item),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: colorScheme.error
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(Icons.delete_outline_rounded,
                                  color: colorScheme.error, size: 22),
                            ),
                            child: StaggerItem(
                              index: i,
                              child: _NotificationTile(
                                notification: item,
                                onTap: () => _handleTap(context, item),
                              ),
                            ),
                          );
                        },
                        childCount: items.length,
                      ),
                    ),
                  ),
                ],
              );
            }),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ── Group notifications by date ────────────────────────────────────────────

  Map<String, List<Map<String, dynamic>>> _groupByDate(
      List<Map<String, dynamic>> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final Map<String, List<Map<String, dynamic>>> groups = {};

    for (final n in notifications) {
      final ts = DateTime.tryParse(n['timestamp']?.toString() ?? '');
      String label;
      if (ts == null) {
        label = 'EARLIER';
      } else if (ts.isAfter(today)) {
        label = 'TODAY';
      } else if (ts.isAfter(yesterday)) {
        label = 'YESTERDAY';
      } else if (ts.isAfter(weekAgo)) {
        label = 'THIS WEEK';
      } else {
        label = 'EARLIER';
      }
      groups.putIfAbsent(label, () => []).add(n);
    }

    // Maintain order: Today → Yesterday → This Week → Earlier
    final ordered = <String, List<Map<String, dynamic>>>{};
    for (final key in ['TODAY', 'YESTERDAY', 'THIS WEEK', 'EARLIER']) {
      if (groups.containsKey(key)) ordered[key] = groups[key]!;
    }
    return ordered;
  }

  // ── Clear all confirmation ─────────────────────────────────────────────────

  void _showClearDialog(
      BuildContext context, NotificationProvider provider) async {
    await AppHaptics.selection();
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(  // ← use different name
        title: const Text('Clear notifications'),
        content:
        const Text('Remove all notifications? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Clear all',
                style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await AppHaptics.success();
      await provider.clearAll();  // ← add await
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Notification tile
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRead = notification['is_read'] == true;
    final type = notification['type'] ?? 'system';

    final (icon, iconColor) = _resolveIcon(context, type);

    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead
              ? colorScheme.surfaceContainer
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRead
                ? colorScheme.outlineVariant.withValues(alpha: 0.1)
                : colorScheme.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification['title'] ?? 'Notification',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                            isRead ? FontWeight.w600 : FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(notification['timestamp']),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['body'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Action hint for tappable notifications
                  if (notification['type'] == 'new_invoice') ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.open_in_new_rounded,
                            size: 12,
                            color:
                            colorScheme.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          'View invoice',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                            colorScheme.primary.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _resolveIcon(BuildContext context, String type) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case 'new_invoice':
        return (Icons.rocket_launch_rounded, colorScheme.primary);
      case 'wallet':
      case 'deposit':
        return (
        Icons.account_balance_wallet_rounded,
        AppColors.success(context)
        );
      case 'repayment':
      case 'settlement':
        return (
        Icons.assignment_turned_in_rounded,
        AppColors.success(context)
        );
      case 'withdrawal':
        return (Icons.south_rounded, AppColors.warning(context));
      case 'kyc':
        return (Icons.verified_user_outlined, colorScheme.primary);
      case 'alert':
        return (Icons.warning_amber_rounded, AppColors.warning(context));
      default:
        return (Icons.info_outline_rounded, colorScheme.onSurfaceVariant);
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${date.day}/${date.month}';
    } catch (_) {
      return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'All caught up!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No new notifications.\nWe\'ll let you know when something happens.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}