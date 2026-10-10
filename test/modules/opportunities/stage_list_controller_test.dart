import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/opportunities/application/opportunities_providers.dart';
import 'package:omni_app/modules/opportunities/data/opportunities_api.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';
import 'package:omni_app/modules/opportunities/domain/pipeline_catalog.dart';
import 'package:omni_app/security/permissions/access_scope.dart';
import 'package:omni_app/security/permissions/resource_access.dart';

/// Bảng cơ hội: tải theo trang trong từng cột, lọc "Của tôi", chuyển giai
/// đoạn có kiểm kết quả, và chạy được với API chưa có `/pipelines`.
///
/// Trước đây mỗi cột chỉ lấy trang 1 (30 dòng) — cơ hội thứ 31 không bao giờ
/// hiện, và không có gì báo là còn nữa.
void main() {
  late _FakeOpportunitiesApi api;
  late ProviderContainer container;

  ProviderContainer build({AccessScope scope = AccessScope.all}) {
    final c = ProviderContainer(
      overrides: [
        opportunitiesApiProvider.overrideWithValue(api),
        opportunityAccessProvider.overrideWithValue(
          ResourceAccess(readScope: scope, canUpdate: true),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    api = _FakeOpportunitiesApi();
    container = build();
  });

  Future<StageListState> open(String code) {
    container.listen(stageOpportunitiesProvider(code), (_, _) {});
    return container.read(stageOpportunitiesProvider(code).future);
  }

  StageListState read(String code) =>
      container.read(stageOpportunitiesProvider(code)).requireValue;

  test('tải thêm trang 2 khi cột có 45 cơ hội', () async {
    api.total = 45;
    final first = await open('lien_he');
    expect(first.items, hasLength(30));
    expect(first.hasMore, isTrue);

    await container
        .read(stageOpportunitiesProvider('lien_he').notifier)
        .loadMore();

    expect(read('lien_he').items, hasLength(45));
    expect(read('lien_he').hasMore, isFalse);
    expect(read('lien_he').loadingMore, isFalse);
    expect(api.calls.map((c) => c.page), [1, 2]);
    expect(
      read('lien_he').items.map((o) => o.id).toSet(),
      hasLength(45),
      reason: 'Không lặp dòng của trang 1.',
    );
  });

  group('trang 2 về muộn', () {
    // Mạng chậm: trang 2 đang bay thì cột được dựng lại (chuyển một thẻ ra
    // khỏi cột → invalidate, hay kéo để làm mới). Trang 2 về sau không được
    // nối vào 30 dòng CŨ — thẻ đã rời cột sẽ hiện lại ở đây.
    Future<void> race(Future<void> Function() rebuild) async {
      api.total = 45;
      await open('lien_he');
      final gate = api.holds[2] = Completer<void>();

      final more = container
          .read(stageOpportunitiesProvider('lien_he').notifier)
          .loadMore();
      await Future<void>.delayed(Duration.zero);

      api.idPrefix = 'moi';
      await rebuild();
      expect(read('lien_he').items.first.id, 'moi0');

      gate.complete();
      await more;

      final ids = read('lien_he').items.map((o) => o.id);
      expect(ids, hasLength(30), reason: 'Trang 2 của danh sách cũ bị bỏ.');
      expect(ids.every((id) => id.startsWith('moi')), isTrue);
      expect(read('lien_he').hasMore, isTrue, reason: 'Cuộn tiếp vẫn tải.');
      expect(read('lien_he').loadingMore, isFalse);
    }

    test('sau invalidate (chuyển giai đoạn)', () async {
      await race(() async {
        container.invalidate(stageOpportunitiesProvider);
        await container.read(stageOpportunitiesProvider('lien_he').future);
      });
    });

    test('sau kéo để làm mới', () async {
      await race(
        () => container
            .read(stageOpportunitiesProvider('lien_he').notifier)
            .refresh(),
      );
    });

    test('trang 2 lỗi muộn cũng không ghi đè danh sách mới', () async {
      api.total = 45;
      await open('lien_he');
      final gate = api.holds[2] = Completer<void>();
      final more = container
          .read(stageOpportunitiesProvider('lien_he').notifier)
          .loadMore();
      await Future<void>.delayed(Duration.zero);
      api.idPrefix = 'moi';
      container.invalidate(stageOpportunitiesProvider);
      await container.read(stageOpportunitiesProvider('lien_he').future);

      gate.completeError(const NetworkException('mất mạng'));
      await more;
      expect(read('lien_he').items.first.id, 'moi0');
    });
  });

  test('cột gửi mã giai đoạn thô và quy trình đang xem', () async {
    await open('lien_he');
    expect(api.calls.single.stageCode, 'lien_he');
    expect(api.calls.single.pipeline, 'ban_le');
    expect(api.calls.single.mine, isFalse);
  });

  test('"Của tôi" gửi owner=me', () async {
    await open('lien_he');
    container.read(pipelineMineProvider.notifier).state = true;
    await container.read(stageOpportunitiesProvider('lien_he').future);
    expect(api.calls.last.mine, isTrue);
    expect(api.calls.last.page, 1);
    expect(api.lastQuery['owner'], 'me');
  });

  test('phạm vi đọc chỉ "của mình" → mặc định bật "Của tôi"', () {
    final own = build(scope: AccessScope.own);
    expect(own.read(pipelineMineProvider), isTrue);
    expect(container.read(pipelineMineProvider), isFalse);
  });

  test('đổi quy trình → cột chọn trở về giai đoạn mở đầu tiên', () async {
    await container.read(pipelineCatalogProvider.future);
    container.read(selectedStageProvider.notifier).state = 'tu_van';
    container.read(selectedPipelineProvider.notifier).state = 'standard';
    expect(container.read(selectedStageProvider), isNull);
  });

  group('chuyển giai đoạn', () {
    final opp = Opportunity.fromJson({
      'id': 'o1',
      'title': 'Đàn',
      'opportunity_stage': 'lien_he',
      'pipeline': 'ban_le',
      'opportunity_status': 'OPEN',
    });

    test('máy chủ trả mã khác → báo lỗi, không báo thành công', () async {
      api.moveResult = (code) => {
        'id': 'o1',
        'opportunity_stage': 'lien_he',
        'pipeline': 'ban_le',
        'opportunity_status': 'OPEN',
      };
      await expectLater(
        container.read(opportunityActionsProvider).moveStage(opp, 'tu_van'),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            'Máy chủ không chuyển được giai đoạn',
          ),
        ),
      );
    });

    test('máy chủ trả đúng mã → trả cơ hội mới', () async {
      final updated = await container
          .read(opportunityActionsProvider)
          .moveStage(opp, 'da_mua');
      expect(updated.stageCode, 'da_mua');
      expect(api.moved, [('o1', 'da_mua')]);
    });

    test('422 từ máy chủ đi thẳng tới người gọi', () async {
      api.moveError = const ValidationException(
        'Giai đoạn không thuộc quy trình',
        errors: {
          'opportunity_stage': ['Giai đoạn không thuộc quy trình'],
        },
      );
      await expectLater(
        container.read(opportunityActionsProvider).moveStage(opp, 'xyz'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('chuyển xong thì cột cũ và tổng được tải lại', () async {
      await open('lien_he');
      container.listen(pipelineSummaryProvider, (_, _) {});
      await container.read(pipelineSummaryProvider.future);
      final before = (api.calls.length, api.summaryCalls);

      await container.read(opportunityActionsProvider).moveStage(opp, 'tu_van');
      await container.read(stageOpportunitiesProvider('lien_he').future);
      await container.read(pipelineSummaryProvider.future);

      expect(api.calls.length, before.$1 + 1);
      expect(api.summaryCalls, before.$2 + 1);
    });
  });

  test('markWon đọc {opportunity, order_id}', () async {
    final result = await container
        .read(opportunityActionsProvider)
        .markWon('o1');
    expect(result.opportunity.stageCode, 'da_mua');
    expect(result.opportunity.isWon, isTrue);
    expect(result.orderId, 'ord-1');
    expect(result.orderCreated, isTrue);
  });

  group('API chưa có /pipelines', () {
    test('404 → dùng danh mục 6 giai đoạn chuẩn', () async {
      final real = OpportunitiesApi(_NotFoundClient());
      final catalog = await real.pipelines();
      expect(catalog.fromServer, isFalse);
      expect(catalog.defaultPipeline.stages.map((s) => s.code), [
        'new',
        'consulted',
        'quoted',
        'negotiating',
        'won',
        'lost',
      ]);
    });

    test('danh mục dự phòng → không gửi pipeline khi lọc cột', () async {
      api.catalog = PipelineCatalog.legacy;
      await open('new');
      expect(api.calls.single.pipeline, isNull);
    });

    test('lỗi khác 404 không bị nuốt', () async {
      final real = OpportunitiesApi(_NotFoundClient(status: 500));
      await expectLater(real.pipelines(), throwsA(isA<ServerException>()));
    });
  });
}

typedef _ListCall = ({
  String? stageCode,
  String? pipeline,
  bool mine,
  int page,
});

class _FakeOpportunitiesApi extends OpportunitiesApi {
  _FakeOpportunitiesApi() : super(ApiClient(Dio()));

  int total = 3;
  String idPrefix = 'o';

  /// Trang nào đang bị giữ lại (mạng chậm) cho tới khi completer xong.
  final holds = <int, Completer<void>>{};
  PipelineCatalog catalog = PipelineCatalog.fromJson({
    'default': 'ban_le',
    'pipelines': [
      {
        'code': 'ban_le',
        'label': 'Bán lẻ',
        'is_default': true,
        'stages': [
          {'code': 'lien_he', 'outcome': 'open', 'sort_order': 1},
          {'code': 'tu_van', 'outcome': 'open', 'sort_order': 2},
          {'code': 'da_mua', 'outcome': 'won', 'sort_order': 3},
        ],
      },
      {
        'code': 'standard',
        'label': 'Chuẩn',
        'is_default': false,
        'stages': [
          {'code': 'new', 'outcome': 'open', 'sort_order': 1},
        ],
      },
    ],
  });
  final calls = <_ListCall>[];
  Map<String, dynamic> lastQuery = const {};
  int summaryCalls = 0;
  final moved = <(String, String)>[];
  Map<String, dynamic> Function(String code)? moveResult;
  AppException? moveError;

  @override
  Future<PipelineCatalog> pipelines() async => catalog;

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
    lastQuery = OpportunitiesApi.listQuery(
      stageCode: stageCode,
      pipeline: pipeline,
      mine: mine,
      search: search,
      page: page,
      perPage: perPage,
    );
    // Chụp tiền tố LÚC GỬI: trang trả muộn mang dữ liệu của lúc nó được hỏi.
    final prefix = idPrefix;
    await holds[page]?.future;
    final start = (page - 1) * perPage;
    final count = (total - start).clamp(0, perPage);
    return Paged(
      items: [
        for (var i = start; i < start + count; i++)
          Opportunity.fromJson({
            'id': '$prefix$i',
            'title': 'Cơ hội $i',
            'opportunity_stage': stageCode,
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

  @override
  Future<PipelineSummary> summary({String? pipeline, bool mine = false}) async {
    summaryCalls++;
    return const PipelineSummary();
  }

  @override
  Future<Opportunity> moveStage(String id, {required String stageCode}) async {
    if (moveError case final error?) throw error;
    moved.add((id, stageCode));
    return Opportunity.fromJson(
      moveResult?.call(stageCode) ??
          {
            'id': id,
            'opportunity_stage': stageCode,
            'pipeline': 'ban_le',
            'opportunity_status': 'OPEN',
          },
    );
  }

  @override
  Future<WinResult> markWon(String id) async => OpportunitiesApi.parseWin({
    'opportunity': {
      'id': id,
      'opportunity_stage': 'da_mua',
      'pipeline': 'ban_le',
      'opportunity_status': 'WON',
    },
    'order_id': 'ord-1',
    'order_created': true,
  });
}

/// `GET` luôn lỗi theo mã [status] — như API chưa deploy Task 8.
class _NotFoundClient extends ApiClient {
  _NotFoundClient({this.status = 404}) : super(Dio());

  final int status;

  @override
  Future<ApiEnvelope> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    if (status == 404) throw const NotFoundException('Không tìm thấy.');
    throw const ServerException('Lỗi máy chủ', code: '500');
  }
}
