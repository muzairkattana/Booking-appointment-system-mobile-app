import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/appointments/booking_screen.dart';
import '../features/appointments/appointments_list_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/calculator/calculator_screen.dart';
import '../features/care_tips/care_tips_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/notes/clinical_notes_screen.dart';
import '../features/patient/profile_screen.dart';
import '../features/payments/payment_screen.dart';
import '../features/appointments/appointment_detail_screen.dart';

import '../features/auth/screens/splash_entry_screen.dart';
import '../features/auth/screens/security_settings_screen.dart';
import '../features/auth/screens/security_lock_screen.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/',
    routes: <GoRoute>[
      GoRoute(path: '/', name: 'splash', builder: (context, state) => const SplashEntryScreen()),
      GoRoute(path: '/login', name: 'login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/dashboard', name: 'dashboard', builder: (context, state) => const DashboardScreen()),
      GoRoute(path: '/profile', name: 'profile', builder: (context, state) => const PatientProfileScreen()),
      GoRoute(path: '/booking', name: 'booking', builder: (context, state) => const BookingScreen()),
      GoRoute(path: '/appointments', name: 'appointments', builder: (context, state) => const AppointmentsListScreen()),
      GoRoute(path: '/analytics', name: 'analytics', builder: (context, state) => const AnalyticsScreen()),
      GoRoute(path: '/payments', name: 'payments', builder: (context, state) => const PaymentScreen()),
      GoRoute(path: '/calculator', name: 'calculator', builder: (context, state) => const CalculatorScreen()),
      GoRoute(path: '/notes', name: 'notes', builder: (context, state) => const ClinicalNotesScreen()),
      GoRoute(path: '/care-tips', name: 'careTips', builder: (context, state) => const CareTipsScreen()),
      GoRoute(path: '/security-settings', name: 'securitySettings', builder: (context, state) => const SecuritySettingsScreen()),
      GoRoute(path: '/security-lock', name: 'securityLock', builder: (context, state) => const SecurityLockScreen()),
      GoRoute(
        path: '/appointment/:id',
        name: 'appointmentDetail',
        builder: (context, state) => AppointmentDetailScreen(id: state.pathParameters['id']!),
      ),
    ],
  );
});
