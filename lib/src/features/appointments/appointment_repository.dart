import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/appointment.dart';

class AppointmentRepository {
  AppointmentRepository() : _prefsFuture = SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;
  static const String _appointmentsKey = 'clinic_booked_appointments';

  Future<List<Appointment>> loadAppointments() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_appointmentsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => Appointment.fromJson(Map<String, dynamic>.from(entry as Map)))
        .toList(growable: false);
  }

  Future<void> saveAppointment(Appointment appointment) async {
    final prefs = await _prefsFuture;
    final appointments = await loadAppointments();
    final next = [appointment, ...appointments];
    await prefs.setString(
      _appointmentsKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }

  Future<Appointment?> findById(String id) async {
    final appointments = await loadAppointments();
    for (final appointment in appointments) {
      if (appointment.id == id) {
        return appointment;
      }
    }
    return null;
  }

  Future<void> updateAppointment(Appointment updatedAppointment) async {
    final prefs = await _prefsFuture;
    final appointments = await loadAppointments();
    final next = appointments
        .map((item) => item.id == updatedAppointment.id ? updatedAppointment : item)
        .toList(growable: false);
    await prefs.setString(
      _appointmentsKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> deleteAppointment(String appointmentId) async {
    final prefs = await _prefsFuture;
    final appointments = await loadAppointments();
    final next = appointments
        .where((item) => item.id != appointmentId)
        .toList(growable: false);
    await prefs.setString(
      _appointmentsKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }
}
