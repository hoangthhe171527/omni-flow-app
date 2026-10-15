import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/assign_task_sheet.dart';
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
    TeamMember(
      membershipId: 'm1',
      userId: 'u1',
      name: 'Hằng Ni',
      jobTitle: 'employee',
    ),
    TeamMember(
      membershipId: 'm2',
      userId: 'u2',
      name: 'Bảo Khánh',
      jobTitle: 'admin',
    ),
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
        teamDirectoryProvider.overrideWith((ref) async => members),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const TaskDetailPage(taskId: 't1'),
      ),
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    // Vòng nét đứt + của dòng "Người làm" (thẻ thông tin).
    await tester.tap(find.byType(OmniDashedCircle));
    await tester.pumpAndSettle();
  }

  group('mở bộ chọn', () {
    testWidgets('chạm vòng + ở dòng "Người làm" là gán được', (tester) async {
      // Chỗ người ta nhìn cũng là chỗ người ta bấm — không phải một nút ở tận
      // đâu khác trên màn.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await openMenu(tester);

      expect(find.byKey(const Key('assign-task-menu')), findsOneWidget);
      expect(find.text('Ai làm việc này'), findsOneWidget);
      expect(find.text('Hằng Ni'), findsOneWidget);
      expect(find.text('Bảo Khánh'), findsOneWidget);
      expect(find.text('Nhân viên'), findsOneWidget);
      expect(find.text('Quản trị viên'), findsOneWidget);
      expect(find.text('employee'), findsNothing);
      expect(find.text('admin'), findsNothing);
    });

    testWidgets('người NHẬN việc chạm dòng Người làm không mở bộ chọn', (
      tester,
    ) async {
      // Bảng điều phối là của người giao việc. Cho thợ thấy nút gán người là
      // mời họ làm một việc API sẽ từ chối.
      await tester.pumpWidget(host(permissions: worker));
      await tester.pumpAndSettle();

      // Thợ VẪN thấy dòng (chỉ đọc), nhưng chạm vào không mở bộ chọn người.
      await tester.tap(find.text('Chưa giao ai'));
      await tester.pumpAndSettle();
      expect(find.text('Ai làm việc này'), findsNothing);
    });

    testWidgets('người đã nghỉ không hiện trong danh sách', (tester) async {
      // Giao việc cho một tài khoản đã ngừng hoạt động là giao vào chỗ không
      // ai nhận.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(find.text('Người đã nghỉ'), findsNothing);
    });
  });

  group('lưu', () {
    testWidgets('chọn hai người thì gửi cả hai id', (tester) async {
      // Một đầu việc thường hai người cùng làm (§B2), nên bộ chọn phải là
      // nhiều-chọn chứ không phải một-chọn.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await openMenu(tester);

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

      await openMenu(tester);
      await tester.tap(find.text('Hằng Ni'));
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

      await openMenu(tester);
      await tester.tap(find.text('Giao cho 1 người'));
      await tester.pumpAndSettle();

      expect(saved, isEmpty);
    });

    testWidgets(
      'allowedIds: chỉ hiện người trong tập; người đang chọn vẫn hiện '
      'để còn gỡ',
      (tester) async {
        List<String>? picked;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              teamDirectoryProvider.overrideWith((ref) async => members),
            ],
            child: MaterialApp(
              theme: OmniTheme.light(TargetPlatform.android),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async => picked = await showAssignTaskSheet(
                      context: context,
                      currentIds: const ['u1'],
                      allowedIds: const {'u2'},
                      title: 'Người thực hiện bản sao',
                      confirmLabel: (n) => 'Chọn $n người',
                    ),
                    child: const Text('mở'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('mở'));
        await tester.pumpAndSettle();

        expect(find.text('Người thực hiện bản sao'), findsOneWidget);
        // u1 ngoài tập nhưng đang được chọn → vẫn hiện; u2 trong tập.
        expect(find.text('Hằng Ni'), findsOneWidget);
        expect(find.text('Bảo Khánh'), findsOneWidget);

        await tester.tap(find.text('Hằng Ni'));
        await tester.pump();
        // Gỡ xong vẫn còn trong danh sách (đang hiện thì không biến mất).
        await tester.tap(find.text('Bảo Khánh'));
        await tester.pump();
        await tester.tap(find.text('Chọn 1 người'));
        await tester.pumpAndSettle();
        expect(picked, ['u2']);
      },
    );

    testWidgets('allowedIds: người ngoài tập, không được chọn → không hiện', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teamDirectoryProvider.overrideWith((ref) async => members),
          ],
          child: MaterialApp(
            theme: OmniTheme.light(TargetPlatform.android),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showAssignTaskSheet(
                    context: context,
                    currentIds: const [],
                    allowedIds: const {'u2'},
                  ),
                  child: const Text('mở'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();

      expect(find.text('Hằng Ni'), findsNothing);
      expect(find.text('Bảo Khánh'), findsOneWidget);
    });

    testWidgets('đóng sheet mà không lưu thì không gọi API', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await openMenu(tester);

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
