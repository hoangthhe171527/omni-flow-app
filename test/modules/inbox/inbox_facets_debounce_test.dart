import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:omni_app/modules/inbox/application/inbox_providers.dart';
import 'package:omni_app/modules/inbox/application/inbox_realtime.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Tenant sôi động bắn `conversation.updated` liên tục: số đếm (facets) chỉ được
/// tải lại MỘT lần mỗi cửa sổ 3 giây, không phải một lần mỗi lô.
void main() {
  testWidgets('nhiều lô conversation.updated → một lượt facets sau 3 giây', (
    tester,
  ) async {
    final api = _Api();
    final container = ProviderContainer(
      overrides: [
        inboxApiProvider.overrideWithValue(api),
        inboxConversationUpdatesProvider.overrideWith(_ManualUpdates.new),
        realtimeClientProvider.overrideWithValue(
          RealtimeClient(
            config: const RealtimeConfig.disabled(),
            authorizer: (_, _) async => '',
          ),
        ),
        sessionProvider.overrideWithValue(
          const Session(
            status: SessionStatus.authenticated,
            user: SessionUser(id: 'u1', fullName: 'Kiệt', email: 'k@x.vn'),
            tenant: SessionTenant(id: 't1', name: 'Xưởng đàn'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.listen(inboxListProvider, (_, _) {});
    container.listen(inboxFacetsProvider, (_, _) {});
    await tester.pump();
    await tester.pump();
    expect(api.facetsCalls, 1, reason: 'lượt đầu khi mở');

    final updates =
        container.read(inboxConversationUpdatesProvider.notifier)
            as _ManualUpdates;
    for (var i = 0; i < 4; i++) {
      updates.push({
        'c1': {'updated'},
      });
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(api.facetsCalls, 1, reason: 'chưa hết cửa sổ 3 giây');

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(api.facetsCalls, 2, reason: 'bốn lô gộp thành một lượt');
  });
}

class _ManualUpdates extends InboxConversationUpdates {
  @override
  ConversationUpdateBatch? build() => null;

  void push(Map<String, Set<String>> reasonsById) => state =
      ConversationUpdateBatch(reasonsById: reasonsById, unscoped: false);
}

Conversation _c(String id) => Conversation(
  id: id,
  channel: Channel.zalo,
  status: ConversationStatus.open,
  customerName: 'Khách $id',
  lastMessage: 'Tin của $id',
  unread: 1,
);

class _Api extends InboxApi {
  _Api() : super(ApiClient(Dio()));

  int facetsCalls = 0;

  @override
  Future<InboxFacets> facets(Map<String, dynamic> query) async {
    facetsCalls++;
    return const InboxFacets();
  }

  @override
  Future<Conversation> get(String id) async => _c(id);

  @override
  Future<CursorPaged<Conversation>> list({
    required Map<String, dynamic> query,
    String? before,
    int perPage = AppConfig.defaultPerPage,
    bool? pinned,
  }) async => CursorPaged(
    items: [_c('c1')],
    cursor: CursorPage(perPage: perPage, hasMore: false, nextBefore: null),
  );
}
