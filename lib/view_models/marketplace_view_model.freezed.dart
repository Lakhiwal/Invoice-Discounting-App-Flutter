// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'marketplace_view_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MarketplaceState {
  List<InvoiceItem> get allInvoices => throw _privateConstructorUsedError;
  List<InvoiceItem> get filtered => throw _privateConstructorUsedError;
  int get page => throw _privateConstructorUsedError;
  bool get hasMore => throw _privateConstructorUsedError;
  bool get isLoadingMore => throw _privateConstructorUsedError;
  String get selectedStatus => throw _privateConstructorUsedError;
  String get searchQuery => throw _privateConstructorUsedError;
  double get minRoi => throw _privateConstructorUsedError;
  double get maxRoi => throw _privateConstructorUsedError;
  double get minDays => throw _privateConstructorUsedError;
  double get maxDays => throw _privateConstructorUsedError;
  double get minFunding => throw _privateConstructorUsedError;
  double get maxFunding => throw _privateConstructorUsedError;
  String get sortBy => throw _privateConstructorUsedError;
  String? get activeQuickFilter => throw _privateConstructorUsedError;
  int get filterGeneration => throw _privateConstructorUsedError;
  String? get errorMessage => throw _privateConstructorUsedError;

  /// Create a copy of MarketplaceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MarketplaceStateCopyWith<MarketplaceState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MarketplaceStateCopyWith<$Res> {
  factory $MarketplaceStateCopyWith(
          MarketplaceState value, $Res Function(MarketplaceState) then) =
      _$MarketplaceStateCopyWithImpl<$Res, MarketplaceState>;
  @useResult
  $Res call(
      {List<InvoiceItem> allInvoices,
      List<InvoiceItem> filtered,
      int page,
      bool hasMore,
      bool isLoadingMore,
      String selectedStatus,
      String searchQuery,
      double minRoi,
      double maxRoi,
      double minDays,
      double maxDays,
      double minFunding,
      double maxFunding,
      String sortBy,
      String? activeQuickFilter,
      int filterGeneration,
      String? errorMessage});
}

/// @nodoc
class _$MarketplaceStateCopyWithImpl<$Res, $Val extends MarketplaceState>
    implements $MarketplaceStateCopyWith<$Res> {
  _$MarketplaceStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MarketplaceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? allInvoices = null,
    Object? filtered = null,
    Object? page = null,
    Object? hasMore = null,
    Object? isLoadingMore = null,
    Object? selectedStatus = null,
    Object? searchQuery = null,
    Object? minRoi = null,
    Object? maxRoi = null,
    Object? minDays = null,
    Object? maxDays = null,
    Object? minFunding = null,
    Object? maxFunding = null,
    Object? sortBy = null,
    Object? activeQuickFilter = freezed,
    Object? filterGeneration = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_value.copyWith(
      allInvoices: null == allInvoices
          ? _value.allInvoices
          : allInvoices // ignore: cast_nullable_to_non_nullable
              as List<InvoiceItem>,
      filtered: null == filtered
          ? _value.filtered
          : filtered // ignore: cast_nullable_to_non_nullable
              as List<InvoiceItem>,
      page: null == page
          ? _value.page
          : page // ignore: cast_nullable_to_non_nullable
              as int,
      hasMore: null == hasMore
          ? _value.hasMore
          : hasMore // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoadingMore: null == isLoadingMore
          ? _value.isLoadingMore
          : isLoadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      selectedStatus: null == selectedStatus
          ? _value.selectedStatus
          : selectedStatus // ignore: cast_nullable_to_non_nullable
              as String,
      searchQuery: null == searchQuery
          ? _value.searchQuery
          : searchQuery // ignore: cast_nullable_to_non_nullable
              as String,
      minRoi: null == minRoi
          ? _value.minRoi
          : minRoi // ignore: cast_nullable_to_non_nullable
              as double,
      maxRoi: null == maxRoi
          ? _value.maxRoi
          : maxRoi // ignore: cast_nullable_to_non_nullable
              as double,
      minDays: null == minDays
          ? _value.minDays
          : minDays // ignore: cast_nullable_to_non_nullable
              as double,
      maxDays: null == maxDays
          ? _value.maxDays
          : maxDays // ignore: cast_nullable_to_non_nullable
              as double,
      minFunding: null == minFunding
          ? _value.minFunding
          : minFunding // ignore: cast_nullable_to_non_nullable
              as double,
      maxFunding: null == maxFunding
          ? _value.maxFunding
          : maxFunding // ignore: cast_nullable_to_non_nullable
              as double,
      sortBy: null == sortBy
          ? _value.sortBy
          : sortBy // ignore: cast_nullable_to_non_nullable
              as String,
      activeQuickFilter: freezed == activeQuickFilter
          ? _value.activeQuickFilter
          : activeQuickFilter // ignore: cast_nullable_to_non_nullable
              as String?,
      filterGeneration: null == filterGeneration
          ? _value.filterGeneration
          : filterGeneration // ignore: cast_nullable_to_non_nullable
              as int,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$MarketplaceStateImplCopyWith<$Res>
    implements $MarketplaceStateCopyWith<$Res> {
  factory _$$MarketplaceStateImplCopyWith(_$MarketplaceStateImpl value,
          $Res Function(_$MarketplaceStateImpl) then) =
      __$$MarketplaceStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<InvoiceItem> allInvoices,
      List<InvoiceItem> filtered,
      int page,
      bool hasMore,
      bool isLoadingMore,
      String selectedStatus,
      String searchQuery,
      double minRoi,
      double maxRoi,
      double minDays,
      double maxDays,
      double minFunding,
      double maxFunding,
      String sortBy,
      String? activeQuickFilter,
      int filterGeneration,
      String? errorMessage});
}

