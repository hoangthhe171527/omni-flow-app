import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Giao việc ngay trên điện thoại.
///
/// Trước đây dòng "Người làm" chỉ ĐỌC được: muốn giao việc phải mở máy tính.
/// Người giao việc ở xưởng thì đứng giữa nhà xưởng, nên một thao tác chỉ làm
/// được ở chỗ họ không đứng thì thực tế là không có.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  Task taskWith(List<String> ids, List<String> names) => Task.fromJson({
    'id': 't1',
    'title': 'KAWAI HAT-5 · 2308512',
    'project_id': 'p1',
    'section_id': 's2',
    'assignee_ids': ids,
    'assignee_names': names,
  });

  final members = [
    TeamMember(membershipId: 'm1', userId: 'u1', name: 'Hằng Ni'),
    TeamMember(membershipId: 'm2', userId: 'u2', name: 'Bảo Khánh'),
    TeamMember(
      membershipId: 'm3',
      userId: 'u3',
      name: 'Người đã nghỉ',
      status: 'inactive',
    ),
  ];

  late List<List<String>> saved;

  Widget host({
    Set<String> permissions = assigner,
    List<String> ids = const [],
    List<String> names = const [],
  }) {
    saved = [];

    return ProviderScope(
      overrides: [
        taskDetailProvider.overrideWith(
          () => _RecordingDetail(
            TaskDetailState(task: taskWith(ids, names)),
            saved,
          ),
        ),
        taskAccessProvider.overrideWithValue(
          TaskAccess.of(AccessPolicy(permissions)),
        ),
        teamMembersProvider.overrideWith((ref) async => members),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const TaskDetailPage(taskId: 't1'),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Chưa gán ai'));
    await tester.pumpAndSettle();
  }

  group('mở bộ chọn', () {
    testWidgets('chạm vào chính dòng "Chưa gán ai" là gán được', (
      tester,
    ) async {
      // Chỗ người ta nhìn cũng là chỗ người ta bấm — không phải một nút ở tận
      // đâu khác trên màn.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await openSheet(tester);

      expect(find.text('Ai làm việc này'), findsOneWidget);
      expect(find.text('Hằng Ni'), findsOneWidget);
      expect(find.text('Bảo Khánh'), findsOneWidget);
    });

    testWidgets('người NHẬN việc không thấy dòng gán', (tester) async {
      // Bảng điều phối là của người giao việc. Cho thợ thấy nút gán người là
      // mời họ làm một việc API sẽ từ chối.
      await tester.pumpWidget(host(permissions: worker));
      await tester.pumpAndSettle();

      expect(find.text('Chưa gán ai'), findsNothing);
    });

    testWidgets('người đã nghỉ không hiện trong danh sách', (tester) async {
      // Giao việc cho một tài khoản đã ngừng hoạt động là giao vào chỗ không
      // ai nhận.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await openSheet(tester);

      expect(find.text('Người đã nghỉ'), findsNothing);
    });
  });

  group('lưu', () {
    testWidgets('chọn hai người thì gửi cả hai id', (tester) async {
      // Một đầu việc thường hai người cùng làm (§B2), nên bộ chọn phải là
      // nhiều-chọn chứ không phải một-chọn.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.tap(find.text('Hằng Ni'));
      await tester.pump();
      await tester.tap(find.text('Bảo Khánh'));
      await tester.pump();
      await tester.tap(find.text('Giao cho 2 người'));
      await tester.pumpAndSettle();

      expect(saved, [
        ['u1', 'u2'],
      ]);
    });

    testWidgets('bỏ chọn hết là một lựa chọn hợp lệ, không phải huỷ', (
      tester,
    ) async {
      // Trả việc về hàng đợi chung để ai rảnh tự nhận — mô hình pull-based ở
      // §3. Nút phải nói ra điều đó, chứ không im lặng như một lần bấm nhầm.
      await tester.pumpWidget(host(ids: ['u1'], names: ['Hằng Ni']));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hằng Ni').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hằng Ni').last);
      await tester.pump();

      expect(find.text('Bỏ gán tất cả'), findsOneWidget);

      await tester.tap(find.text('Bỏ gán tất cả'));
      await tester.pumpAndSettle();

      expect(saved, [<String>[]]);
    });

    testWidgets('lưu lại đúng danh sách cũ thì KHÔNG gọi API', (tester) async {
      // Một lượt ghi rỗng vẫn chạm updated_at và đẻ ra một dòng nhật ký hoạt
      // động nói rằng có người đổi phân công — trong khi không ai đổi gì.
      await tester.pumpWidget(host(ids: ['u1'], names: ['Hằng Ni']));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hằng Ni').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giao cho 1 người'));
      await tester.pumpAndSettle();

      expect(saved, isEmpty);
    });

    testWidgets('đóng sheet mà không lưu thì không gọi API', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await openSheet(tester);

      await tester.tap(find.text('Hằng Ni'));
      await tester.pump();
      // Chạm ra ngoài sheet = đóng lại.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(saved, isEmpty);
    });
  });
}

class _RecordingDetail extends TaskController {
  _RecordingDetail(this._state, this._saved);

  final TaskDetailState _state;
  final List<List<String>> _saved;

  @override
  Future<TaskDetailState> build(String taskId) async => _state;

  @override
  Future<void> setAssignees(List<String> userIds) async {
    _saved.add(userIds);
  }
}
