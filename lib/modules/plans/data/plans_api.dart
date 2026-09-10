import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../tasks/domain/task.dart';
import '../domain/plan.dart';
import '../domain/feed_entry.dart';
import '../domain/workshop_kpi.dart';
import '../domain/team.dart';

/// Đọc cây Team → Kế hoạch → Công việc.
///
/// Ba trong bốn tầng đã có sẵn ở API từ lâu — `projects` mang `sections` và
/// `member_roles`, `tasks` mang `section_id`. App chỉ chưa từng hỏi tới.
class PlansApi {
  PlansApi(this._client);

  static const _tasks = '/tasks';

  final ApiClient _client;

  Future<List<Team>> teams() async {
    final response = await _client.get(
      '/teams',
      query: {'per_page': AppConfig.defaultPerPage},
    );

    return response.list.map(Team.fromJson).toList();
  }

  /// Kế hoạch, tuỳ chọn lọc theo team.
  ///
  /// Bỏ trống [teamId] thì trả về TẤT CẢ, kể cả kế hoạch chưa thuộc team nào —
  /// mọi kế hoạch tạo trước tầng Team đều vậy, và giấu chúng đi nghĩa là công
  /// việc đang chạy biến mất khỏi app.
  Future<List<Plan>> plans({String? teamId}) async {
    final response = await _client.get(
      '/projects',
      query: {
        if (teamId != null && teamId.isNotEmpty) 'team_id': teamId,
        'per_page': AppConfig.defaultPerPage,
      },
    );

    return response.list.map(Plan.fromJson).toList();
  }

