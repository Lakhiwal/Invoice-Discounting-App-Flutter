import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:invoice_discounting_app/models/invoice_item.dart';
import 'package:invoice_discounting_app/services/api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'marketplace_view_model.freezed.dart';
part 'marketplace_view_model.g.dart';

typedef MarketplaceNotifier = Marketplace;

@freezed
class MarketplaceState with _$MarketplaceState {
  const factory MarketplaceState({
    @Default([]) List<InvoiceItem> allInvoices,
    @Default([]) List<InvoiceItem> filtered,
    @Default(1) int page,
    @Default(true) bool hasMore,
    @Default(false) bool isLoadingMore,
    @Default('All') String selectedStatus,
    @Default('') String searchQuery,
    @Default(0.0) double minRoi,
    @Default(30.0) double maxRoi,
    @Default(0.0) double minDays,
    @Default(365.0) double maxDays,
    @Default(0.0) double minFunding,
    @Default(100.0) double maxFunding,
    @Default('default') String sortBy,
    String? activeQuickFilter,
    @Default(0) int filterGeneration,
    String? errorMessage,
  }) = _MarketplaceState;
}

@Riverpod(keepAlive: true)
class Marketplace extends _$Marketplace {
  static const int _limit = 40;
  static const List<String> statusFilters = [
    'All',
    'Available',
    'Partially Funded',
  ];
  static const List<String> quickFilters = [
    'High ROI',
    'Short Tenure',
    'Almost Funded',
  ];

  @override
  FutureOr<MarketplaceState> build() async {
    // Initial state setup
    const initialState = MarketplaceState();

    // Trigger initial load
    return _fetchInvoices(initialState, forceRefresh: true);
  }

  Future<MarketplaceState> _fetchInvoices(
    MarketplaceState current, {
    bool forceRefresh = false,
  }) async {
    final targetPage = forceRefresh ? 1 : current.page;

    try {
      final data = await ApiService.getInvoices(
        page: targetPage,
        limit: _limit,
        forceRefresh: forceRefresh,
      );

      final incoming = data
          .map<InvoiceItem>(
            (e) => InvoiceItem.fromMap(e as Map<String, dynamic>),
          )
          .toList();

      final updatedAll = forceRefresh
          ? <InvoiceItem>[]
          : List<InvoiceItem>.from(current.allInvoices);

      for (final item in incoming) {
        final idx = updatedAll.indexWhere((i) => i.id == item.id);
        if (idx != -1) {
          updatedAll[idx] = item;
        } else {
          updatedAll.add(item);
        }
      }

      final hasMore = incoming.length >= _limit;
      final newState = current.copyWith(
        allInvoices: updatedAll,
        page: hasMore ? targetPage + 1 : targetPage,
        hasMore: hasMore,
        isLoadingMore: false,
        errorMessage: null,
      );

      // Apply filtering to the newly fetched data
      return _applyFiltersToState(newState);
    } catch (e) {
      debugPrint('Notification sync error: $e');
      return current.copyWith(
        isLoadingMore: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    state = await AsyncValue.guard(
      () => _fetchInvoices(state.value!),
    );
  }

  Future<void> refresh({bool silent = false}) async {
    final startTime = DateTime.now();

    if (!silent) {
      state = const AsyncLoading();
    }

    final newState = await AsyncValue.guard(
      () => _fetchInvoices(const MarketplaceState(), forceRefresh: true),
    );

    // Ensure the "Syncing" state is visible for a premium feel
    final elapsed = DateTime.now().difference(startTime).inMilliseconds;
    if (elapsed < 800) {
      await Future<void>.delayed(Duration(milliseconds: 800 - elapsed));
    }

    state = newState;
  }

  void setSearchQuery(String q) {
    final current = state.value;
    if (current == null || current.searchQuery == q) return;

    state = AsyncData(current.copyWith(searchQuery: q));
    _triggerFiltering();
  }

  void setStatus(String s) {
    final current = state.value;
    if (current == null || current.selectedStatus == s) return;

    state = AsyncData(current.copyWith(selectedStatus: s));
    _triggerFiltering();
  }

  void toggleQuickFilter(String f) {
    final current = state.value;
    if (current == null) return;

    MarketplaceState next;
    if (current.activeQuickFilter == f) {
      next = current.copyWith(
        activeQuickFilter: null,
        minRoi: 0,
        maxRoi: 30,
        minDays: 0,
        maxDays: 365,
        minFunding: 0,
        maxFunding: 100,
      );
    } else {
      next = current.copyWith(
        activeQuickFilter: f,
        minRoi: f == 'High ROI' ? 13 : 0,
        maxDays: f == 'Short Tenure' ? 30 : 365,
        minFunding: f == 'Almost Funded' ? 75 : 0,
      );
    }

    state = AsyncData(next);
    _triggerFiltering();
  }

  void setSortBy(String s) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(sortBy: s));
    _triggerFiltering();
  }

