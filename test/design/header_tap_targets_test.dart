import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/customers/application/customers_providers.dart';
import 'package:omni_app/modules/customers/data/customers_api.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/modules/customers/presentation/customers_page.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/modules/inbox/presentation/inbox_page.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/permissions/access_scope.dart';
import 'package:omni_app/security/permissions/resource_access.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../support/fixed_background.dart';

class _InboxApi extends InboxApi {
  _InboxApi() : super(ApiClient(Dio()));

  @override
  Future<CursorPaged<Conversation>> list({
    required Map<String, dynamic> query,
    String? before,
    int perPage = AppConfig.defaultPerPage,
  }) async => const CursorPaged(items: []);

  @override
  Future<InboxFacets> facets(Map<String, dynamic> query) async =>
      const InboxFacets();

  @override
  Future<List<String>> labels() async => const [];

  @override
  Future<InboxChanges> changes(String? after, {String? conversationId}) async =>
      const InboxChanges(cursor: 'cur', count: 0);
}

class _CustomersApi implements CustomersApi {
  @override
  Future<Paged<Customer>> list({
    Map<String, dynamic> query = const {},
    int page = 1,
    int perPage = 20,
  }) async => const Paged(
    items: [],
    pagination: ApiPagination(
      currentPage: 1,
      lastPage: 1,
      perPage: 20,
      total: 0,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Vùng chạm thật của IconButton là chính nó (lớp InputPadding nằm trong): Tooltip
/// bọc phần vẽ bên trong nên đo Tooltip sẽ ra phần vẽ, không phải vùng chạm.
Size hitSize(WidgetTester t, String tooltip) => t.getSize(
  find.ancestor(of: find.byTooltip(tooltip), matching: find.byType(IconButton)),
);

/// Hình vẽ 36 nhưng vùng chạm phải ≥ 44 (ruling của dự án).
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  Session session() => Session(
    status: SessionStatus.authenticated,
    user: const SessionUser(id: 'u1', fullName: 'Kiệt', email: 'k@x.vn'),
    tenant: const SessionTenant(id: 't1', name: 'Xưởng đàn'),
    policy: AccessPolicy(const {
      'inbox.read',
      'inbox.write',
      'inbox.label',
      'channels.read',
      'channels.write',
    }),
  );

  Future<void> closePage(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump();
  }

  for (final width in [600.0, 360.0]) {
    testWidgets('nút vuông header của Hộp thư đủ 44 ở rộng $width', (t) async {
      final handle = t.ensureSemantics();
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            inboxApiProvider.overrideWithValue(_InboxApi()),
            realtimeClientProvider.overrideWithValue(
              RealtimeClient(
                config: const RealtimeConfig.disabled(),
                authorizer: (_, _) async => '',
              ),
            ),
            sessionProvider.overrideWithValue(session()),
          ],
          child: MaterialApp(
            theme: OmniTheme.light(TargetPlatform.android),
            home: const InboxPage(),
          ),
        ),
      );
      await t.pump();
      await t.pump();

      for (final tip in ['Kết nối kênh', 'Chọn nhiều']) {
        expect(find.byTooltip(tip), findsOneWidget, reason: tip);
        final s = hitSize(t, tip);
        expect(s.width, greaterThanOrEqualTo(44), reason: tip);
        expect(s.height, greaterThanOrEqualTo(44), reason: tip);
      }
      expect(t.getSize(find.bySemanticsLabel('Bộ lọc')), const Size(44, 44));
      // Phần vẽ vẫn 36.
      expect(
        t.getSize(
          find
              .ancestor(
                of: find.byIcon(Icons.tune_rounded),
                matching: find.byType(Material),
              )
              .first,
        ),
        const Size(36, 36),
      );
      // Không tràn ngang: mọi nút nằm trong màn và ô tìm còn chỗ.
      for (final tip in ['Kết nối kênh', 'Chọn nhiều']) {
        final r = t.getRect(
          find.ancestor(
            of: find.byTooltip(tip),
            matching: find.byType(IconButton),
          ),
        );
        expect(r.right, lessThanOrEqualTo(width), reason: tip);
      }
      expect(t.getSize(find.byType(TextField)).width, greaterThan(60));
      expect(t.takeException(), isNull);
      await closePage(t);
      handle.dispose();
    });
  }

  testWidgets('nút vuông header của Khách đủ 44', (t) async {
    final handle = t.ensureSemantics();
    t.view.physicalSize = const Size(600, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          customersApiProvider.overrideWithValue(_CustomersApi()),
          customerAccessProvider.overrideWithValue(
            const ResourceAccess(readScope: AccessScope.all, canCreate: true),
          ),
          backgroundProvider.overrideWith(FixedBackground.new),
          sessionProvider.overrideWithValue(session()),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const CustomersPage(),
        ),
      ),
    );
    await t.pumpAndSettle();

    final add = hitSize(t, 'Thêm khách');
    expect(add.width, greaterThanOrEqualTo(44));
    expect(add.height, greaterThanOrEqualTo(44));
    expect(t.getSize(find.bySemanticsLabel('Bộ lọc')), const Size(44, 44));
    handle.dispose();
  });
}
