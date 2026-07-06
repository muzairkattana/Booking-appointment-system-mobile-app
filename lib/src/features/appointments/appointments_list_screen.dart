import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/import_export_service.dart';
import 'package:uuid/uuid.dart';

import '../shared/widgets/app_shell_scaffold.dart';
import '../shared/widgets/premium_card.dart';
import '../../models/appointment.dart';
import '../appointments/appointment_repository.dart';
import '../../theme/app_theme.dart';

class AppointmentsListScreen extends StatefulWidget {
  const AppointmentsListScreen({super.key});

  @override
  State<AppointmentsListScreen> createState() => _AppointmentsListScreenState();
}

class _AppointmentsListScreenState extends State<AppointmentsListScreen> with SingleTickerProviderStateMixin {
  final AppointmentRepository _repository = AppointmentRepository();
  List<Appointment> _appointments = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  Future<void> _exportAppointments() async {
    try {
      final header = [
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
      final rows = <List<dynamic>>[header];
      for (final apt in _appointments) {
        rows.add([
          apt.id,
          apt.patientName,
          apt.patientProfession,
          apt.scheduledAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(apt.scheduledAt!) : apt.time,
          apt.treatmentType,
          apt.phoneNumber,
          apt.email,
          apt.status,
          apt.isEmergency ? 'EMERGENCY' : 'Standard',
          apt.visitReason,
          apt.patientNote,
          apt.cancellationReason,
          apt.updatedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(apt.updatedAt!) : '',
        ]);
      }

      final success = await ImportExportService.exportExcel(
        context: context,
        defaultFileName: 'gct_appointments.xlsx',
        sheets: {'Appointments': rows},
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointments exported to Excel successfully! 💾')),
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

  Future<void> _importAppointments() async {
    try {
      final excel = await ImportExportService.importExcel(context: context);
      if (excel == null) return;

      final rows = ImportExportService.parseSheet(excel: excel, sheetName: 'Appointments');
      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No appointments sheet found or sheet is empty.')),
          );
        }
        return;
      }

      final List<Appointment> imported = [];
      for (final row in rows) {
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
          imported.add(Appointment(
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'clinic_booked_appointments',
        jsonEncode(imported.map((item) => item.toJson()).toList()),
      );

      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointments imported successfully! 🔄')),
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
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.toLowerCase()));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final apts = await _repository.loadAppointments();
    if (!mounted) return;
    setState(() { _appointments = apts; _isLoading = false; });
  }

  List<Appointment> _filter(String type) {
    final now = DateTime.now();
    List<Appointment> result;
    switch (type) {
      case 'upcoming':
        result = _appointments.where((a) {
          final d = a.scheduledAt;
          return d != null && d.isAfter(now) && a.status.toLowerCase() != 'cancelled';
        }).toList()..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
        break;
      case 'past':
        result = _appointments.where((a) {
          final d = a.scheduledAt;
          return (d != null && d.isBefore(now)) || a.status.toLowerCase() == 'completed';
        }).toList();
        break;
      case 'cancelled':
        result = _appointments.where((a) => a.status.toLowerCase() == 'cancelled').toList();
        break;
      default: result = _appointments;
    }
    if (_searchQuery.isEmpty) return result;
    return result.where((a) => a.patientName.toLowerCase().contains(_searchQuery) || a.treatmentType.toLowerCase().contains(_searchQuery)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final upcoming = _filter('upcoming');
    final past = _filter('past');
    final cancelled = _filter('cancelled');

    return AppShellScaffold(
      title: 'All Appointments',
      currentRoute: '/appointments',
      actions: [
        IconButton(
          icon: const Icon(Icons.download_rounded),
          onPressed: _exportAppointments,
          tooltip: 'Export Appointments',
        ),
        IconButton(
          icon: const Icon(Icons.upload_file_rounded),
          onPressed: _importAppointments,
          tooltip: 'Import Appointments',
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/booking'),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by patient or treatment…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () => _searchController.clear()) : null,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Tab bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: cs.outline.withValues(alpha: 0.15))),
            child: TabBar(
              controller: _tabController,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
              unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w400, fontSize: 12),
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurface.withValues(alpha: 0.5),
              indicator: BoxDecoration(color: cs.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              tabs: [
                Tab(text: 'Upcoming (${upcoming.length})'),
                Tab(text: 'Past (${past.length})'),
                Tab(text: 'Cancelled (${cancelled.length})'),
              ],
            ),
          ),
          const SizedBox(height: 6),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _AppointmentListView(appointments: upcoming, onRefresh: _load, emptyMessage: 'No upcoming appointments'),
                      _AppointmentListView(appointments: past, onRefresh: _load, emptyMessage: 'No past appointments'),
                      _AppointmentListView(appointments: cancelled, onRefresh: _load, emptyMessage: 'No cancelled appointments'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentListView extends StatelessWidget {
  const _AppointmentListView({required this.appointments, required this.onRefresh, required this.emptyMessage});
  final List<Appointment> appointments;
  final Future<void> Function() onRefresh;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (appointments.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.event_busy_rounded, size: 54, color: cs.onSurface.withValues(alpha: 0.2)),
        const SizedBox(height: 12),
        Text(emptyMessage, style: GoogleFonts.poppins(color: cs.onSurface.withValues(alpha: 0.45))),
      ]));
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
        itemCount: appointments.length,
        itemBuilder: (_, i) {
          final apt = appointments[i];
          final sColor = statusColor(apt.status);
          final sBg = statusBgColor(apt.status);
          final date = apt.scheduledAt != null ? DateFormat('EEE, d MMM y  •  hh:mm a').format(apt.scheduledAt!) : apt.time;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PremiumCard(
              padding: const EdgeInsets.all(16),
              child: InkWell(
                onTap: () => context.push('/appointment/${apt.id}'),
                borderRadius: BorderRadius.circular(20),
                child: Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: cs.primary.withValues(alpha: 0.1),
                    child: Text(apt.patientName.isNotEmpty ? apt.patientName[0].toUpperCase() : '?', style: GoogleFonts.poppins(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(
                      children: [
                        Expanded(child: Text(apt.patientName, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14))),
                        if (apt.isEmergency)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                            child: Text('EMG', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFFEF4444))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(date, style: GoogleFonts.poppins(fontSize: 11.5, color: cs.onSurface.withValues(alpha: 0.55)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(apt.treatmentType, style: GoogleFonts.poppins(fontSize: 11.5, color: cs.onSurface.withValues(alpha: 0.45))),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: sBg, borderRadius: BorderRadius.circular(20)),
                      child: Text(apt.status, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: sColor)),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18),
                  ]),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
