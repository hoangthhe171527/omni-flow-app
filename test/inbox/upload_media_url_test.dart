import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';

/// Ảnh app gửi cho khách phải mang ĐÚNG URL server trả về (APP-I1).
///
/// URL đó đi tiếp vào POST /messages, và nền tảng (Zalo/FB) tải ảnh từ chính
/// URL ấy. Trước đây kết quả upload chạy qua `resolveMediaUrl`, bị dựng lại
/// thành một URL mất `<tenant>/`: khách nhận một ảnh 404.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('omni_upload_test');
  });

  tearDown(() async {
    // Windows có thể còn giữ tệp (luồng multipart chưa đóng hẳn): dọn được
    // thì dọn, không được thì để hệ điều hành dọn thư mục tạm.
    try {
      await dir.delete(recursive: true);
    } on FileSystemException {
      // bỏ qua
    }
  });

  test('uploadMedia trả url nguyên văn của server', () async {
    const serverUrl = 'https://api.that.vn/api/v1/inbox/media/t-9/u.jpg';
    final adapter = _JsonAdapter(
      '{"success":true,"data":{"url":"$serverUrl","type":"image","name":"u.jpg"}}',
    );
    final api = InboxApi(ApiClient(Dio()..httpClientAdapter = adapter));
    final file = File('${dir.path}/u.jpg')..writeAsBytesSync([1, 2, 3]);

    final attachment = await api.uploadMedia(file.path, filename: 'u.jpg');

    expect(adapter.requests.single.uri.path, '/api/v1/inbox/media');
    expect(attachment.url, serverUrl);
    expect(attachment.type, 'image');
    expect(attachment.name, 'u.jpg');
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
