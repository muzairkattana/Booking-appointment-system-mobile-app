Setup Firebase Cloud Messaging (FCM) and Local Notifications

1) Firebase project
- Create a Firebase project at https://console.firebase.google.com
- Add Android and/or iOS apps. For Android, you'll need your `applicationId` (package name) from `android/app/build.gradle.kts`.

2) Android setup
- Download `google-services.json` and place it under `android/app/`.
- In `android/build.gradle.kts` add classpath for google services (if using Gradle Kotlin DSL) and apply plugin in `android/app/build.gradle.kts`:

```kotlin
plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
}
```
- Add the Firebase BOM or individual dependencies if needed.
- Ensure `minSdkVersion >= 21` for firebase_messaging.

3) iOS setup
- Download `GoogleService-Info.plist` and add to Xcode Runner target.
- Place the file at `ios/Runner/GoogleService-Info.plist`.
- Enable Push Notifications and Background Modes (Remote notifications) in Xcode capabilities.

4) Flutter side
- Run `flutter pub get` to install packages.
- Ensure `Firebase.initializeApp()` is called early (done in `main.dart`).
- To test push notifications, obtain device token via `NotificationService().getDeviceToken()` and send a message from Firebase console or server.

5) Local notifications
- `flutter_local_notifications` is used to show incoming foreground messages.
- You can customize channels, icons, and actions.

6) Notes and caveats
- Background message handling requires a top-level function (`_firebaseBackgroundHandler`) and minimal logic.
- For production, handle navigation and deep linking from `onMessageOpenedApp` and notification tap callbacks.

Commands to run locally:

```powershell
flutter pub get
flutter run -d <device-id>
```

Testing tips:
- Use Firebase console "Send test message" with the FCM token from a device.
- Verify foreground notifications appear as local notifications.
- Verify background/terminated notifications show via OS tray.
