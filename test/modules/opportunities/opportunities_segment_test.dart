import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/opportunities/application/opportunities_providers.dart';
import 'package:omni_app/modules/opportunities/data/opportunities_api.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';
import 'package:omni_app/modules/opportunities/domain/pipeline_catalog.dart';
import 'package:omni_app/modules/opportunities/opportunities_module.dart';
import 'package:omni_app/modules/opportunities/presentation/opportunities_segment.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/security/permissions/access_scope.dart';
import 'package:omni_app/security/permissions/resource_access.dart';

import '../../support/fixed_background.dart';

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _FakeApi api;
  setUp(() => api = _FakeApi());

  Widget host({
    bool canUpdate = true,
    bool canCreate = false,
    bool withSearch = false,
  }) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            appBar: withSearch
                ? OpportunitySearchRow(
                    filtersOpen: true,
                    onToggleFilters: () {},
                  )
                : null,
            body: const OpportunitiesSegment(filtersOpen: true),
          ),
        ),
        GoRoute(
          path: '/opportunities/:id',
          name: OpportunitiesModule.detail,
          builder: (_, state) => Text('chi tiết ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    return ProviderScope(
      overrides: [
        opportunitiesApiProvider.overrideWithValue(api),
        opportunityAccessProvider.overrideWithValue(
          ResourceAccess(
            readScope: AccessScope.all,
            canUpdate: canUpdate,
            canCreate: canCreate,
          ),
        ),
        backgroundProvider.overrideWith(FixedBackground.new),
      ],
      child: MaterialApp.router(
        theme: OmniTheme.light(TargetPlatform.android),
        routerConfig: router,
      ),
    );
  }

  testWidgets('mặc định tải tất cả giai đoạn mở, không gửi stage', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(api.calls.last.stageCode, isNull);
    // Không có stage thì máy chủ trả cả cơ hội đã đóng: phải gửi status=OPEN.
    expect(api.calls.last.status, 'OPEN');
    expect(find.textContaining('Đang mở ·'), findsOneWidget);
    // Tổng tiền các giai đoạn mở (chỉ Báo giá có 3 triệu).
    expect(find.text('Đang mở · 7 · 3 tr'), findsOneWidget);
  });

  testWidgets('chạm ô "Báo giá" → lọc stage=bao_gia; chạm lại → bỏ lọc', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.text('Bỏ lọc'), findsNothing);

    await t.tap(find.text('Báo giá').first);
    await t.pumpAndSettle();
    expect(api.calls.last.stageCode, 'bao_gia');
    expect(api.calls.last.status, isNull);
    expect(find.text('Bỏ lọc'), findsOneWidget);
    expect(find.text('Báo giá · 2 · 3 tr'), findsOneWidget);

    await t.tap(find.text('Bỏ lọc'));
    await t.pumpAndSettle();
    expect(api.calls.last.stageCode, isNull);

    // Chạm ô đang chọn lần nữa cũng bỏ lọc.
    await t.tap(find.text('Báo giá').first);
    await t.pumpAndSettle();
    expect(api.calls.last.stageCode, 'bao_gia');
    await t.tap(find.text('Báo giá').first);
    await t.pumpAndSettle();
    expect(api.calls.last.stageCode, isNull);
  });

  testWidgets('"Đã đóng" → liệt kê giai đoạn thắng/thua, dải đổi sang ô đóng', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    await t.tap(find.text('Đã đóng'));
    await t.pumpAndSettle();
    // Giai đoạn đóng đầu tiên được chọn sẵn; không gửi status=OPEN.
    expect(api.calls.last.stageCode, 'da_mua');
    expect(api.calls.last.status, isNull);
    expect(find.text('Đã mua'), findsWidgets);
    expect(find.text('Tư vấn'), findsNothing);
    expect(find.text('Bỏ lọc'), findsNothing);
    expect(find.textContaining('Đã mua · 2'), findsOneWidget);

    await t.tap(find.text('Đã đóng'));
    await t.pumpAndSettle();
    expect(api.calls.last.stageCode, isNull);
    expect(api.calls.last.status, 'OPEN');
    expect(find.text('Báo giá'), findsWidgets);
  });

  testWidgets('đổi quy trình đưa lọc giai đoạn về null', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Báo giá').first);
    await t.pumpAndSettle();

    await t.tap(find.text('Bán lẻ'));
    await t.pumpAndSettle();
    await t.tap(find.text('Bán hàng chuẩn'));
    await t.pumpAndSettle();

    expect(api.calls.last.pipeline, 'standard');
    expect(api.calls.last.stageCode, isNull);
    expect(find.text('Bỏ lọc'), findsNothing);
  });

  testWidgets('bấm giữ dòng chọn giai đoạn khi canUpdate', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    await t.longPress(find.text('Đàn U3'));
    await t.pumpAndSettle();
    expect(find.text('Chuyển giai đoạn'), findsOneWidget);

    await t.tap(find.text('Đàm phán').last);
    await t.pumpAndSettle();
    expect(api.moved.single, ('o1', 'dam_phan'));
    expect(find.text('Đã chuyển sang "Đàm phán".'), findsOneWidget);
  });

  testWidgets('không canUpdate → bấm giữ không mở sheet', (t) async {
    await t.pumpWidget(host(canUpdate: false));
    await t.pumpAndSettle();

    await t.longPress(find.text('Đàn U3'));
    await t.pumpAndSettle();
    expect(find.text('Chuyển giai đoạn'), findsNothing);
  });

  testWidgets('chạm dòng → mở chi tiết cơ hội', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Đàn U3'));
    await t.pumpAndSettle();
    expect(find.text('chi tiết o1'), findsOneWidget);
  });

  testWidgets('vòng % dùng probability, rồi mặc định giai đoạn, thắng = 100', (
    t,
  ) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(find.text('60%'), findsOneWidget); // probability đặt trên cơ hội
    expect(find.text('40%'), findsOneWidget); // mặc định của giai đoạn
    expect(find.text('100%'), findsOneWidget); // giai đoạn thắng
    final ring = t.widget<OmniProgressRing>(
      find.byType(OmniProgressRing).first,
    );
    expect(ring.size, 36);
  });

  testWidgets('dòng phụ: khách · Hạn dd/MM, quá hạn tô màu lỗi', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    final scheme = Theme.of(t.element(find.byType(Scaffold))).colorScheme;
    final overdue = t.widget<Text>(find.text('An Nguyễn · Hạn 05/01'));
    expect(overdue.style?.color, scheme.error);
    expect(find.text('Chưa gắn khách hàng'), findsNWidgets(2));
  });

  testWidgets('cuộn tới cuối → tải trang sau theo cùng bộ lọc', (t) async {
    api.total = 45;
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(api.calls.map((c) => c.page).toList(), [1]);

    await t.drag(_column, const Offset(0, -3000));
    await t.pumpAndSettle();
    expect(api.calls.map((c) => c.page).toList(), [1, 2]);
    expect(api.calls.last.stageCode, isNull);
  });

  testWidgets('"Của tôi" → tải lại với owner=me', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    await t.tap(find.text('Của tôi'));
    await t.pumpAndSettle();
    expect(api.calls.last.mine, isTrue);
    expect(api.summaryMine.last, isTrue);
  });

  testWidgets('quy trình hơn 4 giai đoạn mở → dải cuộn ngang', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    final strip = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );
    expect(strip, findsOneWidget);
    // Ô rộng (800 - 32) / 4 = 192 → 5 ô vượt chiều ngang.
    expect(t.getSize(find.text('Báo giá').first).width, lessThan(192));
    expect(
      t.widget<SingleChildScrollView>(strip).scrollDirection,
      Axis.horizontal,
    );
  });
  test(
    'hợp đồng: status đi lên bằng khoá `status`, không status thì không gửi',
    () {
      expect(OpportunitiesApi.listQuery(status: 'OPEN')['status'], 'OPEN');
      expect(OpportunitiesApi.listQuery().containsKey('status'), isFalse);
    },
  );

  testWidgets('đang tìm → list và summary cùng nhận từ khoá', (t) async {
    await t.pumpWidget(host(withSearch: true));
    await t.pumpAndSettle();
    expect(api.summarySearch.last, isNull);
    expect(api.calls.last.search, isNull);

    await t.enterText(find.byType(TextField), 'đàn');
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    expect(api.calls.last.search, 'đàn');
    expect(api.summarySearch.last, 'đàn');
  });

  test('hợp đồng: summaryQuery gửi `search` khi có, bỏ khi rỗng', () {
    expect(OpportunitiesApi.summaryQuery(search: 'đàn')['search'], 'đàn');
    expect(
      OpportunitiesApi.summaryQuery(search: '').containsKey('search'),
      isFalse,
    );
    expect(OpportunitiesApi.summaryQuery().containsKey('search'), isFalse);
    expect(OpportunitiesApi.summaryQuery(mine: true)['owner'], 'me');
    expect(
      OpportunitiesApi.summaryQuery(pipeline: 'ban_le')['pipeline'],
      'ban_le',
    );
  });
}

