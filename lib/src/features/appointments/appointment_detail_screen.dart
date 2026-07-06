import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../models/appointment.dart';
import 'appointment_repository.dart';
import '../shared/widgets/app_shell_scaffold.dart';
import '../shared/widgets/premium_card.dart';
import 'pdf_generator.dart';
import '../../theme/app_theme.dart';

class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  final AppointmentRepository _repo = AppointmentRepository();
  final _noteController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Appointment? _appointment;
  bool _isEditing = false;
  bool _isLoading = true;
  String _statusValue = 'Pending';
  DateTime? _scheduledAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _treatmentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final apt = await _repo.findById(widget.id);
    if (!mounted) return;
    setState(() {
      _appointment = apt;
      _noteController.text = apt?.patientNote ?? '';
      _nameController.text = apt?.patientName ?? '';
      _phoneController.text = apt?.phoneNumber ?? '';
      _emailController.text = apt?.email ?? '';
      _treatmentController.text = apt?.treatmentType ?? '';
      _statusValue = apt?.status ?? 'Pending';
      _scheduledAt = apt?.scheduledAt;
      _isLoading = false;
    });
  }

  Future<void> _saveEdits() async {
    if (_appointment == null) return;
    final updated = _appointment!.copyWith(
      patientName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      treatmentType: _treatmentController.text.trim(),
      status: _statusValue,
      scheduledAt: _scheduledAt ?? _appointment!.scheduledAt,
      updatedAt: DateTime.now(),
    );
    await _repo.updateAppointment(updated);
    if (!mounted) return;
    setState(() { _appointment = updated; _isEditing = false; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment updated')));
  }

  Future<void> _saveNote() async {
    if (_appointment == null) return;
    final updated = _appointment!.copyWith(patientNote: _noteController.text.trim(), updatedAt: DateTime.now());
    await _repo.updateAppointment(updated);
    if (!mounted) return;
    setState(() => _appointment = updated);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved')));
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_appointment == null) return;
    final updated = _appointment!.copyWith(status: newStatus, updatedAt: DateTime.now());
    await _repo.updateAppointment(updated);
    if (!mounted) return;
    setState(() => _appointment = updated);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status → $newStatus')));
  }

  Future<void> _deleteAppointment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Appointment', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('This will permanently delete this appointment.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (confirmed != true || _appointment == null) return;
    await _repo.deleteAppointment(_appointment!.id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? DateTime.now()));
    if (time == null) return;
    setState(() => _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _generatePdf() async {
    if (_appointment == null) return;
    final bytes = await generatePatientReportPdf(_appointment!);
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: '${_appointment!.patientName}_REPORT',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(body: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)));
    final apt = _appointment;
    if (apt == null) return AppShellScaffold(title: 'Appointment', currentRoute: '/dashboard', body: const Center(child: Text('Not found')));

    final cs = Theme.of(context).colorScheme;
    final dateText = apt.scheduledAt != null ? DateFormat('EEEE, d MMM y  •  hh:mm a').format(apt.scheduledAt!) : apt.time;
    final sColor = statusColor(apt.status);
    final sBg = statusBgColor(apt.status);

    return AppShellScaffold(
      title: 'Appointment Detail',
      currentRoute: '/dashboard',
      actions: [
        IconButton(icon: const Icon(Icons.picture_as_pdf_rounded), onPressed: _generatePdf, tooltip: 'PDF'),
        PopupMenuButton<String>(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: (v) async {
            if (v == 'edit') setState(() => _isEditing = true);
            if (v == 'confirm') await _updateStatus('Confirmed');
            if (v == 'complete') await _updateStatus('Completed');
            if (v == 'cancel') await _updateStatus('Cancelled');
            if (v == 'delete') await _deleteAppointment();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'confirm', child: Text('Mark Confirmed')),
            const PopupMenuItem(value: 'complete', child: Text('Mark Completed')),
            const PopupMenuItem(value: 'cancel', child: Text('Cancel Appointment')),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status timeline
          _StatusTimeline(status: apt.status),
          const SizedBox(height: 14),

          // Main card
          PremiumCard(
            padding: const EdgeInsets.all(20),
            child: _isEditing ? _buildEditForm() : _buildViewCard(apt, cs, dateText, sColor, sBg),
          ),
          const SizedBox(height: 14),

          // Quick action buttons
          if (!_isEditing)
            Row(children: [
              _QuickBtn(icon: Icons.check_circle_outline_rounded, label: 'Confirm', color: AppColors.statusConfirmed, onTap: () => _updateStatus('Confirmed')),
              const SizedBox(width: 10),
              _QuickBtn(icon: Icons.task_alt_rounded, label: 'Complete', color: AppColors.statusCompleted, onTap: () => _updateStatus('Completed')),
              const SizedBox(width: 10),
              _QuickBtn(icon: Icons.picture_as_pdf_rounded, label: 'PDF', color: cs.primary, onTap: _generatePdf),
            ]),

          const SizedBox(height: 16),
          Text('Clinical Note', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          PremiumCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _noteController,
                  maxLines: 5,
                  decoration: const InputDecoration(hintText: 'Add clinical note…', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: _saveNote, child: const Text('Save Note'))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: _generatePdf, child: const Text('Report'))),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildViewCard(Appointment apt, ColorScheme cs, String dateText, Color sColor, Color sBg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (apt.isEmergency) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 8),
                Text(
                  'CRITICAL EMERGENCY APPOINTMENT',
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFFEF4444), letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ],
        Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            child: Text(apt.patientName.isNotEmpty ? apt.patientName[0].toUpperCase() : '?', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: cs.primary)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(apt.patientName, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: sBg, borderRadius: BorderRadius.circular(20)), child: Text(apt.status, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: sColor))),
          ])),
        ]),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        _DetailRow(icon: Icons.calendar_today_rounded, label: 'Date', value: dateText),
        _DetailRow(icon: Icons.medical_services_outlined, label: 'Treatment', value: apt.treatmentType),
        if (apt.phoneNumber.isNotEmpty) _DetailRow(icon: Icons.phone_outlined, label: 'Phone', value: apt.phoneNumber),
        if (apt.email.isNotEmpty) _DetailRow(icon: Icons.mail_outline_rounded, label: 'Email', value: apt.email),
        if (apt.visitReason.isNotEmpty) _DetailRow(icon: Icons.edit_note_rounded, label: 'Reason', value: apt.visitReason),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () => setState(() => _isEditing = true), icon: const Icon(Icons.edit_rounded, size: 18), label: const Text('Edit Appointment')),
      ],
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit Appointment', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 14),
          TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Patient name', prefixIcon: Icon(Icons.person_outline_rounded))),
          const SizedBox(height: 10),
          TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 10),
          TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded))),
          const SizedBox(height: 10),
          TextFormField(controller: _treatmentController, decoration: const InputDecoration(labelText: 'Treatment', prefixIcon: Icon(Icons.medical_services_outlined))),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _pickDateTime,
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: Text(_scheduledAt != null ? DateFormat('d MMM y • hh:mm a').format(_scheduledAt!) : 'Change date & time'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _statusValue,
            decoration: const InputDecoration(labelText: 'Status'),
            items: ['Pending', 'Confirmed', 'Completed', 'Cancelled'].map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.poppins()))).toList(),
            onChanged: (v) => setState(() => _statusValue = v ?? _statusValue),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _isEditing = false), child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: _saveEdits, child: const Text('Save'))),
          ]),
        ],
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    const steps = ['Pending', 'Confirmed', 'Completed'];
    final cs = Theme.of(context).colorScheme;
    final currentIdx = steps.indexWhere((s) => s.toLowerCase() == status.toLowerCase());
    final isCancelled = status.toLowerCase() == 'cancelled';

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isCancelled ? Icons.cancel_rounded : Icons.timeline_rounded, size: 18, color: isCancelled ? AppColors.statusCancelled : cs.primary),
          const SizedBox(width: 8),
          Text(isCancelled ? 'Appointment Cancelled' : 'Appointment Progress', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
        if (!isCancelled) ...[
          const SizedBox(height: 14),
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                return Expanded(child: Container(height: 2, color: (i ~/ 2) < currentIdx ? AppColors.statusConfirmed : AppColors.grey200));
              }
              final idx = i ~/ 2;
              final done = idx <= currentIdx;
              final curr = idx == currentIdx;
              return Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: curr ? 30 : 24,
                  height: curr ? 30 : 24,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: done ? AppColors.statusConfirmed : AppColors.grey200, boxShadow: curr ? [BoxShadow(color: AppColors.statusConfirmed.withValues(alpha: 0.35), blurRadius: 8)] : []),
                  child: Center(child: Icon(Icons.check_rounded, size: 14, color: done ? Colors.white : AppColors.grey400)),
                ),
                const SizedBox(height: 4),
                Text(steps[idx], style: GoogleFonts.poppins(fontSize: 10, fontWeight: curr ? FontWeight.w600 : FontWeight.w400, color: done ? AppColors.statusConfirmed : AppColors.grey400)),
              ]);
            }),
          ),
        ],
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon; final String label; final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 17, color: cs.onSurface.withValues(alpha: 0.45)),
        const SizedBox(width: 10),
        SizedBox(width: 68, child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)))),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon; final String label; final Color color; final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.25))),
          child: Column(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }
}
