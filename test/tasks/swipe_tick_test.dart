import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/notifications/application/notifications_providers.dart';
import 'package:omni_app/modules/notifications/data/notifications_api.dart';
import 'package:omni_app/modules/notifications/domain/app_notification.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/my_tasks_page.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_card.dart';

/// Vuốt phải một thẻ ở "Việc của tôi" là tick công đoạn kế tiếp.
///
/// Thao tác lặp nhiều nhất trong ngày của người thợ là "xong một công đoạn":
/// mở thẻ, cuộn tới việc con, tick, quay lại — bốn bước cho một cái tick, tay
/// còn dính dầu. Mọi app việc trên thị trường cho tick ngay trên danh sách; ở
/// đây một thẻ là một cây đàn, nên "tick" là tick công đoạn ĐANG MỞ đầu tiên,
/// và nhãn nói rõ tên nó trước khi buông tay.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _RecordingApi api;

  Map<String, dynamic> taskJson({List<Map<String, dynamic>>? checklist}) => {
    'id': 't1',
    'title': 'KAWAI HAT-5',
    'project_name': 'Phục chế T9',
    'checklist':
        checklist ??
        [
          {'id': 's1', 'title': 'Vệ sinh máy', 'done': true},
          {'id': 's2', 'title': 'Body ngoài', 'done': false},
          {'id': 's3', 'title': 'Lên dây', 'done': false},
        ],
  };

  Widget host() => ProviderScope(
    overrides: [
      tasksApiProvider.overrideWithValue(api),
      notificationsApiProvider.overrideWithValue(_NoNotifications()),
      notificationRealtimeProvider.overrideWithValue(null),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const MyTasksPage(),
    ),
  );

  Future<void> swipe(WidgetTester tester) async {
    await tester.drag(find.byType(TaskCard), const Offset(400, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('vuốt phải thì công đoạn đang mở ĐẦU TIÊN được tick', (
    tester,
  ) async {
    api = _RecordingApi([taskJson()]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('1/3 việc con'), findsOneWidget);

    await swipe(tester);

    // s1 đã xong nên bị bỏ qua; s2 là công đoạn mở đầu tiên. Không phải s3.
    expect(api.ticks, [('t1', 's2', true)]);
    // Thẻ VẪN ở đó: cây đàn chưa xong, chỉ một công đoạn xong.
    expect(find.text('KAWAI HAT-5'), findsOneWidget);
    expect(find.text('2/3 việc con'), findsOneWidget);
  });

  testWidgets('trong lúc vuốt, nhãn nói rõ công đoạn nào sắp xong', (
    tester,
  ) async {
    // Một dải xanh trơn không nói tick cái gì. Người thợ phải biết mình sắp
    // đánh dấu "Body ngoài" chứ không phải "Lên dây" TRƯỚC khi buông tay.
    api = _RecordingApi([taskJson()]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(TaskCard)),
    );
    // Hai sự kiện di chuyển như một ngón tay thật: sự kiện đầu chỉ để bộ nhận
    // cử chỉ thắng vòng phân xử, sự kiện sau mới đẩy dải ra.
    await gesture.moveBy(const Offset(60, 0));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();

    expect(find.text('Xong: Body ngoài'), findsOneWidget);

    await gesture.moveBy(const Offset(-120, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(api.ticks, isEmpty, reason: 'chưa qua ngưỡng thì không được tick');
  });

  testWidgets('có HOÀN TÁC, và hoàn tác bỏ tick đúng công đoạn đó', (
    tester,
  ) async {
    // Vuốt nhầm là chuyện của một buổi sáng. Không có đường lui thì người ta
    // sẽ không dám vuốt nữa, và tính năng chết dù vẫn chạy.
    api = _RecordingApi([taskJson()]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await swipe(tester);
    expect(find.text('2/3 việc con'), findsOneWidget);

    await tester.tap(find.text('HOÀN TÁC'));
    await tester.pumpAndSettle();

    expect(api.ticks.last, ('t1', 's2', false));
    expect(find.text('1/3 việc con'), findsOneWidget);
  });

  testWidgets('thẻ không còn công đoạn nào mở thì không vuốt được', (
    tester,
  ) async {
    api = _RecordingApi([
      taskJson(
        checklist: [
          {'id': 's1', 'title': 'Vệ sinh máy', 'done': true},
        ],
      ),
    ]);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await swipe(tester);

    expect(api.ticks, isEmpty);
    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('API lỗi thì thẻ về như cũ và NÓI RA', (tester) async {
    // Tick lạc quan rồi lặng lẽ trả về là tệ nhất: người thợ thấy 2/3 trong
    // một giây, quay lại thấy 1/3, và không biết tin cái nào.
    api = _RecordingApi([taskJson()], fail: true);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await swipe(tester);

    expect(api.ticks, isEmpty);
    expect(find.text('1/3 việc con'), findsOneWidget);
    expect(find.text('Mất mạng rồi'), findsOneWidget);
  });
}

class _RecordingApi implements TasksApi {
  _RecordingApi(this._tasks, {this.fail = false});

  final List<Map<String, dynamic>> _tasks;
  final bool fail;

  /// (taskId, subtaskId, done) theo thứ tự gọi.
  final ticks = <(String, String, bool)>[];

  @override
  Future<Paged<Task>> mine({
    required TaskBucket bucket,
    int page = 1,
    int perPage = 20,
  }) async => Paged(
    items: _tasks.map(Task.fromJson).toList(),
    pagination: const ApiPagination(
      currentPage: 1,
      lastPage: 1,
      perPage: 20,
      total: 1,
    ),
  );

  @override
  Future<Task> setSubtaskDone(
    String taskId,
    String subtaskId, {
    required bool done,
    String? clientRequestId,
  }) async {
    if (fail) throw const NetworkException('Mất mạng rồi');
    ticks.add((taskId, subtaskId, done));

    // Giữ trạng thái "server" để lần gọi sau (hoàn tác) trả về đúng.
    final json = _tasks.firstWhere((t) => t['id'] == taskId);
    json['checklist'] = [
      for (final s in json['checklist'] as List)
        {...s as Map<String, dynamic>, if (s['id'] == subtaskId) 'done': done},
    ];

    return Task.fromJson(json);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoNotifications implements NotificationsApi {
  @override
  Future<Paged<AppNotification>> list({
    int page = 1,
    int perPage = 20,
    bool unreadOnly = false,
  }) async => const Paged.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
