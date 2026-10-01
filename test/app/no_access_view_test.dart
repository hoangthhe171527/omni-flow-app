import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/router/access_boundary.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/security/guard/access_requirement.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

void main() {
  Widget app(Widget home) => ProviderScope(
    overrides: [accessProvider.overrideWithValue(const AccessPolicy({}))],
    child: MaterialApp(theme: OmniTheme.light(), home: home),
  );

  const guarded = AccessBoundary(
    requirement: AccessRequirement.any(['crm.customers.read']),
    child: Text('màn thật'),
  );

  testWidgets('thiếu quyền: nói rõ quyền nào, không lộ màn thật', (
    tester,
  ) async {
    await tester.pumpWidget(app(guarded));

    expect(find.text('màn thật'), findsNothing);
    expect(find.text('Bạn không có quyền xem mục này'), findsOneWidget);
    expect(
      find.textContaining('crm.customers.read', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('màn gốc không có chỗ để quay lại thì không có nút', (
    tester,
  ) async {
    await tester.pumpWidget(app(guarded));

    expect(find.text('Quay lại'), findsNothing);
  });

  testWidgets('màn đẩy vào có nút "Quay lại" và nút đó quay lại thật', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => guarded)),
            child: const Text('mở'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quay lại'));
    await tester.pumpAndSettle();

    expect(find.text('mở'), findsOneWidget);
  });

  testWidgets('cần đủ nhiều quyền thì câu nói "và", cần một thì nói "hoặc"', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const AccessBoundary(
          requirement: AccessRequirement.all(['a.read', 'b.read']),
          child: SizedBox(),
        ),
      ),
    );
    expect(
      find.textContaining('a.read và b.read', findRichText: true),
      findsOneWidget,
    );

    await tester.pumpWidget(
      app(
        const AccessBoundary(
          requirement: AccessRequirement.any(['a.read', 'b.read']),
          child: SizedBox(),
        ),
      ),
    );
    expect(
      find.textContaining('a.read hoặc b.read', findRichText: true),
      findsOneWidget,
    );
  });
}
