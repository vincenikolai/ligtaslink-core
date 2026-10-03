import 'dart:convert';

class VulnerabilityFlags {
  final bool isPwd;
  final bool isSenior;
  final bool isPregnant;

  const VulnerabilityFlags({required this.isPwd, required this.isSenior, required this.isPregnant});

  factory VulnerabilityFlags.fromJson(Map<String, dynamic> json) => VulnerabilityFlags(
        isPwd: json['is_pwd'] == true,
        isSenior: json['is_senior'] == true,
        isPregnant: json['is_pregnant'] == true,
      );

  Map<String, bool> toJson() => {'is_pwd': isPwd, 'is_senior': isSenior, 'is_pregnant': isPregnant};

  bool get any => isPwd || isSenior || isPregnant;

  List<String> get labels => [
        if (isPwd) 'PWD',
        if (isSenior) 'Senior',
        if (isPregnant) 'Pregnant',
      ];
}

class Resident {
  final String householdId;
  final String familyHeadName;
  final int addressPurok;
  final int dependentCount;
  final VulnerabilityFlags flags;
  final String qrToken;

  const Resident({
    required this.householdId,
    required this.familyHeadName,
    required this.addressPurok,
    required this.dependentCount,
    required this.flags,
    required this.qrToken,
  });

  /// Head of household plus dependents.
  int get householdSize => dependentCount + 1;

  /// Relief packs released per claim: one per household plus one per four dependents.
  int get reliefAllocation => 1 + dependentCount ~/ 4;

  factory Resident.fromJson(Map<String, dynamic> json) => Resident(
        householdId: json['household_id'] as String,
        familyHeadName: json['family_head_name'] as String,
        addressPurok: json['address_purok'] as int,
        dependentCount: json['dependent_count'] as int,
        flags: VulnerabilityFlags.fromJson(Map<String, dynamic>.from(json['vulnerability_flags'] as Map)),
        qrToken: json['qr_token'] as String,
      );

  factory Resident.fromRow(Map<String, Object?> row) => Resident(
        householdId: row['household_id'] as String,
        familyHeadName: row['family_head_name'] as String,
        addressPurok: row['address_purok'] as int,
        dependentCount: row['dependent_count'] as int,
        flags: VulnerabilityFlags.fromJson(jsonDecode(row['vulnerability_flags'] as String) as Map<String, dynamic>),
        qrToken: row['qr_token'] as String,
      );

  Map<String, Object?> toRow() => {
        'household_id': householdId,
        'family_head_name': familyHeadName,
        'address_purok': addressPurok,
        'dependent_count': dependentCount,
        'vulnerability_flags': jsonEncode(flags.toJson()),
        'qr_token': qrToken,
      };
}
