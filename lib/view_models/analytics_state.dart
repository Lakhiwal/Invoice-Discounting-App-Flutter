import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'analytics_state.freezed.dart';

@freezed
class AnalyticsState with _$AnalyticsState {
  const factory AnalyticsState({
    @Default([]) List<Map<String, dynamic>> allActive,
    @Default([]) List<Map<String, dynamic>> allRepaid,
    @Default([]) List<Map<String, dynamic>> filteredActive,
    @Default([]) List<Map<String, dynamic>> filteredRepaid,
    @Default('All') String timeFilter,
    @Default(['All', '3M', '6M', '1Y']) List<String> timeOptions,
    @Default(0.0) double totalInvested,
    @Default(0.0) double totalReturns,
    @Default(0.0) double avgYield,
    @Default(0) int avgTenure,
    @Default(0) int healthScore,
    @Default('No data') String healthLabel,
    @Default(Colors.grey) Color healthColor,
    @Default([]) List<String> healthFactors,
    @Default([]) List<Map<String, dynamic>> sectorData,
    @Default([]) List<Map<String, dynamic>> maturityData,
    @Default({}) Map<String, double> riskBuckets,
    @Default([]) List<Map<String, dynamic>> monthlyEarnings,
    @Default([]) List<Map<String, dynamic>> topHoldings,
    @Default(false) bool isFetching,
  }) = _AnalyticsState;
}