  void clearFilters() {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(
        activeQuickFilter: null,
        minRoi: 0,
        maxRoi: 30,
        minDays: 0,
        maxDays: 365,
        minFunding: 0,
        maxFunding: 100,
        sortBy: 'default',
        selectedStatus: 'All',
        searchQuery: '',
      ),
    );
    _triggerFiltering();
  }

  Future<void> _triggerFiltering() async {
    final current = state.value;
    if (current == null) return;
    state = await AsyncValue.guard(() => _applyFiltersToState(current));
  }

  Future<MarketplaceState> _applyFiltersToState(
    MarketplaceState current,
  ) async {
    final generation = current.filterGeneration + 1;
    final params = {
      'invoices': current.allInvoices
          .map(
            (i) => {
              'id': i.id,
              'company': i.company,
              'status': i.status,
              'statusDisplay': i.statusDisplay,
              'roi': i.roi,
              'tenureDays': i.tenureDays,
              'remainingAmount': i.remainingAmount,
              'fundingPct': i.fundingPct,
            },
          )
          .toList(),
      'status': current.selectedStatus,
      'minRoi': current.minRoi,
      'maxRoi': current.maxRoi,
      'minDays': current.minDays,
      'maxDays': current.maxDays,
      'minFunding': current.minFunding,
      'maxFunding': current.maxFunding,
      'sortBy': current.sortBy,
      'query': current.searchQuery,
    };

    final rawResult = current.allInvoices.length < 300
        ? _filterInvoicesIsolate(params)
        : await compute(_filterInvoicesIsolate, params);

    final idMap = {for (final item in current.allInvoices) item.id: item};
    final filtered =
        rawResult.map((m) => idMap[m['id']]).whereType<InvoiceItem>().toList();

    return current.copyWith(
      filtered: filtered,
      filterGeneration: generation,
    );
  }

  int getActiveFilterCount() {
    final current = state.value;
    if (current == null) return 0;
    var c = 0;
    if (current.minRoi > 0 || current.maxRoi < 30) c++;
    if (current.minDays > 0 || current.maxDays < 365) c++;
    if (current.sortBy != 'default') c++;
    if (current.minFunding > 0 || current.maxFunding < 100) c++;
    return c;
  }
}

List<Map<String, dynamic>> _filterInvoicesIsolate(Map<String, dynamic> params) {
  final raw = List<Map<String, dynamic>>.from(params['invoices'] as List);
  final selectedStatus = params['status'] as String;
  final query = (params['query'] as String).toLowerCase();

  var result = raw;
  if (selectedStatus == 'Available') {
    result = result
        .where(
          (i) => (i['status'] ?? '').toString().toLowerCase() == 'available',
        )
        .toList();
  } else if (selectedStatus == 'Partially Funded') {
    result = result.where((i) {
      final s = (i['status'] ?? '').toString().toLowerCase();
      final d = (i['statusDisplay'] ?? '').toString().toLowerCase();
      return s.contains('partial') || d.contains('partial');
    }).toList();
  }

  result = result.where((i) {
    final roi = (i['roi'] as num?)?.toDouble() ?? 0;
    final tenure = (i['tenureDays'] as num?)?.toDouble() ?? 0;
    final funding = (i['fundingPct'] as num?)?.toDouble() ?? 0;
    return roi >= (params['minRoi'] as num) &&
        roi <= (params['maxRoi'] as num) &&
        tenure >= (params['minDays'] as num) &&
        tenure <= (params['maxDays'] as num) &&
        funding >= (params['minFunding'] as num) &&
        funding <= (params['maxFunding'] as num);
  }).toList();

  if (query.isNotEmpty) {
    result = result
        .where((i) => (i['company'] as String).toLowerCase().contains(query))
        .toList();
  }

  final sortBy = params['sortBy'] as String;
  if (sortBy == 'roi_high') {
    result.sort((a, b) => (b['roi'] as num).compareTo(a['roi'] as num));
  } else if (sortBy == 'days_low') {
    result.sort(
      (a, b) => (a['tenureDays'] as num).compareTo(b['tenureDays'] as num),
    );
  } else if (sortBy == 'amount_high') {
    result.sort(
      (a, b) =>
          (b['remainingAmount'] as num).compareTo(a['remainingAmount'] as num),
    );
  }

  return result;
}
