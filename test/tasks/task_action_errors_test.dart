import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_detail/task_action_bar.dart';

/// Báo hoàn thành / mở lại việc (CV-I6, CV-I15).
///
/// - Mọi lỗi từng thành "Kiểm tra mạng rồi thử lại", kể cả 422 "còn việc phụ
///   thuộc chưa xong" — người thợ thử lại mãi một việc server sẽ không bao giờ
///   nhận. Nay: chỉ nhắc mạng khi thật sự mất mạng, còn lại là lời của API.
/// - Mở lại từng gửi `in_progress`, mã server lưu nguyên mà không bảng nào có
///   cột đó. Nay gửi `doing` (API A2 còn chuẩn hoá ở server).
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _StubDetail stub;

  Future<void> pump(WidgetTester tester, {required String status}) async {
    final task = Task.fromJson({
      'id': 't1',
      'title': 'KAWAI HAT-5',
      'status': status,
      'checklist': <Map<String, dynamic>>[],
    });
    stub = _StubDetail(TaskDetailState(task: task));
    // Rung phản hồi là kênh nền tảng; không giả thì lời gọi treo mãi.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskDetailProvider.overrideWith(() => stub)],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                // Nạp controller trước khi bấm, như màn chi tiết.
                ref.watch(taskDetailProvider('t1'));
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: TaskActionBar(
                    task: task,
                    canComplete: true,
                    canAttach: false,
                    taskId: 't1',
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('422 phụ thuộc → snackbar là lời của API', (tester) async {
    await pump(tester, status: 'doing');
    stub.error = const ValidationException(
      'Không thể hoàn thành: còn công việc phụ thuộc chưa xong.',
    );

    await tester.tap(find.text('Hoàn thành công việc'));
    await tester.pumpAndSettle();

    expect(
      find.text('Không thể hoàn thành: còn công việc phụ thuộc chưa xong.'),
      findsOneWidget,
    );
    expect(find.textContaining('Kiểm tra mạng'), findsNothing);
  });

  testWidgets('mất mạng → nhắc mạng', (tester) async {
    await pump(tester, status: 'doing');
    stub.error = const NetworkException('Không có kết nối mạng.');

    await tester.tap(find.text('Hoàn thành công việc'));
    await tester.pumpAndSettle();

    expect(
      find.text('Chưa lưu được. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
  });

  testWidgets('mở lại công việc → gửi doing', (tester) async {
    await pump(tester, status: 'done');
    stub.error = const ValidationException('dừng ở đây');

    await tester.tap(find.text('Mở lại công việc'));
    await tester.pumpAndSettle();

    expect(stub.sent, ['doing']);
  });
}

class _StubDetail extends TaskController {
  _StubDetail(this._state);

  final TaskDetailState _state;
  final sent = <String>[];
  Object? error;

  @override
  Future<TaskDetailState> build(String taskId) async => _state;

  @override
  Future<void> setStatus(String status) async {
    sent.add(status);
    if (error case final e?) throw e;
  }
}
