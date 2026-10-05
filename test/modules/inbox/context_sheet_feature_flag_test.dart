import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/modules/inbox/application/inbox_providers.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/conversation_context_sheet.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Fix vòng 1 (M8, chốt P5 — MS-I33): workspace tắt module Cơ hội thì sheet
/// ngữ cảnh hội thoại không còn nút "Tạo cơ hội".
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  Future<void> pump(WidgetTester tester, Map<String, bool> features) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(
            Session(
              status: SessionStatus.authenticated,
              user: const SessionUser(id: 'u1', fullName: 'Kiệt', email: 'k@x'),
              tenant: const SessionTenant(id: 't1', name: 'Xưởng'),
              policy: const AccessPolicy({'inbox.read', 'inbox.write'}),
              features: features,
            ),
          ),
          conversationProvider('c1').overrideWith(
            (ref) async => const Conversation(
              id: 'c1',
              channel: Channel.zalo,
              status: ConversationStatus.open,
              customerName: 'Thuý Phạm',
              lastMessage: 'Còn đàn không',
              unread: 0,
            ),
          ),
          conversationContextProvider(
            'c1',
          ).overrideWith((ref) async => const ConversationContext()),
          conversationAssetsProvider(
            'c1',
          ).overrideWith((ref) async => const ConversationAssets()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ConversationContextSheet(conversationId: 'c1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cơ hội bật: có nút Tạo cơ hội', (tester) async {
    await pump(tester, const {});

    expect(find.text('Tạo cơ hội'), findsOneWidget);
  });

  testWidgets('cơ hội tắt: không có nút Tạo cơ hội', (tester) async {
    await pump(tester, const {'opportunities': false});

    expect(find.text('Thuý Phạm'), findsWidgets);
    expect(find.text('Tạo cơ hội'), findsNothing);
  });
}
