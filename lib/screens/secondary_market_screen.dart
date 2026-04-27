import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/services/secondary_market_api_service.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/formatters.dart';
import 'package:invoice_discounting_app/widgets/app_logo_header.dart';
import 'package:invoice_discounting_app/widgets/liquidity_refresh_indicator.dart';
import 'package:invoice_discounting_app/widgets/pressable.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';
import 'package:invoice_discounting_app/widgets/stagger_list.dart';
import 'package:invoice_discounting_app/widgets/vibe_state_wrapper.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class SecondaryMarketScreen extends ConsumerStatefulWidget {
  const SecondaryMarketScreen({super.key, this.isEmbedded = false});
  final bool isEmbedded;

  @override
  ConsumerState<SecondaryMarketScreen> createState() =>
      _SecondaryMarketScreenState();
}

class _SecondaryMarketScreenState extends ConsumerState<SecondaryMarketScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _listings = [];

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final data = await SecondaryMarketApiService.fetchListings();
      if (mounted) {
        setState(() {
          _listings = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = _isLoading
        ? VibeState.loading
        : (_listings.isEmpty ? VibeState.empty : VibeState.success);

    final body = LiquidityRefreshIndicator(
      onRefresh: () => _loadListings(silent: true),
      child: CustomScrollView(
        slivers: [
          if (!widget.isEmbedded)
            AppLogoHeader(
              title: 'Secondary Market',
              actions: [
                IconButton(
                  icon: Icon(AppIcons.refresh),
                  onPressed: _loadListings,
                ),
              ],
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'P2P Marketplace',
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Purchase existing invoice stakes from other investors for immediate returns.',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: VibeStateWrapper(
                state: state,
                loadingSkeleton: const SkeletonSecondaryMarket(),
                emptyIcon: AppIcons.portfolio,
                emptyTitle: 'No Listings Available',
                emptySubtitle:
                    'Active exit requests from other investors will appear here.',
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _listings.length,
                  itemBuilder: (ctx, i) => StaggerItem(
                    index: i,
                    child: _SecondaryListingCard(listing: _listings[i]),
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: body,
    );
  }
}

class _SecondaryListingCard extends ConsumerWidget {
  const _SecondaryListingCard({required this.listing});
  final Map<String, dynamic> listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final funding = listing['funding'] ?? {};
    final invoice = funding['invoice'] ?? {};

    final price = double.tryParse(listing['price']?.toString() ?? '0') ?? 0;
    final rate =
        double.tryParse(funding['investor_rate']?.toString() ?? '0') ?? 0;
    final daysLeft = int.tryParse(funding['days_left']?.toString() ?? '0') ?? 0;

    return Pressable(
      onTap: () => _showPurchaseDialog(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(UI.radiusLg),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice['company']?.toString() ?? 'Company',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Listed by Investor #${listing['seller_id'] ?? '?'}',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.emerald(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(UI.radiusSm),
                  ),
                  child: Text(
                    '${rate.toStringAsFixed(1)}% p.a.',
                    style: TextStyle(
                      color: AppColors.emerald(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MiniMetric(
                  label: 'SALE PRICE',
                  value: '₹${fmtAmount(price)}',
                  color: cs.primary,
                ),
                _MiniMetric(
                  label: 'DAYS LEFT',
                  value: '$daysLeft Days',
                  color: daysLeft < 7 ? AppColors.amber(context) : cs.onSurface,
                ),
                _MiniMetric(
                  label: 'EST. RETURN',
                  value:
                      '₹${fmtAmount(double.tryParse(funding['expected_profit']?.toString() ?? '0') ?? 0)}',
                  color: AppColors.emerald(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _showPurchaseDialog(context),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UI.radiusMd),
                  ),
                ),
                child: const Text('Buy Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context) {
    unawaited(showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Purchase Stake?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to purchase an invoice stake for ₹${fmtAmount(double.tryParse(listing['price']?.toString() ?? '0') ?? 0)}.',
              ),
              const SizedBox(height: 12),
              Text(
                'Upon purchase, you will become the new owner of this funding and receive the full maturity value including interest at the end of the tenure.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _handlePurchase(context),
              child: const Text('Confirm Purchase'),
            ),
          ],
        );
      },
    ),);
  }

  Future<void> _handlePurchase(BuildContext context) async {
    Navigator.pop(context); // Close dialog

    // Show loading
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
          child: LoadingAnimationWidget.hexagonDots(
        color: Theme.of(context).colorScheme.primary,
        size: 40,
      ),),
    ),);

    final result = await SecondaryMarketApiService.buyListing(listing['id']);

    if (!context.mounted) return;
    Navigator.pop(context); // Pop loading

    if (result['success']) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(AppIcons.check, color: AppColors.emerald(ctx), size: 48),
          title: const Text('Purchase Successful'),
          content: Text(result['message']),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Refresh listings
                final state = context
                    .findAncestorStateOfType<_SecondaryMarketScreenState>();
                state?._loadListings();
              },
              child: const Text('View Portfolio'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
    }
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
}
