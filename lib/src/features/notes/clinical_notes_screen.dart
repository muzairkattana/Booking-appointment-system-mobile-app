import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import '../utils/import_export_service.dart';
import '../../services/app_preferences.dart';
import 'package:flutter/services.dart';

import '../shared/widgets/app_shell_scaffold.dart';
import '../shared/widgets/premium_card.dart';
import 'clinical_notes_repository.dart';
import 'note_template_repository.dart';
import '../appointments/appointment_repository.dart';
import '../../theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/repository_providers.dart';
import '../../services/notification_service.dart';

class ClinicalNotesScreen extends ConsumerStatefulWidget {
  const ClinicalNotesScreen({super.key});

  @override
  ConsumerState<ClinicalNotesScreen> createState() => _ClinicalNotesScreenState();
}

class _ClinicalNotesScreenState extends ConsumerState<ClinicalNotesScreen> {
  ClinicalNotesRepository get _repository => ref.read(clinicalNotesRepositoryProvider);
  NoteTemplateRepository get _templateRepository => ref.read(noteTemplateRepositoryProvider);
  final _patientController = TextEditingController();
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();
  
  final _soapSubjectiveController = TextEditingController();
  final _soapObjectiveController = TextEditingController();
  final _soapAssessmentController = TextEditingController();
  final _soapPlanController = TextEditingController();
  bool _useSoap = false;

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

