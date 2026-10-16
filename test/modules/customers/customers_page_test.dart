import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/module/extra_segment.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/customers/application/customers_providers.dart';
import 'package:omni_app/modules/customers/data/customers_api.dart';
import 'package:omni_app/modules/customers/customers_module.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/modules/customers/presentation/customer_form_page.dart';
import 'package:omni_app/modules/customers/presentation/customers_page.dart';
import 'package:omni_app/modules/opportunities/application/opportunities_providers.dart';
import 'package:omni_app/modules/opportunities/data/opportunities_api.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';
import 'package:omni_app/modules/opportunities/domain/pipeline_catalog.dart';
import 'package:omni_app/modules/opportunities/presentation/opportunities_segment.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/permissions/access_scope.dart';
import 'package:omni_app/security/permissions/resource_access.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../../support/fixed_background.dart';

class _FakeApi implements CustomersApi {
  final queries = <Map<String, dynamic>>[];
  Customer? created;
  DuplicateMatch? duplicate;
  int createCalls = 0;

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
      pagination: const ApiPagination(
        currentPage: 1,
        lastPage: 1,
        perPage: 20,
        total: 2,
      ),
    );
  }

  @override
  Future<DuplicateMatch?> checkDuplicate({
    String? phone,
    String? email,
  }) async => duplicate;

  @override
  Future<Customer> create(Customer draft) async {
    createCalls++;
    created = draft;
    return Customer.fromJson({
      'id': 'new-customer',
      'display_name': draft.name,
      'primary_contact_phone': draft.phone,
      'metadata': {'source': 'zalo'},
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _FakeApi api;
  setUp(() => api = _FakeApi());

  Widget host({
    bool canCreate = true,
    ResourceAccess? oppAccess,
    Map<String, bool> features = const {},
    int initialSegment = 0,
    GoRouter? router,
  }) => ProviderScope(
    overrides: [
      customersApiProvider.overrideWithValue(api),
      khachExtraSegmentProvider.overrideWithValue(opportunitiesKhachSegment),
      opportunitiesApiProvider.overrideWithValue(_FakeOppApi()),
      if (oppAccess != null)
        opportunityAccessProvider.overrideWithValue(oppAccess),
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
          features: features,
        ),
      ),
    ],
    child: router != null
        ? MaterialApp.router(
            theme: OmniTheme.light(TargetPlatform.android),
            routerConfig: router,
          )
        : MaterialApp(
            theme: OmniTheme.light(TargetPlatform.android),
            home: CustomersPage(initialSegment: initialSegment),
          ),
  );

  const readAll = ResourceAccess(readScope: AccessScope.all);

  testWidgets(
    'có quyền + cờ bật → loại dữ liệu nằm trong bộ lọc; chọn "Cơ hội" '
    '→ dải giai đoạn',
    (t) async {
      await t.pumpWidget(host(oppAccess: readAll));
      await t.pumpAndSettle();
      expect(find.byType(OmniSegmented), findsNothing);
      expect(find.byKey(const Key('customer-filter-menu')), findsNothing);
      expect(find.text('An Nguyễn'), findsOneWidget);

      await t.tap(find.bySemanticsLabel('Bộ lọc'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('customer-filter-menu')), findsOneWidget);
      expect(find.text('Khách hàng · 2'), findsOneWidget);
      expect(find.text('Cơ hội · 7'), findsOneWidget);

      await t.tap(find.text('Cơ hội · 7'));
      await t.pumpAndSettle();
      expect(find.text('Báo giá'), findsOneWidget);
      expect(find.textContaining('Đang mở · 7'), findsOneWidget);
      expect(find.text('An Nguyễn'), findsNothing);
      // Hàng tìm đổi theo đoạn.
      expect(find.byTooltip('Thêm khách'), findsNothing);

      await t.tap(find.bySemanticsLabel('Bộ lọc'));
      await t.pumpAndSettle();
      await t.tap(find.text('Khách hàng · 2'));
      await t.pumpAndSettle();
      expect(find.text('An Nguyễn'), findsOneWidget);
      expect(find.text('Báo giá'), findsNothing);
    },
  );

  testWidgets('initialSegment=1 (?seg=co-hoi) mở thẳng đoạn Cơ hội', (t) async {
    await t.pumpWidget(host(oppAccess: readAll, initialSegment: 1));
    await t.pumpAndSettle();
    expect(find.text('Báo giá'), findsOneWidget);
  });

  // Route thật của module: `?seg=co-hoi` phải tới đoạn Cơ hội.
  testWidgets('route /customers?seg=co-hoi mở đoạn Cơ hội, không có seg thì '
      'mở Khách hàng', (t) async {
    final route = const CustomersModule().routes().firstWhere(
      (r) => r.path == '/customers',
    );
    for (final (location, expectOpp) in [
      ('/customers?seg=co-hoi', true),
      ('/customers', false),
      ('/customers?seg=khac', false),
    ]) {
      final router = GoRouter(
        initialLocation: location,
        routes: [GoRoute(path: route.path, builder: route.builder)],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(host(oppAccess: readAll, router: router));
      await t.pumpAndSettle();
      expect(find.text('Báo giá'), expectOpp ? findsOneWidget : findsNothing);
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('nút lọc và "Thêm khách" có vùng chạm 44 dù hình 36', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    final icon = t.getCenter(find.byIcon(Icons.tune_rounded));
    // 20px lệch tâm: ngoài hình 36 (bán kính 18), trong vùng chạm 44.
    await t.tapAt(icon + const Offset(20, 0));
    await t.pumpAndSettle();
    expect(find.text('VIP'), findsOneWidget);
    final add = t.getSize(
      find.ancestor(
        of: find.byIcon(Icons.person_add_alt_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(add.shortestSide, greaterThanOrEqualTo(44));
  });

  testWidgets('cờ opportunities tắt → không có thanh đoạn', (t) async {
    await t.pumpWidget(
      host(oppAccess: readAll, features: const {'opportunities': false}),
    );
    await t.pumpAndSettle();
    expect(find.byType(OmniSegmented), findsNothing);
    expect(find.text('An Nguyễn'), findsOneWidget);
  });

  testWidgets('không có quyền đọc cơ hội → không có thanh đoạn, kể cả '
      '?seg=co-hoi', (t) async {
    await t.pumpWidget(
      host(oppAccess: ResourceAccess.denied, initialSegment: 1),
    );
    await t.pumpAndSettle();
    expect(find.byType(OmniSegmented), findsNothing);
    expect(find.text('An Nguyễn'), findsOneWidget);
    expect(find.text('Báo giá'), findsNothing);
  });

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

  testWidgets('nút lọc: mặc định không hiện 0; chọn VIP → 1 và API nhận WARM', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    Finder count(String n) => find.descendant(
      of: find.byKey(const Key('customer-filter-count')),
      matching: find.text(n),
    );
    expect(find.byKey(const Key('customer-filter-count')), findsNothing);

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

  testWidgets('dấu + mở form đầy đủ tại chỗ và lưu không chuyển trang', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    await t.tap(find.byTooltip('Thêm khách'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('customer-create-dialog')), findsOneWidget);
    expect(
      find.text('Điền thông tin hồ sơ ngay tại danh sách'),
      findsOneWidget,
    );
    expect(find.byType(CustomerFormPage), findsNothing);

    await t.enterText(find.byKey(const Key('customer-form-name')), 'Mai Anh');
    await t.enterText(
      find.byKey(const Key('customer-form-phone')),
      '0901234567',
    );
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('customer-form-save')));
    await t.pumpAndSettle();

    expect(api.created?.name, 'Mai Anh');
    expect(api.created?.phone, '0901234567');
    expect(find.byKey(const Key('customer-create-dialog')), findsNothing);
    expect(find.text('Đã thêm Mai Anh.'), findsOneWidget);
    expect(find.byType(CustomerFormPage), findsNothing);
  });

  testWidgets('form đầy đủ chặn tạo trùng và không mất dữ liệu khi chạm nền', (
    t,
  ) async {
    api.duplicate = const DuplicateMatch(id: 'existing', name: 'Khách đã có');
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Thêm khách'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('customer-form-name')), 'Khách mới');
    await t.enterText(
      find.byKey(const Key('customer-form-phone')),
      '0901234567',
    );
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();

    expect(find.textContaining('Số điện thoại này đã tồn tại'), findsOneWidget);
    expect(find.textContaining('Khách đã có'), findsOneWidget);
    final save = t.widget<FilledButton>(
      find.byKey(const Key('customer-form-save')),
    );
    expect(save.onPressed, isNull);

    await t.tapAt(const Offset(8, 500));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('customer-create-dialog')), findsOneWidget);
    expect(find.text('Khách mới'), findsOneWidget);
  });

  testWidgets('modal cân bốn cạnh và chứa đầy đủ trường khách hàng', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Thêm khách'));
    await t.pumpAndSettle();

    final rect = t.getRect(find.byKey(const Key('customer-create-dialog')));
    expect(rect.left, 16);
    expect(390 - rect.right, 16);
    expect(rect.top, 16);
    expect(844 - rect.bottom, 16);
    expect(find.byKey(const Key('customer-form-name')), findsOneWidget);
    expect(find.byKey(const Key('customer-form-contact')), findsOneWidget);
    expect(find.byKey(const Key('customer-form-phone')), findsOneWidget);

    await t.drag(
      find.byType(ListView).last,
      const Offset(0, -700),
      warnIfMissed: false,
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('customer-form-email')), findsOneWidget);
    expect(find.byKey(const Key('customer-form-address')), findsOneWidget);
    expect(find.byKey(const Key('customer-form-note')), findsOneWidget);
    expect(find.text('Nguồn khách'), findsOneWidget);
    expect(find.text('Trạng thái'), findsOneWidget);
  });

  testWidgets('double tap lưu chỉ tạo một khách hàng', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Thêm khách'));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('customer-form-name')), 'Mai Anh');
    await t.enterText(
      find.byKey(const Key('customer-form-phone')),
      '0901234567',
    );
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();

    final save = find.byKey(const Key('customer-form-save'));
    await t.tap(save, warnIfMissed: false);
    await t.tap(save, warnIfMissed: false);
    await t.pumpAndSettle();
    expect(api.createCalls, 1);
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

class _FakeOppApi extends OpportunitiesApi {
  _FakeOppApi() : super(ApiClient(Dio()));

  @override
  Future<PipelineCatalog> pipelines() async => PipelineCatalog.fromJson({
    'default': 'ban_le',
    'pipelines': [
      {
        'code': 'ban_le',
        'label': 'Bán lẻ',
        'is_default': true,
        'stages': [
          {
            'code': 'tu_van',
            'label': 'Tư vấn',
            'outcome': 'open',
            'sort_order': 1,
          },
          {
            'code': 'bao_gia',
            'label': 'Báo giá',
            'outcome': 'open',
            'sort_order': 2,
          },
          {
            'code': 'da_mua',
            'label': 'Đã mua',
            'outcome': 'won',
            'sort_order': 3,
          },
        ],
      },
    ],
  });

  @override
  Future<PipelineSummary> summary({
    String? pipeline,
    bool mine = false,
    String? search,
  }) async => PipelineSummary.fromJson({
    'count_by_stage': {'tu_van': 4, 'bao_gia': 3, 'da_mua': 5},
    'value_by_stage': {'bao_gia': 1000000},
  });

  @override
  Future<Paged<Opportunity>> list({
    String? stageCode,
    String? status,
    String? pipeline,
    bool mine = false,
    String? search,
    String? customerId,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async => Paged(
    items: [
      Opportunity.fromJson({
        'id': 'o1',
        'title': 'Đàn U3',
        'opportunity_stage': 'tu_van',
        'opportunity_status': 'OPEN',
      }),
    ],
    pagination: const ApiPagination(
      currentPage: 1,
      lastPage: 1,
      perPage: 20,
      total: 7,
    ),
  );
}
