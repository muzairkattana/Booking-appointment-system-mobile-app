import 'package:flutter_test/flutter_test.dart';
import 'package:gct/src/features/auth/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers and signs in locally', () async {
    SharedPreferences.setMockInitialValues({});

    final repository = AuthRepository();
    final user = await repository.registerWithEmail(
      name: 'Test User',
      email: 'test@example.com',
      password: 'secret123',
    );

    expect(user.email, 'test@example.com');

    final signedInUser = await repository.signInWithEmail(
      email: 'test@example.com',
      password: 'secret123',
    );

    expect(signedInUser.displayName, 'Test User');
    expect(repository.currentUser?.email, 'test@example.com');
  });
}
