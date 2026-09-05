import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_envelope.dart';
import '../../tasks/domain/task.dart';
import '../domain/plan.dart';
import '../domain/team.dart';

/// Đọc cây Team → Kế hoạch → Công việc.
///
/// Ba trong bốn tầng đã có sẵn ở API từ lâu — `projects` mang `sections` và
/// `member_roles`, `tasks` mang `section_id`. App chỉ chưa từng hỏi tới.
class PlansApi {
  PlansApi(this._client);

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
              {'id': 's${i + 1}', 'name': sectionNames[i], 'order': i},
          ],
      },
    );

    return Plan.fromJson(response.object);
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
      query: {'project_id': planId, 'page': page, 'per_page': perPage},
    );

    return Paged(
      items: response.list.map(Task.fromJson).toList(),
      pagination: response.pagination ?? const ApiPagination.empty(),
    );
  }
}

final plansApiProvider = Provider<PlansApi>(
  (ref) => PlansApi(ref.watch(apiClientProvider)),
);
