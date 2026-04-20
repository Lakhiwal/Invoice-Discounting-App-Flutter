import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:invoice_discounting_app/theme/app_icons.dart';
import 'package:invoice_discounting_app/theme/ui_constants.dart';
import 'package:invoice_discounting_app/view_models/analytics_view_model.dart';
import 'package:shimmer/shimmer.dart';

/// ─────────────────────────────────────────────────────────
/// AiInsightsService
/// ─────────────────────────────────────────────────────────
class AiInsightsService {
  // The user requested to hardcode testing key
  static const _apiKey = 'REMOVED_API_KEY';

  // 🛡️ SESSION CACHE
  static final Map<String, List<String>> _cache = {};

  static String _getCacheKey(
    double inv,
    double ret,
    double yid,
    String filter,
  ) =>
      '$inv-$ret-$yid-$filter';

  static Future<List<String>> generateInsights({
    required double totalInvested,
    required double totalReturns,
    required double avgYield,
    required String activeFilter,
  }) async {
    final cacheKey =
        _getCacheKey(totalInvested, totalReturns, avgYield, activeFilter);
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final yieldStr = avgYield.toStringAsFixed(1);
    final investedStr = totalInvested.toStringAsFixed(0);
    final returnsStr = totalReturns.toStringAsFixed(0);

    // Mock mode (keep this)
    if (_apiKey == 'REMOVED_API_KEY') {
      await Future<void>.delayed(const Duration(seconds: 1));
      final mock = [
        'Portfolio performance is stable with a $yieldStr% yield, indicating consistent returns.',
        'Your current allocation may have concentration risk under $activeFilter; consider diversifying exposure.',
        'Increasing allocation or exploring higher-yield invoices could improve overall returns.',
      ];
      _cache[cacheKey] = mock;
      return mock;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final prompt =
          _getPrompt(investedStr, returnsStr, yieldStr, activeFilter);
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      final insights = _parseInsights(text);
      if (insights.isNotEmpty) {
        _cache[cacheKey] = insights;
        return insights;
      }

      return _fallbackInsights(yieldStr, investedStr, returnsStr, activeFilter);
    } catch (e) {
      return _fallbackInsights(yieldStr, investedStr, returnsStr, activeFilter);
    }
  }

  static Stream<String> generateInsightsStream({
    required double totalInvested,
    required double totalReturns,
    required double avgYield,
    required String activeFilter,
  }) async* {
    final yieldStr = avgYield.toStringAsFixed(1);
    final investedStr = totalInvested.toStringAsFixed(0);
    final returnsStr = totalReturns.toStringAsFixed(0);

    if (_apiKey == 'REMOVED_API_KEY') {
      const text =
          'Analyzing your portfolio performance... Finding optimization opportunities...';
      for (final word in text.split(' ')) {
        yield '$word ';
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final prompt =
          _getPrompt(investedStr, returnsStr, yieldStr, activeFilter);
      final responseStream =
          model.generateContentStream([Content.text(prompt)]);

      await for (final chunk in responseStream) {
        if (chunk.text != null) yield chunk.text!;
      }
    } catch (_) {}
  }

  static String _getPrompt(
    String invested,
    String returns,
    String yid,
    String filter,
  ) =>
      '''
You are a senior financial advisor specializing in invoice discounting portfolios.

Analyze the portfolio and return EXACTLY 3 insights in STRICT JSON format.

OUTPUT FORMAT (MANDATORY):
{
  "insights": [
    "string",
    "string",
    "string"
  ]
}

RULES:
- Return ONLY JSON (no markdown, no explanation)
- Exactly 3 insights
- Each insight must be 1–2 sentences
- Keep it concise, professional, and actionable
- No numbering, no labels

PORTFOLIO:
- Total Invested: ₹$invested
- Total Returns: ₹$returns
- Average Yield: $yid%
- Active Filter: $filter

GUIDANCE:
- High yield → mention risk trade-off
- Low yield → suggest optimization
- Filter → consider diversification impact
- Strong returns → highlight efficiency briefly

Generate response now.
''';

  static List<String> _parseInsights(String text) {
    final jsonStart = text.indexOf('{');
    final jsonEnd = text.lastIndexOf('}');

    if (jsonStart != -1 && jsonEnd != -1) {
      final jsonString = text.substring(jsonStart, jsonEnd + 1);
      try {
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        final insights =
            List<String>.from(decoded['insights'] as Iterable? ?? []);
        if (insights.length == 3) return insights;
      } catch (_) {}
    }
    return [];
  }

  static List<String> _fallbackInsights(
    String yieldStr,
    String investedStr,
    String returnsStr,
    String activeFilter,
  ) =>
      [
        'Portfolio performance is moderate with a $yieldStr% yield; monitor for better opportunities.',
        'Your investments under $activeFilter may lack diversification; spreading risk could improve stability.',
        'Reinvesting returns or targeting higher-yield invoices can enhance long-term growth.',
      ];
}

/// ─────────────────────────────────────────────────────────
/// AiInsightState & Notifier
/// ─────────────────────────────────────────────────────────
class AiInsightState {
  AiInsightState({
    this.insights = const [],
    this.streamingText = '',
    this.isStreaming = false,
    this.isLoading = false,
    this.error,
  });
  final List<String> insights;
  final String streamingText;
  final bool isStreaming;
  final bool isLoading;
  final String? error;

