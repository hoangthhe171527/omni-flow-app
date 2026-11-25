import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/hr/application/hr_providers.dart';
import 'package:omni_app/modules/hr/domain/hr_models.dart';
import 'package:omni_app/modules/hr/presentation/approvals_page.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../../support/fixed_background.dart';

void main() {
  testWidgets('chạm đơn chờ mở sheet chi tiết có Từ chối / Duyệt', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(
            const Session(
              status: SessionStatus.authenticated,
              policy: AccessPolicy({'hr.requests.approve'}),
            ),
          ),
          backgroundProvider.overrideWith(FixedBackground.new),
          hrApprovalsProvider.overrideWith(
            (_) async => [
              HrRequest.fromJson({
                'id': 'a1',
                'name': 'Vũ Văn Hoàng',
                'type': 'phep',
                'status': 'cho',
                'from': '2026-11-28',
                'to': '2026-11-28',
                'reason': 'Về quê',
                'created_at': '2026-11-24T00:40:00Z',
              }),
            ],
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(),
          home: const ApprovalsPage(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('Chờ duyệt 1'), findsOneWidget);

    await t.tap(find.text('Vũ Văn Hoàng'));
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
    expect(find.text('Duyệt'), findsOneWidget);
    expect(find.text('Từ chối'), findsOneWidget);
    expect(find.text('Về quê'), findsOneWidget);
  });
}
