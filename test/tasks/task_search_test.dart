import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/task_search_page.dart'
    show TaskSearchPage, kTaskSearchDebounce;

/// "Cây SN 471302 đang ở đâu."
///
/// Ở xưởng người ta gọi cây đàn bằng số máy. Khách gọi điện hỏi cây của họ, và
/// câu trả lời nằm rải trong bảy cột của hai dự án — app trước đây không có
/// đường nào tới nó ngoài việc lướt từng cột.
///
/// `pumpAndSettle` KHÔNG đủ để vượt quãng lặng gõ phím: nó bơm tới khi không
/// còn khung hình nào được xếp lịch, mà một `Timer` đang chờ thì không xếp
/// khung hình nào. Không đẩy đồng hồ giả qua mốc ấy thì mọi bài dưới đây đều
/// "xanh" vì lượt tìm chưa từng chạy — hạng test tệ nhất.
Duration _past(Duration debounce) =>
    debounce + const Duration(milliseconds: 50);

void main() {
  Widget host(TasksApi api) => ProviderScope(
    overrides: [tasksApiProvider.overrideWithValue(api)],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const TaskSearchPage(),
    ),
  );

  testWidgets('ô rỗng thì KHÔNG gọi mạng', (tester) async {
    // `search=` trống ở API nghĩa là "không lọc", tức là trả về toàn bộ công
    // việc của xưởng — 500 dòng hiện ra trước khi người dùng kịp gõ chữ đầu.
    final api = _RecordingTasksApi();
    await tester.pumpWidget(host(api));
    await tester.pumpAndSettle();

    expect(api.queries, isEmpty);
    expect(find.text('Tìm một cây đàn'), findsOneWidget);
  });

  testWidgets('chờ người dùng ngừng gõ rồi mới gọi MỘT lượt', (tester) async {
    // Mỗi ký tự một lượt đi mạng xưởng là cách một ô tìm kiếm trở thành thứ
    // không ai dùng được lúc wifi yếu.
    final api = _RecordingTasksApi();
    await tester.pumpWidget(host(api));

    await tester.enterText(find.byType(TextField), '4');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), '47');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), '4713');
    await tester.pump(_past(kTaskSearchDebounce));
    await tester.pumpAndSettle();

    expect(api.queries, ['4713']);
  });

  testWidgets('tìm ra cây đàn theo số máy nằm trong tiêu đề', (tester) async {
    final api = _RecordingTasksApi(
      hits: [
        Task.fromJson({'id': 't1', 'title': 'SCHWESTER No.53 — SN 471302'}),
      ],
    );
    await tester.pumpWidget(host(api));

    await tester.enterText(find.byType(TextField), '471302');
    await tester.pump(_past(kTaskSearchDebounce));
    await tester.pumpAndSettle();

    expect(find.text('SCHWESTER No.53 — SN 471302'), findsOneWidget);
  });

  testWidgets('không có kết quả thì nói rõ đã tìm chữ gì', (tester) async {
    // Một màn trống sau khi gõ đọc giống hệt một lượt tải hỏng.
    final api = _RecordingTasksApi();
    await tester.pumpWidget(host(api));

    await tester.enterText(find.byType(TextField), 'khong-co-cay-nay');
    await tester.pump(_past(kTaskSearchDebounce));
    await tester.pumpAndSettle();

    expect(find.textContaining('khong-co-cay-nay'), findsWidgets);
  });

  testWidgets('nút xoá hiện ngay từ ký tự đầu, không chờ hết quãng lặng', (
    tester,
  ) async {
    // Nó nói về Ô NHẬP, không nói về kết quả.
    final api = _RecordingTasksApi();
    await tester.pumpWidget(host(api));

    await tester.enterText(find.byType(TextField), 'S');
    await tester.pump();

    expect(find.byTooltip('Xoá'), findsOneWidget);
  });

  testWidgets('xoá đưa màn về lời mời tìm, không để lại kết quả cũ', (
    tester,
  ) async {
    final api = _RecordingTasksApi(
      hits: [
        Task.fromJson({'id': 't1', 'title': 'KAWAI HAT-5'}),
      ],
    );
    await tester.pumpWidget(host(api));

    await tester.enterText(find.byType(TextField), 'KAWAI');
    await tester.pump(_past(kTaskSearchDebounce));
    await tester.pumpAndSettle();
    expect(find.text('KAWAI HAT-5'), findsOneWidget);

    await tester.tap(find.byTooltip('Xoá'));
    await tester.pumpAndSettle();

    expect(find.text('KAWAI HAT-5'), findsNothing);
    expect(find.text('Tìm một cây đàn'), findsOneWidget);
  });

  test('gửi đúng đường dẫn và tìm cả trong việc ĐÃ XONG', () async {
    // Đọc thẳng yêu cầu HTTP, không hỏi một bản giả. Tám lỗi im lặng của dự
    // án này đều là client gửi một hình dạng server không nhận, và không một
    // bản giả nào bắt được: nó luôn trả lời đúng cái người viết test nghĩ
    // server sẽ trả lời.
    //
    // `bucket=all` là phần dễ mất nhất: một cây đã bàn giao tháng trước vẫn
    // phải tra lại được, và đó gần như là lý do duy nhất người ta gõ một số
    // máy vào ô tìm kiếm. Mặc định của API là ẩn việc đã xong.
    final recorder = _RecordingAdapter();
    final api = TasksApi(ApiClient(Dio()..httpClientAdapter = recorder));

    await api.search('471302');

    final request = recorder.singleRequest;
    expect(request.method, 'GET');
    expect(request.uri.path, '/api/v1/tasks');
    expect(request.uri.queryParameters['search'], '471302');
    expect(request.uri.queryParameters['bucket'], 'all');
  });
}

class _RecordingTasksApi implements TasksApi {
  _RecordingTasksApi({this.hits = const []});

  final List<Task> hits;
  final List<String> queries = [];

  @override
  Future<Paged<Task>> search(
    String query, {
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    queries.add(query);

    return Paged(
      items: hits,
      pagination: ApiPagination(
        currentPage: 1,
        lastPage: 1,
        perPage: perPage,
        total: hits.length,
      ),
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
      jsonEncode({'success': true, 'data': <Map<String, dynamic>>[]}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