final _column = find.byWidgetPredicate(
  (w) => w is ListView && w.scrollDirection == Axis.vertical,
);

typedef _Call = ({
  String? search,
  String? stageCode,
  String? status,
  String? pipeline,
  bool mine,
  int page,
});

class _FakeApi extends OpportunitiesApi {
  _FakeApi() : super(ApiClient(Dio()));

  int total = 7;
  final calls = <_Call>[];
  final summaryMine = <bool>[];
  final summarySearch = <String?>[];
  final moved = <(String, String)>[];

  @override
  Future<Opportunity> moveStage(String id, {required String stageCode}) async {
    moved.add((id, stageCode));
    return Opportunity.fromJson({'id': id, 'opportunity_stage': stageCode});
  }

  static Map<String, dynamic> _stage(
    String code,
    String label,
    int order, {
    String outcome = 'open',
    int? probability,
    String? color,
  }) => {
    'code': code,
    'label': label,
    'outcome': outcome,
    'sort_order': order,
    'probability': ?probability,
    'color': ?color,
  };

  @override
  Future<PipelineCatalog> pipelines() async => PipelineCatalog.fromJson({
    'default': 'ban_le',
    'pipelines': [
      {
        'code': 'ban_le',
        'label': 'Bán lẻ',
        'is_default': true,
        'stages': [
          _stage('lien_he', 'Liên hệ', 1, probability: 40, color: '#0ea5e9'),
          _stage('tu_van', 'Tư vấn', 2, probability: 30),
          _stage('bao_gia', 'Báo giá', 3, probability: 50),
          _stage('dam_phan', 'Đàm phán', 4, probability: 70),
          _stage('cho_giao', 'Chờ giao', 5, probability: 90),
          _stage('da_mua', 'Đã mua', 6, outcome: 'won', probability: 100),
        ],
      },
      {
        'code': 'standard',
        'label': 'Bán hàng chuẩn',
        'is_default': false,
        'stages': [_stage('new', 'Mới', 1)],
      },
    ],
  });

