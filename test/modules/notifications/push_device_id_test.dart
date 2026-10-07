import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/device/installation_id.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/notifications/data/push_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `device_id` ổn định cho một lượt cài đặt (phần app của Đợt 8 B2, NT-I9).
///
/// API đang xoá MỌI token khác cùng `(tenant, user, platform)` mỗi lần đăng ký:
/// một người dùng điện thoại và tablet thì máy đăng ký sau đạp token của máy
/// trước, nên chỉ một máy nhận được thông báo. Server cần một khoá nhận dạng
/// máy; client phải gửi khoá ấy, và nó phải là CÙNG một khoá qua mọi lượt
/// đăng ký, kể cả sau khi token FCM được cấp lại.
void main() {
  late _RecordingAdapter adapter;
  late SharedPreferences prefs;
  late PushApi api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    adapter = _RecordingAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    api = PushApi(ApiClient(dio), InstallationId(prefs));
  });

  test('đăng ký gửi device_id, lưu lại ở SharedPreferences', () async {
    await api.register('tk-1', 'android');

    final id = prefs.getString(installationIdKey);
    expect(id, isNotNull);
    expect(id, isNotEmpty);
    expect((adapter.requests.single.data! as Map)['device_id'], id);
  });

  test('cùng máy = cùng device_id qua hai lượt đăng ký', () async {
    await api.register('tk-1', 'android');
    final first = prefs.getString(installationIdKey);

    await api.register('tk-2', 'android');

    expect(first, isNotNull);
    expect(prefs.getString(installationIdKey), first);
    expect(adapter.requests.map((r) => (r.data! as Map)['device_id']), [
      first,
      first,
    ]);
  });

  test('id sống sót qua một lần mở app mới (đọc lại từ prefs)', () async {
    final first = InstallationId(prefs).value;

    expect(InstallationId(prefs).value, first);
  });

  test('id là UUID v4', () {
    final id = InstallationId(prefs).value;

    expect(
      id,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ),
      ),
    );
  });

  test('hai lượt cài khác nhau sinh id khác nhau', () async {
    final a = InstallationId(prefs).value;
    SharedPreferences.setMockInitialValues({});
    final b = InstallationId(await SharedPreferences.getInstance()).value;

    expect(a, isNot(b));
  });

  test('device_id đi cùng device_name, không thay thế nó', () async {
    await api.register('tk-1', 'ios', deviceName: 'iPhone của Linh');

    final body = adapter.requests.single.data! as Map;
    expect(body['device_name'], 'iPhone của Linh');
    expect(body['device_id'], prefs.getString(installationIdKey));
    expect(body['token'], 'tk-1');
    expect(body['platform'], 'ios');
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
