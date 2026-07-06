import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

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
  ClinicalNotesRepository() : _prefsFuture = SharedPreferences.getInstance();

  final Future<SharedPreferences> _prefsFuture;
  static const String _notesKey = 'clinic_clinical_notes';

  Future<List<ClinicalNote>> loadNotes() async {
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
    final prefs = await _prefsFuture;
    final notes = await loadNotes();
    final next = [note, ...notes];
    await prefs.setString(_notesKey, jsonEncode(next.map((item) => item.toJson()).toList()));
  }

  Future<void> deleteNote(String id) async {
    final prefs = await _prefsFuture;
    final notes = await loadNotes();
    final updated = notes.where((n) => n.id != id).toList();
    await prefs.setString(_notesKey, jsonEncode(updated.map((item) => item.toJson()).toList()));
  }
}
