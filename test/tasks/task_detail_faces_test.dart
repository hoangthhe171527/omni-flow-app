import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Một màn, hai bộ mặt.
///
/// Người thợ mở công việc để LÀM nó: tên đàn, công đoạn, tick, chụp ảnh.
/// Người quản đốc mở để ĐIỀU nó: ai làm, hạn nào, đang ở công đoạn nào.
/// Cho thợ thấy nút gán người là mời họ làm một việc API sẽ từ chối, và mỗi
/// nút thừa là một chỗ để bấm nhầm khi tay đang bẩn.
void main() {
  // `Formatters.date` dùng DateFormat('vi_VN'), và app nạp dữ liệu locale
  // trong `bootstrap()`. Test không đi qua bootstrap, nên phải tự nạp —
  // không có nó thì bảng điều phối ném LocaleDataException ngay lúc dựng.
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  final task = Task.fromJson({
    'id': 't1',
    'title': 'KAWAI HAT-5 · 2308512',
    'project_id': 'p1',
    'section_id': 's2',
    'due_date': '2026-12-31',
    'priority': 'high',
    'assignee_ids': ['u1'],
    'assignee_names': ['Hằng Ni'],
    'checklist': [
      {'id': 'c1', 'title': 'Tháo dây', 'done': true},
      {'id': 'c2', 'title': 'Nắp phím', 'done': false},
    ],
  });

  Widget host({Set<String> permissions = worker}) => ProviderScope(
    overrides: [
      taskDetailProvider.overrideWith(
        () => _StubDetail(TaskDetailState(task: task)),
      ),
      taskAccessProvider.overrideWithValue(
        TaskAccess.of(AccessPolicy(permissions)),
      ),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const TaskDetailPage(taskId: 't1'),
    ),
  );

  group('người nhận việc', () {
    testWidgets('không thấy bảng điều phối', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('Điều phối'), findsNothing);
      expect(find.text('Nhóm việc'), findsNothing);
    });

    testWidgets('VẪN thấy và tick được công đoạn', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('Tháo dây'), findsOneWidget);
      expect(find.text('Nắp phím'), findsOneWidget);
    });

    testWidgets('vẫn thấy tên đàn và tiến độ', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('KAWAI HAT-5 · 2308512'), findsOneWidget);
      expect(find.textContaining('1/2'), findsOneWidget);
    });
  });

  group('người giao việc', () {
    testWidgets('thấy bảng điều phối', (tester) async {
      await tester.pumpWidget(host(permissions: assigner));
      await tester.pumpAndSettle();

      expect(find.text('Điều phối'), findsOneWidget);
    });

    testWidgets('thấy ai đang làm', (tester) async {
      await tester.pumpWidget(host(permissions: assigner));
      await tester.pumpAndSettle();

      expect(find.text('Hằng Ni'), findsOneWidget);
    });

    testWidgets('dòng "Nhóm việc" bấm được để chuyển — không có nút riêng', (
      tester,
    ) async {
      // Bản trước dòng này trơ và một nút "Chuyển nhóm việc" đứng riêng bên
      // dưới: hai chỗ cho một việc, và là dòng DUY NHẤT trong bảng không bấm
      // được. Cùng quy ước với "Người làm", "Hạn", "Ưu tiên": chỗ người ta
      // nhìn cũng là chỗ người ta bấm.
      await tester.pumpWidget(host(permissions: assigner));
      await tester.pumpAndSettle();

      final row = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('Nhóm việc'),
              matching: find.byType(InkWell),
            )
            .first,
      );

      expect(row.onTap, isNotNull);
      expect(find.text('Chuyển nhóm việc'), findsNothing);
    });

    testWidgets('việc chưa gán ai thì nói rõ, không để trống', (tester) async {
      final unassigned = Task.fromJson({
        'id': 't1',
        'title': 'Chưa gán',
        'checklist': <Map<String, dynamic>>[],
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskDetailProvider.overrideWith(
              () => _StubDetail(TaskDetailState(task: unassigned)),
            ),
            taskAccessProvider.overrideWithValue(
              TaskAccess.of(const AccessPolicy(assigner)),
            ),
          ],
          child: MaterialApp(
            theme: OmniTheme.light(TargetPlatform.android),
            home: const TaskDetailPage(taskId: 't1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Chưa gán ai'),
        findsOneWidget,
        reason:
            'Một ô trống ở chỗ tên người đọc như lỗi tải. "Chưa gán ai" là '
            'câu trả lời, và nó cũng là việc cần làm.',
      );
    });

    // Người nhận việc thấy tình trạng hạn qua chip ở đầu màn. Người giao việc
    // không còn chip đó (nó trùng với bảng điều phối), nên bảng phải tự mang
    // tín hiệu — nếu không họ mất đúng thứ họ mở màn này ra để tìm.
    testWidgets('quá hạn hiện ngay trong bảng điều phối', (tester) async {
      final late_ = Task.fromJson({
        'id': 't1',
        'title': 'Trễ',
        'due_date': '2020-01-01',
        'checklist': <Map<String, dynamic>>[],
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            taskDetailProvider.overrideWith(
              () => _StubDetail(TaskDetailState(task: late_)),
            ),
            taskAccessProvider.overrideWithValue(
              TaskAccess.of(const AccessPolicy(assigner)),
            ),
          ],
          child: MaterialApp(
            theme: OmniTheme.light(TargetPlatform.android),
            home: const TaskDetailPage(taskId: 't1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('quá hạn'), findsOneWidget);
    });

    testWidgets('vẫn tick được công đoạn như thợ', (tester) async {
      await tester.pumpWidget(host(permissions: assigner));
      await tester.pumpAndSettle();

      // Bảng điều phối đẩy danh sách công đoạn xuống dưới mép màn trong khung
      // test 600x800 — nó vẫn ở trong cây, chỉ chưa được vẽ.
      expect(
        find.text('Tháo dây', skipOffstage: false),
        findsOneWidget,
        reason:
            '"Người giao việc" là quyền THÊM, không phải vai thay thế. Quản '
            'đốc cũng tick công đoạn.',
      );
    });
  });
}

/// Trả về một trạng thái cố định, không gọi API.
class _StubDetail extends TaskController {
  _StubDetail(this._state);

  final TaskDetailState _state;

  @override
  Future<TaskDetailState> build(String taskId) async => _state;
}
