// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invoice_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

InvoiceItem _$InvoiceItemFromJson(Map<String, dynamic> json) {
  return _InvoiceItem.fromJson(json);
}

/// @nodoc
mixin _$InvoiceItem {
  String get id => throw _privateConstructorUsedError;
  String get company => throw _privateConstructorUsedError;
  String get particular => throw _privateConstructorUsedError;
  String get debtor => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  String get statusDisplay => throw _privateConstructorUsedError;
  double get roi => throw _privateConstructorUsedError;
  int get daysLeft => throw _privateConstructorUsedError;
  int get tenureDays => throw _privateConstructorUsedError;
  double get remainingAmount => throw _privateConstructorUsedError;
  double get fundingPct => throw _privateConstructorUsedError;
  String get roiDisplay => throw _privateConstructorUsedError;
  String get daysLeftDisplay => throw _privateConstructorUsedError;
  String get tenureDisplay => throw _privateConstructorUsedError;
  String get remainingDisplay => throw _privateConstructorUsedError;
  String get fundingDisplay => throw _privateConstructorUsedError;

  /// Serializes this InvoiceItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of InvoiceItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $InvoiceItemCopyWith<InvoiceItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $InvoiceItemCopyWith<$Res> {
  factory $InvoiceItemCopyWith(
          InvoiceItem value, $Res Function(InvoiceItem) then) =
      _$InvoiceItemCopyWithImpl<$Res, InvoiceItem>;
  @useResult
  $Res call(
      {String id,
      String company,
      String particular,
      String debtor,
      String status,
      String statusDisplay,
      double roi,
      int daysLeft,
      int tenureDays,
      double remainingAmount,
      double fundingPct,
      String roiDisplay,
      String daysLeftDisplay,
      String tenureDisplay,
      String remainingDisplay,
      String fundingDisplay});
}

/// @nodoc
class _$InvoiceItemCopyWithImpl<$Res, $Val extends InvoiceItem>
    implements $InvoiceItemCopyWith<$Res> {
  _$InvoiceItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of InvoiceItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? company = null,
    Object? particular = null,
    Object? debtor = null,
    Object? status = null,
    Object? statusDisplay = null,
    Object? roi = null,
    Object? daysLeft = null,
    Object? tenureDays = null,
    Object? remainingAmount = null,
    Object? fundingPct = null,
    Object? roiDisplay = null,
    Object? daysLeftDisplay = null,
    Object? tenureDisplay = null,
    Object? remainingDisplay = null,
    Object? fundingDisplay = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      company: null == company
          ? _value.company
          : company // ignore: cast_nullable_to_non_nullable
              as String,
      particular: null == particular
          ? _value.particular
          : particular // ignore: cast_nullable_to_non_nullable
              as String,
      debtor: null == debtor
          ? _value.debtor
          : debtor // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      statusDisplay: null == statusDisplay
          ? _value.statusDisplay
          : statusDisplay // ignore: cast_nullable_to_non_nullable
              as String,
      roi: null == roi
          ? _value.roi
          : roi // ignore: cast_nullable_to_non_nullable
              as double,
      daysLeft: null == daysLeft
          ? _value.daysLeft
          : daysLeft // ignore: cast_nullable_to_non_nullable
              as int,
      tenureDays: null == tenureDays
          ? _value.tenureDays
          : tenureDays // ignore: cast_nullable_to_non_nullable
              as int,
      remainingAmount: null == remainingAmount
          ? _value.remainingAmount
          : remainingAmount // ignore: cast_nullable_to_non_nullable
              as double,
      fundingPct: null == fundingPct
          ? _value.fundingPct
          : fundingPct // ignore: cast_nullable_to_non_nullable
              as double,
      roiDisplay: null == roiDisplay
          ? _value.roiDisplay
          : roiDisplay // ignore: cast_nullable_to_non_nullable
              as String,
      daysLeftDisplay: null == daysLeftDisplay
          ? _value.daysLeftDisplay
          : daysLeftDisplay // ignore: cast_nullable_to_non_nullable
              as String,
      tenureDisplay: null == tenureDisplay
          ? _value.tenureDisplay
          : tenureDisplay // ignore: cast_nullable_to_non_nullable
              as String,
      remainingDisplay: null == remainingDisplay
          ? _value.remainingDisplay
          : remainingDisplay // ignore: cast_nullable_to_non_nullable
              as String,
      fundingDisplay: null == fundingDisplay
          ? _value.fundingDisplay
          : fundingDisplay // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$InvoiceItemImplCopyWith<$Res>
    implements $InvoiceItemCopyWith<$Res> {
  factory _$$InvoiceItemImplCopyWith(
          _$InvoiceItemImpl value, $Res Function(_$InvoiceItemImpl) then) =
      __$$InvoiceItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String company,
      String particular,
      String debtor,
      String status,
      String statusDisplay,
      double roi,
      int daysLeft,
      int tenureDays,
      double remainingAmount,
      double fundingPct,
      String roiDisplay,
      String daysLeftDisplay,
      String tenureDisplay,
      String remainingDisplay,
      String fundingDisplay});
}

