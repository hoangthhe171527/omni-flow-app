import 'package:flutter/material.dart';

import 'bootstrap.dart';
import 'core/error/crash_reporting.dart';
import 'modules/notifications/application/push_notifications.dart';

Future<void> main() async {
  // FCM needs its background handler registered before runApp. Otherwise a
  // data-bearing push received while Android starts a killed app can be lost.
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializePushRuntime();
  } catch (_) {
    // A build without Firebase configuration must still be able to open.
    // `PushNotifications.start` retries after the user has authenticated.
  }

  // Everything after this point runs inside the guarded zone, so a failure in
  // bootstrap() is reported rather than becoming a blank screen nobody can
  // explain. Push initialisation stays outside it deliberately: it has to
  // complete before runApp, and it already handles its own absence.
  await CrashReporting.runGuarded(() async {
    runApp(await bootstrap());
  });
}
