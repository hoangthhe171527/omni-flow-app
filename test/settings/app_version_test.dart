import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';

void main() {
  test('AppConfig.appVersion khớp version trong pubspec.yaml', () {
    final line = File(
      'pubspec.yaml',
    ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final name = line.split(':')[1].trim().split('+').first;
    expect(AppConfig.appVersion, name);
  });
}
