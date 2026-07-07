import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/payment.dart';
import '../../services/app_preferences.dart';

class PaymentRepository {
  PaymentRepository() : _prefsFuture = AppPreferences.instance.prefs;

  final Future<SharedPreferences> _prefsFuture;
  static const String _paymentsKey = 'clinic_patient_payments';

  Future<List<Payment>> loadPayments() async {
    final prefs = await _prefsFuture;
    final raw = prefs.getString(_paymentsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => Payment.fromJson(Map<String, dynamic>.from(entry as Map)))
        .toList(growable: false);
  }

  Future<void> savePayment(Payment payment) async {
    final prefs = await _prefsFuture;
    final payments = await loadPayments();
    final index = payments.indexWhere((p) => p.id == payment.id);
    final List<Payment> updated;
    if (index >= 0) {
      updated = List<Payment>.from(payments);
      updated[index] = payment;
    } else {
      updated = [payment, ...payments];
    }
    await prefs.setString(_paymentsKey, jsonEncode(updated.map((item) => item.toJson()).toList()));
  }

  Future<void> deletePayment(String id) async {
    final prefs = await _prefsFuture;
    final payments = await loadPayments();
    final updated = payments.where((p) => p.id != id).toList();
    await prefs.setString(_paymentsKey, jsonEncode(updated.map((item) => item.toJson()).toList()));
  }

  Future<SharedPreferences> getPrefs() async => _prefsFuture;
}
