import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/opportunities/application/opportunities_providers.dart';
import 'package:omni_app/modules/opportunities/data/opportunities_api.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';
import 'package:omni_app/modules/opportunities/domain/pipeline_catalog.dart';
import 'package:omni_app/modules/opportunities/opportunities_module.dart';
import 'package:omni_app/modules/opportunities/presentation/opportunity_form_page.dart';
import 'package:omni_app/modules/opportunities/presentation/pipeline_page.dart';
import 'package:omni_app/security/permissions/access_scope.dart';
import 'package:omni_app/security/permissions/resource_access.dart';

/// Bảng cơ hội dựng cột từ quy trình THẬT của tenant, có nút "Của tôi", và
/// cuộn tới cuối cột thì tải trang sau.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _FakeApi api;
  setUp(() => api = _FakeApi());

  Widget host() => ProviderScope(
    overrides: [
      opportunitiesApiProvider.overrideWithValue(api),
      opportunityAccessProvider.overrideWithValue(
        const ResourceAccess(readScope: AccessScope.all),
      ),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const PipelinePage(),
    ),
  );

  testWidgets('cột là giai đoạn của quy trình, không phải 6 mã cố định', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Liên hệ'), findsOneWidget);
    // Dải chỉ có giai đoạn mở: "Đã mua" (Thắng) không phải ô.
    expect(find.text('Đã mua'), findsNothing);
    expect(find.text('Đàm phán'), findsNothing);
    // "Của tôi" nằm trong panel lọc, đóng cho tới khi chạm nút lọc.
    expect(find.text('Của tôi'), findsNothing);
    // Mặc định: mọi giai đoạn mở, không gửi `stage`.
    expect(api.calls.first.stageCode, isNull);
    expect(api.calls.first.pipeline, 'ban_le');
    expect(find.text('Cơ hội 0'), findsOneWidget);
  });

  testWidgets('chạm "Của tôi" → tải lại với owner=me', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Bộ lọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Của tôi'));
    await tester.pumpAndSettle();

    expect(api.calls.last.mine, isTrue);
    expect(api.summaryMine.last, isTrue);
  });

  testWidgets('cuộn tới cuối danh sách → tải trang 2', (tester) async {
    api.total = 45;
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(api.calls.map((c) => c.page).toList(), [1]);

    await tester.drag(_column, const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(api.calls.map((c) => c.page).toList(), [1, 2]);
    await tester.drag(_column, const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(find.text('Cơ hội 44'), findsOneWidget);
  });

  testWidgets('nhiều quy trình → đổi quy trình đổi cả cột', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Bộ lọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bán lẻ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bán hàng chuẩn'));
    await tester.pumpAndSettle();

    expect(find.text('Liên hệ'), findsNothing);
    expect(find.text('Mới'), findsOneWidget);
    expect(api.calls.last.pipeline, 'standard');
    expect(api.calls.last.stageCode, isNull);
  });

  testWidgets('tạo cơ hội khi đang xem quy trình khác mặc định → vào đúng '
      'quy trình đó', (tester) async {
    final router = GoRouter(
      initialLocation: '/opportunities/new',
      routes: [
        GoRoute(
          path: '/opportunities/new',
          name: OpportunitiesModule.create,
          builder: (_, _) => const OpportunityFormPage(),
        ),
        GoRoute(
          path: '/opportunities/:id',
          name: OpportunitiesModule.detail,
          builder: (_, _) => const Text('chi tiết'),
        ),
      ],
    );
    addTearDown(router.dispose);
    // Biểu mẫu là ListView: cửa sổ test 800×600 không dựng tới hàng viên
    // giai đoạn ở cuối.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          opportunitiesApiProvider.overrideWithValue(api),
          opportunityAccessProvider.overrideWithValue(
            const ResourceAccess(readScope: AccessScope.all),
          ),
          // Bảng đang xem "Bán hàng chuẩn", không phải quy trình mặc định.
          selectedPipelineProvider.overrideWith((ref) => 'standard'),
        ],
        child: MaterialApp.router(
          theme: OmniTheme.light(TargetPlatform.android),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Viên giai đoạn là của quy trình đang xem.
    expect(find.text('Mới'), findsOneWidget);
    expect(find.text('Liên hệ'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(0), 'Đàn U3');
    await tester.enterText(find.byType(TextFormField).at(1), '5000000');
    await tester.tap(find.text('Tạo cơ hội'));
    await tester.pumpAndSettle();

    expect(api.created.single['pipeline'], 'standard');
    expect(api.created.single['opportunity_stage'], 'new');
  });

  // Danh mục quy trình từng giữ suốt phiên: web thêm giai đoạn thì app không
  // thấy cho tới khi khởi động lại (APP-I12).
  testWidgets('mở bảng lần hai → đọc lại danh mục quy trình', (tester) async {
    final show = ValueNotifier(true);
    addTearDown(show.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          opportunitiesApiProvider.overrideWithValue(api),
          opportunityAccessProvider.overrideWithValue(
            const ResourceAccess(readScope: AccessScope.all),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, visible, _) =>
                visible ? const PipelinePage() : const Text('khác'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.pipelineCalls, 1);

    show.value = false;
    await tester.pumpAndSettle();
    show.value = true;
    await tester.pumpAndSettle();

    expect(api.pipelineCalls, 2);
    expect(find.textContaining('Liên hệ'), findsOneWidget);
  });

  test('đổi giai đoạn bị 422 opportunity_stage → đọc lại danh mục', () async {
    final container = ProviderContainer(
      overrides: [
        opportunitiesApiProvider.overrideWithValue(api),
        opportunityAccessProvider.overrideWithValue(
          const ResourceAccess(readScope: AccessScope.all),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(pipelineCatalogProvider.future);
    expect(api.pipelineCalls, 1);

    api.rejectStage = true;
    final opp = Opportunity.fromJson({
      'id': 'o1',
      'opportunity_stage': 'lien_he',
    });
    await expectLater(
      container.read(opportunityActionsProvider).moveStage(opp, 'cu'),
      throwsA(isA<ValidationException>()),
    );
    await container.read(pipelineCatalogProvider.future);
    expect(api.pipelineCalls, 2);
  });
}

typedef _Call = ({String? stageCode, String? pipeline, bool mine, int page});

class _FakeApi extends OpportunitiesApi {
  _FakeApi() : super(ApiClient(Dio()));

  int total = 3;
  final calls = <_Call>[];
  final summaryMine = <bool>[];
  final created = <Map<String, dynamic>>[];
  int pipelineCalls = 0;
  bool rejectStage = false;

  @override
  Future<Opportunity> moveStage(String id, {required String stageCode}) async {
    if (rejectStage) {
      throw const ValidationException(
        'Giai đoạn không thuộc quy trình.',
        errors: {
          'opportunity_stage': ['Giai đoạn không thuộc quy trình.'],
        },
      );
    }
    return Opportunity.fromJson({'id': id, 'opportunity_stage': stageCode});
  }

  @override
  Future<Opportunity> create(Opportunity draft) async {
    created.add(draft.toPayload());
    return Opportunity.fromJson({...draft.toPayload(), 'id': 'new1'});
  }

  @override
  Future<PipelineCatalog> pipelines() async {
    pipelineCalls++;
    return _catalog;
  }

  static final _catalog = PipelineCatalog.fromJson({
    'default': 'ban_le',
    'pipelines': [
      {
        'code': 'ban_le',
        'label': 'Bán lẻ',
        'is_default': true,
        'stages': [
          {
            'code': 'lien_he',
            'label': 'Liên hệ',
            'outcome': 'open',
            'sort_order': 1,
          },
          {
            'code': 'da_mua',
            'label': 'Đã mua',
            'outcome': 'won',
            'sort_order': 2,
          },
        ],
      },
      {
        'code': 'standard',
        'label': 'Bán hàng chuẩn',
        'is_default': false,
        'stages': [
          {'code': 'new', 'label': 'Mới', 'outcome': 'open', 'sort_order': 1},
        ],
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
    return PipelineSummary.fromJson({
      'count_by_stage': {'lien_he': total, 'da_mua': 2},
      'value_by_stage': {'lien_he': 1000000, 'da_mua': 5000000},
    });
  }

  @override
  Future<Paged<Opportunity>> list({
    String? stageCode,
    String? status,
    String? pipeline,
    bool mine = false,
    String? search,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    calls.add((
      stageCode: stageCode,
      pipeline: pipeline,
      mine: mine,
      page: page,
    ));
    final start = (page - 1) * perPage;
    final count = (total - start).clamp(0, perPage);
    return Paged(
      items: [
        for (var i = start; i < start + count; i++)
          Opportunity.fromJson({
            'id': 'o$i',
            'title': 'Cơ hội $i',
            'opportunity_stage': stageCode,
            'opportunity_status': 'OPEN',
          }),
      ],
      pagination: ApiPagination(
        currentPage: page,
        lastPage: (total / perPage).ceil().clamp(1, 1 << 30),
        perPage: perPage,
        total: total,
      ),
    );
  }
}

/// Danh sách dọc của cột (dải giai đoạn cũng là một ListView, nằm ngang).
final _column = find.byWidgetPredicate(
  (widget) => widget is ListView && widget.scrollDirection == Axis.vertical,
);
