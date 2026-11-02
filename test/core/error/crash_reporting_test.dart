import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/crash_reporting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialization and app body share the guarded zone in order', () async {
    final events = <String>[];
    Zone? initializationZone;
    Zone? bodyZone;

    await CrashReporting.runGuarded(
      () async {
        events.add('body');
        bodyZone = Zone.current;
      },
      initialize: () async {
        events.add('initialize');
        initializationZone = Zone.current;
      },
    );

    expect(events, <String>['initialize', 'body']);
    expect(initializationZone, isNotNull);
    expect(bodyZone, same(initializationZone));
  });
}
