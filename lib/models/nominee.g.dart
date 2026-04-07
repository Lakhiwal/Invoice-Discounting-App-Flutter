// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nominee.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$NomineeImpl _$$NomineeImplFromJson(Map<String, dynamic> json) =>
    _$NomineeImpl(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      age: (json['age'] as num).toInt(),
      gender: json['gender'] as String,
      relationship: json['relationship'] as String,
      guardianName: json['guardianName'] as String,
      address: json['address'] as String,
    );

Map<String, dynamic> _$$NomineeImplToJson(_$NomineeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'age': instance.age,
      'gender': instance.gender,
      'relationship': instance.relationship,
      'guardianName': instance.guardianName,
      'address': instance.address,
    };
