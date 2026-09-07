import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
import 'package:omni_app/security/permissions/access_policy.dart';

/// Dựng checklist ngay trên điện thoại.
///
/// Trước đây việc con chỉ TICK được: thêm một công đoạn, sửa một cái tên gõ
/// nhầm, bỏ một mục thừa đều phải mở máy tính — mà người dựng checklist là quản
/// đốc, người đứng giữa nhà xưởng.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  late _RecordingAdapter adapter;

  final task = Task.fromJson({
    'id': 't1',
    'title': 'KAWAI HAT-5',
    'project_id': 'p1',
    'priority': 'med',
    'checklist': [
      {'id': 'c1', 'title': 'Tháo máy', 'done': false},
      {'id': 'c2', 'title': 'Body ngaoi', 'done': false},
    ],
  });

  Widget host({Set<String> permissions = assigner}) {
    adapter = _RecordingAdapter();

    return ProviderScope(
      overrides: [
        tasksApiProvider.overrideWithValue(
          TasksApi(ApiClient(Dio()..httpClientAdapter = adapter)),
        ),
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
  }

  RequestOptions sent() => adapter.singleRequest;

  /// Khung mặc định của flutter_test là 800×600 — thấp hơn một màn điện thoại,
  /// nên nút cuối danh sách việc con nằm ngoài vùng chạm được và mọi tap đều
  /// trượt. Đặt khung cao như máy thật.
  Future<void> pumpApp(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  Future<void> openActions(WidgetTester tester) async {
    // Hàng thứ hai ("Body ngaoi") — cái gõ nhầm.
    await tester.tap(find.byIcon(Icons.more_horiz_rounded).last);
    await tester.pumpAndSettle();
  }

  group('thêm', () {
    testWidgets('thêm được một việc con mới', (tester) async {
      await pumpApp(tester, host());

      await tester.tap(find.text('Thêm việc con'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Lên dây');
      await tester.pump();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(sent().method, 'POST');
      expect(sent().uri.path, '/api/v1/tasks/t1/checklist');
      expect(sent().data, {'title': 'Lên dây'});
    });

    testWidgets('không cho thêm việc con không tên', (tester) async {
      await pumpApp(tester, host());

      await tester.tap(find.text('Thêm việc con'));
      await tester.pumpAndSettle();

      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Lưu'),
      );
      expect(save.onPressed, isNull);
    });
  });

  group('đổi tên', () {
    testWidgets('sửa được cái tên gõ nhầm', (tester) async {
      await pumpApp(tester, host());

      await openActions(tester);
      await tester.tap(find.text('Đổi tên'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Body ngoài');
      await tester.pump();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(sent().method, 'PATCH');
      expect(sent().uri.path, '/api/v1/tasks/t1/checklist/c2');
      expect(sent().data, {'title': 'Body ngoài'});
    });
  });

  group('xoá', () {
    testWidgets('xoá được, và nút xoá phải CỐ Ý mở ra mới thấy', (
      tester,
    ) async {
      // Hàng việc con là chỗ thợ chạm hàng chục lần một ca với tay bẩn. Một
      // nút thùng rác nằm ngay đó là một cái bẫy.
      await pumpApp(tester, host());

      expect(find.text('Xoá việc con'), findsNothing);

      await openActions(tester);
      expect(find.text('Xoá việc con'), findsOneWidget);

      await tester.tap(find.text('Xoá việc con'));
      await tester.pumpAndSettle();

      expect(sent().method, 'DELETE');
      expect(sent().uri.path, '/api/v1/tasks/t1/checklist/c2');
    });
  });

  group('người nhận việc', () {
    testWidgets('tick được nhưng KHÔNG đổi được danh sách', (tester) async {
      // Thợ tick chứ không đổi danh sách việc phải làm — đó là việc của người
      // dựng quy trình.
      await pumpApp(tester, host(permissions: worker));

      expect(find.text('Tháo máy'), findsOneWidget);
      expect(find.text('Thêm việc con'), findsNothing);
      expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    });
  });
}

class _StubDetail extends TaskController {
  _StubDetail(this._state);

  final TaskDetailState _state;

  @override
  Future<TaskDetailState> build(String taskId) async => _state;
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  RequestOptions get singleRequest {
    expect(requests, hasLength(1));
    return requests.single;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    return ResponseBody.fromString(
      '{"success":true,"data":{"id":"t1","title":"KAWAI HAT-5","checklist":[]}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
