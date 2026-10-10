import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/notifications/data/notifications_api.dart';

/// Khoá khớp `NotificationController@index` (`$request->boolean('unread')`,
/// `per_page`, `page`) và routes.php của module Notification.
void main() {
  late _Recorder rec;
  late NotificationsApi api;

  setUp(() {
    rec = _Recorder();
    api = NotificationsApi(ApiClient(Dio()..httpClientAdapter = rec));
  });

  test('Chưa đọc gửi đúng khoá unread; Tất cả không gửi khoá', () async {
    await api.list(unreadOnly: true);
    expect(rec.last.method, 'GET');
    expect(rec.last.uri.path, endsWith('/notifications'));
    expect(rec.last.uri.queryParameters['unread'], 'true');
    await api.list();
    expect(rec.last.uri.queryParameters.containsKey('unread'), isFalse);
  });

  test('phân trang gửi đúng page và per_page', () async {
    await api.list(page: 3, perPage: 20);
    expect(rec.last.uri.queryParameters['page'], '3');
    expect(rec.last.uri.queryParameters['per_page'], '20');
  });

  test('đếm chưa đọc / đánh dấu đã đọc đúng đường dẫn', () async {
    await api.unreadCount();
    expect(rec.last.method, 'GET');
    expect(rec.last.uri.path, endsWith('/notifications/unread-count'));
    await api.markRead('n1');
    expect(rec.last.method, 'POST');
    expect(rec.last.uri.path, endsWith('/notifications/n1/mark-read'));
    await api.markAllRead();
    expect(rec.last.method, 'POST');
    expect(rec.last.uri.path, endsWith('/notifications/mark-all-read'));
  });
}

class _Recorder implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  RequestOptions get last => requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{"success":true,"data":{"count":0}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