/// @nodoc
class __$$MarketplaceStateImplCopyWithImpl<$Res>
    extends _$MarketplaceStateCopyWithImpl<$Res, _$MarketplaceStateImpl>
    implements _$$MarketplaceStateImplCopyWith<$Res> {
  __$$MarketplaceStateImplCopyWithImpl(_$MarketplaceStateImpl _value,
      $Res Function(_$MarketplaceStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of MarketplaceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? allInvoices = null,
    Object? filtered = null,
    Object? page = null,
    Object? hasMore = null,
    Object? isLoadingMore = null,
    Object? selectedStatus = null,
    Object? searchQuery = null,
    Object? minRoi = null,
    Object? maxRoi = null,
    Object? minDays = null,
    Object? maxDays = null,
    Object? minFunding = null,
    Object? maxFunding = null,
    Object? sortBy = null,
    Object? activeQuickFilter = freezed,
    Object? filterGeneration = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_$MarketplaceStateImpl(
      allInvoices: null == allInvoices
          ? _value._allInvoices
          : allInvoices // ignore: cast_nullable_to_non_nullable
              as List<InvoiceItem>,
      filtered: null == filtered
          ? _value._filtered
          : filtered // ignore: cast_nullable_to_non_nullable
              as List<InvoiceItem>,
      page: null == page
          ? _value.page
          : page // ignore: cast_nullable_to_non_nullable
              as int,
      hasMore: null == hasMore
          ? _value.hasMore
          : hasMore // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoadingMore: null == isLoadingMore
          ? _value.isLoadingMore
          : isLoadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      selectedStatus: null == selectedStatus
          ? _value.selectedStatus
          : selectedStatus // ignore: cast_nullable_to_non_nullable
              as String,
      searchQuery: null == searchQuery
          ? _value.searchQuery
          : searchQuery // ignore: cast_nullable_to_non_nullable
              as String,
      minRoi: null == minRoi
          ? _value.minRoi
          : minRoi // ignore: cast_nullable_to_non_nullable
              as double,
      maxRoi: null == maxRoi
          ? _value.maxRoi
          : maxRoi // ignore: cast_nullable_to_non_nullable
              as double,
      minDays: null == minDays
          ? _value.minDays
          : minDays // ignore: cast_nullable_to_non_nullable
              as double,
      maxDays: null == maxDays
          ? _value.maxDays
          : maxDays // ignore: cast_nullable_to_non_nullable
              as double,
      minFunding: null == minFunding
          ? _value.minFunding
          : minFunding // ignore: cast_nullable_to_non_nullable
              as double,
      maxFunding: null == maxFunding
          ? _value.maxFunding
          : maxFunding // ignore: cast_nullable_to_non_nullable
              as double,
      sortBy: null == sortBy
          ? _value.sortBy
          : sortBy // ignore: cast_nullable_to_non_nullable
              as String,
      activeQuickFilter: freezed == activeQuickFilter
          ? _value.activeQuickFilter
          : activeQuickFilter // ignore: cast_nullable_to_non_nullable
              as String?,
      filterGeneration: null == filterGeneration
          ? _value.filterGeneration
          : filterGeneration // ignore: cast_nullable_to_non_nullable
              as int,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$MarketplaceStateImpl
    with DiagnosticableTreeMixin
    implements _MarketplaceState {
  const _$MarketplaceStateImpl(
      {final List<InvoiceItem> allInvoices = const [],
      final List<InvoiceItem> filtered = const [],
      this.page = 1,
      this.hasMore = true,
      this.isLoadingMore = false,
      this.selectedStatus = 'All',
      this.searchQuery = '',
      this.minRoi = 0.0,
      this.maxRoi = 30.0,
      this.minDays = 0.0,
      this.maxDays = 365.0,
      this.minFunding = 0.0,
      this.maxFunding = 100.0,
      this.sortBy = 'default',
      this.activeQuickFilter,
      this.filterGeneration = 0,
      this.errorMessage})
      : _allInvoices = allInvoices,
        _filtered = filtered;

  final List<InvoiceItem> _allInvoices;
  @override
  @JsonKey()
  List<InvoiceItem> get allInvoices {
    if (_allInvoices is EqualUnmodifiableListView) return _allInvoices;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allInvoices);
  }

  final List<InvoiceItem> _filtered;
  @override
  @JsonKey()
  List<InvoiceItem> get filtered {
    if (_filtered is EqualUnmodifiableListView) return _filtered;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_filtered);
  }

  @override
  @JsonKey()
  final int page;
  @override
  @JsonKey()
  final bool hasMore;
  @override
  @JsonKey()
  final bool isLoadingMore;
  @override
  @JsonKey()
  final String selectedStatus;
  @override
  @JsonKey()
  final String searchQuery;
  @override
  @JsonKey()
  final double minRoi;
  @override
  @JsonKey()
  final double maxRoi;
  @override
  @JsonKey()
  final double minDays;
  @override
  @JsonKey()
  final double maxDays;
  @override
  @JsonKey()
  final double minFunding;
  @override
  @JsonKey()
  final double maxFunding;
  @override
  @JsonKey()
  final String sortBy;
  @override
  final String? activeQuickFilter;
  @override
  @JsonKey()
  final int filterGeneration;
  @override
  final String? errorMessage;

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return 'MarketplaceState(allInvoices: $allInvoices, filtered: $filtered, page: $page, hasMore: $hasMore, isLoadingMore: $isLoadingMore, selectedStatus: $selectedStatus, searchQuery: $searchQuery, minRoi: $minRoi, maxRoi: $maxRoi, minDays: $minDays, maxDays: $maxDays, minFunding: $minFunding, maxFunding: $maxFunding, sortBy: $sortBy, activeQuickFilter: $activeQuickFilter, filterGeneration: $filterGeneration, errorMessage: $errorMessage)';
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty('type', 'MarketplaceState'))
      ..add(DiagnosticsProperty('allInvoices', allInvoices))
      ..add(DiagnosticsProperty('filtered', filtered))
      ..add(DiagnosticsProperty('page', page))
      ..add(DiagnosticsProperty('hasMore', hasMore))
      ..add(DiagnosticsProperty('isLoadingMore', isLoadingMore))
      ..add(DiagnosticsProperty('selectedStatus', selectedStatus))
      ..add(DiagnosticsProperty('searchQuery', searchQuery))
      ..add(DiagnosticsProperty('minRoi', minRoi))
      ..add(DiagnosticsProperty('maxRoi', maxRoi))
      ..add(DiagnosticsProperty('minDays', minDays))
      ..add(DiagnosticsProperty('maxDays', maxDays))
      ..add(DiagnosticsProperty('minFunding', minFunding))
      ..add(DiagnosticsProperty('maxFunding', maxFunding))
      ..add(DiagnosticsProperty('sortBy', sortBy))
      ..add(DiagnosticsProperty('activeQuickFilter', activeQuickFilter))
      ..add(DiagnosticsProperty('filterGeneration', filterGeneration))
      ..add(DiagnosticsProperty('errorMessage', errorMessage));
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MarketplaceStateImpl &&
            const DeepCollectionEquality()
                .equals(other._allInvoices, _allInvoices) &&
            const DeepCollectionEquality().equals(other._filtered, _filtered) &&
            (identical(other.page, page) || other.page == page) &&
            (identical(other.hasMore, hasMore) || other.hasMore == hasMore) &&
            (identical(other.isLoadingMore, isLoadingMore) ||
                other.isLoadingMore == isLoadingMore) &&
            (identical(other.selectedStatus, selectedStatus) ||
                other.selectedStatus == selectedStatus) &&
            (identical(other.searchQuery, searchQuery) ||
                other.searchQuery == searchQuery) &&
            (identical(other.minRoi, minRoi) || other.minRoi == minRoi) &&
            (identical(other.maxRoi, maxRoi) || other.maxRoi == maxRoi) &&
            (identical(other.minDays, minDays) || other.minDays == minDays) &&
            (identical(other.maxDays, maxDays) || other.maxDays == maxDays) &&
            (identical(other.minFunding, minFunding) ||
                other.minFunding == minFunding) &&
            (identical(other.maxFunding, maxFunding) ||
                other.maxFunding == maxFunding) &&
            (identical(other.sortBy, sortBy) || other.sortBy == sortBy) &&
            (identical(other.activeQuickFilter, activeQuickFilter) ||
                other.activeQuickFilter == activeQuickFilter) &&
            (identical(other.filterGeneration, filterGeneration) ||
                other.filterGeneration == filterGeneration) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_allInvoices),
      const DeepCollectionEquality().hash(_filtered),
      page,
      hasMore,
      isLoadingMore,
      selectedStatus,
      searchQuery,
      minRoi,
      maxRoi,
      minDays,
      maxDays,
      minFunding,
      maxFunding,
      sortBy,
      activeQuickFilter,
      filterGeneration,
      errorMessage);

  /// Create a copy of MarketplaceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MarketplaceStateImplCopyWith<_$MarketplaceStateImpl> get copyWith =>
      __$$MarketplaceStateImplCopyWithImpl<_$MarketplaceStateImpl>(
          this, _$identity);
}