/// @nodoc
class __$$InvoiceItemImplCopyWithImpl<$Res>
    extends _$InvoiceItemCopyWithImpl<$Res, _$InvoiceItemImpl>
    implements _$$InvoiceItemImplCopyWith<$Res> {
  __$$InvoiceItemImplCopyWithImpl(
      _$InvoiceItemImpl _value, $Res Function(_$InvoiceItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of InvoiceItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? company = null,
    Object? particular = null,
    Object? debtor = null,
    Object? status = null,
    Object? statusDisplay = null,
    Object? roi = null,
    Object? daysLeft = null,
    Object? tenureDays = null,
    Object? remainingAmount = null,
    Object? fundingPct = null,
    Object? roiDisplay = null,
    Object? daysLeftDisplay = null,
    Object? tenureDisplay = null,
    Object? remainingDisplay = null,
    Object? fundingDisplay = null,
  }) {
    return _then(_$InvoiceItemImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      company: null == company
          ? _value.company
          : company // ignore: cast_nullable_to_non_nullable
              as String,
      particular: null == particular
          ? _value.particular
          : particular // ignore: cast_nullable_to_non_nullable
              as String,
      debtor: null == debtor
          ? _value.debtor
          : debtor // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      statusDisplay: null == statusDisplay
          ? _value.statusDisplay
          : statusDisplay // ignore: cast_nullable_to_non_nullable
              as String,
      roi: null == roi
          ? _value.roi
          : roi // ignore: cast_nullable_to_non_nullable
              as double,
      daysLeft: null == daysLeft
          ? _value.daysLeft
          : daysLeft // ignore: cast_nullable_to_non_nullable
              as int,
      tenureDays: null == tenureDays
          ? _value.tenureDays
          : tenureDays // ignore: cast_nullable_to_non_nullable
              as int,
      remainingAmount: null == remainingAmount
          ? _value.remainingAmount
          : remainingAmount // ignore: cast_nullable_to_non_nullable
              as double,
      fundingPct: null == fundingPct
          ? _value.fundingPct
          : fundingPct // ignore: cast_nullable_to_non_nullable
              as double,
      roiDisplay: null == roiDisplay
          ? _value.roiDisplay
          : roiDisplay // ignore: cast_nullable_to_non_nullable
              as String,
      daysLeftDisplay: null == daysLeftDisplay
          ? _value.daysLeftDisplay
          : daysLeftDisplay // ignore: cast_nullable_to_non_nullable
              as String,
      tenureDisplay: null == tenureDisplay
          ? _value.tenureDisplay
          : tenureDisplay // ignore: cast_nullable_to_non_nullable
              as String,
      remainingDisplay: null == remainingDisplay
          ? _value.remainingDisplay
          : remainingDisplay // ignore: cast_nullable_to_non_nullable
              as String,
      fundingDisplay: null == fundingDisplay
          ? _value.fundingDisplay
          : fundingDisplay // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$InvoiceItemImpl extends _InvoiceItem {
  const _$InvoiceItemImpl(
      {required this.id,
      required this.company,
      required this.particular,
      required this.debtor,
      required this.status,
      required this.statusDisplay,
      required this.roi,
      required this.daysLeft,
      required this.tenureDays,
      required this.remainingAmount,
      required this.fundingPct,
      required this.roiDisplay,
      required this.daysLeftDisplay,
      required this.tenureDisplay,
      required this.remainingDisplay,
      required this.fundingDisplay})
      : super._();

  factory _$InvoiceItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$InvoiceItemImplFromJson(json);

  @override
  final String id;
  @override
  final String company;
  @override
  final String particular;
  @override
  final String debtor;
  @override
  final String status;
  @override
  final String statusDisplay;
  @override
  final double roi;
  @override
  final int daysLeft;
  @override
  final int tenureDays;
  @override
  final double remainingAmount;
  @override
  final double fundingPct;
  @override
  final String roiDisplay;
  @override
  final String daysLeftDisplay;
  @override
  final String tenureDisplay;
  @override
  final String remainingDisplay;
  @override
  final String fundingDisplay;

  @override
  String toString() {
    return 'InvoiceItem(id: $id, company: $company, particular: $particular, debtor: $debtor, status: $status, statusDisplay: $statusDisplay, roi: $roi, daysLeft: $daysLeft, tenureDays: $tenureDays, remainingAmount: $remainingAmount, fundingPct: $fundingPct, roiDisplay: $roiDisplay, daysLeftDisplay: $daysLeftDisplay, tenureDisplay: $tenureDisplay, remainingDisplay: $remainingDisplay, fundingDisplay: $fundingDisplay)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$InvoiceItemImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.company, company) || other.company == company) &&
            (identical(other.particular, particular) ||
                other.particular == particular) &&
            (identical(other.debtor, debtor) || other.debtor == debtor) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.statusDisplay, statusDisplay) ||
                other.statusDisplay == statusDisplay) &&
            (identical(other.roi, roi) || other.roi == roi) &&
            (identical(other.daysLeft, daysLeft) ||
                other.daysLeft == daysLeft) &&
            (identical(other.tenureDays, tenureDays) ||
                other.tenureDays == tenureDays) &&
            (identical(other.remainingAmount, remainingAmount) ||
                other.remainingAmount == remainingAmount) &&
            (identical(other.fundingPct, fundingPct) ||
                other.fundingPct == fundingPct) &&
            (identical(other.roiDisplay, roiDisplay) ||
                other.roiDisplay == roiDisplay) &&
            (identical(other.daysLeftDisplay, daysLeftDisplay) ||
                other.daysLeftDisplay == daysLeftDisplay) &&
            (identical(other.tenureDisplay, tenureDisplay) ||
                other.tenureDisplay == tenureDisplay) &&
            (identical(other.remainingDisplay, remainingDisplay) ||
                other.remainingDisplay == remainingDisplay) &&
            (identical(other.fundingDisplay, fundingDisplay) ||
                other.fundingDisplay == fundingDisplay));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      company,
      particular,
      debtor,
      status,
      statusDisplay,
      roi,
      daysLeft,
      tenureDays,
      remainingAmount,
      fundingPct,
      roiDisplay,
      daysLeftDisplay,
      tenureDisplay,
      remainingDisplay,
      fundingDisplay);

  /// Create a copy of InvoiceItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$InvoiceItemImplCopyWith<_$InvoiceItemImpl> get copyWith =>
      __$$InvoiceItemImplCopyWithImpl<_$InvoiceItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$InvoiceItemImplToJson(
      this,
    );
  }
}

