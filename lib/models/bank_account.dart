import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:invoice_discounting_app/utils/bank_resolver.dart';

part 'bank_account.freezed.dart';
part 'bank_account.g.dart';

@freezed
class BankAccount with _$BankAccount {
  const factory BankAccount({
    required int id,
    required String bankName,
    required String accountNumber,
    required String ifscCode,
    required String beneficiaryName,
    required String branchAddress,
    required bool isPrimary,
  }) = _BankAccount;

  const BankAccount._();

  factory BankAccount.fromJson(Map<String, dynamic> json) =>
      _$BankAccountFromJson(json);

  factory BankAccount.fromMap(Map<String, dynamic> m) => BankAccount(
        id: m['id'] as int,
        bankName: (m['bank_name'] ?? '') as String,
        accountNumber: (m['account_number'] ?? '') as String,
        ifscCode: (m['ifsc_code'] ?? '') as String,
        beneficiaryName: (m['beneficiary_name'] ?? '') as String,
        branchAddress: (m['branch_address'] ?? '') as String,
        isPrimary: (m['is_primary'] ?? false) as bool,
      );

  String get maskedNumber {
    if (accountNumber.length <= 4) return accountNumber;
    return '···· ${accountNumber.substring(accountNumber.length - 4)}';
  }

  /// Get info for the bank based on IFSC
  BankInfo get bankInfo => BankResolver.resolve(ifscCode);

  /// Get a color for the bank icon
  Color get brandColor => bankInfo.brandColor;

  /// Get the official bank name
  String get officialName => bankInfo.name;

  /// Get logo URL if available
  String? get logoUrl => bankInfo.logoUrl;
}
