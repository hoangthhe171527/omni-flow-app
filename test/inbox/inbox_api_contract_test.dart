import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';

/// Hợp đồng Hộp thư, dựng từ JSON THẬT của API (Đợt 7 P2).
///
/// - `GET /inbox/changes` trả `{success, data:[…], cursor, has_more}`: con trỏ
///   nằm NGANG `data`, không trong nó (`InboxController::changes` gộp kết quả
///   `InboxChangesQuery` vào gốc). Đọc trong `data` thì cursor luôn `''`, mỗi
///   lượt poll là lượt khởi tạo và lưới an toàn khi mất socket chết hẳn
///   (INB-I19).
/// - `POST …/pin` trả `{success, pinned}` ở gốc (INB-I21).
void main() {
  test('changes đọc cursor ở gốc phản hồi', () async {
    final adapter = _JsonAdapter(
      '{"success":true,"data":[{"type":"conversation","conversation_id":"c1"}],'
      '"cursor":"2026-10-05T01:02:03.000Z","has_more":false}',
    );
    final api = InboxApi(ApiClient(Dio()..httpClientAdapter = adapter));

    final changes = await api.changes(null);

    expect(changes.cursor, '2026-10-05T01:02:03.000Z');
    expect(changes.count, 1);
    expect(adapter.requests.single.uri.path, '/api/v1/inbox/changes');
  });

  // Đợt 7 P4 (APP-I3): danh sách theo con trỏ (`cursor=1`, rồi `before=`)
  // như web; API trả `pagination: {per_page, has_more, next_before}`.
  group('list theo con trỏ', () {
    const body =
        '{"success":true,"data":[{"id":"c1","channel":"zalo"}],'
        '"pagination":{"per_page":30,"has_more":true,"next_before":"abc"}}';

    test('trang đầu gửi cursor=1, không gửi page', () async {
      final adapter = _JsonAdapter(body);
      final api = InboxApi(ApiClient(Dio()..httpClientAdapter = adapter));

      final page = await api.list(query: const {'status': 'open'});

      final q = adapter.requests.single.uri.queryParameters;
      expect(q['cursor'], '1');
      expect(q.containsKey('page'), isFalse);
      expect(q.containsKey('before'), isFalse);
      expect(q['status'], 'open');
      expect(page.items.single.id, 'c1');
      expect(page.cursor.hasMore, isTrue);
      expect(page.cursor.nextBefore, 'abc');
    });

    test('trang sau gửi before, không gửi cursor/page', () async {
      final adapter = _JsonAdapter(body);
      final api = InboxApi(ApiClient(Dio()..httpClientAdapter = adapter));

      await api.list(query: const {}, before: 'abc');

      final q = adapter.requests.single.uri.queryParameters;
      expect(q['before'], 'abc');
      expect(q.containsKey('cursor'), isFalse);
      expect(q.containsKey('page'), isFalse);
    });
  });

  test('togglePin đọc pinned ở gốc phản hồi', () async {
    final api = InboxApi(
      ApiClient(
        Dio()
          ..httpClientAdapter = _JsonAdapter('{"success":true,"pinned":true}'),
      ),
    );

    expect(await api.togglePin('c1', 'm1'), isTrue);
  });

  test('togglePin bỏ ghim → false', () async {
    final api = InboxApi(
      ApiClient(
        Dio()
          ..httpClientAdapter = _JsonAdapter('{"success":true,"pinned":false}'),
      ),
    );

    expect(await api.togglePin('c1', 'm1'), isFalse);
  });

  test('setStatus gửi PUT status=closed và đọc hội thoại về', () async {
    final adapter = _JsonAdapter(
      '{"success":true,"data":{"id":"c1","channel":"zalo","status":"closed"}}',
    );
    final api = InboxApi(ApiClient(Dio()..httpClientAdapter = adapter));

    final updated = await api.setStatus('c1', ConversationStatus.closed);

    final request = adapter.requests.single;
    expect(request.method, 'PUT');
    expect(request.uri.path, '/api/v1/inbox/conversations/c1');
    expect(request.data, {'status': 'closed'});
    expect(updated.status, ConversationStatus.closed);
  });

  test('quickReplies: data null (tenant chưa cài) → null', () async {
    final api = InboxApi(
      ApiClient(
        Dio()..httpClientAdapter = _JsonAdapter('{"success":true,"data":null}'),
      ),
    );
    expect(await api.quickReplies(), isNull);
  });

  test('quickReplies đọc title/body', () async {
    final adapter = _JsonAdapter(
      '{"success":true,"data":[{"id":"q1","title":"Chào","body":"Dạ em chào chị ạ"}]}',
    );
    final api = InboxApi(ApiClient(Dio()..httpClientAdapter = adapter));
    final replies = await api.quickReplies();
    expect(adapter.requests.single.uri.path, '/api/v1/inbox/quick-replies');
    expect(replies!.single.title, 'Chào');
    expect(replies.single.body, 'Dạ em chào chị ạ');
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);

  final String body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
