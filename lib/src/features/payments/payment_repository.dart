import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../models/payment.dart';
import '../../services/app_preferences.dart';

class PaymentRepository {
  PaymentRepository() : _prefsFuture = AppPreferences.instance.prefs;

  final Future<SharedPreferences> _prefsFuture;
  static const String _paymentsKey = 'clinic_patient_payments';

  bool get _useFirestore {
    try {
      return Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<Payment>> loadPayments() async {
    if (_useFirestore) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('payments')
            .get();
        final payments = snapshot.docs
            .map((doc) => Payment.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
        payments.sort((a, b) => b.paidAt.compareTo(a.paidAt));
        return payments;
      } catch (error) {
        debugPrint('Failed to load payments from Firestore: $error');
      }
    }

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
    if (_useFirestore) {
      try {
        await FirebaseFirestore.instance
            .collection('payments')
            .doc(payment.id)
            .set(payment.toJson());
        return;
      } catch (error) {
        debugPrint('Failed to save payment to Firestore: $error');
      }
    }
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
    if (_useFirestore) {
      try {
        await FirebaseFirestore.instance
            .collection('payments')
            .doc(id)
            .delete();
        return;
      } catch (error) {
        debugPrint('Failed to delete payment from Firestore: $error');
      }
    }
    final prefs = await _prefsFuture;
    final payments = await loadPayments();
    final updated = payments.where((p) => p.id != id).toList();
    await prefs.setString(_paymentsKey, jsonEncode(updated.map((item) => item.toJson()).toList()));
  }

  Future<SharedPreferences> getPrefs() async => _prefsFuture;
}
