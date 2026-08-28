import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/notifications/data/push_api.dart';

void main() {
  late _RecordingAdapter adapter;
  late PushApi api;

  setUp(() {
    adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    api = PushApi(ApiClient(dio));
  });

  test(
    'register sends an Android token without an empty device name',
    () async {
      await api.register('android-token', 'android', deviceName: '   ');

      final request = adapter.singleRequest;
      expect(request.method, 'POST');
      expect(request.uri.path, '/api/v1/devices/push-tokens');
      expect(request.data, {'token': 'android-token', 'platform': 'android'});
    },
  );

  test('register sends iOS platform and an optional device name', () async {
    await api.register('ios-token', 'ios', deviceName: '  iPhone của Linh  ');

    expect(adapter.singleRequest.data, {
      'token': 'ios-token',
      'platform': 'ios',
      'device_name': 'iPhone của Linh',
    });
  });

  test('unregister keeps the existing token-only DELETE contract', () async {
    await api.unregister('expired-token');

    final request = adapter.singleRequest;
    expect(request.method, 'DELETE');
    expect(request.uri.path, '/api/v1/devices/push-tokens');
    expect(request.data, {'token': 'expired-token'});
  });
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
      '{"success":true,"data":{}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