abstract class _InvoiceItem extends InvoiceItem {
  const factory _InvoiceItem(
      {required final String id,
      required final String company,
      required final String particular,
      required final String debtor,
      required final String status,
      required final String statusDisplay,
      required final double roi,
      required final int daysLeft,
      required final int tenureDays,
      required final double remainingAmount,
      required final double fundingPct,
      required final String roiDisplay,
      required final String daysLeftDisplay,
      required final String tenureDisplay,
      required final String remainingDisplay,
      required final String fundingDisplay}) = _$InvoiceItemImpl;
  const _InvoiceItem._() : super._();

  factory _InvoiceItem.fromJson(Map<String, dynamic> json) =
      _$InvoiceItemImpl.fromJson;

  @override
  String get id;
  @override
  String get company;
  @override
  String get particular;
  @override
  String get debtor;
  @override
  String get status;
  @override
  String get statusDisplay;
  @override
  double get roi;
  @override
  int get daysLeft;
  @override
  int get tenureDays;
  @override
  double get remainingAmount;
  @override
  double get fundingPct;
  @override
  String get roiDisplay;
  @override
  String get daysLeftDisplay;
  @override
  String get tenureDisplay;
  @override
  String get remainingDisplay;
  @override
  String get fundingDisplay;

  /// Create a copy of InvoiceItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$InvoiceItemImplCopyWith<_$InvoiceItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
