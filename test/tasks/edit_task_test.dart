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

/// Người giao việc sửa được MỌI thứ ngay trên điện thoại.
///
/// Bảng điều phối trước đây chỉ đọc: hạn, ưu tiên, tên việc, mô tả đều phải mở
/// máy tính mới đổi được. Với một quản đốc đứng giữa nhà xưởng thì "phải mở máy
/// tính" và "không làm được" là một.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  late _RecordingAdapter adapter;

  Task taskWith(Map<String, dynamic> extra) => Task.fromJson({
    'id': 't1',
    'title': 'KAWAI HAT-5',
    'project_id': 'p1',
    'priority': 'med',
    ...extra,
  });

  Widget host({Set<String> permissions = assigner, Task? task}) {
    adapter = _RecordingAdapter();

    return ProviderScope(
      overrides: [
        tasksApiProvider.overrideWithValue(
          TasksApi(ApiClient(Dio()..httpClientAdapter = adapter)),
        ),
        taskDetailProvider.overrideWith(
          () => _StubDetail(TaskDetailState(task: task ?? taskWith(const {}))),
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

  Map<String, dynamic> sentBody() =>
      Map<String, dynamic>.from(adapter.singleRequest.data as Map);

  group('hạn', () {
    testWidgets('chưa có hạn thì mở thẳng lịch, không hỏi thêm', (
      tester,
    ) async {
      // Chưa có hạn thì "xoá hạn" là lựa chọn vô nghĩa, và thêm một lần chạm
      // để tới cái duy nhất làm được là thêm một lần chạm thừa.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chưa đặt hạn'));
      await tester.pumpAndSettle();

      expect(find.text('OK'), findsOneWidget, reason: 'lịch phải mở ngay');
    });

    testWidgets('đã có hạn thì XOÁ được', (tester) async {
      // Đặt nhầm ngày rồi kẹt luôn thì lần sau người ta không dám đặt nữa.
      await tester.pumpWidget(host(task: taskWith({'due_date': '2026-12-31'})));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('31/12/2026'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xoá hạn'));
      await tester.pumpAndSettle();

      // Chuỗi RỖNG, không phải null: API lọc bỏ trường null, nên gửi null sẽ
      // lặng lẽ không xoá gì.
      expect(sentBody(), {'due_date': ''});
    });
  });

  group('ưu tiên', () {
    testWidgets('đổi được, và gửi mã API chứ không gửi nhãn tiếng Việt', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bình thường'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cao').last);
      await tester.pumpAndSettle();

      expect(sentBody(), {'priority': 'high'});
    });

    testWidgets('chọn lại đúng mức đang có thì KHÔNG gọi API', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bình thường'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bình thường').last);
      await tester.pumpAndSettle();

      expect(adapter.requests, isEmpty);
    });
  });

  group('tên việc', () {
    testWidgets('sửa được bằng cách chạm vào chính cái tên', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('KAWAI HAT-5'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'KAWAI HAT-5 — SN 2308512',
      );
      await tester.pump();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(sentBody(), {'title': 'KAWAI HAT-5 — SN 2308512'});
    });

    testWidgets('không cho lưu tên rỗng', (tester) async {
      // Một công việc không tên thì không tìm lại được trên bảng.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('KAWAI HAT-5'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Lưu'),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('không đổi gì thì nút Lưu tắt', (tester) async {
      // Lưu lại đúng nội dung cũ vẫn chạm updated_at và đẻ ra một dòng nhật ký
      // nói có người sửa — trong khi không ai sửa gì.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.text('KAWAI HAT-5'));
      await tester.pumpAndSettle();

      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Lưu'),
      );
      expect(save.onPressed, isNull);
    });
  });

  group('mô tả', () {
    testWidgets('chưa có mô tả thì vẫn có chỗ để thêm', (tester) async {
      // Không hiện khối mô tả khi trống thì không có chỗ nào thêm lần đầu.
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      expect(find.text('Thêm mô tả…'), findsOneWidget);
    });

    testWidgets('xoá sạch mô tả là lựa chọn hợp lệ', (tester) async {
      await tester.pumpWidget(
        host(task: taskWith({'description': 'Khách dặn giữ nguyên phím ngà'})),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Khách dặn giữ nguyên phím ngà'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();

      expect(sentBody(), {'description': ''});
    });
  });

  group('người nhận việc', () {
    testWidgets('không sửa được gì trong bảng điều phối', (tester) async {
      // Bảng điều phối là của người giao việc. Cho thợ thấy nút sửa là mời họ
      // làm một việc API sẽ từ chối.
      await tester.pumpWidget(host(permissions: worker));
      await tester.pumpAndSettle();

      // Thợ VẪN thấy hạn — dưới dạng chip chỉ đọc ở đầu màn, vì đó là thứ họ
      // cần biết để làm việc. Thứ họ không có là cách đổi nó.
      expect(find.text('Điều phối'), findsNothing);
      expect(find.text('Thêm mô tả…'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
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
      '{"success":true,"data":{"id":"t1","title":"x"}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
