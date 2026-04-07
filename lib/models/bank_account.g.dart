// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bank_account.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BankAccountImpl _$$BankAccountImplFromJson(Map<String, dynamic> json) =>
    _$BankAccountImpl(
      id: (json['id'] as num).toInt(),
      bankName: json['bankName'] as String,
      accountNumber: json['accountNumber'] as String,
      ifscCode: json['ifscCode'] as String,
      beneficiaryName: json['beneficiaryName'] as String,
      branchAddress: json['branchAddress'] as String,
      isPrimary: json['isPrimary'] as bool,
    );

Map<String, dynamic> _$$BankAccountImplToJson(_$BankAccountImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bankName': instance.bankName,
      'accountNumber': instance.accountNumber,
      'ifscCode': instance.ifscCode,
      'beneficiaryName': instance.beneficiaryName,
      'branchAddress': instance.branchAddress,
      'isPrimary': instance.isPrimary,
    };
