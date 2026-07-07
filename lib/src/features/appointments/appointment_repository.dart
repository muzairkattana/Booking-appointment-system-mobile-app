import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/appointment.dart';
import '../../services/app_preferences.dart';

class AppointmentRepository {
  AppointmentRepository() : _prefsFuture = AppPreferences.instance.prefs;

  final Future<SharedPreferences> _prefsFuture;
  static const String _appointmentsKey = 'clinic_booked_appointments';
  static const Duration _cacheTtl = Duration(seconds: 30);

  static List<Appointment>? _cachedAppointments;
  static DateTime? _cachedAt;

  Future<List<Appointment>> loadAppointments() async {
    final now = DateTime.now();
    if (_cachedAppointments != null && _cachedAt != null && now.difference(_cachedAt!) < _cacheTtl) {
      return List<Appointment>.unmodifiable(_cachedAppointments!);
    }

    final prefs = await _prefsFuture;
    final raw = prefs.getString(_appointmentsKey);
    if (raw == null || raw.isEmpty) {
      _cachedAppointments = const [];
      _cachedAt = now;
      return _cachedAppointments!;
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    final appointments = decoded
        .map((entry) => Appointment.fromJson(Map<String, dynamic>.from(entry as Map)))
        .toList(growable: false);
    _cachedAppointments = appointments;
    _cachedAt = now;
    return List<Appointment>.unmodifiable(appointments);
  }

  Future<void> _saveAppointments(List<Appointment> appointments) async {
    final prefs = await _prefsFuture;
    final encoded = jsonEncode(appointments.map((item) => item.toJson()).toList());
    await prefs.setString(_appointmentsKey, encoded);
    _cachedAppointments = List<Appointment>.unmodifiable(appointments);
    _cachedAt = DateTime.now();
  }

  Future<void> saveAppointment(Appointment appointment) async {
    final appointments = await loadAppointments();
    final next = [appointment, ...appointments];
    await _saveAppointments(next);
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
    final appointments = await loadAppointments();
    final next = appointments
        .map((item) => item.id == updatedAppointment.id ? updatedAppointment : item)
        .toList(growable: false);
    await _saveAppointments(next);
  }

  Future<void> deleteAppointment(String appointmentId) async {
    final appointments = await loadAppointments();
    final next = appointments
        .where((item) => item.id != appointmentId)
        .toList(growable: false);
    await _saveAppointments(next);
  }
}