  Future<Team> createTeam({required String name, String? description}) async {
    final response = await _client.post(
      '/teams',
      body: {
        'name': name,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );

    return Team.fromJson(response.object);
  }

  /// Tạo một kế hoạch, kèm các nhóm việc của nó.
  ///
  /// Nhóm việc đi cùng lúc tạo chứ không thêm sau: một kế hoạch không có công
  /// đoạn nào là một bảng chỉ có một cột, và người tạo sẽ phải quay lại làm
  /// nốt việc mà lẽ ra form đã hỏi xong.
  Future<Plan> createPlan({
    required String name,
    String? teamId,
    List<String> sectionNames = const [],
    Set<String> gatedSectionNames = const {},
  }) async {
    final response = await _client.post(
      '/projects',
      body: {
        'name': name,
        if (teamId != null && teamId.isNotEmpty) 'team_id': teamId,
        if (sectionNames.isNotEmpty)
          'sections': [
            for (var i = 0; i < sectionNames.length; i++)
              // Id do client sinh, và API nhận nguyên: `section_id` trên công
              // việc trỏ vào chính những id này, nên chúng phải ổn định trong
              // suốt vòng đời kế hoạch.
              {
                'id': 's${i + 1}',
                'name': sectionNames[i],
                'order': i,
                // Cổng QC là DỮ LIỆU trên từng công đoạn, không phải một vị
                // trí API suy ra. Gửi cờ chỉ khi bật: một `false` tường minh
                // trên mọi công đoạn làm tài liệu to ra mà không nói gì thêm.
                if (gatedSectionNames.contains(sectionNames[i]))
                  'requires_checklist': true,
              },
          ],
      },
    );

    return Plan.fromJson(response.object);
  }

  /// Đặt lại danh sách nhóm việc của một kế hoạch đã có.
  ///
  /// Nhóm việc trước đây chỉ khai được LÚC TẠO, nên một cái tên gõ nhầm hay
  /// một quy trình đổi đi là phải tạo lại cả kế hoạch — mà công việc thì đã
  /// nằm trong đó rồi.
  ///
  /// Id GIỮ NGUYÊN với nhóm đã có: `section_id` trên từng công việc trỏ vào
  /// chính những id này. Sinh id mới cho một nhóm chỉ đổi tên là làm mọi công
  /// việc trong đó rơi về cột đầu.
  ///
  /// Nhóm mới nhận id chưa từng dùng trong kế hoạch này — không dùng lại id
  /// của nhóm vừa xoá, vì công việc cũ vẫn đang trỏ vào đó.
  Future<Plan> updateSections(String planId, List<PlanSection> sections) async {
    final response = await _client.put(
      '/projects/$planId',
      body: {
        'sections': [
          for (var i = 0; i < sections.length; i++)
            {
              'id': sections[i].id,
              'name': sections[i].name,
              'order': i,
              if (sections[i].requiresChecklist) 'requires_checklist': true,
              if (sections[i].countsForKpi) 'counts_for_kpi': true,
            },
        ],
      },
    );

    return Plan.fromJson(response.object);
  }

  /// "Tháng này xong bao nhiêu cây, còn bao xa tới mốc thưởng."
  ///
  /// Bỏ trống [planId] thì tính trên toàn bộ tenant — đúng cách xưởng đếm,
  /// vì thưởng theo TEAM chứ không theo từng kế hoạch (§1 tài liệu xưởng).
  /// [month] là ngày bất kỳ trong tháng cần xem; bỏ trống là tháng đang chạy.
  ///
  /// Gửi dạng `YYYY-MM-01` chứ không gửi cả ngày giờ: server tự lấy đầu tháng
  /// theo giờ xưởng, và một chuỗi mang giờ UTC của máy người dùng có thể rơi
  /// sang tháng bên cạnh — 2026-10-01T00:00 giờ Việt Nam là 2026-09-30 theo
  /// UTC, và cả thẻ KPI sẽ trả lời cho tháng trước.
  Future<WorkshopKpi> kpi({String? planId, DateTime? month}) async {
    final response = await _client.get(
      '$_tasks/kpi',
      query: {
        if (planId != null && planId.isNotEmpty) 'project_id': planId,
        if (month != null)
          'month':
              '${month.year.toString().padLeft(4, '0')}-'
              '${month.month.toString().padLeft(2, '0')}-01',
      },
    );

    return WorkshopKpi.fromJson(response.object);
  }

  /// Dòng thời gian của cả xưởng, mới nhất trước.
  Future<List<FeedEntry>> feed({int limit = 30}) async {
    // `$_tasks/feed`, không phải `/feed`. Bản đầu viết thiếu tiền tố và gọi
    // vào `/api/v1/feed` — một đường dẫn không tồn tại. Test hợp đồng không
    // bắt được vì nó đọc bản ghi từ FILE: nó kiểm hình dạng phản hồi, không
    // kiểm địa chỉ đã gửi đi. Xem `plans_api_paths_test.dart`.
    final response = await _client.get('$_tasks/feed', query: {'limit': limit});

    return response.list.map(FeedEntry.fromJson).toList();
  }

  Future<Plan> plan(String id) async {
    final response = await _client.get('/projects/$id');

    return Plan.fromJson(response.object);
  }

  /// Công việc trong một kế hoạch, theo thứ tự bảng.
  ///
  /// Lọc theo `project_id` cũng chính là thứ làm API sắp theo `order` rồi
  /// `created_at` thay vì theo ngày tạo giảm dần — xem nhánh trong
  /// `MongoTaskRepository::paginate()`. Thứ tự đó LÀ thứ tự xưởng đã xếp, nên
  /// đừng sắp lại phía client.
  Future<Paged<Task>> tasksInPlan(
    String planId, {
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    final response = await _client.get(
      '/tasks',
      query: {
        'project_id': planId,
        'page': page,
        'per_page': perPage,
        // Tường minh, dù lọc theo project_id đã ngầm cho ra thứ tự này. Một
        // hợp đồng ngầm là thứ đã hỏng một lần rồi: `assignee=me` từng được
        // ghi trong comment là "resolved server-side" cho một hành vi chưa
        // bao giờ tồn tại.
        'sort': 'queue',
      },
    );

    return Paged(
      items: response.list.map(Task.fromJson).toList(),
      pagination: response.pagination ?? const ApiPagination.empty(),
    );
  }
}

/// Số việc tối đa bảng nạp về.
///
/// Xưởng piano có khoảng 60 cây đàn đang chạy; 500 là chỗ để lớn gấp tám lần
/// mà vẫn có trần. Vượt trần không phải "kế hoạch to" mà là dữ liệu hỏng hoặc
/// một cách dùng khác hẳn — và lúc đó bảng phải NÓI RA thay vì lặng lẽ vẽ một
/// phần.
const kMaxTasksOnBoard = 500;

/// Trang xin mỗi lượt. 100 là trần API (`min($perPage, 100)`), nên đây là số
/// lượt đi mạng ít nhất có thể.
const _pageSize = 100;

/// Mọi việc trong một kế hoạch, đã gom hết các trang.
typedef PlanTasks = ({List<Task> tasks, bool truncated});

/// Nạp TẤT CẢ việc của một kế hoạch, không chỉ trang đầu.
///
/// Bảng trước đây gọi [PlansApi.tasksInPlan] đúng một lần và vẽ những gì nhận
/// được — 30 việc, vì đó là `AppConfig.defaultPerPage`. Xưởng có khoảng 60 cây
/// đàn, nên một nửa biến mất khỏi bảng mà KHÔNG có dấu hiệu nào: không nút tải
/// thêm, không con số, không dòng chữ. Quản đốc nhìn một bảng đầy và tưởng
/// mình đã thấy hết.
///
/// Nạp hết chứ không cuộn-vô-tận vì bảng chia theo cột: một việc chưa nạp là
/// một cột hiện sai số lượng, và không ai cuộn tới nó để phát hiện ra.
Future<PlanTasks> loadAllTasksInPlan(PlansApi api, String planId) async {
  final all = <Task>[];
  var reachedEnd = false;

  for (var page = 1; all.length < kMaxTasksOnBoard; page++) {
    final result = await api.tasksInPlan(
      planId,
      page: page,
      perPage: _pageSize,
    );
    all.addAll(result.items);

    // Dừng theo DỮ LIỆU nhận được, không theo `last_page` API tự khai. Một
    // API cũ hoặc lỗi có thể khai còn 98 trang rồi trả về rỗng, và tin nó là
    // lặp vô hạn.
    if (result.items.length < _pageSize) {
      reachedEnd = true;
      break;
    }
  }

  // Hai lý do vòng lặp kết thúc, và chỉ MỘT trong hai nghĩa là đã thấy hết.
  // Bản đầu suy `truncated` từ `all.length > trần` — nhưng vòng lặp dừng ĐÚNG
  // ở trần, nên điều kiện đó không bao giờ đúng và cái trần im lặng cắt dữ
  // liệu. Đúng thứ hàm này ra đời để ngăn.
  return (
    tasks: all.length > kMaxTasksOnBoard
        ? all.sublist(0, kMaxTasksOnBoard)
        : all,
    truncated: !reachedEnd,
  );
}

final plansApiProvider = Provider<PlansApi>(
  (ref) => PlansApi(ref.watch(apiClientProvider)),
);
