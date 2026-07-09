import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../features/auth/auth_providers.dart';
import '../../services/app_preferences.dart';
import '../../models/app_user.dart';
import '../shared/widgets/app_shell_scaffold.dart';
import '../shared/widgets/premium_card.dart';
import '../../theme/theme_mode_provider.dart';
import '../../theme/app_theme.dart';
import '../appointments/appointment_repository.dart';
import '../../models/appointment.dart';
import '../../services/repository_providers.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key});

  @override
  ConsumerState<PatientProfileScreen> createState() => _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  String? _imagePath;
  int _totalAppointments = 0;
  int _upcomingAppointments = 0;
  List<Appointment> _patientAppointments = [];
  Appointment? _activePlanApt;
  int _completedSessions = 0;
  int _totalSessions = 0;
  List<Appointment> _upcomingSessions = [];
  List<Appointment> _pastSessions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await AppPreferences.instance.prefs;
    final path = prefs.getString('doctor_profile_image');
    final apts = await ref.read(appointmentRepositoryProvider).loadAppointments();
    
    final authState = ref.read(authStateProvider);
    final user = authState.asData?.value ?? AppUser(uid: 'guest', email: 'guest@gonstead.com', displayName: 'Guest Patient', phoneNumber: '+92 300 1234567');
    
    final filtered = apts.where((a) {
      final nameMatch = a.patientName.toLowerCase() == user.displayName.toLowerCase();
      final phoneMatch = user.phoneNumber.isNotEmpty && a.phoneNumber == user.phoneNumber;
      final emailMatch = user.email.isNotEmpty && a.email.toLowerCase() == user.email.toLowerCase();
      return nameMatch || phoneMatch || emailMatch;
    }).toList();

    // Sort by scheduled date
    filtered.sort((a, b) {
      if (a.scheduledAt == null && b.scheduledAt == null) return 0;
      if (a.scheduledAt == null) return 1;
      if (b.scheduledAt == null) return -1;
      return b.scheduledAt!.compareTo(a.scheduledAt!);
    });

    final now = DateTime.now();
    
    Appointment? activePlanApt;
    try {
      activePlanApt = filtered.firstWhere((a) => a.treatmentPlanTotalSessions != null && a.treatmentPlanTotalSessions! > 0);
    } catch (_) {}

    int totalSessions = 0;
    int completedSessions = 0;
    if (activePlanApt != null) {
      totalSessions = activePlanApt.treatmentPlanTotalSessions!;
      completedSessions = filtered.where((a) => a.status.toLowerCase() == 'completed' && a.treatmentPlanTotalSessions == totalSessions).length;
    }

    final upcoming = filtered.where((a) {
      final d = a.scheduledAt;
      return d != null && d.isAfter(now) && a.status.toLowerCase() != 'cancelled';
    }).toList()..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

    final past = filtered.where((a) {
      final d = a.scheduledAt;
      return (d != null && d.isBefore(now)) || a.status.toLowerCase() == 'completed' || a.status.toLowerCase() == 'cancelled' || a.status.toLowerCase() == 'no show';
    }).toList();

    if (!mounted) return;
    setState(() {
      _imagePath = path;
      _patientAppointments = filtered;
      _activePlanApt = activePlanApt;
      _totalSessions = totalSessions;
      _completedSessions = completedSessions;
      _upcomingSessions = upcoming;
      _pastSessions = past;
      _totalAppointments = filtered.length;
      _upcomingAppointments = upcoming.length;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (result == null) return;
    final prefs = await AppPreferences.instance.prefs;
    await prefs.setString('doctor_profile_image', result.path);
    if (!mounted) return;
    setState(() => _imagePath = result.path);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Sign Out', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to sign out?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Sign Out', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(authRepositoryProvider).signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);
    final user = authState.asData?.value ?? AppUser(uid: 'guest', email: 'guest@gonstead.com', displayName: 'Guest Patient', phoneNumber: '+92 300 1234567');
    final cs = Theme.of(context).colorScheme;

    Widget avatar;
    if (_imagePath != null && _imagePath!.isNotEmpty) {
      avatar = Image.file(
        File(_imagePath!),
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        cacheWidth: 200,
        cacheHeight: 200,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/dr-bashir-photo.jpeg',
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          cacheWidth: 200,
          cacheHeight: 200,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.person_rounded, size: 50),
        ),
      );
    } else {
      avatar = Image.asset(
        'assets/dr-bashir-photo.jpeg',
        width: 100,
        height: 100,
        fit: BoxFit.cover,
        cacheWidth: 200,
        cacheHeight: 200,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person_rounded, size: 50),
      );
    }

    return AppShellScaffold(
      title: 'Profile',
      currentRoute: '/profile',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Profile hero
          PremiumCard(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Stack(
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.2), blurRadius: 18)],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: avatar,
                  ),
                  Positioned(
                    right: 0, bottom: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(20), border: Border.all(color: cs.surface, width: 2)),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(user.displayName, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.3)),
              const SizedBox(height: 4),
              Text(user.email, style: GoogleFonts.poppins(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.55))),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('Active care plan • DR. BASHIR AHMAD', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
              ),
              const SizedBox(height: 18),
              // Stats row
              Row(children: [
                _StatPill(label: 'Total Visits', value: _totalAppointments.toString(), color: cs.primary),
                const SizedBox(width: 12),
                _StatPill(label: 'Upcoming', value: _upcomingAppointments.toString(), color: AppColors.statusConfirmed),
              ]),
            ]),
          ),
          const SizedBox(height: 18),

          // Patient Details
          _SectionLabel(label: 'Patient Details'),
          const SizedBox(height: 10),
          PremiumCard(
            padding: const EdgeInsets.all(18),
            child: Column(children: [
              _InfoRow(icon: Icons.person_outline_rounded, label: 'Full Name', value: user.displayName),
              const Divider(height: 20),
              _InfoRow(icon: Icons.mail_outline_rounded, label: 'Email', value: user.email),
              const Divider(height: 20),
              _InfoRow(icon: Icons.phone_outlined, label: 'Phone', value: user.phoneNumber.isNotEmpty ? user.phoneNumber : 'Not set'),
              const Divider(height: 20),
              _InfoRow(icon: Icons.healing_rounded, label: 'Care Type', value: 'Spine & posture correction'),
              const Divider(height: 20),
              _InfoRow(icon: Icons.repeat_rounded, label: 'Frequency', value: 'Weekly support plan'),
            ]),
          ),
          const SizedBox(height: 18),

          // Care team
          _SectionLabel(label: 'Care Team'),
          const SizedBox(height: 10),
          PremiumCard(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('DR. BASHIR AHMAD', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 3),
                Text('CHIROPRACTIC SPECIALIST', style: GoogleFonts.poppins(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.statusConfirmedBg, borderRadius: BorderRadius.circular(10)),
                  child: Text('Primary Doctor', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.statusConfirmed)),
                ),
              ])),
            ]),
          ),
          const SizedBox(height: 18),

          // Treatment Plan Card
          if (_activePlanApt != null) ...[
            _SectionLabel(label: 'Treatment Plan Progress'),
            const SizedBox(height: 10),
            PremiumCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Care Plan: $_totalSessions Sessions',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          Text(
                            'Treatment Type: ${_activePlanApt!.treatmentType}',
                            style: GoogleFonts.poppins(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_totalSessions > 0 ? ((_completedSessions / _totalSessions) * 100).round() : 0}% Completed',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _totalSessions > 0 ? _completedSessions / _totalSessions : 0.0,
                      minHeight: 10,
                      backgroundColor: cs.primary.withValues(alpha: 0.1),
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Completed: $_completedSessions sessions',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface.withValues(alpha: 0.65)),
                      ),
                      Text(
                        'Remaining: ${(_totalSessions - _completedSessions).clamp(0, _totalSessions)} sessions',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface.withValues(alpha: 0.65)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Upcoming Sessions List
          if (_upcomingSessions.isNotEmpty) ...[
            _SectionLabel(label: 'Upcoming Sessions'),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _upcomingSessions.length,
              itemBuilder: (context, idx) {
                final apt = _upcomingSessions[idx];
                final dateStr = apt.scheduledAt != null ? DateFormat('EEE, d MMM y • hh:mm a').format(apt.scheduledAt!) : apt.time;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PremiumCard(
                    padding: const EdgeInsets.all(10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      leading: CircleAvatar(
                        backgroundColor: cs.primary.withValues(alpha: 0.1),
                        child: Icon(Icons.event_available_rounded, color: cs.primary, size: 20),
                      ),
                      title: Text(
                        apt.treatmentType,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Text(
                        dateStr,
                        style: GoogleFonts.poppins(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6)),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBgColor(apt.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          apt.status,
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor(apt.status)),
                        ),
                      ),
                      onTap: () => context.push('/appointment/${apt.id}').then((_) => _loadData()),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
          ],

          // Session History List
          if (_pastSessions.isNotEmpty) ...[
            _SectionLabel(label: 'Session History'),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pastSessions.length,
              itemBuilder: (context, idx) {
                final apt = _pastSessions[idx];
                final dateStr = apt.scheduledAt != null ? DateFormat('EEE, d MMM y • hh:mm a').format(apt.scheduledAt!) : apt.time;
                final isPlan = apt.treatmentPlanTotalSessions != null && apt.treatmentPlanTotalSessions! > 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PremiumCard(
                    padding: const EdgeInsets.all(10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      leading: CircleAvatar(
                        backgroundColor: statusBgColor(apt.status).withValues(alpha: 0.4),
                        child: Icon(
                          apt.status.toLowerCase() == 'completed'
                              ? Icons.check_circle_rounded
                              : (apt.status.toLowerCase() == 'no show' ? Icons.person_off_rounded : Icons.history_rounded),
                          color: statusColor(apt.status),
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              apt.treatmentType,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          if (isPlan)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.secondary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Session ${apt.sessionNumber ?? 1}',
                                style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w700, color: cs.secondary),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        dateStr,
                        style: GoogleFonts.poppins(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6)),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusBgColor(apt.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          apt.status,
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor(apt.status)),
                        ),
                      ),
                      onTap: () => context.push('/appointment/${apt.id}').then((_) => _loadData()),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
          ],

          // Preferences
          _SectionLabel(label: 'Preferences'),
          const SizedBox(height: 10),
          PremiumCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: [
              SwitchListTile.adaptive(
                value: themeMode == ThemeMode.dark,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggleTheme(),
                title: Text('Night Mode', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('Switch between light and dark themes', style: GoogleFonts.poppins(fontSize: 12)),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(themeMode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: cs.primary, size: 20),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.statusConfirmed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.analytics_rounded, color: AppColors.statusConfirmed, size: 20),
                ),
                title: Text('Analytics', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('View appointment statistics', style: GoogleFonts.poppins(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/analytics'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.statusPending.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.calculate_rounded, color: AppColors.statusPending, size: 20),
                ),
                title: Text('Treatment Calculator', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('Calculate treatment costs', style: GoogleFonts.poppins(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/calculator'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.security_rounded, color: cs.primary, size: 20),
                ),
                title: Text('Security & Lock', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('Configure PIN and fingerprint security', style: GoogleFonts.poppins(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/security-settings'),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFF4C958D).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.badge_rounded, color: Color(0xFF4C958D), size: 20),
                ),
                title: Text('Staff Portal Access', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('Manage staff credentials and access controls', style: GoogleFonts.poppins(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/staff-management'),
              ),
            ]),
          ),
          const SizedBox(height: 18),

          // Sign out
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: Icon(Icons.logout_rounded, size: 18, color: cs.error),
              label: Text('Sign Out', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: cs.error)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: cs.error.withValues(alpha: 0.5)), foregroundColor: cs.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700));
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value, required this.color});
  final String label, value; final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(children: [
          Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: color.withValues(alpha: 0.8))),
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon; final String label, value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.4)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
      ])),
    ]);
  }
}
