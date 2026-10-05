import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/application/inbox_providers.dart';
import 'package:omni_app/modules/inbox/application/inbox_realtime.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/modules/inbox/presentation/inbox_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Fix vòng 1 (M8, chốt P4): nhịp poll `/inbox/changes` thấy thay đổi thì GỘP
/// trang 1 (`mergeLatest`), không `refresh()` — `refresh()` đưa danh sách về
/// trang 1 và người đang cuộn mất chỗ đang đọc.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  testWidgets('poll có thay đổi → mergeLatest, không refresh', (tester) async {
    final api = _FakeInboxApi();
    final list = _SpyList();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxApiProvider.overrideWithValue(api),
          inboxListProvider.overrideWith(() => list),
          // Không socket: poll chạy ở nhịp dự phòng.
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
              policy: AccessPolicy({'inbox.read', 'inbox.write'}),
            ),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const InboxPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.pump(RealtimePolling.inboxFallback);
    await tester.pump();

    expect(api.changesCalls, greaterThanOrEqualTo(1));
    expect(list.merges, greaterThanOrEqualTo(1));
    expect(list.refreshes, 0);

    // Gỡ trang trước khi bài kiểm kết thúc: poll là Timer.periodic.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

class _SpyList extends InboxListController {
  int merges = 0;
  int refreshes = 0;

  @override
  Future<ConversationListState> build() async => const ConversationListState();

  @override
  Future<void> mergeLatest() async => merges++;

  @override
  Future<void> refresh() async => refreshes++;
}

class _FakeInboxApi extends InboxApi {
  _FakeInboxApi() : super(ApiClient(Dio()));

  int changesCalls = 0;

  @override
  Future<InboxFacets> facets(Map<String, dynamic> query) async =>
      const InboxFacets();

  @override
  Future<List<String>> labels() async => const [];

  @override
  Future<InboxChanges> changes(String? after, {String? conversationId}) async {
    changesCalls++;
    return const InboxChanges(cursor: 'cur', count: 2);
  }
}