      final prefs = await AppPreferences.instance.prefs;
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
  List<NoteTemplate> _templates = [];
  List<String> _patientSuggestions = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCategory = 'General';
  String _selectedDuration = 'All';
  bool _isTodo = false;
  ClinicalNote? _editingNote;

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
    _soapSubjectiveController.dispose();
    _soapObjectiveController.dispose();
    _soapAssessmentController.dispose();
    _soapPlanController.dispose();
    super.dispose();
  }

  Future<void> _loadNotesAndSuggestions() async {
    final notes = await _repository.loadNotes();
    final templates = await _templateRepository.allTemplates();
    final appointments = await ref.read(appointmentRepositoryProvider).loadAppointments();
    final names = appointments.map((a) => a.patientName.trim()).where((name) => name.isNotEmpty).toSet().toList();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _templates = templates;
      _patientSuggestions = names;
      _isLoading = false;
    });
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;
    final patientName = _patientController.text.trim();
    
    String noteText;
    if (_useSoap) {
      final s = _soapSubjectiveController.text.trim();
      final o = _soapObjectiveController.text.trim();
      final a = _soapAssessmentController.text.trim();
      final p = _soapPlanController.text.trim();
      
      final parts = <String>[];
      if (s.isNotEmpty) parts.add('S: $s');
      if (o.isNotEmpty) parts.add('O: $o');
      if (a.isNotEmpty) parts.add('A: $a');
      if (p.isNotEmpty) parts.add('P: $p');
      noteText = parts.join('\n');
    } else {
      noteText = _noteController.text.trim();
    }
    
    final category = _selectedCategory;
    final isTodo = _isTodo;

    if (_editingNote != null) {
      final updatedNote = _editingNote!.copyWith(
        patientName: patientName,
        note: noteText,
        category: category,
        isTodo: isTodo,
      );
      await _repository.updateNote(updatedNote);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note updated ✅')));
    } else {
      await _repository.saveNote(ClinicalNote(
        id: _uuid.v4(),
        patientName: patientName,
        note: noteText,
        category: category,
        createdAt: DateTime.now(),
        isTodo: isTodo,
        isCompleted: false,
      ));

      // Trigger instant notification
      try {
        await NotificationService().showLocalNotification(
          'Clinical Note Saved 📝',
          'Added a $category note for $patientName.',
          payload: '/notes',
        );
      } catch (e) {
        debugPrint('Note notification failed: $e');
      }
    }

    _patientController.clear();
    _noteController.clear();
    _soapSubjectiveController.clear();
    _soapObjectiveController.clear();
    _soapAssessmentController.clear();
    _soapPlanController.clear();
    if (!mounted) return;
    setState(() {
      _selectedCategory = 'General';
      _isTodo = false;
      _useSoap = false;
      _editingNote = null;
    });
    FocusScope.of(context).unfocus();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    _loadNotesAndSuggestions();
  }

  Future<void> _deleteNote(String id) async {
    final note = _notes.firstWhere((n) => n.id == id, orElse: () => ClinicalNote(id: '', patientName: 'Unknown', note: '', category: '', createdAt: DateTime.now()));
    await _repository.deleteNote(id);

    try {
      await NotificationService().showLocalNotification(
        'Clinical Note Deleted 🗑️',
        'Deleted note for ${note.patientName}.',
        payload: '/notes',
      );
    } catch (e) {
      debugPrint('Note delete notification failed: $e');
    }

    _loadNotesAndSuggestions();
  }

  Future<void> _toggleTodoStatus(ClinicalNote note) async {
    final updated = note.copyWith(isCompleted: !note.isCompleted);
    await _repository.updateNote(updated);
    _loadNotesAndSuggestions();
  }

  void _editNote(ClinicalNote note) {
    // Parse note body to check for SOAP formatting
    final lines = note.note.split('\n');
    String s = '';
    String o = '';
    String a = '';
    String p = '';
    bool foundSoap = false;

    for (final line in lines) {
      if (line.startsWith('S: ')) {
        s = line.substring(3);
        foundSoap = true;
      } else if (line.startsWith('O: ')) {
        o = line.substring(3);
        foundSoap = true;
      } else if (line.startsWith('A: ')) {
        a = line.substring(3);
        foundSoap = true;
      } else if (line.startsWith('P: ')) {
        p = line.substring(3);
        foundSoap = true;
      }
    }

    setState(() {
      _editingNote = note;
      _patientController.text = note.patientName;
      _selectedCategory = note.category;
      _isTodo = note.isTodo;
      _useSoap = foundSoap;
      
      if (foundSoap) {
        _soapSubjectiveController.text = s;
        _soapObjectiveController.text = o;
        _soapAssessmentController.text = a;
        _soapPlanController.text = p;
        _noteController.clear();
      } else {
        _noteController.text = note.note;
        _soapSubjectiveController.clear();
        _soapObjectiveController.clear();
        _soapAssessmentController.clear();
        _soapPlanController.clear();
      }
    });
    _showAddNoteSheet(context);
  }

  void _showNoteDetailDialog(ClinicalNote note) {
    final cs = Theme.of(context).colorScheme;
    final ci = _categoryIndex(note.category);
    final catColor = _categoryColors[ci % _categoryColors.length];
    final catIcon = _categoryIcons[ci % _categoryIcons.length];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: catColor.withOpacity(0.12),
              child: Icon(catIcon, color: catColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.patientName,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Category: ${note.category}',
                    style: GoogleFonts.poppins(fontSize: 10, color: cs.onSurface.withOpacity(0.55), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline.withOpacity(0.1)),
              ),
              child: SelectableText(
                note.note,
                style: GoogleFonts.poppins(fontSize: 13, height: 1.5, color: cs.onSurface),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Created:',
                  style: GoogleFonts.poppins(fontSize: 11, color: cs.onSurface.withOpacity(0.5)),
                ),
                Text(
                  DateFormat('MMMM dd, yyyy - hh:mm a').format(note.createdAt),
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurface.withOpacity(0.7)),
                ),
              ],
            ),
            if (note.isTodo) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Task Status:',
                    style: GoogleFonts.poppins(fontSize: 11, color: cs.onSurface.withOpacity(0.5)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: note.isCompleted ? Colors.green.withOpacity(0.12) : Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      note.isCompleted ? 'COMPLETED' : 'PENDING ACTION',
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: note.isCompleted ? Colors.green.shade800 : Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.copy_rounded, color: cs.primary, size: 20),
            tooltip: 'Copy Note text',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: note.note));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note copied to clipboard 📋')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.bookmark_add_outlined, color: cs.primary, size: 20),
            tooltip: 'Save as Template',
            onPressed: () {
              Navigator.pop(ctx);
              _saveAsTemplate(note);
            },
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _editNote(note);
            },
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _saveAsTemplate(ClinicalNote note) {
    final lines = note.note.split('\n');
    String s = '';
    String o = '';
    String a = '';
    String p = '';
    bool foundSoap = false;

    for (final line in lines) {
      if (line.startsWith('S: ')) {
        s = line.substring(3);
        foundSoap = true;
      } else if (line.startsWith('O: ')) {
        o = line.substring(3);
        foundSoap = true;
      } else if (line.startsWith('A: ')) {
        a = line.substring(3);
        foundSoap = true;
      } else if (line.startsWith('P: ')) {
        p = line.substring(3);
        foundSoap = true;
      }
    }

    final temp = NoteTemplate(
      id: const Uuid().v4(),
      name: '${note.patientName}\'s Case',
      category: note.category,
      body: foundSoap ? '' : note.note,
      isSoap: foundSoap,
      soapSubjective: s,
      soapObjective: o,
      soapAssessment: a,
      soapPlan: p,
      createdAt: DateTime.now(),
    );

    _showAddEditTemplateDialog(temp, onSaved: () {
      _loadNotesAndSuggestions();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template saved successfully! 💾')),
      );
    });
  }

  void _showManageTemplatesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final cs = Theme.of(context).colorScheme;
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Note Templates', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditTemplateDialog(null, onSaved: () async {
                    await _loadNotesAndSuggestions();
                    setDlgState(() {});
                  }),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: _templates.isEmpty
                  ? const Center(child: Text('No custom templates yet.'))
                  : ListView.builder(
                      itemCount: _templates.length,
                      itemBuilder: (context, index) {
                        final t = _templates[index];
                        final isBuiltIn = t.id.startsWith('__builtin');
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(t.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text('${t.category} • ${t.isSoap ? "SOAP" : "Text"}', style: GoogleFonts.poppins(fontSize: 11)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isBuiltIn) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    onPressed: () => _showAddEditTemplateDialog(t, onSaved: () async {
                                      await _loadNotesAndSuggestions();
                                      setDlgState(() {});
                                    }),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                    onPressed: () async {
                                      await _templateRepository.deleteTemplate(t.id);
                                      await _loadNotesAndSuggestions();
                                      setDlgState(() {});
                                    },
                                  ),
                                ] else
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Text('System', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddEditTemplateDialog(NoteTemplate? template, {required VoidCallback onSaved}) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: template?.name ?? '');
    final bodyCtrl = TextEditingController(text: template?.body ?? '');
    final subCtrl = TextEditingController(text: template?.soapSubjective ?? '');
    final objCtrl = TextEditingController(text: template?.soapObjective ?? '');
    final assCtrl = TextEditingController(text: template?.soapAssessment ?? '');
    final planCtrl = TextEditingController(text: template?.soapPlan ?? '');
    String category = template?.category ?? 'General';
    bool isSoap = template?.isSoap ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text(template == null ? 'Create Template' : 'Edit Template', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Template Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setDlgState(() => category = v ?? category),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Use SOAP Structure', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    value: isSoap,
                    onChanged: (val) => setDlgState(() => isSoap = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 10),
                  if (isSoap) ...[
                    TextFormField(
                      controller: subCtrl,
                      decoration: const InputDecoration(labelText: 'Subjective (S)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: objCtrl,
                      decoration: const InputDecoration(labelText: 'Objective (O)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: assCtrl,
                      decoration: const InputDecoration(labelText: 'Assessment (A)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: planCtrl,
                      decoration: const InputDecoration(labelText: 'Plan (P)'),
                      maxLines: 2,
                    ),
                  ] else ...[
                    TextFormField(
                      controller: bodyCtrl,
                      decoration: const InputDecoration(labelText: 'Template Text'),
                      maxLines: 4,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newTemplate = NoteTemplate(
                  id: template?.id ?? const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  category: category,
                  body: isSoap ? '' : bodyCtrl.text.trim(),
                  isSoap: isSoap,
                  soapSubjective: isSoap ? subCtrl.text.trim() : '',
                  soapObjective: isSoap ? objCtrl.text.trim() : '',
                  soapAssessment: isSoap ? assCtrl.text.trim() : '',
                  soapPlan: isSoap ? planCtrl.text.trim() : '',
                  createdAt: template?.createdAt ?? DateTime.now(),
                );

                if (template == null) {
                  await _templateRepository.saveTemplate(newTemplate);
                } else {
                  await _templateRepository.updateTemplate(newTemplate);
                }
                onSaved();
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesDuration(DateTime date) {
    if (_selectedDuration == 'All') return true;
    final diff = DateTime.now().difference(date).abs();
    if (_selectedDuration == '7 Days') return diff.inDays <= 7;
    if (_selectedDuration == '30 Days') return diff.inDays <= 30;
    if (_selectedDuration == '6 Months') return diff.inDays <= 180;
    return true;
  }

  List<ClinicalNote> get _filtered {
    var result = _notes;
    // Apply duration filter
    result = result.where((n) => _matchesDuration(n.createdAt)).toList();
    
    if (_searchQuery.isEmpty) return result;
    return result.where((n) => n.patientName.toLowerCase().contains(_searchQuery) || n.note.toLowerCase().contains(_searchQuery)).toList();
  }

  int _categoryIndex(String cat) => _categories.indexOf(cat).clamp(0, _categories.length - 1);

  Widget _buildFormWidget(StateSetter setState) {
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
            SwitchListTile(
              title: Text(
                'Use SOAP Structure',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Structure note as Subjective, Objective, Assessment, Plan',
                style: GoogleFonts.poppins(fontSize: 10),
              ),
              value: _useSoap,
              onChanged: (val) => setState(() => _useSoap = val),
              secondary: const Icon(Icons.playlist_add_check_rounded),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            if (_useSoap) ...[
              TextFormField(
                controller: _soapSubjectiveController,
                decoration: const InputDecoration(hintText: 'Subjective (S) - Patient symptoms, concerns', prefixIcon: Icon(Icons.chat_bubble_outline_rounded, size: 18)),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _soapObjectiveController,
                decoration: const InputDecoration(hintText: 'Objective (O) - ROM, palpation findings', prefixIcon: Icon(Icons.visibility_outlined, size: 18)),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _soapAssessmentController,
                decoration: const InputDecoration(hintText: 'Assessment (A) - Diagnosis, subluxations', prefixIcon: Icon(Icons.assignment_turned_in_outlined, size: 18)),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _soapPlanController,
                decoration: const InputDecoration(hintText: 'Plan (P) - Treatment applied, follow up', prefixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
                maxLines: 2,
              ),
            ] else ...[
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Write clinical note/task here…', prefixIcon: Padding(padding: EdgeInsets.only(bottom: 36), child: Icon(Icons.edit_note_rounded, size: 18))),
                validator: (v) => _useSoap ? null : ((v == null || v.trim().isEmpty) ? 'Note/Task is required' : null),
              ),
            ],
            const SizedBox(height: 12),
            Text('Quick Templates', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _templates.length,
                itemBuilder: (context, idx) {
                  final t = _templates[idx];
                  final isMatchCategory = t.category == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(t.name, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: isMatchCategory ? Colors.white : null)),
                      backgroundColor: isMatchCategory ? Theme.of(context).colorScheme.primary : null,
                      onPressed: () {
                        setState(() {
                          _selectedCategory = t.category;
                          if (t.isSoap) {
                            _useSoap = true;
                            _soapSubjectiveController.text = t.soapSubjective;
                            _soapObjectiveController.text = t.soapObjective;
                            _soapAssessmentController.text = t.soapAssessment;
                            _soapPlanController.text = t.soapPlan;
                          } else {
                            _useSoap = false;
                            final text = _noteController.text.trim();
                            if (text.isEmpty) {
                              _noteController.text = t.body;
                            } else {
                              _noteController.text = '$text\n${t.body}';
                            }
                          }
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: Text(
                'Set as Task (To-Do)',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                'Requires action follow-up',
                style: GoogleFonts.poppins(fontSize: 10),
              ),
              value: _isTodo,
              onChanged: (val) => setState(() => _isTodo = val),
              secondary: const Icon(Icons.task_alt_rounded),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _saveNote,
                icon: Icon(_editingNote != null ? Icons.save_rounded : Icons.note_add_rounded, size: 18),
                label: Text(_editingNote != null ? 'Update Note' : 'Save Note'),
              ),
            ),
          ],
        ),
      );
    }

  Widget _buildDurationFilterChips(ColorScheme cs) {
    final options = ['All', '7 Days', '30 Days', '6 Months'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final isSelected = _selectedDuration == opt;
          return GestureDetector(
            onTap: () => setState(() => _selectedDuration = opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? cs.primary : cs.outline.withOpacity(0.3)),
              ),
              child: Text(
                opt,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : cs.onSurface.withOpacity(0.7),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListWidget(ColorScheme cs) {
    final filteredNotes = _filtered;
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
        const SizedBox(height: 10),
        _buildDurationFilterChips(cs),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${filteredNotes.length} note${filteredNotes.length != 1 ? 's' : ''}', style: GoogleFonts.poppins(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.55))),
        ]),
        const SizedBox(height: 10),
        filteredNotes.isEmpty
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
                itemCount: filteredNotes.length,
                itemBuilder: (_, i) {
                  final note = filteredNotes[i];
                  final ci = _categoryIndex(note.category);
                  final catColor = _categoryColors[ci % _categoryColors.length];
                  final isCompleted = note.isTodo && note.isCompleted;

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
                      child: GestureDetector(
                        onTap: () => _showNoteDetailDialog(note),
                        child: PremiumCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Todo checkmark option on the left
                              if (note.isTodo)
                                Padding(
                                  padding: const EdgeInsets.only(right: 10.0, top: 4.0),
                                  child: IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      color: isCompleted ? Colors.green : cs.primary.withOpacity(0.6),
                                      size: 24,
                                    ),
                                    onPressed: () => _toggleTodoStatus(note),
                                  ),
                                ),
                              Container(
                                width: 4,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isCompleted ? Colors.grey : catColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            note.patientName,
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: isCompleted ? cs.onSurface.withOpacity(0.4) : cs.onSurface,
                                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                                            ),
                                          ),
                                        ),
                                        // Edit Button
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, size: 18, color: cs.primary.withOpacity(0.7)),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _editNote(note),
                                          tooltip: 'Edit Note',
                                        ),
                                        const SizedBox(width: 8),
                                        // History Button
                                        IconButton(
                                          icon: Icon(Icons.history_rounded, size: 18, color: cs.primary.withOpacity(0.7)),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            context.push('/patient-history?name=${Uri.encodeComponent(note.patientName)}');
                                          },
                                          tooltip: 'Patient History',
                                        ),
                                        const SizedBox(width: 8),
                                        // Delete Button
                                        IconButton(
                                          icon: Icon(Icons.delete_outline_rounded, size: 18, color: cs.error.withOpacity(0.7)),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
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
                                          tooltip: 'Delete Note',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          DateFormat('d MMM y, hh:mm a').format(note.createdAt),
                                          style: GoogleFonts.poppins(fontSize: 10.5, color: cs.onSurface.withOpacity(0.4)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (isCompleted ? Colors.grey : catColor).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            note.category.toUpperCase(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                              color: isCompleted ? Colors.grey : catColor,
                                            ),
                                          ),
                                        ),
                                        if (note.isTodo)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (isCompleted ? Colors.green : Colors.amber).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isCompleted ? 'COMPLETED' : 'TASK',
                                              style: GoogleFonts.poppins(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w800,
                                                color: isCompleted ? Colors.green.shade800 : Colors.amber.shade800,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      note.note,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        height: 1.45,
                                        color: isCompleted ? cs.onSurface.withOpacity(0.4) : cs.onSurface.withOpacity(0.8),
                                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
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
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
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
                        _editingNote != null ? 'Edit Clinical Note/Task' : 'Add Clinical Note/Task',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildFormWidget(setModalState),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) {
      // Clear editing state on sheet dismissal
      _patientController.clear();
      _noteController.clear();
      _soapSubjectiveController.clear();
      _soapObjectiveController.clear();
      _soapAssessmentController.clear();
      _soapPlanController.clear();
      setState(() {
        _editingNote = null;
        _isTodo = false;
        _useSoap = false;
        _selectedCategory = 'General';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppShellScaffold(
      title: 'Clinical Notes',
      currentRoute: '/notes',
      actions: [
        IconButton(
          icon: const Icon(Icons.bookmarks_outlined),
          onPressed: _showManageTemplatesDialog,
          tooltip: 'Note Templates',
        ),
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
