import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/customers/application/customers_providers.dart';
import 'package:omni_app/modules/customers/data/customers_api.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/modules/customers/presentation/customers_page.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/permissions/access_scope.dart';
import 'package:omni_app/security/permissions/resource_access.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../../support/fixed_background.dart';

class _FakeApi implements CustomersApi {
  final queries = <Map<String, dynamic>>[];

  @override
  Future<Paged<Customer>> list({
    Map<String, dynamic> query = const {},
    int page = 1,
    int perPage = 20,
  }) async {
    queries.add(query);
    return Paged(
      items: [
        for (final (id, name) in [('a', 'An Nguyễn'), ('b', 'Bình Trần')])
          Customer.fromJson({
            'id': id,
            'display_name': name,
            'primary_contact_phone': '0901',
            'metadata': {'source': 'zalo'},
          }),
      ],
      pagination: const ApiPagination.empty(),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _FakeApi api;
  setUp(() => api = _FakeApi());

  Widget host({bool canCreate = true}) => ProviderScope(
    overrides: [
      customersApiProvider.overrideWithValue(api),
      customerAccessProvider.overrideWithValue(
        ResourceAccess(readScope: AccessScope.own, canCreate: canCreate),
      ),
      backgroundProvider.overrideWith(FixedBackground.new),
      sessionProvider.overrideWithValue(
        Session(
          status: SessionStatus.authenticated,
          user: const SessionUser(id: 'u1', fullName: 'K', email: 'k@x.vn'),
          tenant: const SessionTenant(id: 't1', name: 'X'),
          policy: AccessPolicy(const {'tasks.write'}),
        ),
      ),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const CustomersPage(),
    ),
  );

  testWidgets('mặc định phạm vi own → gọi API với assigned_sales_rep_id', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(api.queries.last['assigned_sales_rep_id'], 'u1');
  });

  testWidgets('chạm dòng B đóng dòng A, mở dòng B', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.text('Hồ sơ'), findsNothing);

    await t.tap(find.text('An Nguyễn'));
    await t.pumpAndSettle();
    expect(find.text('Hồ sơ'), findsOneWidget);
    final aY = t.getTopLeft(find.text('Hồ sơ')).dy;

    await t.tap(find.text('Bình Trần'));
    await t.pumpAndSettle();
    expect(find.text('Hồ sơ'), findsOneWidget);
    expect(t.getTopLeft(find.text('Hồ sơ')).dy, greaterThan(aY));

    await t.tap(find.text('Bình Trần'));
    await t.pumpAndSettle();
    expect(find.text('Hồ sơ'), findsNothing);
  });

  testWidgets('nút lọc: 0 ở mặc định; chọn VIP → 1 và API nhận WARM', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    Finder count(String n) => find.descendant(
      of: find.byKey(const Key('customer-filter-count')),
      matching: find.text(n),
    );
    expect(count('0'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Bộ lọc'));
    await t.pumpAndSettle();
    await t.tap(find.text('VIP'));
    await t.pumpAndSettle();

    expect(count('1'), findsOneWidget);
    expect(api.queries.last['customer_status'], 'WARM');
  });

  testWidgets('canCreate=false → không có nút Thêm khách', (t) async {
    await t.pumpWidget(host(canCreate: false));
    await t.pumpAndSettle();
    expect(find.byTooltip('Thêm khách'), findsNothing);
  });

  testWidgets('đổi bộ lọc thì dòng đang mở đóng lại', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('An Nguyễn'));
    await t.pumpAndSettle();
    expect(find.text('Hồ sơ'), findsOneWidget);

    await t.tap(find.bySemanticsLabel('Bộ lọc'));
    await t.pumpAndSettle();
    await t.tap(find.text('VIP'));
    await t.pumpAndSettle();
    expect(find.text('Hồ sơ'), findsNothing);
  });

  testWidgets('canCreate=true → có nút Thêm khách', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.byTooltip('Thêm khách'), findsOneWidget);
  });

  test('activeCountFor: mặc định theo phạm vi tính 0', () {
    const mine = CustomerFilter(quick: CustomerQuickFilter.mine);
    const all = CustomerFilter();
    expect(mine.activeCountFor(AccessScope.own), 0);
    expect(mine.activeCountFor(AccessScope.all), 1);
    expect(all.activeCountFor(AccessScope.all), 0);
    expect(all.activeCountFor(AccessScope.own), 1);
  });
}
