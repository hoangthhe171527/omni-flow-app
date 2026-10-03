import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/inbox/application/bulk_assign.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';

/// Gán hàng loạt gặp hội thoại Zalo/Facebook cá nhân (Đợt 5, API trả 422).
///
/// Trước đây vòng lặp dừng ở lỗi đầu tiên: hội thoại phía sau không được gán,
/// danh sách không làm mới, người dùng chỉ thấy một câu lỗi.
void main() {
  const personal422 =
      '{"success":false,"code":"personal_thread_not_reassignable","message":"Hội thoại cá nhân.","errors":{"assignee_id":["Hội thoại cá nhân."]}}';
  const assigned = '{"success":true,"data":{"id":"x","channel":"zalo"}}';

  late _RoutingAdapter adapter;
  InboxApi api() => InboxApi(ApiClient(Dio()..httpClientAdapter = adapter));

  test('422 ở giữa: vẫn gán các hội thoại sau, đếm số bỏ qua', () async {
    adapter = _RoutingAdapter({
      'a1': (200, assigned),
      'p1': (422, personal422),
      'a2': (200, assigned),
    });

    final outcome = await bulkAssign(api(), ['a1', 'p1', 'a2'], 'u7');

    expect(adapter.paths, [
      '/api/v1/inbox/conversations/a1/assign',
      '/api/v1/inbox/conversations/p1/assign',
      '/api/v1/inbox/conversations/a2/assign',
    ]);
    expect(outcome.done, 2);
    expect(outcome.skipped, 1);
    expect(outcome.error, isNull);
    expect(outcome.message, 'Đã gán 2, bỏ qua 1 hội thoại cá nhân.');
  });

  // Đợt 6 P1: 422 khác (vd người được giao đã ngưng) cũng rơi vào
  // `assignee_id`. Chỉ mã `personal_thread_not_reassignable` mới là "bỏ qua";
  // 422 không mã là lỗi thật, phải báo và giữ lựa chọn.
  test('422 không có mã: không đếm bỏ qua, báo lỗi', () async {
    adapter = _RoutingAdapter({
      'a1': (200, assigned),
      'i1': (
        422,
        '{"success":false,"message":"Người được giao đã ngưng.","errors":{"assignee_id":["Người được giao đã ngưng."]}}',
      ),
    });

    final outcome = await bulkAssign(api(), ['a1', 'i1'], 'u7');

    expect(outcome.done, 1);
    expect(outcome.skipped, 0);
    expect(outcome.error, isNotNull);
    expect(outcome.error!.message, 'Người được giao đã ngưng.');
    // Fix vòng 1 (m3): không nói "bỏ qua 0".
    expect(outcome.message, 'Đã gán 1 hội thoại. Người được giao đã ngưng.');
  });

  // Fix vòng 1 (m4): người được giao đã ngưng thì mọi hội thoại đều 422 y
  // hệt — dừng ngay ở lần đầu thay vì gọi N request.
  test('422 assignee_id không mã: dừng ở lần đầu', () async {
    adapter = _RoutingAdapter({
      'i1': (
        422,
        '{"success":false,"message":"Người được giao đã ngưng.","errors":{"assignee_id":["Người được giao đã ngưng."]}}',
      ),
      'a1': (200, assigned),
      'a2': (200, assigned),
    });

    final outcome = await bulkAssign(api(), ['i1', 'a1', 'a2'], 'u7');

    expect(adapter.paths, hasLength(1));
    expect(outcome.done, 0);
    expect(outcome.message, 'Người được giao đã ngưng.');
  });

  test('không lỗi: câu báo như cũ', () async {
    adapter = _RoutingAdapter({'a1': (200, assigned), 'a2': (200, assigned)});

    final outcome = await bulkAssign(api(), ['a1', 'a2'], 'u7');

    expect(outcome.message, 'Đã gán 2 hội thoại.');
  });

  test(
    'lỗi thật (500) không chặn các hội thoại sau, và được giữ lại để báo',
    () async {
      adapter = _RoutingAdapter({
        'x1': (500, '{"success":false,"message":"Máy chủ lỗi."}'),
        'a1': (200, assigned),
      });

      final outcome = await bulkAssign(api(), ['x1', 'a1'], 'u7');

      expect(adapter.paths, hasLength(2));
      expect(outcome.done, 1);
      expect(outcome.error, isNotNull);
    },
  );
}

/// Trả phản hồi theo id hội thoại trong đường `/inbox/conversations/{id}/assign`.
class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter(this.byId);

  final Map<String, (int, String)> byId;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.uri.path);
    final segments = options.uri.pathSegments;
    final id = segments.length >= 2 ? segments[segments.length - 2] : '';
    final (status, body) = byId[id] ?? (500, '{"message":"route lạ"}');

    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
