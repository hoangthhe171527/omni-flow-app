import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/tokens/tokens.dart';

void main() {
  test('toàn app dùng Be Vietnam Pro', () {
    expect(OmniType.family, 'Be Vietnam Pro');
    expect(OmniType.displayLg.fontFamily, 'Be Vietnam Pro');
  });

  test('không còn tham chiếu font Inter trong lib/ và pubspec', () {
    final hits =
        [
              File('pubspec.yaml'),
              ...Directory('lib')
                  .listSync(recursive: true)
                  .whereType<File>()
                  .where((f) => f.path.endsWith('.dart')),
            ]
            .where((f) => RegExp(r'\bInter\b').hasMatch(f.readAsStringSync()))
            .map((f) => f.path)
            .toList();
    expect(hits, isEmpty);
  });
}
