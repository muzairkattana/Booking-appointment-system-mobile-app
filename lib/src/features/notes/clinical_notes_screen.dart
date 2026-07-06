import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/import_export_service.dart';

import '../shared/widgets/app_shell_scaffold.dart';
import '../shared/widgets/premium_card.dart';
import 'clinical_notes_repository.dart';
import '../appointments/appointment_repository.dart';
import '../../theme/app_theme.dart';

class ClinicalNotesScreen extends StatefulWidget {
  const ClinicalNotesScreen({super.key});

  @override
  State<ClinicalNotesScreen> createState() => _ClinicalNotesScreenState();
}

class _ClinicalNotesScreenState extends State<ClinicalNotesScreen> {
  final ClinicalNotesRepository _repository = ClinicalNotesRepository();
  final _patientController = TextEditingController();
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final Uuid _uuid = const Uuid();

  Future<void> _exportNotes() async {
    try {
      final header = ['Note ID', 'Patient Name', 'Clinical Note', 'Category', 'Created At'];
      final rows = <List<dynamic>>[header];
      for (final note in _notes) {
        rows.add([
          note.id,
          note.patientName,
          note.note,
          note.category,
          DateFormat('yyyy-MM-dd HH:mm').format(note.createdAt),
        ]);
      }

      final success = await ImportExportService.exportExcel(
        context: context,
        defaultFileName: 'gct_clinical_notes.xlsx',
        sheets: {'Clinical Notes': rows},
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clinical notes exported to Excel successfully! 💾')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _importNotes() async {
    try {
      final excel = await ImportExportService.importExcel(context: context);
      if (excel == null) return;

      final rows = ImportExportService.parseSheet(excel: excel, sheetName: 'Clinical Notes');
      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No clinical notes sheet found or sheet is empty.')),
          );
        }
        return;
      }

      final List<ClinicalNote> imported = [];
      for (final row in rows) {
        final id = row['Note ID']?.toString() ?? _uuid.v4();
        final patientName = row['Patient Name']?.toString() ?? '';
        final note = row['Clinical Note']?.toString() ?? '';
        final category = row['Category']?.toString() ?? 'General';
        
        DateTime createdAt;
        final rawDate = row['Created At'];
        if (rawDate != null) {
          createdAt = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
        } else {
          createdAt = DateTime.now();
        }

        if (patientName.isNotEmpty) {
          imported.add(ClinicalNote(
            id: id,
            patientName: patientName,
            note: note,
            category: category,
            createdAt: createdAt,
          ));
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'clinic_clinical_notes',
        jsonEncode(imported.map((item) => item.toJson()).toList()),
      );

      await _loadNotesAndSuggestions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clinical notes imported successfully! 🔄')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${e.toString()}')),
        );
      }
    }
  }

  List<ClinicalNote> _notes = [];
  List<String> _patientSuggestions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'General';

  static const _categories = ['General', 'Spine', 'Posture', 'Recovery', 'Medication'];
  static const _categoryColors = [Color(0xFF6366F1), Color(0xFF0A6BE8), Color(0xFF00A86B), Color(0xFF8B5CF6), Color(0xFFF59E0B)];
  static const _categoryIcons = [Icons.note_rounded, Icons.airline_seat_flat_rounded, Icons.accessibility_new_rounded, Icons.healing_rounded, Icons.medication_rounded];

  @override
  void initState() {
    super.initState();
    _loadNotesAndSuggestions();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.toLowerCase()));
  }

  @override
  void dispose() {
    _patientController.dispose();
    _noteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotesAndSuggestions() async {
    final notes = await _repository.loadNotes();
    final appointments = await AppointmentRepository().loadAppointments();
    final names = appointments.map((a) => a.patientName.trim()).where((name) => name.isNotEmpty).toSet().toList();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _patientSuggestions = names;
      _isLoading = false;
    });
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;
    await _repository.saveNote(ClinicalNote(
      id: _uuid.v4(),
      patientName: _patientController.text.trim(),
      note: _noteController.text.trim(),
      category: _selectedCategory,
      createdAt: DateTime.now(),
    ));
    _patientController.clear();
    _noteController.clear();
    if (!mounted) return;
    setState(() => _selectedCategory = 'General');
    FocusScope.of(context).unfocus();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved ✅')));
    _loadNotesAndSuggestions();
  }

  Future<void> _deleteNote(String id) async {
    await _repository.deleteNote(id);
    _loadNotesAndSuggestions();
  }

  List<ClinicalNote> get _filtered {
    if (_searchQuery.isEmpty) return _notes;
    return _notes.where((n) => n.patientName.toLowerCase().contains(_searchQuery) || n.note.toLowerCase().contains(_searchQuery)).toList();
  }

  int _categoryIndex(String cat) => _categories.indexOf(cat).clamp(0, _categories.length - 1);

  Widget _buildFormWidget() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
            Row(children: [
              Expanded(
                child: Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return _patientSuggestions.where((String option) {
                      return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  onSelected: (String selection) {
                    _patientController.text = selection;
                  },
                  fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                    if (textController.text != _patientController.text) {
                      textController.text = _patientController.text;
                    }
                    textController.addListener(() {
                      _patientController.text = textController.text;
                    });
                    return TextFormField(
                      controller: textController,
                      focusNode: focusNode,
                      decoration: const InputDecoration(hintText: 'Patient name', prefixIcon: Icon(Icons.person_outline_rounded, size: 18)),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      onFieldSubmitted: (v) => onFieldSubmitted(),
                    );
                  },
                ),
              ),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final isSelected = _selectedCategory == cat;
                  final color = _categoryColors[i];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? color : color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? color : color.withValues(alpha: 0.2)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_categoryIcons[i], size: 13, color: isSelected ? Colors.white : color),
                        const SizedBox(width: 5),
                        Text(cat, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : color)),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Write clinical note here…', prefixIcon: Padding(padding: EdgeInsets.only(bottom: 36), child: Icon(Icons.edit_note_rounded, size: 18))),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Note is required' : null,
            ),
            const SizedBox(height: 8),
            Text('Quick Templates', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                'Subluxation corrected at L5-S1',
                'Gonstead cervical adjustment done',
                'Posture correction advice given',
                'Recommended ice pack application',
                'Symptoms improved, continue care plan',
              ].map((template) => InkWell(
                onTap: () {
                  final text = _noteController.text.trim();
                  if (text.isEmpty) {
                    _noteController.text = template;
                  } else {
                    _noteController.text = '$text. $template';
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    template,
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _saveNote,
                icon: const Icon(Icons.note_add_rounded, size: 18),
                label: const Text('Save Note'),
              ),
            ),
          ],
        ),
      );
    }

  Widget _buildListWidget(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search notes or patient…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () => _searchController.clear()) : null,
          ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${_filtered.length} note${_filtered.length != 1 ? 's' : ''}', style: GoogleFonts.poppins(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.55))),
        ]),
        const SizedBox(height: 10),
        _filtered.isEmpty
            ? Center(child: Padding(
                padding: const EdgeInsets.only(top: 40.0),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.book_outlined, size: 54, color: cs.onSurface.withValues(alpha: 0.2)),
                    const SizedBox(height: 12),
                    Text(_searchQuery.isNotEmpty ? 'No notes match your search' : 'No notes yet', style: GoogleFonts.poppins(color: cs.onSurface.withValues(alpha: 0.45))),
                  ]),
              ))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final note = _filtered[i];
                  final ci = _categoryIndex(note.category);
                  final catColor = _categoryColors[ci % _categoryColors.length];

                  return Dismissible(
                    key: Key(note.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: AppColors.statusCancelledBg, borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.delete_outline_rounded, color: AppColors.statusCancelled),
                    ),
                    confirmDismiss: (_) => showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Delete Note', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                        content: Text('Delete note for ${note.patientName}?', style: GoogleFonts.poppins()),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: cs.error))),
                        ],
                      ),
                    ),
                    onDismissed: (_) => _deleteNote(note.id),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PremiumCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(width: 4, height: 40, decoration: BoxDecoration(color: catColor, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(note.patientName, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                              Text(DateFormat('d MMM y, hh:mm a').format(note.createdAt), style: GoogleFonts.poppins(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                            ])),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.35)),
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Delete Note', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                                    content: Text('Delete note for ${note.patientName}?', style: GoogleFonts.poppins()),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: cs.error))),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  _deleteNote(note.id);
                                }
                              },
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Text(note.note, style: GoogleFonts.poppins(fontSize: 13, height: 1.5, color: cs.onSurface.withValues(alpha: 0.8))),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ],
    );
  }

  void _showAddNoteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Add Clinical Note',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFormWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppShellScaffold(
      title: 'Clinical Notes',
      currentRoute: '/notes',
      actions: [
        IconButton(
          icon: const Icon(Icons.download_rounded),
          onPressed: _exportNotes,
          tooltip: 'Export Notes',
        ),
        IconButton(
          icon: const Icon(Icons.upload_file_rounded),
          onPressed: _importNotes,
          tooltip: 'Import Notes',
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddNoteSheet(context),
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        tooltip: 'Add Note',
        child: const Icon(Icons.book_rounded),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
              child: _buildListWidget(cs),
            ),
    );
  }
}
