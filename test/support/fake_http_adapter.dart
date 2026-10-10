import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Bộ chuyển HTTP giả cho test gọi API: trả một status/body cố định và
/// ghi lại mọi request đã gửi.
String envelope(Object data) => jsonEncode({'success': true, 'data': data});

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.status, this.body);

  final int status;
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
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
