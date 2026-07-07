import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../utils/import_export_service.dart';
import '../../services/app_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:printing/printing.dart';

import '../../features/auth/auth_providers.dart';
import '../../models/app_user.dart';
import '../../models/appointment.dart';
import '../appointments/appointment_repository.dart';
import '../appointments/pdf_generator.dart';
import '../shared/widgets/app_shell_scaffold.dart';
import '../shared/widgets/premium_card.dart';
import '../../theme/app_theme.dart';
import '../payments/payment_repository.dart';
import '../../models/payment.dart';
import '../notes/clinical_notes_repository.dart';
import '../../services/repository_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  AppointmentRepository get _repository => ref.read(appointmentRepositoryProvider);
  PaymentRepository get _paymentRepository => ref.read(paymentRepositoryProvider);
  List<Appointment> _appointments = [];
  List<Payment> _payments = [];
  bool _isLoading = true;

  Future<void> _exportMasterBackup() async {
    try {
      final prefs = await AppPreferences.instance.prefs;
      
      // Parse Appointments
      final appointmentsRaw = prefs.getString('clinic_booked_appointments') ?? '[]';
      final List<dynamic> aptJson = jsonDecode(appointmentsRaw);
      final aptHeader = [
        'Appointment ID',
        'Patient Name',
        'Profession',
        'Scheduled Date & Time',
        'Treatment Type',
        'Phone Number',
        'Email',
        'Status',
        'Priority',
        'Reason for Visit',
        'Clinical Notes',
        'Cancellation Reason',
        'Last Updated'
      ];
      final aptRows = <List<dynamic>>[aptHeader];
      for (final item in aptJson) {
        final map = Map<String, dynamic>.from(item as Map);
        aptRows.add([
          map['id'] ?? '',
          map['patientName'] ?? '',
          map['patientProfession'] ?? '',
          map['scheduledAt'] != null ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(map['scheduledAt'])) : (map['time'] ?? ''),
          map['treatmentType'] ?? '',
          map['phoneNumber'] ?? '',
          map['email'] ?? '',
          map['status'] ?? '',
          (map['isEmergency'] == true) ? 'EMERGENCY' : 'Standard',
          map['visitReason'] ?? '',
          map['patientNote'] ?? '',
          map['cancellationReason'] ?? '',
          map['updatedAt'] != null ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(map['updatedAt'])) : '',
        ]);
      }

      // Parse Payments
      final paymentsRaw = prefs.getString('clinic_patient_payments') ?? '[]';
      final List<dynamic> payJson = jsonDecode(paymentsRaw);
      final payHeader = ['Payment ID', 'Patient Name', 'Amount (PKR)', 'Payment Method', 'Status', 'Note/Details', 'Payment Date'];
      final payRows = <List<dynamic>>[payHeader];
      for (final item in payJson) {
        final map = Map<String, dynamic>.from(item as Map);
        payRows.add([
          map['id'] ?? '',
          map['patientName'] ?? '',
          map['amount'] ?? 0.0,
          map['method'] ?? '',
          map['status'] ?? '',
          map['note'] ?? '',
          map['paidAt'] != null ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(map['paidAt'])) : '',
        ]);
      }

      // Parse Clinical Notes
      final notesRaw = prefs.getString('clinic_clinical_notes') ?? '[]';
      final List<dynamic> notesJson = jsonDecode(notesRaw);
      final notesHeader = ['Note ID', 'Patient Name', 'Clinical Note', 'Category', 'Created At'];
      final notesRows = <List<dynamic>>[notesHeader];
      for (final item in notesJson) {
        final map = Map<String, dynamic>.from(item as Map);
        notesRows.add([
          map['id'] ?? '',
          map['patientName'] ?? '',
          map['note'] ?? '',
          map['category'] ?? '',
          map['createdAt'] != null ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(map['createdAt'])) : '',
        ]);
      }

      final success = await ImportExportService.exportExcel(
        context: context,
        defaultFileName: 'gct_clinic_master_export.xlsx',
        sheets: {
          'Appointments': aptRows,
          'Payments': payRows,
          'Clinical Notes': notesRows,
        },
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Master Export to Excel successfully exported! 💾')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Master Export failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _importMasterBackup() async {
    try {
      final excel = await ImportExportService.importExcel(context: context);
      if (excel == null) return;

      final prefs = await AppPreferences.instance.prefs;

      // 1. Import Appointments
      final aptRows = ImportExportService.parseSheet(excel: excel, sheetName: 'Appointments');
      if (aptRows.isNotEmpty) {
        final List<Appointment> importedApts = [];
        for (final row in aptRows) {
          final id = row['Appointment ID']?.toString() ?? '';
          final patientName = row['Patient Name']?.toString() ?? '';
          final patientProfession = row['Profession']?.toString() ?? '';
          final scheduledRaw = row['Scheduled Date & Time']?.toString() ?? '';
          final treatmentType = row['Treatment Type']?.toString() ?? '';
          final phoneNumber = row['Phone Number']?.toString() ?? '';
          final email = row['Email']?.toString() ?? '';
          final status = row['Status']?.toString() ?? 'Pending';
          final priority = row['Priority']?.toString() ?? 'Standard';
          final visitReason = row['Reason for Visit']?.toString() ?? '';
          final patientNote = row['Clinical Notes']?.toString() ?? '';
          final cancellationReason = row['Cancellation Reason']?.toString() ?? '';
          final updatedRaw = row['Last Updated']?.toString() ?? '';

          DateTime? scheduledAt = DateTime.tryParse(scheduledRaw);
          DateTime? updatedAt = DateTime.tryParse(updatedRaw);

          if (patientName.isNotEmpty) {
            importedApts.add(Appointment(
              id: id.isNotEmpty ? id : Uuid().v4(),
              patientName: patientName,
              patientProfession: patientProfession,
              scheduledAt: scheduledAt,
              time: scheduledAt != null ? DateFormat('hh:mm a').format(scheduledAt) : scheduledRaw,
              treatmentType: treatmentType,
              phoneNumber: phoneNumber,
              email: email,
              status: status,
              isEmergency: priority == 'EMERGENCY',
              visitReason: visitReason,
              patientNote: patientNote,
              cancellationReason: cancellationReason,
              updatedAt: updatedAt,
            ));
          }
        }
        await prefs.setString(
          'clinic_booked_appointments',
          jsonEncode(importedApts.map((a) => a.toJson()).toList()),
        );
      }

      // 2. Import Payments
      final payRows = ImportExportService.parseSheet(excel: excel, sheetName: 'Payments');
      if (payRows.isNotEmpty) {
        final List<Payment> importedPays = [];
        for (final row in payRows) {
          final id = row['Payment ID']?.toString() ?? '';
          final patientName = row['Patient Name']?.toString() ?? '';
          final amount = double.tryParse(row['Amount (PKR)']?.toString() ?? '0') ?? 0.0;
          final method = row['Payment Method']?.toString() ?? 'Cash';
          final status = row['Status']?.toString() ?? 'Paid';
          final note = row['Note/Details']?.toString() ?? '';
          final paidRaw = row['Payment Date']?.toString() ?? '';

          DateTime paidAt = DateTime.tryParse(paidRaw) ?? DateTime.now();

          if (patientName.isNotEmpty) {
            final double pAmt = status.toLowerCase() == 'paid' ? amount : 0.0;
            importedPays.add(Payment(
              id: id.isNotEmpty ? id : Uuid().v4(),
              patientName: patientName,
              amount: amount,
              paidAmount: pAmt,
              paidAt: paidAt,
              method: method,
              status: status,
              note: note,
            ));
          }
        }
        await prefs.setString(
          'clinic_patient_payments',
          jsonEncode(importedPays.map((p) => p.toJson()).toList()),
        );
      }

      // 3. Import Clinical Notes
      final noteRows = ImportExportService.parseSheet(excel: excel, sheetName: 'Clinical Notes');
      if (noteRows.isNotEmpty) {
        final List<ClinicalNote> importedNotes = [];
        for (final row in noteRows) {
          final id = row['Note ID']?.toString() ?? '';
          final patientName = row['Patient Name']?.toString() ?? '';
          final note = row['Clinical Note']?.toString() ?? '';
          final category = row['Category']?.toString() ?? 'General';
          final createdRaw = row['Created At']?.toString() ?? '';

          DateTime createdAt = DateTime.tryParse(createdRaw) ?? DateTime.now();

          if (patientName.isNotEmpty) {
            importedNotes.add(ClinicalNote(
              id: id.isNotEmpty ? id : Uuid().v4(),
              patientName: patientName,
              note: note,
              category: category,
              createdAt: createdAt,
            ));
          }
        }
        await prefs.setString(
          'clinic_clinical_notes',
          jsonEncode(importedNotes.map((n) => n.toJson()).toList()),
        );
      }

      await _loadAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Master Backup restored successfully! 🔄')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Master Restore failed: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final appointments = await _repository.loadAppointments();
    final payments = await _paymentRepository.loadPayments();
    if (!mounted) return;
    setState(() {
      _appointments = appointments;
      _payments = payments;
      _isLoading = false;
    });
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrlString(url)) await launchUrlString(url);
  }

  Appointment? get _nextAppointment {
    final now = DateTime.now();
    final upcoming = _appointments.where((a) {
      final d = a.scheduledAt;
      return d != null && d.isAfter(now) && a.status.toLowerCase() != 'cancelled';
    }).toList()
      ..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    return upcoming.isNotEmpty ? upcoming.first : null;
  }

  Widget _PaymentRemindersBanner(ColorScheme cs) {
    final outstanding = _payments.where((p) => p.status != 'Paid' && p.reminderDate != null).toList()
      ..sort((a, b) => a.reminderDate!.compareTo(b.reminderDate!));
    if (outstanding.isEmpty) return const SizedBox.shrink();

    final fmt = NumberFormat.currency(symbol: 'PKR ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.alarm_on_rounded, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Payment Reminders',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.red.shade900),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...outstanding.take(2).map((p) {
              final isOverdue = p.reminderDate!.isBefore(DateTime.now());
              return Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  '• ${p.patientName} owes PKR ${fmt.format(p.amount - p.paidAmount)} (Due: ${DateFormat('d MMM, h:mm a').format(p.reminderDate!)})',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: Colors.red.shade900,
                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.asData?.value ??
        AppUser(uid: 'guest', email: 'guest@gonstead.com', displayName: 'Guest', phoneNumber: '');
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 720;

    final total = _appointments.length;
    final confirmed = _appointments.where((a) => a.status.toLowerCase() == 'confirmed').length;
    final pending = _appointments.where((a) => a.status.toLowerCase() == 'pending').length;
    final next = _nextAppointment;

    final totalPaid = _payments.fold<double>(0, (s, p) => s + p.paidAmount);
    final totalPending = _payments.fold<double>(0, (s, p) => s + (p.amount - p.paidAmount));
    final totalAll = _payments.fold<double>(0, (s, p) => s + p.amount);

    return AppShellScaffold(
      title: 'Dashboard',
      currentRoute: '/dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.analytics_outlined),
          onPressed: () => context.push('/analytics'),
          tooltip: 'Analytics',
        ),
        IconButton(
          icon: const Icon(Icons.download_rounded),
          onPressed: _exportMasterBackup,
          tooltip: 'Export Master Backup',
        ),
        IconButton(
          icon: const Icon(Icons.upload_file_rounded),
          onPressed: _importMasterBackup,
          tooltip: 'Restore Master Backup',
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/booking'),
        label: Text('Book Visit', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        icon: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAppointments,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column (flex: 3)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _GreetingRow(displayName: user.displayName.split(' ').first),
                          const SizedBox(height: 14),
                          _PaymentRemindersBanner(cs),
                          if (next != null && next.scheduledAt != null && next.scheduledAt!.difference(DateTime.now()).inHours < 24 && !next.scheduledAt!.difference(DateTime.now()).isNegative) ...[
                            _UpcomingNotificationBanner(appointment: next),
                            const SizedBox(height: 14),
                          ],
                          if (!_isLoading) ...[
                            Row(
                              children: [
                                _MiniStatCard(label: 'Total', value: total, icon: Icons.event_note_rounded, color: cs.primary),
                                const SizedBox(width: 10),
                                _MiniStatCard(label: 'Confirmed', value: confirmed, icon: Icons.check_circle_outline_rounded, color: AppColors.statusConfirmed),
                                const SizedBox(width: 10),
                                _MiniStatCard(label: 'Pending', value: pending, icon: Icons.hourglass_top_rounded, color: AppColors.statusPending),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _PaymentsQuickViewCard(total: totalAll, collected: totalPaid, pending: totalPending),
                          ],
                          const SizedBox(height: 18),
                          _SectionLabel(label: 'Next Appointment'),
                          const SizedBox(height: 10),
                          if (_isLoading)
                            const _SkeletonCard()
                          else if (next == null)
                            _EmptyNextCard(onBook: () => context.push('/booking'))
                          else
                            _NextAppointmentCard(appointment: next, onTap: () => context.push('/appointment/${next.id}')),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _SectionLabel(label: 'Upcoming Visits'),
                              TextButton(
                                onPressed: () => context.push('/appointments'),
                                child: const Text('See all'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_isLoading)
                            ...[1, 2].map((_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: _SkeletonCard()))
                          else if (_appointments.isEmpty)
                            PremiumCard(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Icon(Icons.event_busy_rounded, color: cs.onSurface.withValues(alpha: 0.3), size: 32),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('No visits booked yet', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Text('Book your first appointment above', style: GoogleFonts.poppins(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.55))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ..._appointments.take(5).map(
                                  (apt) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _AppointmentTile(appointment: apt, onDeleted: _loadAppointments),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right Column (flex: 2)
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(label: 'Quick Actions'),
                          const SizedBox(height: 10),
                          _QuickActionsGrid(onLaunchUrl: _launchUrl),
                          const SizedBox(height: 20),
                          _SectionLabel(label: 'Clinic Information'),
                          const SizedBox(height: 10),
                          _ClinicInfoCard(onLaunchUrl: _launchUrl),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GreetingRow(displayName: user.displayName.split(' ').first),
                    const SizedBox(height: 14),
                    _PaymentRemindersBanner(cs),
                    if (next != null && next.scheduledAt != null && next.scheduledAt!.difference(DateTime.now()).inHours < 24 && !next.scheduledAt!.difference(DateTime.now()).isNegative) ...[
                      _UpcomingNotificationBanner(appointment: next),
                      const SizedBox(height: 14),
                    ],
                    if (!_isLoading) ...[
                      Row(
                        children: [
                          _MiniStatCard(label: 'Total', value: total, icon: Icons.event_note_rounded, color: cs.primary),
                          const SizedBox(width: 10),
                          _MiniStatCard(label: 'Confirmed', value: confirmed, icon: Icons.check_circle_outline_rounded, color: AppColors.statusConfirmed),
                          const SizedBox(width: 10),
                          _MiniStatCard(label: 'Pending', value: pending, icon: Icons.hourglass_top_rounded, color: AppColors.statusPending),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _PaymentsQuickViewCard(total: totalAll, collected: totalPaid, pending: totalPending),
                    ],
                    const SizedBox(height: 18),
                    _SectionLabel(label: 'Next Appointment'),
                    const SizedBox(height: 10),
                    if (_isLoading)
                      const _SkeletonCard()
                    else if (next == null)
                      _EmptyNextCard(onBook: () => context.push('/booking'))
                    else
                      _NextAppointmentCard(appointment: next, onTap: () => context.push('/appointment/${next.id}')),
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Quick Actions'),
                    const SizedBox(height: 10),
                    _QuickActionsGrid(onLaunchUrl: _launchUrl),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SectionLabel(label: 'Upcoming Visits'),
                        TextButton(
                          onPressed: () => context.push('/appointments'),
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      ...[1, 2].map((_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: _SkeletonCard()))
                    else if (_appointments.isEmpty)
                      PremiumCard(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Icon(Icons.event_busy_rounded, color: cs.onSurface.withValues(alpha: 0.3), size: 32),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('No visits booked yet', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text('Book your first appointment above', style: GoogleFonts.poppins(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.55))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._appointments.take(5).map(
                            (apt) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _AppointmentTile(appointment: apt, onDeleted: _loadAppointments),
                            ),
                          ),
                    const SizedBox(height: 20),
                    _SectionLabel(label: 'Clinic Information'),
                    const SizedBox(height: 10),
                    _ClinicInfoCard(onLaunchUrl: _launchUrl),
                  ],
                ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Sub-widgets
// ──────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2A40) : const Color(0xFFE8EFF8),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _GreetingRow extends StatelessWidget {
  const _GreetingRow({required this.displayName});
  final String displayName;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$_greeting,', style: GoogleFonts.poppins(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.55))),
        Text(displayName, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface, letterSpacing: -0.5)),
      ],
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value.toString(), style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55))),
          ],
        ),
      ),
    );
  }
}

class _EmptyNextCard extends StatelessWidget {
  const _EmptyNextCard({required this.onBook});
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.event_available_rounded, color: cs.primary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No upcoming visits', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 3),
                Text('Schedule your next visit now', style: GoogleFonts.poppins(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55))),
              ],
            ),
          ),
          TextButton(onPressed: onBook, child: const Text('Book')),
        ],
      ),
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({required this.appointment, required this.onTap});
  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = appointment.scheduledAt != null
        ? DateFormat('EEE, d MMM • hh:mm a').format(appointment.scheduledAt!)
        : appointment.time;
    final sColor = statusColor(appointment.status);
    final sBg = statusBgColor(appointment.status);

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.calendar_today_rounded, color: cs.primary, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(appointment.patientName, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      if (appointment.isEmergency) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            'EMERGENCY',
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(date, style: GoogleFonts.poppins(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 3),
                  Text(appointment.treatmentType, style: GoogleFonts.poppins(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: sBg, borderRadius: BorderRadius.circular(20)),
              child: Text(appointment.status, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: sColor)),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.onLaunchUrl});
  final Future<void> Function(String) onLaunchUrl;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cols = width > 1000 ? 3 : (width > 720 ? 2 : 3);
    final isMobile = width <= 720;

    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: isMobile ? 0.8 : 1.0,
      children: [
        _QuickAction(icon: Icons.calendar_month_rounded, label: 'Book Visit', color: const Color(0xFF0A6BE8), onTap: () => context.push('/booking')),
        _QuickAction(icon: Icons.list_alt_rounded, label: 'Appointments', color: const Color(0xFF6366F1), onTap: () => context.push('/appointments')),
        _QuickAction(icon: Icons.account_balance_wallet_rounded, label: 'Payments', color: const Color(0xFF00A86B), onTap: () => context.push('/payments')),
        _QuickAction(icon: Icons.book_rounded, label: 'Notes', color: const Color(0xFFF59E0B), onTap: () => context.push('/notes')),
        _QuickAction(icon: Icons.calculate_rounded, label: 'Calculator', color: const Color(0xFF8B5CF6), onTap: () => context.push('/calculator')),
        _QuickAction(icon: Icons.health_and_safety_rounded, label: 'Care Tips', color: const Color(0xFFEF4444), onTap: () => context.push('/care-tips')),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClinicInfoCard extends StatelessWidget {
  const _ClinicInfoCard({required this.onLaunchUrl});
  final Future<void> Function(String) onLaunchUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Gonstead Chiropractic Treatment', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(icon: Icons.access_time_rounded, text: 'Mon – Sat  •  09:00 AM – 07:00 PM'),
          const SizedBox(height: 6),
          _InfoLine(icon: Icons.location_on_rounded, text: 'Tehsil Road, Near Peshawar Model School, Nowshera City, KPK.'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onLaunchUrl('tel:+923046996267'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.call_rounded, size: 18),
                        const SizedBox(width: 6),
                        const Text('Call'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onLaunchUrl('https://maps.google.com/?q=Tehsil+Road+Nowshera'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_rounded, size: 18),
                        const SizedBox(width: 6),
                        const Text('Navigate'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.45)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)))),
      ],
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({required this.appointment, this.onDeleted});
  final Appointment appointment;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sColor = statusColor(appointment.status);
    final sBg = statusBgColor(appointment.status);

    return Dismissible(
      key: Key(appointment.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.statusCancelled.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.statusCancelled),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Delete appointment', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            content: Text('Remove ${appointment.patientName}\'s appointment?', style: GoogleFonts.poppins()),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Delete', style: TextStyle(color: cs.error)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        await AppointmentRepository().deleteAppointment(appointment.id);
        onDeleted?.call();
      },
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: InkWell(
          onTap: () => context.push('/appointment/${appointment.id}'),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                child: Text(
                  appointment.patientName.isNotEmpty ? appointment.patientName[0].toUpperCase() : '?',
                  style: GoogleFonts.poppins(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(appointment.patientName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                        ),
                        if (appointment.isEmergency) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'EMG',
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${appointment.time}  •  ${appointment.treatmentType}',
                        style: GoogleFonts.poppins(fontSize: 11.5, color: cs.onSurface.withValues(alpha: 0.55)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: sBg, borderRadius: BorderRadius.circular(20)),
                child: Text(appointment.status, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: sColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingNotificationBanner extends StatelessWidget {
  const _UpcomingNotificationBanner({required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final diff = appointment.scheduledAt!.difference(DateTime.now());
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final timeStr = hours > 0 ? '$hours hr $minutes min' : '$minutes min';

    return GestureDetector(
      onTap: () => context.push('/appointment/${appointment.id}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF97316).withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF97316).withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFFEA580C),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'UPCOMING VISIT',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFEA580C),
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          timeStr,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    appointment.patientName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF431407),
                    ),
                  ),
                  Text(
                    '${appointment.treatmentType}  •  Today at ${appointment.time}',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: const Color(0xFF431407).withOpacity(0.65),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentsQuickViewCard extends StatelessWidget {
  const _PaymentsQuickViewCard({
    required this.total,
    required this.collected,
    required this.pending,
  });
  final double total;
  final double collected;
  final double pending;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Payments Quick View',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem('Total', total, cs.primary),
              _buildDivider(),
              _buildStatItem('Collected', collected, AppColors.statusConfirmed),
              _buildDivider(),
              _buildStatItem('Pending', pending, AppColors.statusPending),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 36,
      width: 1,
      color: Colors.grey.withOpacity(0.2),
      margin: const EdgeInsets.symmetric(horizontal: 12),
    );
  }

  Widget _buildStatItem(String label, double amount, Color color) {
    final fmt = NumberFormat('PKR #,##0', 'en_US');
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fmt.format(amount),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
