import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/presentation/archived_tasks_page.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/tasks.dart';
import 'package:omni_app/modules/tasks/tasks_module.dart';

/// Việc đã lưu trữ của một kế hoạch (Task 7): danh sách `archived=archived`,
/// "Khôi phục" gửi `archived:false` rồi dòng biến mất, chạm mở chi tiết.
void main() {
  const planId = 'p1';

  Task task(String id, String title) =>
      Task.fromJson({'id': id, 'title': title, 'archived': true});

  late _ArchiveApi api;

  Future<void> pump(
    WidgetTester tester, {
    bool canRestore = true,
    List<Task>? archived,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api = _ArchiveApi(archived ?? [task('t1', 'Đàn A'), task('t2', 'Đàn B')]);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              ArchivedTasksPage(planId: planId, canRestore: canRestore),
        ),
        GoRoute(
          path: '/tasks/:id',
          name: TasksModule.detail,
          builder: (_, state) =>
              Scaffold(body: Text('chi tiet ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksApiProvider.overrideWithValue(api),
          planTasksProvider.overrideWith(
            (ref, id) async => (tasks: <Task>[], truncated: false),
          ),
        ],
        child: MaterialApp.router(
          theme: OmniTheme.light(TargetPlatform.android),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('liệt kê việc lưu trữ bằng TaskCard, gọi list(archived)', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Việc đã lưu trữ'), findsOneWidget);
    expect(find.byType(TaskCard), findsNWidgets(2));
    expect(find.text('Đàn A'), findsOneWidget);
    expect(api.lists.first, (planId, TaskArchiveScope.archived, 1));
  });

  testWidgets('(a) "Khôi phục" gửi archived:false và dòng biến mất', (
    tester,
  ) async {
    await pump(tester);

    final restore = find.bySemanticsLabel('Khôi phục Đàn A');
    expect(restore, findsOneWidget);
    expect(tester.getSize(restore).height, greaterThanOrEqualTo(44));
    await tester.tap(restore);
    await tester.pumpAndSettle();

    expect(api.archives, [('t1', false)]);
    expect(find.text('Đàn A'), findsNothing);
    expect(find.text('Đàn B'), findsOneWidget);
    expect(find.text('Đã khôi phục “Đàn A”.'), findsOneWidget);
  });

  testWidgets('khôi phục lỗi: giữ dòng, hiện câu server', (tester) async {
    await pump(tester);
    api.fail = true;

    await tester.tap(find.bySemanticsLabel('Khôi phục Đàn A'));
    await tester.pumpAndSettle();

    expect(find.text('Đàn A'), findsOneWidget);
    expect(find.text('Việc đã khoá.'), findsOneWidget);
  });

  testWidgets('(d) không có quyền ghi: không có "Khôi phục"', (tester) async {
    await pump(tester, canRestore: false);

    expect(find.byType(TaskCard), findsNWidgets(2));
    expect(find.text('Khôi phục'), findsNothing);
  });

  testWidgets('chạm thẻ mở chi tiết việc', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Đàn B'));
    await tester.pumpAndSettle();
    expect(find.text('chi tiet t2'), findsOneWidget);
  });

  testWidgets('rỗng: lời nhắn trống', (tester) async {
    await pump(tester, archived: const []);

    expect(find.text('Chưa có việc nào được lưu trữ'), findsOneWidget);
  });

  test('archivedTasksProvider đi hết các trang', () async {
    final many = [for (var i = 0; i < 103; i++) task('t$i', 'Việc $i')];
    final fake = _ArchiveApi(many);
    final container = ProviderContainer(
      overrides: [tasksApiProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final sub = container.listen(archivedTasksProvider(planId), (_, _) {});
    addTearDown(sub.close);
    final items = await container.read(archivedTasksProvider(planId).future);

    expect(items, hasLength(103));
    expect(fake.lists.map((c) => c.$3), [1, 2]);
  });
}

class _ArchiveApi implements TasksApi {
  _ArchiveApi(this._archived);

  final List<Task> _archived;
  final lists = <(String, TaskArchiveScope, int)>[];
  final archives = <(String, bool)>[];
  bool fail = false;

  @override
  Future<Paged<Task>> list({
    required String projectId,
    String? search,
    TaskArchiveScope archived = TaskArchiveScope.active,
    int page = 1,
    int perPage = 100,
  }) async {
    lists.add((projectId, archived, page));
    final live = [
      for (final t in _archived)
        if (!archives.any((a) => a.$1 == t.id)) t,
    ];
    final start = (page - 1) * perPage;
    return Paged(
      items: start >= live.length
          ? const []
          : live.sublist(start, (start + perPage).clamp(0, live.length)),
      pagination: const ApiPagination.empty(),
    );
  }

  @override
  Future<Task> setArchived(String taskId, bool archived) async {
    if (fail) {
      throw const ValidationException('Việc đã khoá.');
    }
    archives.add((taskId, archived));
    return Task.fromJson({'id': taskId, 'title': 'x', 'archived': archived});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
