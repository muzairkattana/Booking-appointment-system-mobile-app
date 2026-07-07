import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/appointments/appointment_repository.dart';
import '../features/payments/payment_repository.dart';
import '../features/notes/clinical_notes_repository.dart';

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return AppointmentRepository();
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository();
});

final clinicalNotesRepositoryProvider = Provider<ClinicalNotesRepository>((ref) {
  return ClinicalNotesRepository();
});
