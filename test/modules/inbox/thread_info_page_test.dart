import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/modules/customers/customers.dart';
import 'package:omni_app/modules/inbox/application/inbox_providers.dart';
import 'package:omni_app/modules/opportunities/opportunities.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/presentation/thread_info_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Trang Thông tin hội thoại (GĐ3 · T9) — thay sheet ngữ cảnh cũ. Giữ lại ca
/// "workspace tắt module Cơ hội thì không mời tạo" (MS-I33).
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const baseCustomer = Customer(
    id: 'k1',
    name: 'Thuý Phạm',
    phone: '0912345468',
    source: Channel.zalo,
  );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  ProviderScope scope({
    required Map<String, bool> features,
    required Set<String> permissions,
    required Widget home,
    Customer? customer,
    String status = 'open',
  }) {
    return ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(
          Session(
            status: SessionStatus.authenticated,
            user: const SessionUser(id: 'u1', fullName: 'Kiệt', email: 'k@x'),
            tenant: const SessionTenant(id: 't1', name: 'Xưởng'),
            policy: AccessPolicy(permissions),
            features: features,
          ),
        ),
        conversationProvider('c1').overrideWith(
          (ref) async => Conversation(
            id: 'c1',
            channel: Channel.zalo,
            status: ConversationStatus.parse(status),
            customerId: customer?.id,
            customerName: 'Thuý Phạm',
            lastMessage: 'Còn đàn không',
            sourceName: 'Zalo OA · Trung Nguyên',
            tags: const ['Đặt lịch'],
          ),
        ),
        // Không gọi mạng thật: danh mục giai đoạn chưa về.
        pipelineCatalogProvider.overrideWith(
          (ref) => Completer<PipelineCatalog>().future,
        ),
        if (customer != null)
          customerProvider('k1').overrideWith((ref) async => customer),
        conversationContextProvider(
          'c1',
        ).overrideWith((ref) async => const ConversationContext()),
        conversationAssetsProvider(
          'c1',
        ).overrideWith((ref) async => const ConversationAssets()),
      ],
      child: MaterialApp(home: home),
    );
  }

  Future<void> pump(
    WidgetTester tester,
    Map<String, bool> features, {
    Customer? customer,
    Set<String> permissions = const {'inbox.read', 'inbox.write'},
    String status = 'open',
  }) async {
    tall(tester);
    await tester.pumpWidget(
      scope(
        features: features,
        permissions: permissions,
        customer: customer,
        status: status,
        home: const ThreadInfoPage(conversationId: 'c1'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpPushed(
    WidgetTester tester, {
    required ValueChanged<ThreadInfoResult?> onResult,
  }) async {
    tall(tester);
    await tester.pumpWidget(
      scope(
        features: const {},
        permissions: const {'inbox.read', 'inbox.write'},
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await Navigator.of(context)
                    .push<ThreadInfoResult>(
                      MaterialPageRoute(
                        builder: (_) =>
                            const ThreadInfoPage(conversationId: 'c1'),
                      ),
                    );
                onResult(result);
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  testWidgets('đủ mục theo thiết kế, không có mục API chưa hỗ trợ', (
    tester,
  ) async {
    await pump(tester, const {'opportunities': true});
    expect(find.text('Thông tin'), findsOneWidget);
    expect(find.text('Tìm tin'), findsOneWidget);
    expect(find.text('Phụ trách'), findsOneWidget);
    expect(find.text('Nhãn'), findsOneWidget);
    expect(find.text('Đặt lịch'), findsOneWidget);
    expect(find.text('Lưu trữ hội thoại'), findsOneWidget);
    for (final l in ['Tắt TB', 'Ghim hội thoại', 'Chặn khách này']) {
      expect(find.text(l), findsNothing);
    }
  });

  testWidgets('cơ hội bật: có Tạo cơ hội; tắt: không có thẻ Bán hàng', (
    tester,
  ) async {
    await pump(tester, const {'opportunities': true});
    expect(find.text('Tạo cơ hội'), findsOneWidget);
    expect(find.text('BÁN HÀNG'), findsOneWidget);
    await pump(tester, const {'opportunities': false});
    expect(find.text('Tạo cơ hội'), findsNothing);
    expect(find.text('BÁN HÀNG'), findsNothing);
  });

  testWidgets('chưa gắn khách: không Gọi, có Chuyển KH', (tester) async {
    await pump(tester, const {});
    expect(find.text('Gọi'), findsNothing);
    expect(find.text('Chuyển KH'), findsOneWidget);
  });

  testWidgets('đã gắn khách có số: Gọi + số điện thoại hiện', (tester) async {
    await pump(tester, const {}, customer: baseCustomer);
    expect(find.text('Gọi'), findsOneWidget);
    expect(find.text('0912345468'), findsOneWidget);
    expect(find.text('Hồ sơ'), findsOneWidget);
    expect(find.text('Chuyển KH'), findsNothing);
  });

  testWidgets('chỉ inbox.read: không có Lưu trữ', (tester) async {
    await pump(tester, const {}, permissions: const {'inbox.read'});
    expect(find.text('Lưu trữ hội thoại'), findsNothing);
  });

  testWidgets('hội thoại đã đóng: hiện Mở lại hội thoại', (tester) async {
    await pump(tester, const {}, status: 'closed');
    expect(find.text('Mở lại hội thoại'), findsOneWidget);
    expect(find.text('Lưu trữ hội thoại'), findsNothing);
  });

  testWidgets('Tìm tin → pop với ThreadInfoResult.search', (tester) async {
    ThreadInfoResult? result;
    await pumpPushed(tester, onResult: (r) => result = r);
    await tester.tap(find.text('Tìm tin'));
    await tester.pumpAndSettle();
    expect(result, ThreadInfoResult.search);
  });

  testWidgets('tab Ảnh · Tệp · Link có số đếm', (tester) async {
    await pump(tester, const {});
    expect(find.text('Ảnh · 0'), findsOneWidget);
    expect(find.text('Tệp · 0'), findsOneWidget);
    expect(find.text('Link · 0'), findsOneWidget);
  });

  testWidgets('máy hẹp 320: không tràn', (tester) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      scope(
        features: const {'opportunities': true},
        permissions: const {'inbox.read', 'inbox.write'},
        customer: baseCustomer,
        home: const ThreadInfoPage(conversationId: 'c1'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Thuý Phạm'), findsWidgets);
  });

  testWidgets('giảm chuyển động: hiện ngay không cần chờ', (tester) async {
    tall(tester);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          disableAnimations: true,
          size: Size(400, 2400),
        ),
        child: scope(
          features: const {},
          permissions: const {'inbox.read', 'inbox.write'},
          home: const ThreadInfoPage(conversationId: 'c1'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final opacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.text('Lưu trữ hội thoại'),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity.opacity, 1);
  });
}
