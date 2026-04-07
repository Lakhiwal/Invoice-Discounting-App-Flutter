// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$InvoiceItemImpl _$$InvoiceItemImplFromJson(Map<String, dynamic> json) =>
    _$InvoiceItemImpl(
      id: json['id'] as String,
      company: json['company'] as String,
      particular: json['particular'] as String,
      debtor: json['debtor'] as String,
      status: json['status'] as String,
      statusDisplay: json['statusDisplay'] as String,
      roi: (json['roi'] as num).toDouble(),
      daysLeft: (json['daysLeft'] as num).toInt(),
      tenureDays: (json['tenureDays'] as num).toInt(),
      remainingAmount: (json['remainingAmount'] as num).toDouble(),
      fundingPct: (json['fundingPct'] as num).toDouble(),
      roiDisplay: json['roiDisplay'] as String,
      daysLeftDisplay: json['daysLeftDisplay'] as String,
      tenureDisplay: json['tenureDisplay'] as String,
      remainingDisplay: json['remainingDisplay'] as String,
      fundingDisplay: json['fundingDisplay'] as String,
    );

Map<String, dynamic> _$$InvoiceItemImplToJson(_$InvoiceItemImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'company': instance.company,
      'particular': instance.particular,
      'debtor': instance.debtor,
      'status': instance.status,
      'statusDisplay': instance.statusDisplay,
      'roi': instance.roi,
      'daysLeft': instance.daysLeft,
      'tenureDays': instance.tenureDays,
      'remainingAmount': instance.remainingAmount,
      'fundingPct': instance.fundingPct,
      'roiDisplay': instance.roiDisplay,
      'daysLeftDisplay': instance.daysLeftDisplay,
      'tenureDisplay': instance.tenureDisplay,
      'remainingDisplay': instance.remainingDisplay,
      'fundingDisplay': instance.fundingDisplay,
    };
