import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/domain/team.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

/// Bảng công việc phải thấy MỌI cây đàn trong kế hoạch.
///
/// `tasksInPlan` trả về một trang. Bảng gọi nó một lần và vẽ những gì nhận
/// được — 30 việc, vì đó là `AppConfig.defaultPerPage`. Xưởng có khoảng 60
/// cây đàn, nên một nửa biến mất khỏi bảng mà không có dấu hiệu nào: không
/// nút "tải thêm", không con số, không dòng chữ. Quản đốc nhìn một bảng đầy
/// và tưởng mình đã thấy hết.
void main() {
  test('gom hết các trang, không dừng ở trang đầu', () async {
    final api = _PagedApi(total: 137);

    final all = await loadAllTasksInPlan(api, 'p1');

    expect(all.tasks.length, 137);
    expect(all.truncated, isFalse);
    expect(api.pagesFetched, greaterThan(1));
  });

  test('một trang là đủ thì chỉ gọi một lần', () async {
    final api = _PagedApi(total: 12);

    await loadAllTasksInPlan(api, 'p1');

    expect(api.pagesFetched, 1);
  });

  test('kế hoạch rỗng không gọi thêm trang nào', () async {
    final api = _PagedApi(total: 0);

    final all = await loadAllTasksInPlan(api, 'p1');

    expect(all.tasks, isEmpty);
    expect(api.pagesFetched, 1);
  });

  test('có trần, và khi chạm trần thì NÓI RA', () async {
    final api = _PagedApi(total: 5000);

    final all = await loadAllTasksInPlan(api, 'p1');

    expect(all.tasks.length, kMaxTasksOnBoard);
    expect(
      all.truncated,
      isTrue,
      reason:
          'Một kế hoạch 5000 việc là dữ liệu hỏng hoặc một cách dùng khác hẳn. '
          'Nạp hết sẽ treo máy; nạp một phần mà im lặng là nói dối.',
    );
  });

  test('phân trang hỏng giữa chừng vẫn dừng, không lặp vô hạn', () async {
    // API cũ, hoặc lỗi, trả về `last_page` là 0 hoặc pagination rỗng. Vòng lặp
    // phải dừng ở dữ liệu chứ không dựa vào một con số API tự khai.
    final api = _BrokenPagingApi();

    final all = await loadAllTasksInPlan(api, 'p1');

    expect(all.tasks.length, 3);
    expect(api.pagesFetched, lessThan(5));
  });

  test('giữ nguyên thứ tự API trả về', () async {
    final api = _PagedApi(total: 60);

    final all = await loadAllTasksInPlan(api, 'p1');

    // Thứ tự này LÀ thứ tự xưởng đã xếp (`sort=queue`). Sắp lại phía client là
    // bịa ra một hàng đợi khác.
    expect(all.tasks.first.id, 't0');
    expect(all.tasks.last.id, 't59');
  });
}

/// Trả về đúng [total] việc, chia trang theo `perPage` mà chỗ gọi xin.
class _PagedApi implements PlansApi {
  @override
  Future<Plan> updateSections(String planId, List<PlanSection> sections) async {
    throw UnimplementedError();
  }

  _PagedApi({required this.total});

  final int total;
  int pagesFetched = 0;

  @override
  Future<Paged<Task>> tasksInPlan(
    String planId, {
    int page = 1,
    int perPage = 50,
  }) async {
    pagesFetched++;
    final from = (page - 1) * perPage;
    final to = (from + perPage).clamp(0, total);
    final items = [
      for (var i = from; i < to; i++)
        Task.fromJson({'id': 't$i', 'title': 'Cây $i'}),
    ];

    return Paged(
      items: items,
      pagination: ApiPagination(
        currentPage: page,
        perPage: perPage,
        total: total,
        lastPage: (total / perPage).ceil().clamp(1, 1 << 30),
      ),
    );
  }

  @override
  Future<WorkshopKpi> kpi({String? planId}) async =>
      WorkshopKpi.fromJson(const {});

  @override
  Future<List<FeedEntry>> feed({int limit = 30}) async => const [];

  @override
  Future<List<Team>> teams() async => const [];
  @override
  Future<List<Plan>> plans({String? teamId}) async => const [];
  @override
  Future<Plan> plan(String id) async => Plan.fromJson({'id': id, 'name': 'X'});
  @override
  Future<Team> createTeam({required String name, String? description}) async =>
      Team.fromJson({'id': 't', 'name': name});
  @override
  Future<Plan> createPlan({
    required String name,
    String? teamId,
    List<String> sectionNames = const [],
    Set<String> gatedSectionNames = const {},
  }) async => Plan.fromJson({'id': 'p', 'name': name});
}

/// Khai `last_page` sai, và trả về trang rỗng sau trang đầu.
class _BrokenPagingApi extends _PagedApi {
  _BrokenPagingApi() : super(total: 3);

  @override
  Future<Paged<Task>> tasksInPlan(
    String planId, {
    int page = 1,
    int perPage = 50,
  }) async {
    pagesFetched++;

    return Paged(
      items: page == 1
          ? [
              for (var i = 0; i < 3; i++)
                Task.fromJson({'id': 't$i', 'title': 'Cây $i'}),
            ]
          : const [],
      // last_page = 99: API nói còn 98 trang nữa, nhưng không trả về gì.
      pagination: const ApiPagination(
        currentPage: 1,
        perPage: 50,
        total: 4950,
        lastPage: 99,
      ),
    );
  }
}