abstract class _MarketplaceState implements MarketplaceState {
  const factory _MarketplaceState(
      {final List<InvoiceItem> allInvoices,
      final List<InvoiceItem> filtered,
      final int page,
      final bool hasMore,
      final bool isLoadingMore,
      final String selectedStatus,
      final String searchQuery,
      final double minRoi,
      final double maxRoi,
      final double minDays,
      final double maxDays,
      final double minFunding,
      final double maxFunding,
      final String sortBy,
      final String? activeQuickFilter,
      final int filterGeneration,
      final String? errorMessage}) = _$MarketplaceStateImpl;

  @override
  List<InvoiceItem> get allInvoices;
  @override
  List<InvoiceItem> get filtered;
  @override
  int get page;
  @override
  bool get hasMore;
  @override
  bool get isLoadingMore;
  @override
  String get selectedStatus;
  @override
  String get searchQuery;
  @override
  double get minRoi;
  @override
  double get maxRoi;
  @override
  double get minDays;
  @override
  double get maxDays;
  @override
  double get minFunding;
  @override
  double get maxFunding;
  @override
  String get sortBy;
  @override
  String? get activeQuickFilter;
  @override
  int get filterGeneration;
  @override
  String? get errorMessage;

  /// Create a copy of MarketplaceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MarketplaceStateImplCopyWith<_$MarketplaceStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
