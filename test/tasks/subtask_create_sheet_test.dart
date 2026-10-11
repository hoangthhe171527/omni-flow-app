import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Sheet "Việc con mới" (`SubtaskCreate.dc.html`): Huỷ / Việc con mới / Tạo,
/// ô tên, người làm. Chạy qua controller THẬT và HTTP giả để chốt chuỗi
/// `POST checklist {title}` rồi `PATCH checklist/{id} {assignee_id}`.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  late _Adapter adapter;

  Widget host({int patchStatus = 200}) {
    adapter = _Adapter(patchStatus);
    final task = Task.fromJson({
      'id': 't1',
      'title': 'YAMAHA U3E',
      'project_id': 'p1',
      'checklist': [
        {'id': 'c1', 'title': 'Lấy đàn về xưởng', 'done': true},
      ],
    });

    return ProviderScope(
      overrides: [
        tasksApiProvider.overrideWithValue(
          TasksApi(ApiClient(Dio()..httpClientAdapter = adapter)),
        ),
        taskDetailProvider.overrideWith(
          () => _Seeded(TaskDetailState(task: task)),
        ),
        planCustomFieldsProvider.overrideWith((ref, id) async => const []),
        projectMembersProvider.overrideWith(
          (ref, id) async => [
            TeamMember(membershipId: 'm1', userId: 'u1', name: 'Khánh'),
            TeamMember(membershipId: 'm2', userId: 'u2', name: 'Linh'),
          ],
        ),
        taskAccessProvider.overrideWithValue(
          TaskAccess.of(const AccessPolicy(assigner)),
        ),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const TaskDetailPage(taskId: 't1'),
      ),
    );
  }

  Future<void> openSheet(WidgetTester t, Widget app) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    await t.pumpWidget(app);
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Thêm việc con'));
    await t.pumpAndSettle();
  }

  final nameField = find.byWidgetPredicate(
    (w) => w is TextField && w.autofocus,
  );

  Finder createButton() => find.widgetWithText(TextButton, 'Tạo');

  testWidgets('đầu sheet: Huỷ / "Việc con mới" / Tạo (mờ khi tên rỗng)', (
    t,
  ) async {
    await openSheet(t, host());
    expect(find.text('Huỷ'), findsOneWidget);
    expect(find.text('Việc con mới'), findsOneWidget);
    expect(t.widget<TextButton>(createButton()).onPressed, isNull);
    expect(t.getSize(createButton()).height, greaterThanOrEqualTo(44));
    await t.enterText(nameField, 'Thay nỉ búa');
    await t.pump();
    expect(t.widget<TextButton>(createButton()).onPressed, isNotNull);
  });

  testWidgets('(d) "Thay nỉ búa" + chọn Khánh: POST rồi PATCH assignee_id', (
    t,
  ) async {
    await openSheet(t, host());
    await t.enterText(nameField, 'Thay nỉ búa');
    await t.pump();
    await t.tap(find.bySemanticsLabel('Chọn người làm'));
    await t.pumpAndSettle();
    await t.tap(find.text('Khánh'));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('Người làm: Khánh'), findsOneWidget);
    await t.tap(createButton());
    await t.pumpAndSettle();

    final writes = adapter.requests.where((r) => r.method != 'GET').toList();
    expect(writes, hasLength(2));
    expect(writes[0].method, 'POST');
    expect(writes[0].uri.path, '/api/v1/tasks/t1/checklist');
    expect(writes[0].data, {'title': 'Thay nỉ búa'});
    expect(writes[1].method, 'PATCH');
    expect(writes[1].uri.path, '/api/v1/tasks/t1/checklist/c9');
    expect(writes[1].data, {'assignee_id': 'u1'});
    // Sheet đóng, việc con mới có trên thẻ.
    expect(find.text('Việc con mới'), findsNothing);
    expect(find.text('Thay nỉ búa'), findsOneWidget);
  });

  testWidgets(
    'giao hỏng: việc con vẫn tạo, báo "Đã tạo nhưng chưa giao được."',
    (t) async {
      await openSheet(t, host(patchStatus: 422));
      await t.enterText(nameField, 'Thay nỉ búa');
      await t.pump();
      await t.tap(find.bySemanticsLabel('Chọn người làm'));
      await t.pumpAndSettle();
      await t.tap(find.text('Khánh'));
      await t.pumpAndSettle();
      await t.tap(createButton());
      await t.pumpAndSettle();
      expect(find.text('Đã tạo nhưng chưa giao được.'), findsOneWidget);
      expect(find.text('Thay nỉ búa'), findsOneWidget);
    },
  );

  testWidgets('không chọn người: chỉ POST', (t) async {
    await openSheet(t, host());
    await t.enterText(nameField, 'Lên dây');
    await t.pump();
    await t.tap(createButton());
    await t.pumpAndSettle();
    final writes = adapter.requests.where((r) => r.method != 'GET').toList();
    expect(writes.map((r) => r.method), ['POST']);
  });

  testWidgets('(e) API cũ: không có ô mô tả, ô ngày, chip nhanh', (t) async {
    await openSheet(t, host());
    expect(find.text('Mô tả (không bắt buộc)'), findsNothing);
    expect(find.text('Ngày bắt đầu'), findsNothing);
    for (final chip in ['Hôm nay', 'Ngày mai', 'Tuần sau']) {
      expect(find.text(chip), findsNothing, reason: chip);
    }
  });

  testWidgets('Huỷ đóng sheet, không gửi gì', (t) async {
    await openSheet(t, host());
    await t.enterText(nameField, 'Bỏ');
    await t.tap(find.text('Huỷ'));
    await t.pumpAndSettle();
    expect(find.text('Việc con mới'), findsNothing);
    expect(adapter.requests.where((r) => r.method != 'GET'), isEmpty);
  });
}

class _Seeded extends TaskController {
  _Seeded(this._state);

  final TaskDetailState _state;

  @override
  Future<TaskDetailState> build(String taskId) async => _state;
}

/// POST checklist trả việc có thêm `c9`; PATCH trả [patchStatus].
class _Adapter implements HttpClientAdapter {
  _Adapter(this.patchStatus);

  final int patchStatus;
  final List<RequestOptions> requests = [];

  static final _task = {
    'id': 't1',
    'title': 'YAMAHA U3E',
    'project_id': 'p1',
    'checklist': [
      {'id': 'c1', 'title': 'Lấy đàn về xưởng', 'done': true},
      {'id': 'c9', 'title': 'Thay nỉ búa', 'done': false},
    ],
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final failed = options.method == 'PATCH' && patchStatus != 200;

    return ResponseBody.fromString(
      failed
          ? jsonEncode({
              'success': false,
              'message': 'Người này không còn trong workspace.',
            })
          : jsonEncode({'success': true, 'data': _task}),
      failed ? patchStatus : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
