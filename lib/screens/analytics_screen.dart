import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/theme_provider.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/utils/app_haptics.dart';
import 'package:invoice_discounting_app/view_models/analytics_state.dart';
import 'package:invoice_discounting_app/view_models/analytics_view_model.dart';
import 'package:invoice_discounting_app/widgets/analytics/ai_insight_card.dart';
import 'package:invoice_discounting_app/widgets/analytics/analytics_cards.dart';
import 'package:invoice_discounting_app/widgets/analytics/analytics_charts.dart';
import 'package:invoice_discounting_app/widgets/analytics/earnings_card.dart';
import 'package:invoice_discounting_app/widgets/app_logo_header.dart';
import 'package:invoice_discounting_app/widgets/liquidity_refresh_indicator.dart';
import 'package:invoice_discounting_app/widgets/skeleton.dart';
import 'package:invoice_discounting_app/widgets/vibe_state_wrapper.dart';

// - [x] Implement `AnalyticsNotifier` in `analytics_view_model.dart` [MODIFY]
// - [x] Refactor `AnalyticsScreen` to `ConsumerStatefulWidget` [MODIFY]
// - [x] Update Analytics UI components for new state structure

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hide = ref.watch(themeProvider.select((p) => p.hideBalance));
    final analyticsAsync = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      body: LiquidityRefreshIndicator(
        onRefresh: () => ref.read(analyticsProvider.notifier).refresh(),
        color: cs.primary,
        child: analyticsAsync.when(
          data: (state) => _buildContent(context, state, hide),
          loading: () => const VibeStateWrapper(
            state: VibeState.loading,
            loadingSkeleton: SkeletonAnalyticsContent(),
            child: SizedBox.shrink(),
          ),
          error: (err, stack) => VibeStateWrapper(
            state: VibeState.error,
            errorMessage: "We couldn't load your analytics data.",
            onRetry: () => ref.read(analyticsProvider.notifier).refresh(),
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AnalyticsState state, bool hide) {
    final cs = Theme.of(context).colorScheme;
    final notifier = ref.read(analyticsProvider.notifier);

    return VibeStateWrapper(
      state: state.allActive.isEmpty && state.allRepaid.isEmpty
          ? VibeState.empty
          : VibeState.success,
      emptyIcon: AppIcons.analytics,
      emptyTitle: 'No Data Yet',
      emptySubtitle: 'Start investing to see your analytics here.',
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final currentIndex = state.timeOptions.indexOf(state.timeFilter);
          if (details.primaryVelocity! < 0 &&
              currentIndex < state.timeOptions.length - 1) {
            notifier.setTimeFilter(state.timeOptions[currentIndex + 1]);
            unawaited(AppHaptics.selection());
          } else if (details.primaryVelocity! > 0 && currentIndex > 0) {
            notifier.setTimeFilter(state.timeOptions[currentIndex - 1]);
            unawaited(AppHaptics.selection());
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            AppLogoHeader(
              title: 'Analytics',
              actions: [
                IconButton(
                  onPressed: () => unawaited(AppHaptics.selection()),
                  icon: Icon(AppIcons.download, color: cs.primary),
                ),
                const SizedBox(width: 8),
              ],
            ),

            // Time Filters
            SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: state.timeOptions.map((f) {
                    final active = state.timeFilter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          notifier.setTimeFilter(f);
                          unawaited(AppHaptics.selection());
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? cs.primary.withValues(alpha: 0.12)
                                : cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(UI.radiusSm),
                            border: Border.all(
                              color: active
                                  ? cs.primary
                                  : cs.outlineVariant.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              color: active ? cs.primary : cs.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight:
                                  active ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Health Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(UI.md, 12, UI.md, 0),
                child: Column(
                  children: [
                    HealthScoreCard(
                      score: state.healthScore,
                      label: state.healthLabel,
                      color: state.healthColor,
                      factors: state.healthFactors,
                    ),
                    const SizedBox(height: 16),
                    const AiInsightCard(),
                  ],
                ),
              ),
            ),

            // Metrics Grid
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(UI.md, 16, UI.md, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Invested',
                        numericValue: hide ? null : state.totalInvested,
                        value: hide ? '₹● ● ●' : null,
                        prefix: '₹',
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MetricCard(
                        label: 'Returns',
                        numericValue: hide ? null : state.totalReturns,
                        value: hide ? '₹● ● ●' : null,
                        prefix: '₹',
                        color: const Color(0xFF12B76A),
                        staggerIndex: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(UI.md, 8, UI.md, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: MetricCard(
                        label: 'Avg. yield',
                        numericValue: state.avgYield,
                        suffix: '%',
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MetricCard(
                        label: 'Active / Repaid',
                        value:
                            '${state.filteredActive.length} / ${state.filteredRepaid.length}',
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Charts & Risk Analysis
            if (state.maturityData.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(UI.md, 16, UI.md, 0),
                  child: MaturityCalendar(
                    data: state.maturityData,
                    hideBalance: hide,
                  ),
                ),
              ),

            if (state.totalInvested > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(UI.md, 12, UI.md, 0),
                  child: RiskCard(
                    buckets: state.riskBuckets,
                    total: state.totalInvested,
                    hideBalance: hide,
                  ),
                ),
              ),

            if (state.sectorData.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(UI.md, 12, UI.md, 0),
                  child: SectorCard(
                    sectorData: state.sectorData,
                    totalInvested: state.totalInvested,
                  ),
                ),
              ),

            if (state.topHoldings.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(UI.md, 12, UI.md, 0),
                  child: TopHoldingsCard(
                    holdings: state.topHoldings,
                    hideBalance: hide,
                  ),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(UI.md, 12, UI.md, 0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: EarningsCard(
                    key: ValueKey(state.timeFilter),
                    data: state.monthlyEarnings,
                    hideBalance: hide,
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}
