import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/settings/data/avatar_api.dart';

void main() {
  late Directory temp;
  late File image;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('omni-avatar-api-');
    image = File('${temp.path}/avatar.jpg')..writeAsBytesSync([1, 2, 3]);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('trả đúng URL avatar do server sinh', () async {
    final recorder = _Recorder({
      'success': true,
      'data': {'avatar': '/api/v1/auth/avatar/new.jpg'},
    });
    final api = AvatarApi(ApiClient(Dio()..httpClientAdapter = recorder));

    expect(await api.upload(image.path), '/api/v1/auth/avatar/new.jpg');
    expect(recorder.single.method, 'POST');
    expect(recorder.single.uri.path, '/api/v1/auth/avatar');
  });

  test('không báo thành công khi phản hồi thiếu URL avatar', () async {
    final recorder = _Recorder({'success': true, 'data': <String, dynamic>{}});
    final api = AvatarApi(ApiClient(Dio()..httpClientAdapter = recorder));

    await expectLater(
      api.upload(image.path),
      throwsA(
        isA<ServerException>().having(
          (error) => error.code,
          'code',
          'avatar_missing',
        ),
      ),
    );
  });

  test('xoá ảnh gọi đúng endpoint tự phục vụ', () async {
    final recorder = _Recorder({'success': true, 'data': <String, dynamic>{}});
    final api = AvatarApi(ApiClient(Dio()..httpClientAdapter = recorder));

    await api.remove();

    expect(recorder.single.method, 'DELETE');
    expect(recorder.single.uri.path, '/api/v1/auth/avatar');
  });
}

class _Recorder implements HttpClientAdapter {
  _Recorder(this.body);

  final Map<String, dynamic> body;
  final requests = <RequestOptions>[];

  RequestOptions get single {
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
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
