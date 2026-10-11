import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/modules/inbox/presentation/inbox_page.dart';
import 'package:omni_app/modules/inbox/presentation/thread_page.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../../support/fixed_background.dart';

/// Lưới poll dự phòng, kiểm trên HAI MÀN HÌNH THẬT.
///
/// `inbox_realtime_backoff_test.dart` chỉ kiểm `InboxRealtime` — một lớp mới,
/// nên không bài nào ở đó có thể đỏ trên mã cũ, và quan trọng hơn: chỗ hỏng
/// thật nằm ở hai màn hình, nơi `setState` gặp `Timer`. Hai điều phải đúng ở
/// đó:
///
/// - kênh còn sống thì KHÔNG có lượt `/inbox/changes` nào (mục tiêu của P1);
/// - một đợt mất kết nối CHẬP CHỜN phải có lượt poll SỚM. Vòng nối lại sinh
///   hai lần đổi trạng thái mỗi lượt thử (`disconnected` → `connecting` →
///   `disconnected`) ở t ≈ 0, 2, 6, 14 s; nếu mỗi lần đổi đều `cancel()` rồi
///   dựng lại hẹn giờ từ 0 thì lượt poll đầu tiên chỉ chạy quanh t ≈ 19 s —
///   đúng 19 giây đầu của một đợt mất kết nối thì lưới an toàn không tồn tại.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _FakeInboxApi api;
  late StreamController<RealtimeStatus> statuses;

  setUp(() {
    api = _FakeInboxApi();
    statuses = StreamController<RealtimeStatus>.broadcast();
  });

  tearDown(() => statuses.close());

  Widget host(Widget screen) => ProviderScope(
    overrides: [
      inboxApiProvider.overrideWithValue(api),
      realtimeClientProvider.overrideWithValue(
        RealtimeClient(
          config: const RealtimeConfig.disabled(),
          authorizer: (_, _) async => '',
        ),
      ),
      // Trạng thái socket do bài kiểm lái: đây là đầu vào duy nhất mà hai màn
      // hình dùng để quyết định có poll hay không.
      realtimeStatusProvider.overrideWith((ref) => statuses.stream),
      sessionProvider.overrideWithValue(
        Session(
          status: SessionStatus.authenticated,
          user: const SessionUser(id: 'u1', fullName: 'Kiệt', email: 'k@x.vn'),
          tenant: const SessionTenant(id: 't1', name: 'Xưởng đàn'),
          policy: AccessPolicy(const {'inbox.read', 'inbox.write'}),
        ),
      ),
      backgroundProvider.overrideWith(FixedBackground.new),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: screen,
    ),
  );

  /// Đẩy một trạng thái socket vào và để màn hình dựng lại theo nó.
  Future<void> emit(WidgetTester tester, RealtimeStatus status) async {
    statuses.add(status);
    await tester.pump();
    await tester.pump();
  }

  /// Gỡ màn hình trước khi bài kiểm kết thúc: poll dự phòng là một `Timer`.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  for (final screen in <({String name, Widget widget})>[
    (name: 'hộp thư', widget: const InboxPage()),
    (name: 'màn chat', widget: const ThreadPage(conversationId: 'c1')),
  ]) {
    testWidgets('${screen.name}: kênh còn sống thì không gọi /inbox/changes', (
      tester,
    ) async {
      await tester.pumpWidget(host(screen.widget));
      await tester.pump();
      await emit(tester, RealtimeStatus.connected);
      api.changesCalls = 0;

      // Hai phút — dài hơn cả nhịp poll cũ (2 phút) và hơn mọi bậc giãn.
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(seconds: 5));
      }

      expect(
        api.changesCalls,
        0,
        reason:
            'socket sống rồi: mỗi lượt poll ở đây chỉ để biết là không có gì mới',
      );
      await close(tester);
    });

    testWidgets(
      '${screen.name}: đợt mất kết nối chập chờn vẫn có lượt poll sớm',
      (tester) async {
        await tester.pumpWidget(host(screen.widget));
        await tester.pump();
        await emit(tester, RealtimeStatus.connected);
        api.changesCalls = 0;

        // t=0: rớt. Nhịp đầu là 4–6 giây (hộp thư) / 6,4–9,6 giây (màn chat).
        await emit(tester, RealtimeStatus.disconnected);

        // Vòng nối lại của RealtimeClient: thử ở t=2 và t=6, cả hai đều thất
        // bại. `connecting` và `disconnected` là CÙNG một chế độ về phía hẹn
        // giờ — không được dựng lại hẹn giờ từ 0 vì chúng.
        await tester.pump(const Duration(seconds: 2));
        await emit(tester, RealtimeStatus.connecting);
        await tester.pump(const Duration(seconds: 4));
        await emit(tester, RealtimeStatus.disconnected);
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();

        expect(
          api.changesCalls,
          greaterThanOrEqualTo(1),
          reason:
              'tới t≈10 giây phải có lượt poll: sóng yếu càng lâu thì lưới an '
              'toàn càng không được lùi mãi',
        );
        await close(tester);
      },
    );
  }
}

class _FakeInboxApi extends InboxApi {
  _FakeInboxApi() : super(ApiClient(Dio()));

  int changesCalls = 0;

  @override
  Future<InboxChanges> changes(String? after, {String? conversationId}) async {
    changesCalls++;
    return const InboxChanges(cursor: 'cur', count: 0);
  }

  @override
  Future<InboxFacets> facets(Map<String, dynamic> query) async =>
      const InboxFacets();

  @override
  Future<List<String>> labels() async => const [];

  @override
  Future<CursorPaged<Conversation>> list({
    required Map<String, dynamic> query,
    String? before,
    int perPage = AppConfig.defaultPerPage,
    bool? pinned,
  }) async => const CursorPaged<Conversation>.empty();

  @override
  Future<MessagePage> messages(
    String id, {
    String? before,
    int perPage = AppConfig.messagePageSize,
  }) async => const MessagePage(messages: [], cursor: CursorPage.empty());

  @override
  Future<Conversation> get(String id) async => Conversation(
    id: id,
    channel: Channel.zalo,
    status: ConversationStatus.open,
    customerName: 'Thuý Phạm',
    lastMessage: 'Còn đàn không',
  );

  @override
  Future<void> markRead(String id) async {}
}
