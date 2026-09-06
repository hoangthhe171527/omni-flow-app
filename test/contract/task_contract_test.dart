import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/team.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

/// Hợp đồng giữa app và API, đo trên PHẢN HỒI THẬT.
///
/// App đã ba lần đoán một tên trường mà API không gửi:
///
///   - `assignee_names` — chưa từng được sinh ra
///   - `tasks_count`/`done_count`/`overdue_count` — API gói trong `stats`
///   - `project_name` — chưa từng được gửi
///
/// Cả ba đều IM LẶNG. Không lỗi biên dịch, không lỗi lúc chạy, không dòng log:
/// giá trị chỉ là null hoặc 0 mãi mãi. Và test cũ cũng xanh, vì chúng dựng dữ
/// liệu bằng chính những cái tên đã đoán sai.
///
/// Bài này đọc các bản ghi trong `test/contract/fixtures/`, được chép NGUYÊN
/// VĂN từ phản hồi thật của API (xem `tool/capture_contract.sh`). Nó không
/// chứng minh app hiển thị đúng — nó chứng minh app ĐỌC ĐƯỢC những gì API
/// thật sự gửi, và đó là chỗ ba lỗi trên đã lọt qua.
void main() {
  Map<String, dynamic> load(String name) {
    final file = File('test/contract/fixtures/$name.json');

    expect(
      file.existsSync(),
      isTrue,
      reason:
          'Thiếu bản ghi $name.json. Chạy tool/capture_contract.sh với một '
          'API đang chạy để chép lại phản hồi thật.',
    );

    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> listOf(Map<String, dynamic> envelope) =>
      (envelope['data'] as List).cast<Map<String, dynamic>>();

  group('GET /tasks', () {
    test('mọi trường màn hình dựa vào đều có mặt và đọc được', () {
      final rows = listOf(load('tasks_index'));
      expect(rows, isNotEmpty, reason: 'Bản ghi rỗng thì không kiểm được gì.');

      final task = Task.fromJson(rows.first);

      expect(task.id, isNotEmpty);
      expect(task.title, isNotEmpty);
      // Ba trường đã từng im lặng null:
      expect(task.assigneeNames, isNotEmpty);
      expect(task.projectName, isNotNull);
      expect(task.sectionName, isNotNull);
    });

    test('dòng danh sách KHÔNG mang theo danh sách công đoạn', () {
      // 50 việc × 5 công đoạn là 250 bản sao cùng một mảng trên mỗi trang.
      final task = Task.fromJson(listOf(load('tasks_index')).first);

      expect(task.planSections, isEmpty);
    });

    test('phân trang đọc được, vì bảng dựa vào nó để gom hết các trang', () {
      final pagination =
          load('tasks_index')['pagination'] as Map<String, dynamic>;

      expect(pagination['per_page'], isA<int>());
      expect(pagination['total'], isA<int>());
    });
  });

  group('GET /tasks/{id}', () {
    test('chi tiết mang thêm những gì danh sách không mang', () {
      final task = Task.fromJson(
        load('tasks_show')['data'] as Map<String, dynamic>,
      );

      expect(task.subtasks, isNotEmpty, reason: 'checklist');
      expect(task.planSections, isNotEmpty, reason: 'cho sheet chuyển công đoạn');
    });

    test('người đã xem có TÊN, không phải một UUID trần', () {
      final task = Task.fromJson(
        load('tasks_show')['data'] as Map<String, dynamic>,
      );

      if (task.viewers.isEmpty) return;

      final viewer = task.viewers.first;
      expect(
        viewer.name,
        isNotNull,
        reason:
            'TaskViewer.label rơi về userId khi thiếu tên, nên một UUID hiện '
            'lên màn hình thay cho tên người thợ.',
      );
    });
  });

  group('GET /projects', () {
    test('số liệu kế hoạch nằm trong `stats`, không rải phẳng', () {
      final rows = listOf(load('projects_index'));
      expect(rows, isNotEmpty);

      final plan = Plan.fromJson(rows.first);

      // Đây chính là chỗ bản đầu đoán `tasks_count` và mọi kế hoạch hiện
      // "Chưa có việc nào" dù có 5 cây đàn.
      expect(plan.taskCount, greaterThan(0));
      expect(rows.first['stats'], isA<Map>());
    });

    test('nhóm việc đọc được, kèm cờ cổng QC', () {
      final plan = Plan.fromJson(listOf(load('projects_index')).first);

      expect(plan.sections, isNotEmpty);
      expect(plan.sections.first.id, isNotEmpty);
    });

    test('vai trong kế hoạch nằm trong bốn giá trị API định nghĩa', () {
      final raw = listOf(load('projects_index')).first;
      final roles = (raw['member_roles'] as Map?)?.values ?? const [];

      for (final role in roles) {
        expect(
          const {'owner', 'manager', 'member', 'viewer'},
          contains('$role'),
          reason:
              'PlanRole.parse rơi về viewer với giá trị lạ — an toàn, nhưng '
              'nếu API thêm vai mới thì cả một nhóm người mất quyền trong im '
              'lặng.',
        );
      }
    });
  });

  group('GET /teams', () {
    test('team đọc được', () {
      final rows = listOf(load('teams_index'));
      expect(rows, isNotEmpty);

      final team = Team.fromJson(rows.first);

      expect(team.id, isNotEmpty);
      expect(team.name, isNotEmpty);
    });
  });
}
