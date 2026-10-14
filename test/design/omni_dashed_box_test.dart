import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

void main() {
  testWidgets('OmniDashedBox: cao theo height, rộng theo cha, vẽ được', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const Center(
          child: SizedBox(width: 200, child: OmniDashedBox(height: 64)),
        ),
      ),
    );

    expect(tester.getSize(find.byType(OmniDashedBox)), const Size(200, 64));
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