  AiInsightState copyWith({
    List<String>? insights,
    String? streamingText,
    bool? isStreaming,
    bool? isLoading,
    String? error,
  }) =>
      AiInsightState(
        insights: insights ?? this.insights,
        streamingText: streamingText ?? this.streamingText,
        isStreaming: isStreaming ?? this.isStreaming,
        isLoading: isLoading ?? this.isLoading,
        error: error ?? this.error,
      );
}

class AiInsightNotifier extends StateNotifier<AiInsightState> {
  AiInsightNotifier() : super(AiInsightState());

  Future<void> fetchInsights({
    required double totalInvested,
    required double totalReturns,
    required double avgYield,
    required String activeFilter,
  }) async {
    // If we have insights and parameters haven't changed (handled by provider watching analytics),
    // we might want to return early, but AnalyticsState change usually means we need fresh insights.

    state = state.copyWith(
      isLoading: true,
      insights: [],
      streamingText: '',
    );

    // Initial delay to show shimmer if mock mode is too fast
    await Future<void>.delayed(const Duration(milliseconds: 500));

    state = state.copyWith(isLoading: false, isStreaming: true);

    try {
      final stream = AiInsightsService.generateInsightsStream(
        totalInvested: totalInvested,
        totalReturns: totalReturns,
        avgYield: avgYield,
        activeFilter: activeFilter,
      );

      final buffer = StringBuffer();
      await for (final chunk in stream) {
        buffer.write(chunk);
        state = state.copyWith(streamingText: buffer.toString());
      }

      // Once stream ends, finalize with the 3-slide data
      final finalInsights = await AiInsightsService.generateInsights(
        totalInvested: totalInvested,
        totalReturns: totalReturns,
        avgYield: avgYield,
        activeFilter: activeFilter,
      );

      state = state.copyWith(
        isStreaming: false,
        insights: finalInsights,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isStreaming: false,
        error: e.toString(),
      );
    }
  }
}

final AutoDisposeStateNotifierProvider<AiInsightNotifier, AiInsightState>
    aiInsightProvider =
    StateNotifierProvider.autoDispose<AiInsightNotifier, AiInsightState>((ref) {
  final notifier = AiInsightNotifier();

  // Watch analytics to trigger fresh insights
  ref.watch(analyticsProvider.future).then((analytics) {
    notifier.fetchInsights(
      totalInvested: analytics.totalInvested,
      totalReturns: analytics.totalReturns,
      avgYield: analytics.avgYield,
      activeFilter: analytics.timeFilter,
    );
  });

  return notifier;
});

/// ─────────────────────────────────────────────────────────
/// AiInsightCard
/// ─────────────────────────────────────────────────────────
class AiInsightCard extends ConsumerStatefulWidget {
  const AiInsightCard({super.key});

  @override
  ConsumerState<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends ConsumerState<AiInsightCard> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (!mounted) return;
      final next = (_currentPage + 1) % 3;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final insightsState = ref.watch(aiInsightProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(UI.radiusMd),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(AppIcons.magic, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    'AI Insights',
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              if (insightsState.insights.isNotEmpty &&
                  !insightsState.isStreaming &&
                  !insightsState.isLoading)
                Row(
                  children: List.generate(
                    insightsState.insights.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(left: 4),
                      width: _currentPage == index ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? cs.primary
                            : cs.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 65, // Fixed height for text stability
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _buildContent(insightsState, cs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AiInsightState state, ColorScheme cs) {
    if (state.isLoading) return _buildSkeleton(cs);

    if (state.isStreaming) {
      return Text(
        state.streamingText,
        key: const ValueKey('streaming'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 13,
          height: 1.5,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    if (state.error != null) {
      return Text(
        'AI evaluation is busy. Please try refreshing dashboard.',
        key: const ValueKey('error'),
        style: TextStyle(color: cs.error.withValues(alpha: 0.7), fontSize: 13),
      );
    }

    if (state.insights.isEmpty) return const SizedBox.shrink();

    return PageView.builder(
      key: const ValueKey('slides'),
      controller: _pageController,
      onPageChanged: (idx) {
        setState(() => _currentPage = idx);
        _startAutoSlide();
      },
      itemCount: state.insights.length,
      itemBuilder: (context, index) => Text(
        state.insights[index],
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 13,
          height: 1.5,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildSkeleton(ColorScheme cs) => Shimmer.fromColors(
        baseColor: cs.onSurface.withValues(alpha: 0.05),
        highlightColor: cs.onSurface.withValues(alpha: 0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(UI.radiusSm),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 12,
              width: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(UI.radiusSm),
              ),
            ),
          ],
        ),
      );
}
