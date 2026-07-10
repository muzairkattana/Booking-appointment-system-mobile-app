import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'src/screens/staff_login_screen.dart';
import 'src/screens/staff_appointments_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }
  
  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('is_staff_logged_in') ?? false;
  final staffEmail = prefs.getString('logged_in_staff_email') ?? '';

  runApp(StaffApp(
    isLoggedIn: isLoggedIn && staffEmail.isNotEmpty,
    staffEmail: staffEmail,
  ));
}

class StaffApp extends StatelessWidget {
  final bool isLoggedIn;
  final String staffEmail;

  const StaffApp({
    super.key,
    required this.isLoggedIn,
    required this.staffEmail,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GCT Staff Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E7490),
          primary: const Color(0xFF0E7490),
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: isLoggedIn
          ? StaffAppointmentsScreen(staffEmail: staffEmail)
          : const StaffLoginScreen(),
    );
  }
}
