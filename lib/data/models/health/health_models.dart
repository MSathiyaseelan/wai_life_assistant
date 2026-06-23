// ─────────────────────────────────────────────────────────────────────────────
// Health Space — Data Models
// ─────────────────────────────────────────────────────────────────────────────

String _dateStr(DateTime d) => d.toIso8601String().substring(0, 10);
DateTime? _parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v as String);

// ── Health Profile ────────────────────────────────────────────────────────────

class HealthProfile {
  String id, walletId, memberId;
  String? bloodGroup, height, weight, emergencyContact, emergencyPhone;
  List<String> allergies, conditions, disabilities;

  HealthProfile({
    required this.id,
    required this.walletId,
    required this.memberId,
    this.bloodGroup,
    this.height,
    this.weight,
    this.emergencyContact,
    this.emergencyPhone,
    List<String>? allergies,
    List<String>? conditions,
    List<String>? disabilities,
  })  : allergies = allergies ?? [],
        conditions = conditions ?? [],
        disabilities = disabilities ?? [];

  Map<String, dynamic> toJson() => {
        'wallet_id': walletId,
        'member_id': memberId,
        if (bloodGroup != null) 'blood_group': bloodGroup,
        if (height != null) 'height': height,
        if (weight != null) 'weight': weight,
        if (emergencyContact != null) 'emergency_contact': emergencyContact,
        if (emergencyPhone != null) 'emergency_phone': emergencyPhone,
        'allergies': allergies,
        'conditions': conditions,
        'disabilities': disabilities,
      };

  factory HealthProfile.fromJson(Map<String, dynamic> j) => HealthProfile(
        id: j['id'] as String,
        walletId: j['wallet_id'] as String,
        memberId: j['member_id'] as String,
        bloodGroup: j['blood_group'] as String?,
        height: j['height'] as String?,
        weight: j['weight'] as String?,
        emergencyContact: j['emergency_contact'] as String?,
        emergencyPhone: j['emergency_phone'] as String?,
        allergies: (j['allergies'] as List<dynamic>? ?? []).cast<String>(),
        conditions: (j['conditions'] as List<dynamic>? ?? []).cast<String>(),
        disabilities: (j['disabilities'] as List<dynamic>? ?? []).cast<String>(),
      );

  HealthProfile copyWith({
    String? bloodGroup,
    String? height,
    String? weight,
    String? emergencyContact,
    String? emergencyPhone,
    List<String>? allergies,
    List<String>? conditions,
    List<String>? disabilities,
  }) =>
      HealthProfile(
        id: id,
        walletId: walletId,
        memberId: memberId,
        bloodGroup: bloodGroup ?? this.bloodGroup,
        height: height ?? this.height,
        weight: weight ?? this.weight,
        emergencyContact: emergencyContact ?? this.emergencyContact,
        emergencyPhone: emergencyPhone ?? this.emergencyPhone,
        allergies: allergies ?? List.from(this.allergies),
        conditions: conditions ?? List.from(this.conditions),
        disabilities: disabilities ?? List.from(this.disabilities),
      );
}

// ── Medication ────────────────────────────────────────────────────────────────

class Medication {
  String id, walletId, memberId, name, dosage, frequency;
  List<String> scheduleTimes;
  String? mealTiming, notes;
  bool isActive;
  DateTime startDate;
  DateTime? endDate, refillDate;

  Medication({
    required this.id,
    required this.walletId,
    required this.memberId,
    required this.name,
    required this.dosage,
    required this.frequency,
    List<String>? scheduleTimes,
    this.mealTiming,
    this.notes,
    this.isActive = true,
    DateTime? startDate,
    this.endDate,
    this.refillDate,
  })  : scheduleTimes = scheduleTimes ?? [],
        startDate = startDate ?? DateTime.now();

  String get scheduleLabel {
    final parts = <String>[
      ...scheduleTimes,
      if (mealTiming != null) mealTiming!,
    ];
    return parts.join('  ·  ');
  }

  Map<String, dynamic> toJson() => {
        'wallet_id': walletId,
        'member_id': memberId,
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'schedule_times': scheduleTimes,
        if (mealTiming != null) 'meal_timing': mealTiming,
        if (notes != null) 'notes': notes,
        'is_active': isActive,
        'start_date': _dateStr(startDate),
        if (endDate != null) 'end_date': _dateStr(endDate!),
        if (refillDate != null) 'refill_date': _dateStr(refillDate!),
      };

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: j['id'] as String,
        walletId: j['wallet_id'] as String,
        memberId: j['member_id'] as String,
        name: j['name'] as String,
        dosage: j['dosage'] as String,
        frequency: j['frequency'] as String,
        scheduleTimes: (j['schedule_times'] as List<dynamic>? ?? []).cast<String>(),
        mealTiming: j['meal_timing'] as String?,
        notes: j['notes'] as String?,
        isActive: j['is_active'] as bool? ?? true,
        startDate: _parseDate(j['start_date']) ?? DateTime.now(),
        endDate: _parseDate(j['end_date']),
        refillDate: _parseDate(j['refill_date']),
      );
}

