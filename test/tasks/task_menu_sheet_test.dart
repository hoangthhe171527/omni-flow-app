import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Menu việc (`TaskMenu.dc.html`): sheet ba nhóm theo quyền, chuyển việc hai
/// bước, lưu trữ rồi rời màn. Mục Nhóm 2 không bao giờ hiện với API cũ.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const worker = {'tasks.read', 'tasks.write', 'system_options.read'};
  const assigner = {
    'tasks.read',
    'tasks.write',
    'tasks.projects.manage.all',
    'system_options.read',
  };

  late List<(String, Object?)> recorded;
  late List<Object?> clipboard;
  var clipboardFails = false;

  Widget host({Set<String> perms = assigner, bool archived = false}) {
    recorded = [];
    final task = Task.fromJson({
      'id': 't1',
      'title': 'YAMAHA U3E',
      'project_id': 'A',
      'section_id': 'a1',
      'archived': archived,
      'checklist': <Map<String, dynamic>>[],
    });

    return ProviderScope(
      overrides: [
        taskDetailProvider.overrideWith(
          () => _Detail(TaskDetailState(task: task), recorded),
        ),
        tasksApiProvider.overrideWithValue(_PlansApi()),
        planCustomFieldsProvider.overrideWith((ref, id) async => const []),
        taskLabelsProvider.overrideWith((ref) async => const []),
        taskAccessProvider.overrideWithValue(
          TaskAccess.of(AccessPolicy(perms)),
        ),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TaskDetailPage(taskId: 't1'),
                  ),
                ),
                child: const Text('Mở việc'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester t, Widget app) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    clipboard = [];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          if (clipboardFails) throw PlatformException(code: 'denied');
          clipboard.add((call.arguments as Map)['text']);
        }
        return null;
      },
    );
    await t.pumpWidget(app);
    await t.tap(find.text('Mở việc'));
    await t.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester t) async {
    await t.tap(find.byTooltip('Tuỳ chọn công việc'));
    await t.pumpAndSettle();
  }

  const group2 = [
    'Người theo dõi',
    'Nhắc việc',
    'Sao chép công việc',
    'Khoá công việc',
  ];

  testWidgets('(i) người giao việc: Nhãn, Đổi tên, Chuyển, Lưu trữ, Xoá', (
    t,
  ) async {
    await open(t, host());
    await openMenu(t);
    for (final label in [
      'Nhãn màu',
      'Đổi tên việc',
      'Chuyển sang nhóm / kế hoạch khác',
      'Lưu trữ',
      'Xoá công việc',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    for (final label in group2) {
      expect(find.text(label), findsNothing, reason: label);
    }
    // Ba nhóm `.og`, mục cao 50.
    expect(find.byKey(const Key('detail-menu-group-2')), findsOneWidget);
    expect(
      t
          .getSize(
            find
                .ancestor(
                  of: find.text('Lưu trữ'),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .height,
      greaterThanOrEqualTo(50),
    );
  });

  testWidgets('(i) thợ: chỉ có Nhãn màu và Sao chép liên kết', (t) async {
    await open(t, host(perms: worker));
    await openMenu(t);
    expect(find.text('Nhãn màu'), findsOneWidget);
    expect(find.text('Sao chép liên kết'), findsOneWidget);
    for (final label in [
      'Đổi tên việc',
      'Chuyển sang nhóm / kế hoạch khác',
      'Lưu trữ',
      'Xoá công việc',
      ...group2,
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }
  });

  testWidgets('thợ không đọc được nhãn: ⋯ chỉ còn "Sao chép liên kết"', (
    t,
  ) async {
    await open(t, host(perms: {'tasks.read', 'tasks.write'}));
    await openMenu(t);
    expect(find.text('Sao chép liên kết'), findsOneWidget);
    expect(find.text('Nhãn màu'), findsNothing);
  });

  testWidgets('"Sao chép liên kết" ở nhóm 2, sau "Chuyển sang…"', (t) async {
    await open(t, host());
    await openMenu(t);
    final group = find.byKey(const Key('detail-menu-group-1'));
    final move = t.getTopLeft(
      find.descendant(
        of: group,
        matching: find.text('Chuyển sang nhóm / kế hoạch khác'),
      ),
    );
    final link = t.getTopLeft(
      find.descendant(of: group, matching: find.text('Sao chép liên kết')),
    );
    expect(link.dy, greaterThan(move.dy));
  });

  testWidgets('thợ: "Sao chép liên kết" chép link web my-work, báo đã chép', (
    t,
  ) async {
    await open(t, host(perms: worker));
    await openMenu(t);
    await t.tap(find.text('Sao chép liên kết'));
    await t.pumpAndSettle();
    expect(clipboard, [
      'https://omni.app.sunriseieco.vn/projects/my-work?task=t1',
    ]);
    expect(find.text('Đã sao chép liên kết.'), findsOneWidget);
    expect(recorded, isEmpty);
  });

  testWidgets('chép liên kết lỗi: báo không chép được', (t) async {
    clipboardFails = true;
    addTearDown(() => clipboardFails = false);
    await open(t, host());
    await openMenu(t);
    await t.tap(find.text('Sao chép liên kết'));
    await t.pumpAndSettle();
    expect(clipboard, isEmpty);
    expect(find.text('Không sao chép được liên kết.'), findsOneWidget);
  });

  testWidgets('(j) chuyển sang kế hoạch B, nhóm "Đang xử lý"', (t) async {
    await open(t, host());
    await openMenu(t);
    await t.tap(find.text('Chuyển sang nhóm / kế hoạch khác'));
    await t.pumpAndSettle();
    expect(find.text('Kế hoạch A'), findsOneWidget);
    await t.tap(find.text('Kế hoạch B'));
    await t.pumpAndSettle();
    await t.tap(find.text('Đang xử lý'));
    await t.pumpAndSettle();
    expect(recorded.last, ('move', ('B', 's2')));
    expect(find.text('Đã chuyển công việc.'), findsOneWidget);
  });

  testWidgets('(j) chọn đúng chỗ đang ở thì không gửi gì', (t) async {
    await open(t, host());
    await openMenu(t);
    await t.tap(find.text('Chuyển sang nhóm / kế hoạch khác'));
    await t.pumpAndSettle();
    await t.tap(find.text('Kế hoạch A'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tiếp nhận'));
    await t.pumpAndSettle();
    expect(recorded, isEmpty);
  });

  testWidgets('(k) Lưu trữ gửi archived:true rồi rời màn', (t) async {
    await open(t, host());
    await openMenu(t);
    await t.tap(find.text('Lưu trữ'));
    await t.pumpAndSettle();
    expect(recorded.last, ('archived', true));
    expect(find.byType(TaskDetailPage), findsNothing);
    expect(find.text('Đã lưu trữ.'), findsOneWidget);
  });

  testWidgets('việc đã lưu trữ: "Bỏ lưu trữ" gửi false, ở lại màn', (t) async {
    await open(t, host(archived: true));
    await openMenu(t);
    expect(find.text('Lưu trữ'), findsNothing);
    await t.tap(find.text('Bỏ lưu trữ'));
    await t.pumpAndSettle();
    expect(recorded.last, ('archived', false));
    expect(find.byType(TaskDetailPage), findsOneWidget);
  });

  testWidgets('Nhãn màu từ menu mở sheet nhãn', (t) async {
    await open(t, host(perms: worker));
    await openMenu(t);
    await t.tap(find.text('Nhãn màu'));
    await t.pumpAndSettle();
    expect(find.text('Xong'), findsOneWidget);
  });
}

class _PlansApi implements TasksApi {
  @override
  Future<List<MovablePlan>> projectsForMove() async => [
    (
      id: 'A',
      name: 'Kế hoạch A',
      teamId: null,
      teamName: null,
      ownerId: null,
      memberRoles: const {},
      sections: const [TaskSection(id: 'a1', name: 'Tiếp nhận')],
    ),
    (
      id: 'B',
      name: 'Kế hoạch B',
      teamId: null,
      teamName: null,
      ownerId: null,
      memberRoles: const {},
      sections: const [
        TaskSection(id: 's1', name: 'Tiếp nhận B'),
        TaskSection(id: 's2', name: 'Đang xử lý'),
      ],
    ),
  ];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Detail extends TaskController {
  _Detail(this._state, this._saved);

  final TaskDetailState _state;
  final List<(String, Object?)> _saved;

  @override
  Future<TaskDetailState> build(String taskId) async => _state;

  @override
  Future<void> moveTask({required String projectId, String? sectionId}) async =>
      _saved.add(('move', (projectId, sectionId)));

  @override
  Future<void> setArchived(bool archived) async {
    _saved.add(('archived', archived));
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        task: Task.fromJson({
          'id': current.task.id,
          'title': current.task.title,
          'project_id': current.task.projectId,
          'archived': archived,
        }),
      ),
    );
  }
}
