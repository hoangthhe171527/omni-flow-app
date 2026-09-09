import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';

/// `Task.copyWith` phải chép lại MỌI trường.
///
/// Nó viết tay, nên mỗi lần thêm một trường vào `Task` là một lần có thể quên
/// — và bản trước quên đúng ba trường của tầng nhóm việc: `sectionId`,
/// `sectionName`, `planSections`.
///
/// Hậu quả không nằm ở chỗ dễ đoán, nên không ai nghi tới `copyWith`. Tick một
/// việc con đi qua đây (cập nhật lạc quan), nên chỉ cần tick MỘT cái là
/// `planSections` biến mất, và sheet "Chuyển nhóm việc" từ đó báo "kế hoạch
/// này chưa khai báo nhóm việc nào". Thợ tick xong công đoạn thì hết kéo được
/// cây đàn sang cột kế tiếp — đúng hai thao tác đi liền nhau ở §B2 → §B3.
void main() {
  /// Một công việc điền ĐỦ mọi trường. Bỏ trống trường nào là mất khả năng
  /// phát hiện trường đó bị rơi.
  final full = Task.fromJson({
    'id': 't1',
    'title': 'KAWAI HAT-5 — SN 2308512',
    'description': 'Khách dặn giữ nguyên phím ngà',
    'status': 'in_progress',
    'priority': 'high',
    'project_id': 'p1',
    'project_name': 'Xưởng đàn cơ — 2026-09',
    'section_id': 's2',
    'section_name': 'Đang phục chế',
    'plan_sections': [
      {'id': 's1', 'name': 'Nhập xưởng'},
      {'id': 's2', 'name': 'Đang phục chế'},
    ],
    'assignee_ids': ['u1', 'u2'],
    'assignee_names': ['Hằng Ni', 'Bảo Khánh'],
    'due_date': '2026-12-31',
    'start_date': '2026-09-01',
    'checklist': [
      {'id': 'c1', 'title': 'Tháo máy', 'done': true},
      {'id': 'c2', 'title': 'Body ngoài', 'done': false},
    ],
    'custom_fields': {'serial': '2308512'},
    'attachments_count': 3,
    'comments_count': 4,
    'viewers': [
      {'user_id': 'u9', 'name': 'Quản đốc'},
    ],
  });

  test('không sửa gì thì mọi trường giữ nguyên', () {
    final copy = full.copyWith();

    expect(copy.id, full.id);
    expect(copy.title, full.title);
    expect(copy.description, full.description);
    expect(copy.status, full.status);
    expect(copy.priority, full.priority);
    expect(copy.projectId, full.projectId);
    expect(copy.projectName, full.projectName);
    expect(copy.assigneeIds, full.assigneeIds);
    expect(copy.assigneeNames, full.assigneeNames);
    expect(copy.dueDate, full.dueDate);
    expect(copy.startDate, full.startDate);
    expect(copy.subtasks.length, full.subtasks.length);
    expect(copy.customFields, full.customFields);
    expect(copy.attachmentCount, full.attachmentCount);
    expect(copy.commentCount, full.commentCount);
    expect(copy.viewers.length, full.viewers.length);
  });

  group('ba trường từng bị rơi', () {
    test('sectionId', () {
      expect(full.copyWith().sectionId, 's2');
    });

    test('sectionName — không có nó thì bảng điều phối nói "Chưa xếp"', () {
      expect(full.copyWith().sectionName, 'Đang phục chế');
    });

    test('planSections — không có nó thì KHÔNG chuyển cột được nữa', () {
      // Đây là cái đắt nhất: sheet chuyển nhóm việc lấy danh sách từ chính
      // công việc (để khỏi gọi mạng lần hai), nên mất nó là mất luôn đường đi
      // tiếp của cây đàn.
      final copy = full.copyWith();

      expect(copy.planSections.map((s) => s.id).toList(), ['s1', 's2']);
    });
  });

  test('tick một việc con KHÔNG làm rơi gì khác', () {
    // Đường đi thật của lỗi: cập nhật lạc quan gọi copyWith(subtasks: ...).
    final ticked = full.copyWith(
      subtasks: [
        for (final s in full.subtasks)
          s.id == 'c2' ? s.copyWith(done: true) : s,
      ],
    );

    expect(ticked.subtasks.where((s) => s.done).length, 2);
    expect(ticked.sectionId, full.sectionId);
    expect(ticked.sectionName, full.sectionName);
    expect(ticked.planSections.length, full.planSections.length);
  });

  test('đổi trạng thái cũng vậy', () {
    final done = full.copyWith(status: 'done');

    expect(done.status, 'done');
    expect(done.planSections.length, full.planSections.length);
  });
}
