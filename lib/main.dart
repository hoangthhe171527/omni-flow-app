import 'package:flutter/material.dart';

import 'bootstrap.dart';
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
  runApp(await bootstrap());
}
