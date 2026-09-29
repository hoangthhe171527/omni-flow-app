import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
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

    final summary = tester.widget<Text>(find.text('Đang giữ 1 quyền'));
    expect(summary.style!.color, OmniColors.orbit);
    expect(find.text('Hộp thư'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.remove_circle_outline_rounded), findsOneWidget);
  });
}