// ── Doctor Record ─────────────────────────────────────────────────────────────

class DoctorRecord {
  String id, walletId, memberId, name;
  String? specialty, hospital, phone, notes;

  DoctorRecord({
    required this.id,
    required this.walletId,
    required this.memberId,
    required this.name,
    this.specialty,
    this.hospital,
    this.phone,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'wallet_id': walletId,
        'member_id': memberId,
        'name': name,
        if (specialty != null) 'specialty': specialty,
        if (hospital != null) 'hospital': hospital,
        if (phone != null) 'phone': phone,
        if (notes != null) 'notes': notes,
      };

  factory DoctorRecord.fromJson(Map<String, dynamic> j) => DoctorRecord(
        id: j['id'] as String,
        walletId: j['wallet_id'] as String,
        memberId: j['member_id'] as String,
        name: j['name'] as String,
        specialty: j['specialty'] as String?,
        hospital: j['hospital'] as String?,
        phone: j['phone'] as String?,
        notes: j['notes'] as String?,
      );
}

// ── Medical Document ──────────────────────────────────────────────────────────

enum MedDocType {
  prescription('📋', 'Prescription'),
  labReport('🔬', 'Lab Report'),
  discharge('🏥', 'Discharge Summary'),
  vaccination('💉', 'Vaccination Card'),
  insurance('🛡️', 'Insurance'),
  other('📄', 'Other');

  final String emoji, label;
  const MedDocType(this.emoji, this.label);
}

class MedicalDocument {
  String id, walletId, memberId, title;
  MedDocType docType;
  List<String> fileUrls;
  String? notes;
  DateTime docDate;

  MedicalDocument({
    required this.id,
    required this.walletId,
    required this.memberId,
    required this.title,
    required this.docType,
    List<String>? fileUrls,
    this.notes,
    DateTime? docDate,
  })  : fileUrls = fileUrls ?? [],
        docDate = docDate ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'wallet_id': walletId,
        'member_id': memberId,
        'title': title,
        'doc_type': docType.name,
        'file_urls': fileUrls,
        if (notes != null) 'notes': notes,
        'doc_date': _dateStr(docDate),
      };

  factory MedicalDocument.fromJson(Map<String, dynamic> j) {
    // Support both old single file_url and new file_urls array
    final rawUrls = j['file_urls'];
    List<String> urls = rawUrls is List
        ? List<String>.from(rawUrls)
        : <String>[];
    final legacyUrl = j['file_url'] as String?;
    if (urls.isEmpty && legacyUrl != null && legacyUrl.isNotEmpty) {
      urls = [legacyUrl];
    }
    return MedicalDocument(
      id: j['id'] as String,
      walletId: j['wallet_id'] as String,
      memberId: j['member_id'] as String,
      title: j['title'] as String,
      docType: MedDocType.values.firstWhere(
        (e) => e.name == j['doc_type'],
        orElse: () => MedDocType.other,
      ),
      fileUrls: urls,
      notes: j['notes'] as String?,
      docDate: _parseDate(j['doc_date']) ?? DateTime.now(),
    );
  }
}

// ── Appointment ───────────────────────────────────────────────────────────────

class Appointment {
  String id, walletId, memberId, doctorName;
  DateTime apptDate;
  String? apptTime, location, notes;

  Appointment({
    required this.id,
    required this.walletId,
    required this.memberId,
    required this.doctorName,
    required this.apptDate,
    this.apptTime,
    this.location,
    this.notes,
  });

  bool get isUpcoming => apptDate.isAfter(DateTime.now().subtract(const Duration(days: 1)));

  Map<String, dynamic> toJson() => {
        'wallet_id': walletId,
        'member_id': memberId,
        'doctor_name': doctorName,
        'appt_date': _dateStr(apptDate),
        if (apptTime != null) 'appt_time': apptTime,
        if (location != null) 'location': location,
        if (notes != null) 'notes': notes,
      };

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'] as String,
        walletId: j['wallet_id'] as String,
        memberId: j['member_id'] as String,
        doctorName: j['doctor_name'] as String,
        apptDate: _parseDate(j['appt_date']) ?? DateTime.now(),
        apptTime: j['appt_time'] as String?,
        location: j['location'] as String?,
        notes: j['notes'] as String?,
      );
}

// ── Health Vital ──────────────────────────────────────────────────────────────

enum VitalType {
  bloodPressure('❤️', 'Blood Pressure', 'mmHg'),
  bloodSugar('🩸', 'Blood Sugar', 'mg/dL'),
  weight('⚖️', 'Weight', 'kg'),
  temperature('🌡️', 'Temperature', '°C'),
  spo2('💨', 'SpO2', '%'),
  heartRate('💓', 'Heart Rate', 'bpm');

  final String emoji, label, unit;
  const VitalType(this.emoji, this.label, this.unit);
}

