import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/settings/presentation/my_permissions_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

void main() {
  testWidgets('Quyền của tôi: thẻ mực tóm tắt, quyền đang giữ có tick', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(
            const Session(
              status: SessionStatus.authenticated,
              user: SessionUser(id: 'u', fullName: 'Hoàng', email: 'h@x.vn'),
              policy: AccessPolicy({'inbox.read'}),
            ),
          ),
          declaredPermissionsProvider.overrideWithValue({
            'Hộp thư': ['inbox.read', 'inbox.write'],
          }),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const MyPermissionsPage(),
        ),
      ),
    );

    expect(find.text('Đang giữ'), findsOneWidget);
    expect(find.text('1 quyền'), findsOneWidget);
    expect(find.text('Hộp thư'), findsOneWidget);
    // Tên tiếng Việt thay mã thô.
    expect(find.text('Xem hộp thư'), findsOneWidget);
    expect(find.text('inbox.read'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.remove_circle_outline_rounded), findsOneWidget);
  });
}