  @override
  Future<PipelineSummary> summary({
    String? pipeline,
    bool mine = false,
    String? search,
  }) async {
    summaryMine.add(mine);
    summarySearch.add(search);
    return PipelineSummary.fromJson({
      'count_by_stage': {
        'lien_he': 1,
        'tu_van': 1,
        'bao_gia': 2,
        'dam_phan': 1,
        'cho_giao': 2,
        'da_mua': 9,
      },
      'value_by_stage': {'bao_gia': 3000000},
    });
  }

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
  }) async {
    calls.add((
      search: search,
      stageCode: stageCode,
      status: status,
      pipeline: pipeline,
      mine: mine,
      page: page,
    ));
    final items = total > 10
        ? [
            for (
              var i = (page - 1) * perPage;
              i < (page * perPage).clamp(0, total);
              i++
            )
              Opportunity.fromJson({
                'id': 'p$i',
                'title': 'Cơ hội $i',
                'opportunity_stage': 'lien_he',
                'opportunity_status': 'OPEN',
              }),
          ]
        : [
            Opportunity.fromJson({
              'id': 'o1',
              'title': 'Đàn U3',
              'customer_name': 'An Nguyễn',
              'opportunity_stage': 'bao_gia',
              'opportunity_status': 'OPEN',
              'estimated_budget': 12000000,
              'expected_end_date': '2020-01-05',
              'metadata': {'probability': 60},
            }),
            Opportunity.fromJson({
              'id': 'o2',
              'title': 'Guitar',
              'opportunity_stage': 'lien_he',
              'opportunity_status': 'OPEN',
            }),
            Opportunity.fromJson({
              'id': 'o3',
              'title': 'Piano',
              'opportunity_stage': 'da_mua',
              'opportunity_status': 'WON',
            }),
          ];
    return Paged(
      items: items,
      pagination: ApiPagination(
        currentPage: page,
        lastPage: (total / perPage).ceil().clamp(1, 1 << 30),
        perPage: perPage,
        total: stageCode == null ? total : 2,
      ),
    );
  }
}