class HealthVital {
  String id, walletId, memberId;
  VitalType type;
  double value;
  double? value2;
  String? subType, notes;
  DateTime recordedAt;

  HealthVital({
    required this.id,
    required this.walletId,
    required this.memberId,
    required this.type,
    required this.value,
    this.value2,
    this.subType,
    this.notes,
    DateTime? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now();

  String get displayValue {
    if (type == VitalType.bloodPressure && value2 != null) {
      return '${value.toInt()}/${value2!.toInt()} ${type.unit}';
    }
    final v = value == value.toInt() ? '${value.toInt()}' : value.toStringAsFixed(1);
    return '$v ${type.unit}';
  }

  Map<String, dynamic> toJson() => {
        'wallet_id': walletId,
        'member_id': memberId,
        'vital_type': type.name,
        'value': value,
        if (value2 != null) 'value2': value2,
        if (subType != null) 'sub_type': subType,
        if (notes != null) 'notes': notes,
        'recorded_at': recordedAt.toIso8601String(),
      };

  factory HealthVital.fromJson(Map<String, dynamic> j) => HealthVital(
        id: j['id'] as String,
        walletId: j['wallet_id'] as String,
        memberId: j['member_id'] as String,
        type: VitalType.values.firstWhere(
          (e) => e.name == j['vital_type'],
          orElse: () => VitalType.heartRate,
        ),
        value: (j['value'] as num).toDouble(),
        value2: j['value2'] != null ? (j['value2'] as num).toDouble() : null,
        subType: j['sub_type'] as String?,
        notes: j['notes'] as String?,
        recordedAt: j['recorded_at'] != null
            ? DateTime.tryParse(j['recorded_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

// ── Vaccination ───────────────────────────────────────────────────────────────

class Vaccination {
  String id, walletId, memberId, vaccineName;
  DateTime dateGiven;
  DateTime? nextDue;
  int? doseNumber;
  String? notes;

  Vaccination({
    required this.id,
    required this.walletId,
    required this.memberId,
    required this.vaccineName,
    required this.dateGiven,
    this.nextDue,
    this.doseNumber,
    this.notes,
  });

  bool get isDueSoon {
    if (nextDue == null) return false;
    return nextDue!.difference(DateTime.now()).inDays <= 30;
  }

  bool get isOverdue {
    if (nextDue == null) return false;
    return nextDue!.isBefore(DateTime.now());
  }

  Map<String, dynamic> toJson() => {
        'wallet_id': walletId,
        'member_id': memberId,
        'vaccine_name': vaccineName,
        'date_given': _dateStr(dateGiven),
        if (nextDue != null) 'next_due': _dateStr(nextDue!),
        if (doseNumber != null) 'dose_number': doseNumber,
        if (notes != null) 'notes': notes,
      };

  factory Vaccination.fromJson(Map<String, dynamic> j) => Vaccination(
        id: j['id'] as String,
        walletId: j['wallet_id'] as String,
        memberId: j['member_id'] as String,
        vaccineName: j['vaccine_name'] as String,
        dateGiven: _parseDate(j['date_given']) ?? DateTime.now(),
        nextDue: _parseDate(j['next_due']),
        doseNumber: j['dose_number'] as int?,
        notes: j['notes'] as String?,
      );
}

// ── Insurance Policy ──────────────────────────────────────────────────────────

class InsurancePolicy {
  String id, walletId, memberId, policyName;
  String? policyNumber, provider, notes;
  double? coverageAmount;
  DateTime? expiryDate;

  InsurancePolicy({
    required this.id,
    required this.walletId,
    required this.memberId,
    required this.policyName,
    this.policyNumber,
    this.provider,
    this.notes,
    this.coverageAmount,
    this.expiryDate,
  });

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  bool get expiresSoon =>
      expiryDate != null &&
      !isExpired &&
      expiryDate!.difference(DateTime.now()).inDays <= 60;

  Map<String, dynamic> toJson() => {
        'wallet_id': walletId,
        'member_id': memberId,
        'policy_name': policyName,
        if (policyNumber != null) 'policy_number': policyNumber,
        if (provider != null) 'provider': provider,
        if (notes != null) 'notes': notes,
        if (coverageAmount != null) 'coverage_amount': coverageAmount,
        if (expiryDate != null) 'expiry_date': _dateStr(expiryDate!),
      };

  factory InsurancePolicy.fromJson(Map<String, dynamic> j) => InsurancePolicy(
        id: j['id'] as String,
        walletId: j['wallet_id'] as String,
        memberId: j['member_id'] as String,
        policyName: j['policy_name'] as String,
        policyNumber: j['policy_number'] as String?,
        provider: j['provider'] as String?,
        notes: j['notes'] as String?,
        coverageAmount: j['coverage_amount'] != null
            ? (j['coverage_amount'] as num).toDouble()
            : null,
        expiryDate: _parseDate(j['expiry_date']),
      );
}
