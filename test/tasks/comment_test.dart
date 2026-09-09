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
import 'package:omni_app/modules/tasks/presentation/widgets/comment_section.dart';

/// Trao đổi trên một công việc (§B3).
///
/// QC không đạt thì bình luận rồi kéo cây về. Đó là chỗ duy nhất ghi lại LÝ DO
/// — nhật ký hoạt động chỉ biết cây đã chuyển cột. App chưa từng có màn hình
/// nào cho việc này, nên người thợ bị trả việc về mà không đọc được lời giải
/// thích trừ khi mở máy tính, và ở xưởng thì không ai mở máy tính.
void main() {
  late List<String> sent;

  Task task({List<TaskComment> comments = const [], int commentCount = 0}) =>
      Task(
        id: 't1',
        title: 'SCHWESTER No.53 — SN 471302',
        comments: comments,
        commentCount: commentCount,
      );

  Widget host(Task value, {bool canWrite = true}) {
    sent = [];

    return ProviderScope(
      overrides: [
        taskDetailProvider.overrideWith(() => _StubController(value, sent)),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: CommentSection(task: value, taskId: 't1', canWrite: canWrite),
        ),
      ),
    );
  }

  testWidgets('hiện tên người viết, không hiện UUID', (tester) async {
    // API tra tên từ danh sách thành viên ở mỗi lần đọc chứ không lưu tên vào
    // bình luận. Nếu chỗ này rơi về `user_id` thì màn hình hiện một UUID, thứ
    // không nói cho ai điều gì.
    await tester.pumpWidget(
      host(
        task(
          comments: [
            TaskComment(
              id: 'c1',
              body: 'Body còn xước, làm lại phần cạnh.',
              userId: '9f1c-uuid-dai-ngoang',
              userName: 'Hằng Ni',
            ),
          ],
          commentCount: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hằng Ni'), findsOneWidget);
    expect(find.text('Body còn xước, làm lại phần cạnh.'), findsOneWidget);
    expect(find.textContaining('uuid'), findsNothing);
  });

  testWidgets('người đã rời vẫn có tên, không thành bình luận vô danh', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        task(
          comments: const [
            TaskComment(id: 'c1', body: '...', userId: 'da-nghi'),
          ],
          commentCount: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Người đã rời'), findsOneWidget);
  });

  test('gửi bình luận dùng khoá `body`, không phải `content`', () async {
    // Bản trước gửi `content`, còn `CreateTaskCommentRequest` đòi `body` — mọi
    // bình luận từ app sẽ nhận 422. Không ai phát hiện vì chưa màn hình nào
    // gọi tới hàm đó. Đây là lần thứ bảy dự án này có client đoán một tên
    // trường mà server không nhận.
    final recorder = _RecordingAdapter();
    final api = TasksApi(ApiClient(Dio()..httpClientAdapter = recorder));

    await api.comment('t1', 'Đã sửa xong cạnh body.');

    final request = recorder.singleRequest;
    expect(request.method, 'POST');
    expect(request.uri.path, '/api/v1/tasks/t1/comments');
    // Khoá là `body`. Không so cả map: từ khi bình luận mang thêm danh sách
    // người được nhắc (§B3), thân yêu cầu có thêm `mentioned_user_ids` — điều
    // đó đúng, và một phép so cả map sẽ đỏ mỗi lần thêm một trường hợp lệ.
    final body = request.data as Map;
    expect(body['body'], 'Đã sửa xong cạnh body.');
    expect(body.containsKey('content'), isFalse);
  });

  testWidgets('bình luận rỗng thì KHÔNG gửi đi', (tester) async {
    await tester.pumpWidget(host(task()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byTooltip('Gửi'));
    await tester.pumpAndSettle();

    expect(sent, isEmpty);
  });

  testWidgets('gửi xong mới xoá ô nhập', (tester) async {
    // Xoá trước rồi lỗi mạng là mất chữ vừa gõ — mà ở đây chữ đó là lý do một
    // cây đàn bị trả về.
    await tester.pumpWidget(host(task()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Chưa đạt phần đồng.');
    await tester.tap(find.byTooltip('Gửi'));
    await tester.pumpAndSettle();

    expect(sent, ['Chưa đạt phần đồng.']);
    expect(find.text('Chưa đạt phần đồng.'), findsNothing);
  });

  testWidgets('nói ra phần bị cắt bớt thay vì im lặng giấu đi', (tester) async {
    // API chỉ trả về phần mới nhất. Không nói ra thì người đọc tưởng đó là
    // toàn bộ cuộc trao đổi.
    await tester.pumpWidget(
      host(
        task(
          comments: const [TaskComment(id: 'c9', body: 'Mới nhất')],
          commentCount: 12,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Còn 11 bình luận cũ hơn'), findsOneWidget);
  });

  testWidgets('không có quyền ghi và chưa có bình luận thì không chiếm chỗ', (
    tester,
  ) async {
    await tester.pumpWidget(host(task(), canWrite: false));
    await tester.pumpAndSettle();

    expect(find.text('Trao đổi'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('không có quyền ghi vẫn ĐỌC được', (tester) async {
    // Người bị trả việc về phải đọc được lý do; viết lại thì không nhất thiết.
    await tester.pumpWidget(
      host(
        task(
          comments: const [TaskComment(id: 'c1', body: 'Chưa đạt phần đồng')],
          commentCount: 1,
        ),
        canWrite: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa đạt phần đồng'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}

/// Giữ nguyên một công việc và ghi lại những gì màn hình định gửi.
class _StubController extends TaskController {
  _StubController(this._task, this._sent);

  final Task _task;
  final List<String> _sent;

  @override
  Future<TaskDetailState> build(String arg) async =>
      TaskDetailState(task: _task);

  @override
  Future<void> comment(
    String body, {
    List<String> mentionedUserIds = const [],
  }) async => _sent.add(body);
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
      jsonEncode({
        'success': true,
        'data': {'id': 't1', 'title': 'x', 'comments': [], 'comments_count': 0},
      }),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
