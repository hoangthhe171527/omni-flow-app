import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/rating_row.dart';

/// Điểm QC, 0–5 sao (§4, §B3).
///
/// §B3: QC đạt thì "up ảnh sau, chấm sao, kéo sang Hoàn thiện (đạt)". Web chấm
/// được từ lâu, app thì chưa — mà QC đứng ở xưởng với cây đàn trước mặt.
void main() {
  late List<int> rated;

  Task task({int rating = 0}) =>
      Task(id: 't1', title: 'SCHWESTER No.53 — SN 471302', rating: rating);

  Widget host(Task value, {bool canRate = true}) {
    rated = [];

    return ProviderScope(
      overrides: [
        taskDetailProvider.overrideWith(() => _StubController(value, rated)),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: RatingRow(task: value, taskId: 't1', canRate: canRate),
        ),
      ),
    );
  }

  testWidgets('người kiểm chấm được', (tester) async {
    await tester.pumpWidget(host(task()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('4 sao'));
    await tester.pumpAndSettle();

    expect(rated, [4]);
  });

  testWidgets('chạm lại đúng sao đang chọn là XOÁ điểm', (tester) async {
    // Chấm nhầm phải gỡ được, và không có nút nào khác để làm việc đó.
    await tester.pumpWidget(host(task(rating: 3)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('3 sao'));
    await tester.pumpAndSettle();

    expect(rated, [0]);
  });

  testWidgets('người LÀM thấy điểm nhưng không đổi được', (tester) async {
    // Ai cũng tự chấm được thì con số thôi là một đánh giá. Vẫn cho thấy: §7
    // cấm bảng xếp hạng cá nhân, không cấm một người biết việc của chính mình
    // được kiểm ra sao.
    await tester.pumpWidget(host(task(rating: 4), canRate: false));
    await tester.pumpAndSettle();

    expect(find.text('4/5'), findsOneWidget);
    for (final button in tester.widgetList<IconButton>(
      find.byType(IconButton),
    )) {
      expect(button.onPressed, isNull);
    }
  });

  testWidgets('chưa chấm và không được chấm thì không chiếm chỗ', (
    tester,
  ) async {
    await tester.pumpWidget(host(task(), canRate: false));
    await tester.pumpAndSettle();

    expect(find.text('Điểm kiểm tra'), findsNothing);
  });

  test('gửi `rating` là SỐ, kể cả khi xoá điểm', () async {
    // 0 chứ không phải null: `UpdateTaskDTO::toAttributes` lọc bỏ đúng những
    // trường null, nên null sẽ lặng lẽ không xoá gì. Cùng cái bẫy đã gặp ở
    // `section_id` và `due_date`.
    final adapter = _RecordingAdapter();
    final api = TasksApi(ApiClient(Dio()..httpClientAdapter = adapter));

    await api.setRating('t1', 0);

    expect(adapter.requests.single.method, 'PUT');
    expect(adapter.requests.single.uri.path, '/api/v1/tasks/t1');
    expect(adapter.requests.single.data, {'rating': 0});
  });

  test('điểm ngoài thang bị kẹp lại, không gửi lên nguyên trạng', () async {
    final adapter = _RecordingAdapter();
    final api = TasksApi(ApiClient(Dio()..httpClientAdapter = adapter));

    await api.setRating('t1', 9);

    expect(adapter.requests.single.data, {'rating': 5});
  });
}

class _StubController extends TaskController {
  _StubController(this._task, this._rated);

  final Task _task;
  final List<int> _rated;

  @override
  Future<TaskDetailState> build(String arg) async =>
      TaskDetailState(task: _task);

  @override
  Future<void> setRating(int rating) async => _rated.add(rating);
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'id': 't1', 'title': 'x'},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
