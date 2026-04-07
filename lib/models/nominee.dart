import 'package:freezed_annotation/freezed_annotation.dart';

part 'nominee.freezed.dart';
part 'nominee.g.dart';

@freezed
class Nominee with _$Nominee {
  const factory Nominee({
    required int id,
    required String name,
    required int age,
    required String gender,
    required String relationship,
    required String guardianName,
    required String address,
  }) = _Nominee;

  const Nominee._();

  factory Nominee.fromJson(Map<String, dynamic> json) => _$NomineeFromJson(json);

  factory Nominee.fromMap(Map<String, dynamic> m) => Nominee(
        id: m['id'] as int,
        name: (m['name'] ?? '') as String,
        age: (m['age'] ?? 0) as int,
        gender: (m['gender'] ?? '') as String,
        relationship: (m['relationship'] ?? '') as String,
        guardianName: (m['guardian_name'] ?? '') as String,
        address: (m['address'] ?? '') as String,
      );

  bool get isMinor => age < 18;
}
