import 'package:flutter_test/flutter_test.dart';
import 'package:gct/src/services/app_bootstrap.dart';

void main() {
  test('initializeFirebase returns false when Firebase initialization fails', () async {
    final bootstrap = AppBootstrapService(
      firebaseInitializer: () async => throw Exception('boom'),
      notificationInitializer: () async {},
      onError: (error, stackTrace) {},
    );

    expect(await bootstrap.initializeFirebase(), isFalse);
  });

  test('initializeAppServices completes even when notifications fail', () async {
    final bootstrap = AppBootstrapService(
      firebaseInitializer: () async {},
      notificationInitializer: () async => throw Exception('notifications failed'),
      onError: (error, stackTrace) {},
    );

    await expectLater(
      bootstrap.initializeAppServices(runNotificationsInBackground: false),
      completes,
    );
  });

  test('initializeAppServices runs auth and storage initializers after Firebase', () async {
    var firebaseCalls = 0;
    var authCalls = 0;
    var storageCalls = 0;

    final bootstrap = AppBootstrapService(
      firebaseInitializer: () async {
        firebaseCalls++;
      },
      authInitializer: () async {
        authCalls++;
      },
      storageInitializer: () async {
        storageCalls++;
      },
      notificationInitializer: () async {},
      onError: (error, stackTrace) {},
    );

    await bootstrap.initializeAppServices(runNotificationsInBackground: false);

    expect(firebaseCalls, 1);
    expect(authCalls, 1);
    expect(storageCalls, 1);
  });
}
