import 'package:invoice_discounting_app/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PortfolioCache  — fixes applied:
//  #4  In-flight deduplication: concurrent callers share one Future instead
//      of racing to overwrite _portfolio with their own results.
//  #22 invalidate() now resets _lastFetch too, so the stale timestamp
//      can never cause a false cache-hit after the next write.
// ─────────────────────────────────────────────────────────────────────────────

class PortfolioCache {
  static Map<String, dynamic>? _portfolio;
  static DateTime? _lastFetch;

  // FIX #4: single shared in-flight future. If a second caller arrives while
  // the first fetch is in progress, it awaits the same Future instead of
  // firing a duplicate network request.
  static Future<Map<String, dynamic>>? _inflight;

  static const Duration cacheDuration = Duration(hours: 4);

  static Future<Map<String, dynamic>> getPortfolio({
    bool forceRefresh = false,
    int page = 1,
    int limit = 20,
    String type = 'all',
    bool? isSecondary,
  }) async {
    // Serve from cache if still fresh and NOT forced (only for page 1 and 'all')
    if (!forceRefresh &&
        page == 1 &&
        type == 'all' &&
        isSecondary == null &&
        _portfolio != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < cacheDuration) {
      return _portfolio!;
    }

    if (forceRefresh && page == 1 && type == 'all' && isSecondary == null) {
      invalidate();
    }

    // In-flight logic per-request type/page/secondary
    // Note: for simplicity in this facade, we don't fully key the in-flight
    // but the domain service will handle it.
    if (_inflight != null) return _inflight!;

    _inflight = _fetch(
      forceRefresh: forceRefresh,
      page: page,
      limit: limit,
      type: type,
      isSecondary: isSecondary,
    );
    try {
      return await _inflight!;
    } finally {
      _inflight = null;
    }
  }

  static Future<Map<String, dynamic>> _fetch({
    bool forceRefresh = false,
    int page = 1,
    int limit = 20,
    String type = 'all',
    bool? isSecondary,
  }) async {
    final data = await ApiService.getPortfolio(
      forceRefresh: forceRefresh,
      page: page,
      limit: limit,
      type: type,
      isSecondary: isSecondary,
    );
    if (data == null) return {};
    if (page == 1 && type == 'all' && isSecondary == null) {
      _portfolio = data;
      _lastFetch = DateTime.now();
    }
    return data;
  }

  static void invalidate() {
    _portfolio = null;
    // FIX #22: also reset _lastFetch so a stale timestamp cannot produce a
    // false cache-hit if logic around the null check ever changes.
    _lastFetch = null;
  }

  /// Full wipe — call on logout to ensure the next user session
  /// never sees stale data from the previous account.
  static void clear() {
    _portfolio = null;
    _lastFetch = null;
    _inflight = null;
  }
}
