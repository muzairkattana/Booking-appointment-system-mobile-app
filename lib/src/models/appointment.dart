class Appointment {
  final String id;
  final String patientName;
  final String time;
  final String treatmentType;
  final String status;
  final DateTime? scheduledAt;
  final String phoneNumber;
  final String email;
  final String visitReason;
  final String patientNote;
  final String cancellationReason;
  final DateTime? updatedAt;
  final bool isEmergency;

  final String patientProfession;

  Appointment({
    required this.id,
    required this.patientName,
    required this.time,
    required this.treatmentType,
    required this.status,
    this.scheduledAt,
    this.phoneNumber = '',
    this.email = '',
    this.visitReason = '',
    this.patientNote = '',
    this.cancellationReason = '',
    this.updatedAt,
    this.isEmergency = false,
    this.patientProfession = '',
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      treatmentType: json['treatmentType']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      scheduledAt: DateTime.tryParse(json['scheduledAt']?.toString() ?? ''),
      phoneNumber: json['phoneNumber']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      visitReason: json['visitReason']?.toString() ?? '',
      patientNote: json['patientNote']?.toString() ?? '',
      cancellationReason: json['cancellationReason']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      isEmergency: json['isEmergency'] == true || json['isEmergency'] == 'true',
      patientProfession: json['patientProfession']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientName': patientName,
      'time': time,
      'treatmentType': treatmentType,
      'status': status,
      'scheduledAt': scheduledAt?.toIso8601String(),
      'phoneNumber': phoneNumber,
      'email': email,
      'visitReason': visitReason,
      'patientNote': patientNote,
      'cancellationReason': cancellationReason,
      'updatedAt': updatedAt?.toIso8601String(),
      'isEmergency': isEmergency,
      'patientProfession': patientProfession,
    };
  }

  Appointment copyWith({
    String? patientName,
    String? time,
    String? treatmentType,
    String? status,
    DateTime? scheduledAt,
    String? phoneNumber,
    String? email,
    String? visitReason,
    String? patientNote,
    String? cancellationReason,
    DateTime? updatedAt,
    bool? isEmergency,
    String? patientProfession,
  }) {
    return Appointment(
      id: id,
      patientName: patientName ?? this.patientName,
      time: time ?? this.time,
      treatmentType: treatmentType ?? this.treatmentType,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      visitReason: visitReason ?? this.visitReason,
      patientNote: patientNote ?? this.patientNote,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      updatedAt: updatedAt ?? this.updatedAt,
      isEmergency: isEmergency ?? this.isEmergency,
      patientProfession: patientProfession ?? this.patientProfession,
    );
  }
}
