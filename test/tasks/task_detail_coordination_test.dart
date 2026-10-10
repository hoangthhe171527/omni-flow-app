import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_detail/coordination_card.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_detail/option_sheet.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Đầu trang + khối ĐIỀU PHỐI của màn chi tiết việc (GĐ5 Task 5).
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};
  const me = 'u9';

  late List<(String, Object?)> recorded;

  Task task({
    String? project,
    String? section,
    List<String> sections = const [],
    List<String> names = const [],
    List<String> ids = const [],
    String priority = 'med',
    int subtasks = 0,
    int done = 0,
    String? due,
    String? description,
  }) => Task.fromJson({
    'id': 't1',
    'title': 'Lên dây đàn U3',
    'project_id': 'p1',
    'project_name': ?project,
    'section_id': section == null ? null : 'sec-$section',
    'section_name': ?section,
    'plan_sections': [
      for (final s in sections) {'id': 'sec-$s', 'name': s},
    ],
    'assignee_ids': ids,
    'assignee_names': names,
    'priority': priority,
    'due_date': ?due,
    'description': ?description,
    'checklist': [
      for (var i = 0; i < subtasks; i++)
        {'id': 'c$i', 'title': 'Việc con $i', 'done': i < done},
    ],
  });

  Widget host({required Task task, required Set<String> perms}) {
    recorded = [];

    return ProviderScope(
      overrides: [
        taskDetailProvider.overrideWith(
          () => _RecordingDetail(TaskDetailState(task: task), recorded),
        ),
        teamDirectoryProvider.overrideWith(
          (ref) async => [
            TeamMember(membershipId: 'm1', userId: 'u1', name: 'Hằng Ni'),
          ],
        ),
        taskAccessProvider.overrideWithValue(
          TaskAccess.of(AccessPolicy(perms)),
        ),
        sessionProvider.overrideWithValue(
          const Session(
            status: SessionStatus.authenticated,
            user: SessionUser(id: me, fullName: 'Thợ Hùng', email: 'h@tnp.vn'),
          ),
        ),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const TaskDetailPage(taskId: 't1'),
      ),
    );
  }

  Future<void> pump(WidgetTester t, Widget app) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app);
    await t.pumpAndSettle();
  }

  testWidgets('đầu trang "Dự án · Nhóm việc" và 4 dòng Điều phối', (t) async {
    await pump(
      t,
      host(
        task: task(
          project: 'Sửa chữa đàn',
          section: 'Đang sửa',
          names: ['Hoàng', 'Minh'],
          priority: 'high',
        ),
        perms: assigner,
      ),
    );
    expect(find.text('Sửa chữa đàn · Đang sửa'), findsOneWidget);
    expect(find.text('ĐIỀU PHỐI'), findsOneWidget);
    for (final k in ['Người làm', 'Hạn', 'Nhóm việc', 'Ưu tiên']) {
      expect(find.text(k), findsOneWidget);
    }
    expect(find.text('Hoàng, Minh'), findsOneWidget);
    expect(find.text('Cao'), findsOneWidget);
  });

  testWidgets('thiếu nhóm việc thì chỉ còn tên dự án', (t) async {
    await pump(
      t,
      host(
        task: task(project: 'Sửa chữa đàn'),
        perms: worker,
      ),
    );
    expect(find.text('Sửa chữa đàn'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets('không có dự án lẫn nhóm việc thì "Chi tiết công việc"', (
    t,
  ) async {
    await pump(t, host(task: task(), perms: worker));
    expect(find.text('Chi tiết công việc'), findsOneWidget);
  });

  testWidgets('người giao việc: chạm Ưu tiên → sheet, chọn Thấp → ghi priority '
      'low', (t) async {
    await pump(
      t,
      host(
        task: task(priority: 'high'),
        perms: assigner,
      ),
    );
    await t.tap(find.text('Ưu tiên'));
    await t.pumpAndSettle();
    expect(find.text('Mức ưu tiên'), findsOneWidget);
    await t.tap(find.text('Thấp'));
    await t.pumpAndSettle();
    expect(recorded.last, ('priority', 'low'));
  });

  testWidgets('ưu tiên "Bình thường" gửi mã API "med"', (t) async {
    await pump(
      t,
      host(
        task: task(priority: 'high'),
        perms: assigner,
      ),
    );
    await t.tap(find.text('Ưu tiên'));
    await t.pumpAndSettle();
    await t.tap(find.text('Bình thường'));
    await t.pumpAndSettle();
    expect(recorded.last, ('priority', 'med'));
  });

  testWidgets('người giao việc: chạm Nhóm việc → "Chuyển nhóm việc" → '
      'moveSection', (t) async {
    await pump(
      t,
      host(
        task: task(section: 'Đang sửa', sections: ['Tiếp nhận', 'Đang sửa']),
        perms: assigner,
      ),
    );
    await t.tap(find.text('Nhóm việc'));
    await t.pumpAndSettle();
    expect(find.text('Chuyển nhóm việc'), findsOneWidget);
    await t.tap(find.text('Tiếp nhận'));
    await t.pumpAndSettle();
    expect(recorded.last, ('section', 'sec-Tiếp nhận'));
  });

  testWidgets('dự án chưa khai báo nhóm việc: sheet nói rõ, không ghi gì', (
    t,
  ) async {
    await pump(t, host(task: task(), perms: assigner));
    await t.tap(find.text('Nhóm việc'));
    await t.pumpAndSettle();
    expect(find.text('Dự án này chưa khai báo nhóm việc nào.'), findsOneWidget);
    expect(recorded, isEmpty);
  });

  testWidgets(
    'người thợ: Hạn/Nhóm việc/Ưu tiên không mở sheet, không mũi tên',
    (t) async {
      await pump(
        t,
        host(
          task: task(names: ['Me'], ids: [me]),
          perms: worker,
        ),
      );
      await t.tap(find.text('Ưu tiên'));
      await t.pumpAndSettle();
      expect(find.text('Mức ưu tiên'), findsNothing);
      await t.tap(find.text('Nhóm việc'));
      await t.pumpAndSettle();
      expect(find.text('Chuyển nhóm việc'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(CoordinationCard),
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(CoordinationCard),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('người thợ chưa có tên: Người làm → "Nhận việc này" → claim', (
    t,
  ) async {
    await pump(t, host(task: task(), perms: worker));
    await t.tap(find.text('Người làm'));
    await t.pumpAndSettle();
    await t.tap(find.text('Nhận việc này'));
    await t.pumpAndSettle();
    expect(recorded.last, ('claim', me));
  });

  testWidgets('người thợ đã có tên mình: Người làm không mở sheet nhận', (
    t,
  ) async {
    await pump(
      t,
      host(
        task: task(names: ['Thợ Hùng'], ids: [me]),
        perms: worker,
      ),
    );
    await t.tap(find.text('Người làm'));
    await t.pumpAndSettle();
    expect(find.text('Nhận việc này'), findsNothing);
  });

  testWidgets('người giao việc: Người làm → "Ai làm việc này"', (t) async {
    await pump(t, host(task: task(), perms: assigner));
    await t.tap(find.text('Người làm'));
    await t.pumpAndSettle();
    expect(find.text('Ai làm việc này'), findsOneWidget);
  });

  testWidgets('việc chưa giao ai / chưa đặt hạn / chưa xếp nhóm nói rõ', (
    t,
  ) async {
    await pump(t, host(task: task(), perms: assigner));
    expect(find.text('Chưa giao ai'), findsOneWidget);
    expect(find.text('Chưa đặt hạn'), findsOneWidget);
    expect(find.text('Chưa xếp nhóm việc'), findsOneWidget);
  });

  testWidgets('hạn quá hạn: "dd/MM · quá hạn n ngày"', (t) async {
    await pump(
      t,
      host(
        task: task(due: '2020-01-01'),
        perms: assigner,
      ),
    );
    expect(find.textContaining('01/01 · quá hạn'), findsOneWidget);
  });

  testWidgets('tiến độ: "Đã xong 2/5 việc con"', (t) async {
    await pump(t, host(task: task(subtasks: 5, done: 2), perms: worker));
    expect(find.text('Đã xong 2/5 việc con'), findsOneWidget);
  });

  testWidgets('dòng Điều phối cao ≥ 44', (t) async {
    await pump(t, host(task: task(), perms: assigner));
    expect(
      t
          .getSize(
            find
                .ancestor(of: find.text('Hạn'), matching: find.byType(InkWell))
                .first,
          )
          .height,
      greaterThanOrEqualTo(44),
    );
  });

  group('Mô tả', () {
    testWidgets(
      'người giao việc: trống → "Thêm mô tả"; thợ + trống → ẩn khối',
      (t) async {
        await pump(t, host(task: task(), perms: assigner));
        expect(find.text('MÔ TẢ'), findsOneWidget);
        expect(find.text('Thêm mô tả'), findsOneWidget);

        await pump(t, host(task: task(), perms: worker));
        expect(find.text('MÔ TẢ'), findsNothing);
      },
    );

    testWidgets('thợ có mô tả: thấy chữ, không sửa được', (t) async {
      await pump(
        t,
        host(
          task: task(description: 'Giữ phím ngà'),
          perms: worker,
        ),
      );
      expect(find.text('Giữ phím ngà'), findsOneWidget);
      await t.tap(find.text('Giữ phím ngà'));
      await t.pumpAndSettle();
      expect(find.text('Lưu'), findsNothing);
    });
  });

  group('Tuỳ chọn công việc (⋯)', () {
    testWidgets('thợ không thấy nút', (t) async {
      await pump(t, host(task: task(), perms: worker));
      expect(find.byTooltip('Tuỳ chọn công việc'), findsNothing);
    });

    testWidgets('người giao việc: "Đổi tên việc" → sheet → ghi title', (
      t,
    ) async {
      await pump(t, host(task: task(), perms: assigner));
      await t.tap(find.byTooltip('Tuỳ chọn công việc'));
      await t.pumpAndSettle();
      await t.tap(find.text('Đổi tên việc'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.autofocus),
        'Lên dây đàn U3 — 4521',
      );
      await t.pump();
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(recorded.last, ('title', 'Lên dây đàn U3 — 4521'));
    });

    testWidgets('người giao việc: "Xoá công việc" hỏi xác nhận trước', (
      t,
    ) async {
      await pump(t, host(task: task(), perms: assigner));
      await t.tap(find.byTooltip('Tuỳ chọn công việc'));
      await t.pumpAndSettle();
      await t.tap(find.text('Xoá công việc'));
      await t.pumpAndSettle();
      expect(
        find.textContaining('Xoá công việc “Lên dây đàn U3”?'),
        findsOneWidget,
      );
    });
  });

  group('showOptionSheet', () {
    testWidgets('trả về chỉ số mục chọn; ✓ ở mục đang chọn; dòng cao 46', (
      t,
    ) async {
      int? picked;
      await t.pumpWidget(
        MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => picked = await showOptionSheet(
                  context,
                  title: 'Chọn',
                  selected: 1,
                  items: const [
                    OptionItem(label: 'A', color: Colors.red),
                    OptionItem(label: 'B', color: Colors.blue, round: true),
                  ],
                ),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        t
            .getSize(
              find
                  .ancestor(of: find.text('A'), matching: find.byType(InkWell))
                  .first,
            )
            .height,
        46,
      );
      await t.tap(find.text('A'));
      await t.pumpAndSettle();
      expect(picked, 0);
    });
  });

  testWidgets('sectionColor lặp vòng 5 màu', (t) async {
    late OmniTaskTones tones;
    await t.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Builder(
          builder: (c) {
            tones = OmniTaskTones.of(c);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tones.sectionColor(0), const Color(0xFF8A95A8));
    expect(tones.sectionColor(4), const Color(0xFF0A7D76));
    expect(tones.sectionColor(5), tones.sectionColor(0));
  });
}

/// Ghi lại mọi lượt ghi mà màn gọi xuống controller.
class _RecordingDetail extends TaskController {
  _RecordingDetail(this._state, this._saved);

  final TaskDetailState _state;
  final List<(String, Object?)> _saved;

  @override
  Future<TaskDetailState> build(String taskId) async => _state;

  @override
  Future<void> setPriority(String priority) async =>
      _saved.add(('priority', priority));

  @override
  Future<void> moveToSection(String? sectionId) async =>
      _saved.add(('section', sectionId));

  @override
  Future<void> claimSelf(String userId) async => _saved.add(('claim', userId));

  @override
  Future<void> setTitle(String title) async => _saved.add(('title', title));

  @override
  Future<void> setAssignees(List<String> userIds) async =>
      _saved.add(('assign', userIds));
}
