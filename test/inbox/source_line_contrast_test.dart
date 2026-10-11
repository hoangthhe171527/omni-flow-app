import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/design/components/omni_pills.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/application/inbox_providers.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/presentation/thread_info_page.dart';
import 'package:omni_app/modules/opportunities/opportunities.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/thread_intro.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Dòng nguồn kênh (chữ "Zalo OA"…) phải dùng màu chữ theo chế độ, không dùng
/// màu thương hiệu thô `meta.color` (mờ trên nền tối).
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  Widget host(Widget child, Brightness b) => ProviderScope(
    overrides: [
      sessionProvider.overrideWithValue(
        Session(
          status: SessionStatus.authenticated,
          user: const SessionUser(id: 'u1', fullName: 'Kiệt', email: 'k@x.vn'),
          tenant: const SessionTenant(id: 't1', name: 'Xưởng'),
          policy: AccessPolicy(const {'inbox.read', 'inbox.write'}),
        ),
      ),
    ],
    child: MaterialApp(
      theme: b == Brightness.dark
          ? OmniTheme.dark(TargetPlatform.android)
          : OmniTheme.light(TargetPlatform.android),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets('ThreadIntro: dòng nguồn dùng textColorOf(tối)', (t) async {
    for (final channel in Channel.values) {
      final meta = channel.meta;
      await t.pumpWidget(
        host(
          ThreadIntro(
            conversation: Conversation(
              id: 'c1',
              channel: channel,
              status: ConversationStatus.open,
              customerName: 'Thuý Phạm',
            ),
          ),
          Brightness.dark,
        ),
      );
      await t.pumpAndSettle();
      final text = t.widget<Text>(find.text(channel.sourceKind).first);
      expect(
        text.style?.color,
        meta.textColorOf(Brightness.dark),
        reason: '$channel',
      );
    }
  });

  testWidgets('OmniSourcePill: chữ dùng textColorOf(tối)', (t) async {
    for (final channel in Channel.values) {
      await t.pumpWidget(
        host(OmniSourcePill(channel: channel), Brightness.dark),
      );
      await t.pumpAndSettle();
      final text = t.widget<Text>(find.byType(Text).first);
      expect(
        text.style?.color,
        channel.meta.textColorOf(Brightness.dark),
        reason: '$channel',
      );
    }
  });

  testWidgets('ThreadInfoPage: dòng nguồn dùng textColorOf(tối)', (t) async {
    t.view.physicalSize = const Size(400, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    const channel = Channel.zalo;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(
            Session(
              status: SessionStatus.authenticated,
              user: const SessionUser(
                id: 'u1',
                fullName: 'Kiệt',
                email: 'k@x.vn',
              ),
              tenant: const SessionTenant(id: 't1', name: 'Xưởng'),
              policy: AccessPolicy(const {'inbox.read', 'inbox.write'}),
            ),
          ),
          conversationProvider('c1').overrideWith(
            (ref) async => const Conversation(
              id: 'c1',
              channel: channel,
              status: ConversationStatus.open,
              customerName: 'Thuý Phạm',
              sourceName: 'Zalo OA · Trung Nguyên',
            ),
          ),
          pipelineCatalogProvider.overrideWith(
            (ref) => Completer<PipelineCatalog>().future,
          ),
          conversationContextProvider(
            'c1',
          ).overrideWith((ref) async => const ConversationContext()),
          conversationAssetsProvider(
            'c1',
          ).overrideWith((ref) async => const ConversationAssets()),
        ],
        child: MaterialApp(
          theme: OmniTheme.dark(TargetPlatform.android),
          home: const ThreadInfoPage(conversationId: 'c1'),
        ),
      ),
    );
    await t.pumpAndSettle();

    final colors = <Color?>[];
    for (final w in t.widgetList<RichText>(find.byType(RichText))) {
      w.text.visitChildren((span) {
        if (span is TextSpan && span.text == channel.sourceKind) {
          colors.add(span.style?.color);
        }
        return true;
      });
    }
    expect(colors, [channel.meta.textColorOf(Brightness.dark)]);
  });
}
