import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/settings/data/appearance_api.dart';

/// Ghi lựa chọn nền lên tài khoản đúng đường và đúng khoá server đòi.
void main() {
  test('PUT /auth/appearance với đúng khoá `background`', () async {
    final rec = _RecordingAdapter();
    final api = AppearanceApi(ApiClient(Dio()..httpClientAdapter = rec));

    await api.setBackground('walnut');

    final r = rec.requests.single;
    expect(r.method, 'PUT');
    expect(r.uri.path, '/api/v1/auth/appearance');
    expect((r.data as Map)['background'], 'walnut');
  });

  test('null GỬI khoá với giá trị null — bỏ khoá là server trả 422', () async {
    final rec = _RecordingAdapter();
    final api = AppearanceApi(ApiClient(Dio()..httpClientAdapter = rec));

    await api.setBackground(null);

    final body = rec.requests.single.data as Map;
    expect(body.containsKey('background'), isTrue);
    expect(body['background'], isNull);
  });
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
    final sent = options.data is Map
        ? (options.data as Map)['background']
        : null;

    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'background': sent},
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
