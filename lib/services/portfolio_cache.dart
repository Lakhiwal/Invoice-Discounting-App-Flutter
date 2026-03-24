import 'api_service.dart';

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

  static const Duration cacheDuration = Duration(seconds: 10);

  static Future<Map<String, dynamic>> getPortfolio() async {
    // Serve from cache if still fresh
    if (_portfolio != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < cacheDuration) {
      return _portfolio!;
    }

    // FIX #4: if a fetch is already in progress, return that same future
    if (_inflight != null) return _inflight!;

    _inflight = _fetch();
    try {
      return await _inflight!;
    } finally {
      _inflight = null;
    }
  }

  static Future<Map<String, dynamic>> _fetch() async {
    final data = await ApiService.getPortfolio();
    if (data == null) return {};
    _portfolio = data;
    _lastFetch = DateTime.now();
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