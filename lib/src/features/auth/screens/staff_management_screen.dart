import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../shared/widgets/app_shell_scaffold.dart';
import '../../shared/widgets/premium_card.dart';
import '../../../theme/app_theme.dart';
import '../auth_providers.dart';

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  bool _allowStaffView = true;
  List<Map<String, String>> _staffList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authRepo = ref.read(authRepositoryProvider);
    final toggle = await authRepo.getStaffViewToggle();
    final list = await authRepo.loadStaffCredentials();
    if (!mounted) return;
    setState(() {
      _allowStaffView = toggle;
      _staffList = list;
      _isLoading = false;
    });
  }

  Future<void> _toggleAccess(bool value) async {
    setState(() => _allowStaffView = value);
    await ref.read(authRepositoryProvider).setStaffViewToggle(value);
    _showSnackBar(value ? 'Staff access enabled. Appointments can be viewed online.' : 'Staff access disabled. Appointments hidden.');
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _addOrEditStaff({Map<String, String>? existingStaff}) async {
    final isEdit = existingStaff != null;
    final emailController = TextEditingController(text: existingStaff?['email'] ?? '');
    final passwordController = TextEditingController(text: existingStaff?['password'] ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Text(
            isEdit ? 'Edit Staff Credentials' : 'Add Staff Member',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isEdit) ...[
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Staff Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'receptionist@gct.com',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Email is required';
                      if (!val.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Text(
                    'Editing: ${existingStaff['email']}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: cs.primary),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                    hintText: 'Enter secure password',
                  ),
                  obscureText: true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Password is required';
                    if (val.trim().length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.poppins(color: cs.onSurface.withValues(alpha: 0.6))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(ctx);
                
                final email = emailController.text.trim();
                final password = passwordController.text.trim();
                
                setState(() => _isLoading = true);
                try {
                  await ref.read(authRepositoryProvider).addStaffCredential(email, password);
                  _showSnackBar(isEdit ? 'Staff credentials updated.' : 'Staff member added successfully!');
                  await _loadData();
                } catch (e) {
                  _showSnackBar('Operation failed: $e', isError: true);
                  setState(() => _isLoading = false);
                }
              },
              child: Text(isEdit ? 'Save Changes' : 'Create Account'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteStaff(String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Staff Account', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to delete credentials for $email? They will no longer be able to log in.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).deleteStaffCredential(email);
      _showSnackBar('Staff account deleted.');
      await _loadData();
    } catch (e) {
      _showSnackBar('Delete failed: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AppShellScaffold(
      title: 'Staff Portal Settings',
      currentRoute: '/profile',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                // Top Intro Card
                PremiumCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.people_alt_rounded, color: cs.primary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Staff Portal Control',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface),
                            ),
                            Text(
                              'Manage staff credentials and toggle appointments access for the separate Staff App.',
                              style: GoogleFonts.poppins(fontSize: 11.5, color: cs.onSurface.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Access Switch
                Text(
                  'APPOINTMENTS ACCESS STATUS',
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary, letterSpacing: 0.5),
                ),
                const SizedBox(height: 10),
                PremiumCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SwitchListTile.adaptive(
                    value: _allowStaffView,
                    onChanged: _toggleAccess,
                    title: Text('Allow Staff to View Bookings', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('Enable or disable appointment listing on the Staff App.', style: GoogleFonts.poppins(fontSize: 12)),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (_allowStaffView ? cs.primary : Colors.grey).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _allowStaffView ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        color: _allowStaffView ? cs.primary : Colors.grey,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Credentials Management list header
                Row(
                  mainAxisAlignment: MainAxisAlignment.between,
                  children: [
                    Text(
                      'STAFF LOGIN ACCOUNTS',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary, letterSpacing: 0.5),
                    ),
                    TextButton.icon(
                      onPressed: () => _addOrEditStaff(),
                      icon: const Icon(Icons.add, size: 16),
                      label: Text('Add Account', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Staff accounts list
                if (_staffList.isEmpty)
                  PremiumCard(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.badge_outlined, size: 40, color: cs.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'No Staff Accounts Added',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface.withValues(alpha: 0.7)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Add staff logins so they can access the appointment reminders on their devices.',
                          style: GoogleFonts.poppins(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  PremiumCard(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _staffList.length,
                      separatorBuilder: (ctx, i) => const Divider(indent: 16, endIndent: 16),
                      itemBuilder: (ctx, index) {
                        final staff = _staffList[index];
                        final email = staff['email'] ?? '';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cs.primary.withValues(alpha: 0.1),
                            child: Icon(Icons.person_outline_rounded, color: cs.primary, size: 20),
                          ),
                          title: Text(
                            email,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Access: Appointments only',
                            style: GoogleFonts.poppins(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Edit Password',
                                onPressed: () => _addOrEditStaff(existingStaff: staff),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, size: 20, color: cs.error),
                                tooltip: 'Delete Account',
                                onPressed: () => _deleteStaff(email),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
