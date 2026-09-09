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

/// Việc con ĐẦU TIÊN của một công việc còn trống.
///
/// test/tasks/edit_subtask_test.dart đã kiểm "thêm việc con", nhưng task mẫu
/// của nó có sẵn hai việc con — nên nó không bao giờ chạm vào trạng thái duy
/// nhất bị hỏng: checklist rỗng, đúng trạng thái của MỌI công việc vừa tạo.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  late _RecordingAdapter adapter;

  // Công việc vừa tạo: create_task_page không gửi checklist, nên danh sách
  // công đoạn luôn bắt đầu từ rỗng.
  final task = Task.fromJson({
    'id': 't1',
    'title': 'KAWAI HAT-5',
    'project_id': 'p1',
    'priority': 'med',
    'checklist': <Map<String, dynamic>>[],
  });

  Widget host() {
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
          TaskAccess.of(AccessPolicy(assigner)),
        ),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const TaskDetailPage(taskId: 't1'),
      ),
    );
  }

  testWidgets('dựng được công đoạn đầu tiên khi danh sách còn rỗng', (
    tester,
  ) async {
    // Khung mặc định 800×600 thấp hơn máy thật, nút cuối trang sẽ nằm ngoài
    // vùng chạm được.
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Thêm việc con'), findsOneWidget);

    await tester.tap(find.text('Thêm việc con'));
    await tester.pumpAndSettle();
    await tester.enterText(sheetField, 'Tháo máy');
    await tester.pump();
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    final sent = adapter.singleRequest;
    expect(sent.method, 'POST');
    expect(sent.uri.path, '/api/v1/tasks/t1/checklist');
    expect(sent.data, {'title': 'Tháo máy'});
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
      '{"success":true,"data":{"id":"t1","title":"KAWAI HAT-5","checklist":[{"id":"c1","title":"Tháo máy","done":false}]}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Ô nhập của sheet đang mở: màn chi tiết có sẵn ô viết trao đổi ở cuối trang,
/// nên `find.byType(TextField)` khớp hai ô. Sheet luôn tự lấy tiêu điểm.
final sheetField = find.byWidgetPredicate((w) => w is TextField && w.autofocus);
