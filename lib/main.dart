import 'package:flutter/material.dart';

import 'bootstrap.dart';
import 'core/error/crash_reporting.dart';
import 'modules/notifications/application/push_notifications.dart';

Future<void> main() async {
  await CrashReporting.runGuarded(
    () async {
      runApp(await bootstrap());
    },
    initialize: () async {
      // Flutter bindings and runApp must be created in the same zone. FCM still
      // registers before runApp so a data push that wakes a killed app is not
      // lost, while Crashlytics can start after Firebase is available.
      WidgetsFlutterBinding.ensureInitialized();
      try {
        await initializePushRuntime();
      } catch (_) {
        // A build without Firebase configuration must still be able to open.
        // `PushNotifications.start` retries after authentication.
      }
    },
  );
}
