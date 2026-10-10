import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/customers/customers.dart';
import 'package:omni_app/modules/inbox/application/inbox_providers.dart';
import 'package:omni_app/modules/opportunities/opportunities.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/modules/inbox/inbox_routes.dart';
import 'package:omni_app/modules/inbox/presentation/thread_info_page.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
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

  const rw = {'inbox.read', 'inbox.write'};
  const withCustomer = {...rw, CustomerPermissions.read};
  const withOpp = {...rw, OpportunityPermissions.create};

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
    InboxApi? api,
    bool contextFails = false,
  }) {
    return ProviderScope(
      overrides: [
        if (api != null) inboxApiProvider.overrideWithValue(api),
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
        conversationContextProvider('c1').overrideWith((ref) async {
          if (contextFails) throw Exception('offline');
          return const ConversationContext();
        }),
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
    InboxApi? api,
    bool contextFails = false,
  }) async {
    tall(tester);
    await tester.pumpWidget(
      scope(
        features: features,
        permissions: permissions,
        customer: customer,
        status: status,
        api: api,
        contextFails: contextFails,
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

  testWidgets('đủ mục theo thiết kế, gồm các mục Hộp thư mobile', (
    tester,
  ) async {
    await pump(tester, const {'opportunities': true});
    expect(find.text('Thông tin'), findsOneWidget);
    expect(find.text('Tìm tin'), findsOneWidget);
    expect(find.text('Phụ trách'), findsOneWidget);
    expect(find.text('Nhãn'), findsOneWidget);
    expect(find.text('Đặt lịch'), findsOneWidget);
    expect(find.text('Lưu trữ hội thoại'), findsOneWidget);
    for (final l in [
      'Tắt TB',
      'Ghim hội thoại',
      'Đánh dấu chưa đọc',
      'Chặn hội thoại',
    ]) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
  });

  testWidgets('cơ hội bật: có Tạo cơ hội; tắt: không có thẻ Bán hàng', (
    tester,
  ) async {
    await pump(tester, const {'opportunities': true}, permissions: withOpp);
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
    await pump(
      tester,
      const {},
      customer: baseCustomer,
      permissions: withCustomer,
    );
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

  testWidgets('Hồ sơ ẩn khi không có quyền đọc khách; hiện khi có', (
    tester,
  ) async {
    await pump(tester, const {}, customer: baseCustomer);
    expect(find.text('Hồ sơ'), findsNothing);
    expect(find.text('Chuyển KH'), findsNothing);
    await pump(
      tester,
      const {},
      customer: baseCustomer,
      permissions: withCustomer,
    );
    expect(find.text('Hồ sơ'), findsOneWidget);
  });

  testWidgets('Tạo cơ hội ẩn khi thiếu quyền tạo; thẻ Bán hàng ẩn theo', (
    tester,
  ) async {
    await pump(tester, const {'opportunities': true});
    expect(find.text('Tạo cơ hội'), findsNothing);
    expect(find.text('BÁN HÀNG'), findsNothing);
    await pump(tester, const {'opportunities': true}, permissions: withOpp);
    expect(find.text('Tạo cơ hội'), findsOneWidget);
  });

  testWidgets('lỗi tải cơ hội: báo lỗi + Thử lại, không mời Tạo cơ hội', (
    tester,
  ) async {
    await pump(
      tester,
      const {'opportunities': true},
      permissions: withOpp,
      contextFails: true,
    );
    expect(find.text('Không tải được cơ hội. Thử lại'), findsOneWidget);
    expect(find.text('Tạo cơ hội'), findsNothing);
  });

  testWidgets('Phụ trách và Nhãn không bấm được khi thiếu quyền', (
    tester,
  ) async {
    VoidCallback? onTapOf(String label) => tester
        .widget<InkWell>(
          find
              .ancestor(of: find.text(label), matching: find.byType(InkWell))
              .first,
        )
        .onTap;

    await pump(tester, const {}, permissions: const {'inbox.read'});
    expect(onTapOf('Phụ trách'), isNull);
    expect(onTapOf('Nhãn'), isNull);

    await pump(tester, const {});
    expect(onTapOf('Phụ trách'), isNotNull);
    expect(onTapOf('Nhãn'), isNotNull);
    await tester.tap(find.text('Nhãn'));
    await tester.pumpAndSettle();
    expect(find.text('Gắn nhãn'), findsOneWidget);
  });

  testWidgets('bấm Lưu trữ hội thoại → setStatus(closed)', (tester) async {
    final api = _RecordingApi();
    await pump(tester, const {}, api: api);
    await tester.tap(find.text('Lưu trữ hội thoại'));
    await tester.pumpAndSettle();
    expect(api.statuses, [('c1', ConversationStatus.closed)]);
  });

  testWidgets('bấm Mở lại hội thoại → setStatus(open)', (tester) async {
    final api = _RecordingApi();
    await pump(tester, const {}, api: api, status: 'closed');
    await tester.tap(find.text('Mở lại hội thoại'));
    await tester.pumpAndSettle();
    expect(api.statuses, [('c1', ConversationStatus.open)]);
  });

  group('Hộp thư mobile: tắt TB · ghim · chưa đọc · chặn', () {
    Conversation base({
      bool pinned = false,
      bool muted = false,
      DateTime? blockedAt,
      int unread = 0,
    }) => Conversation(
      id: 'c1',
      channel: Channel.zalo,
      status: ConversationStatus.open,
      customerName: 'Thuý Phạm',
      lastMessage: 'Còn đàn không',
      sourceName: 'Zalo OA · Trung Nguyên',
      unread: unread,
      isPinned: pinned,
      isMuted: muted,
      blockedAt: blockedAt,
    );

    /// Trang Thông tin trong GoRouter thật (cần cho "về Hộp thư"), hội thoại
    /// lấy từ [api] — nên `invalidate` sau thao tác dựng lại theo "server".
    Future<void> pumpRouted(
      WidgetTester tester,
      _RecordingApi api, {
      Set<String> permissions = const {'inbox.read', 'inbox.write'},
      bool dark = false,
    }) async {
      tall(tester);
      final router = GoRouter(
        initialLocation: '/inbox/c1/info',
        routes: [
          GoRoute(
            name: InboxRoutes.list,
            path: InboxRoutes.listPath,
            builder: (_, _) => const Scaffold(body: Text('HỘP THƯ')),
            routes: [
              GoRoute(
                path: ':id/info',
                builder: (_, state) =>
                    ThreadInfoPage(conversationId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            inboxApiProvider.overrideWithValue(api),
            sessionProvider.overrideWithValue(
              Session(
                status: SessionStatus.authenticated,
                user: const SessionUser(
                  id: 'u1',
                  fullName: 'Kiệt',
                  email: 'k@x',
                ),
                tenant: const SessionTenant(id: 't1', name: 'Xưởng'),
                policy: AccessPolicy(permissions),
              ),
            ),
            conversationProvider('c1').overrideWith((ref) async => api.current),
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
          child: MaterialApp.router(
            theme: dark
                ? OmniTheme.dark(TargetPlatform.android)
                : OmniTheme.light(TargetPlatform.android),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('có Tắt TB, Ghim hội thoại, Chưa đọc, Chặn hội thoại', (
      tester,
    ) async {
      final api = _RecordingApi()..current = base();
      await pumpRouted(tester, api);
      expect(find.text('Tắt TB'), findsOneWidget);
      expect(find.text('Ghim hội thoại'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.text('Đánh dấu chưa đọc'), findsOneWidget);
      expect(find.text('Chặn hội thoại'), findsOneWidget);
    });

    testWidgets('sale .own: có Ghim + Tắt TB + Chưa đọc, KHÔNG có Chặn', (
      tester,
    ) async {
      final api = _RecordingApi()..current = base();
      await pumpRouted(
        tester,
        api,
        permissions: const {'inbox.read.own', 'inbox.write'},
      );
      expect(find.text('Ghim hội thoại'), findsOneWidget);
      expect(find.text('Tắt TB'), findsOneWidget);
      expect(find.text('Đánh dấu chưa đọc'), findsOneWidget);
      expect(find.text('Chặn hội thoại'), findsNothing);
    });

    testWidgets('chỉ inbox.read: Ghim + Tắt TB; không Chưa đọc/Chặn/Lưu trữ', (
      tester,
    ) async {
      final api = _RecordingApi()..current = base();
      await pumpRouted(tester, api, permissions: const {'inbox.read'});
      expect(find.text('Ghim hội thoại'), findsOneWidget);
      expect(find.text('Tắt TB'), findsOneWidget);
      expect(find.text('Đánh dấu chưa đọc'), findsNothing);
      expect(find.text('Chặn hội thoại'), findsNothing);
      expect(find.text('Lưu trữ hội thoại'), findsNothing);
    });

    testWidgets('công tắc Ghim: POST rồi DELETE, đổi theo phản hồi', (
      tester,
    ) async {
      final api = _RecordingApi()..current = base();
      await pumpRouted(tester, api);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      await tester.tap(find.text('Ghim hội thoại'));
      await tester.pumpAndSettle();
      expect(api.pins, [true]);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(api.pins, [true, false]);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('công tắc Ghim không đổi trước khi server trả lời', (
      tester,
    ) async {
      final api = _RecordingApi()
        ..current = base()
        ..gate = Completer<void>();
      await pumpRouted(tester, api);
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      api.gate!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('Tắt TB → POST mute, nút thành "Đã tắt"; bấm lại → DELETE', (
      tester,
    ) async {
      final api = _RecordingApi()..current = base();
      await pumpRouted(tester, api);
      await tester.tap(find.text('Tắt TB'));
      await tester.pumpAndSettle();
      expect(api.mutes, [true]);
      expect(find.text('Đã tắt'), findsOneWidget);
      await tester.tap(find.text('Đã tắt'));
      await tester.pumpAndSettle();
      expect(api.mutes, [true, false]);
      expect(find.text('Tắt TB'), findsOneWidget);
    });

    testWidgets('Đánh dấu chưa đọc → POST unread rồi về Hộp thư', (
      tester,
    ) async {
      final api = _RecordingApi()..current = base();
      await pumpRouted(tester, api);
      await tester.tap(find.text('Đánh dấu chưa đọc'));
      await tester.pumpAndSettle();
      expect(api.unreads, ['c1']);
      expect(find.text('HỘP THƯ'), findsOneWidget);
    });

    testWidgets('đang chưa đọc → không có mục "Đánh dấu chưa đọc"', (
      tester,
    ) async {
      final api = _RecordingApi()..current = base(unread: 3);
      await pumpRouted(tester, api);
      expect(find.text('Đánh dấu chưa đọc'), findsNothing);
    });

    testWidgets('Chặn hội thoại → xác nhận → POST block rồi về Hộp thư', (
      tester,
    ) async {
      final api = _RecordingApi()..current = base();
      await pumpRouted(tester, api);
      await tester.tap(find.text('Chặn hội thoại'));
      await tester.pumpAndSettle();
      expect(find.text('Chặn hội thoại này?'), findsOneWidget);
      await tester.tap(find.text('Chặn'));
      await tester.pumpAndSettle();
      expect(api.blocks, [true]);
      expect(find.text('HỘP THƯ'), findsOneWidget);
    });

    testWidgets('đã chặn → "Bỏ chặn hội thoại" → DELETE, ở lại trang', (
      tester,
    ) async {
      final api = _RecordingApi()
        ..current = base(blockedAt: DateTime.utc(2026, 10, 10));
      await pumpRouted(tester, api);
      expect(find.text('Chặn hội thoại'), findsNothing);
      // API trả 422 conversation_blocked cho /unread trên hội thoại đã chặn.
      expect(find.text('Đánh dấu chưa đọc'), findsNothing);
      await tester.tap(find.text('Bỏ chặn hội thoại'));
      await tester.pumpAndSettle();
      expect(find.text('Chặn hội thoại này?'), findsNothing);
      expect(api.blocks, [false]);
      expect(find.text('HỘP THƯ'), findsNothing);
      expect(find.text('Chặn hội thoại'), findsOneWidget);
    });

    testWidgets('giao diện tối: "Chặn hội thoại" dùng màu nguy hiểm tối', (
      tester,
    ) async {
      final api = _RecordingApi()..current = base();
      await pumpRouted(tester, api, dark: true);
      final text = tester.widget<Text>(find.text('Chặn hội thoại'));
      expect(text.style!.color, OmniColors.dangerTextDark);
    });

    testWidgets('API lỗi → không báo thành công, không rời trang', (
      tester,
    ) async {
      final api = _RecordingApi()
        ..current = base()
        ..fail = true;
      await pumpRouted(tester, api);
      await tester.tap(find.text('Đánh dấu chưa đọc'));
      await tester.pumpAndSettle();
      expect(find.text('HỘP THƯ'), findsNothing);
      expect(find.text('Máy chủ bận'), findsOneWidget);
      expect(find.text('Đã đánh dấu chưa đọc.'), findsNothing);
    });
  });
}

class _RecordingApi extends InboxApi {
  _RecordingApi() : super(ApiClient(Dio()));

  final statuses = <(String, ConversationStatus)>[];
  final pins = <bool>[];
  final mutes = <bool>[];
  final blocks = <bool>[];
  final unreads = <String>[];
  bool fail = false;

  /// Hội thoại "trên server" — `conversationProvider` đọc lại sau thao tác.
  Conversation current = const Conversation(
    id: 'c1',
    channel: Channel.zalo,
    status: ConversationStatus.open,
  );

  /// Giữ lượt ghim tới khi completer xong.
  Completer<void>? gate;

  void _check() {
    if (fail) throw const ServerException('Máy chủ bận');
  }

  @override
  Future<bool> setPinned(String id, bool on) async {
    await gate?.future;
    _check();
    pins.add(on);
    current = current.copyWith(isPinned: on);
    return on;
  }

  @override
  Future<bool> setMuted(String id, bool on) async {
    _check();
    mutes.add(on);
    current = current.copyWith(isMuted: on);
    return on;
  }

  @override
  Future<int> markUnread(String id) async {
    _check();
    unreads.add(id);
    current = current.copyWith(unread: 1);
    return 1;
  }

  @override
  Future<Conversation> setBlocked(String id, bool on) async {
    _check();
    blocks.add(on);
    current = on
        ? current.copyWith(blockedAt: DateTime.utc(2026, 10, 10))
        : Conversation(
            id: current.id,
            channel: current.channel,
            status: current.status,
            customerName: current.customerName,
            isPinned: current.isPinned,
            isMuted: current.isMuted,
          );
    return current;
  }

  @override
  Future<Conversation> setStatus(String id, ConversationStatus status) async {
    statuses.add((id, status));
    return Conversation(
      id: id,
      channel: Channel.zalo,
      status: status,
      customerName: 'Thuý Phạm',
    );
  }

  @override
  Future<InboxFacets> facets(Map<String, dynamic> query) async =>
      const InboxFacets();

  @override
  Future<CursorPaged<Conversation>> list({
    required Map<String, dynamic> query,
    String? before,
    int perPage = AppConfig.defaultPerPage,
    bool? pinned,
  }) async => const CursorPaged.empty();
}
