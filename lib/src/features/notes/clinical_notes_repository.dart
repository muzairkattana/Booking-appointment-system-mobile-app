import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../services/app_preferences.dart';

class ClinicalNote {
  final String id;
  final String patientName;
  final String note;
  final String category;
  final DateTime createdAt;

  ClinicalNote({
    required this.id,
    required this.patientName,
    required this.note,
    required this.category,
    required this.createdAt,
  });

  factory ClinicalNote.fromJson(Map<String, dynamic> json) {
    return ClinicalNote(
      id: json['id']?.toString() ?? '',
      patientName: json['patientName']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientName': patientName,
      'note': note,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class ClinicalNotesRepository {
  ClinicalNotesRepository() : _prefsFuture = AppPreferences.instance.prefs;

  final Future<SharedPreferences> _prefsFuture;
  static const String _notesKey = 'clinic_clinical_notes';

  bool get _useFirestore {
    try {
      return Firebase.apps.isNotEmpty && FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<ClinicalNote>> loadNotes() async {
    if (_useFirestore) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('clinical_notes')
            .get();
        final notes = snapshot.docs
            .map((doc) => ClinicalNote.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
        notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return notes;
      } catch (error) {
        debugPrint('Failed to load notes from Firestore: $error');
      }
    }

    final prefs = await _prefsFuture;
    final raw = prefs.getString(_notesKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => ClinicalNote.fromJson(Map<String, dynamic>.from(entry as Map)))
        .toList(growable: false);
  }

  Future<void> saveNote(ClinicalNote note) async {
    if (_useFirestore) {
      try {
        await FirebaseFirestore.instance
            .collection('clinical_notes')
            .doc(note.id)
            .set(note.toJson());
        return;
      } catch (error) {
        debugPrint('Failed to save note to Firestore: $error');
      }
    }
    final prefs = await _prefsFuture;
    final notes = await loadNotes();
    final next = [note, ...notes];
    await prefs.setString(_notesKey, jsonEncode(next.map((item) => item.toJson()).toList()));
  }

  Future<void> deleteNote(String id) async {
    if (_useFirestore) {
      try {
        await FirebaseFirestore.instance
            .collection('clinical_notes')
            .doc(id)
            .delete();
        return;
      } catch (error) {
        debugPrint('Failed to delete note from Firestore: $error');
      }
    }
    final prefs = await _prefsFuture;
    final notes = await loadNotes();
    final updated = notes.where((n) => n.id != id).toList();
    await prefs.setString(_notesKey, jsonEncode(updated.map((item) => item.toJson()).toList()));
  }
}
