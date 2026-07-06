import 'package:flutter_test/flutter_test.dart';
import 'package:gct/src/features/appointments/appointment_repository.dart';
import 'package:gct/src/models/appointment.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stores and loads appointments locally', () async {
    SharedPreferences.setMockInitialValues({});

    final repository = AppointmentRepository();
    await repository.saveAppointment(
      Appointment(
        id: 'apt-1',
        patientName: 'Ayesha Khan',
        time: 'Tomorrow · 09:00 AM',
        treatmentType: 'Gonstead Adjustment',
        status: 'Pending',
      ),
    );

    final appointments = await repository.loadAppointments();
    expect(appointments, hasLength(1));
    expect(appointments.first.patientName, 'Ayesha Khan');
  });
}
