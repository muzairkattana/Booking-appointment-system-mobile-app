import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/auth/auth_providers.dart';
import '../../services/app_preferences.dart';
import '../../models/app_user.dart';
import '../shared/widgets/app_shell_scaffold.dart';
import '../shared/widgets/premium_card.dart';
import '../../theme/theme_mode_provider.dart';
import '../../theme/app_theme.dart';
import '../appointments/appointment_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await AppPreferences.instance.prefs;
    final path = prefs.getString('doctor_profile_image');
    final apts = await ref.read(appointmentRepositoryProvider).loadAppointments();
    final now = DateTime.now();
    final upcoming = apts.where((a) => a.scheduledAt != null && a.scheduledAt!.isAfter(now) && a.status.toLowerCase() != 'cancelled').length;
    if (!mounted) return;
    setState(() {
      _imagePath = path;
      _totalAppointments = apts.length;
      _upcomingAppointments = upcoming;
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
